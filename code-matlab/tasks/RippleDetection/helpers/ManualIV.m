function ManualIV(cfg_in,varargin)
% MANUALIV Manually identify intervals in LFP and/or spike train data.
%
% MANUALIV(cfg,varargin) plots S (spiketrain) and/or CSC (LFP)and allows 
% the user to manually identify intervals by clicking on the figure to produce a 
% containment window. The order that S and CSC are passed in does not
% matter. * Do not use more than one S or more than one CSC.
%
% MANUALIV(cfg,S) 
% MANUALIV(cfg,CSC) 
% MANUALIV(cfg,S,CSC) or MANUALIV(cfg,CSC,S) 
%
% Use keyboard input to navigate to different areas of the plot (type "doc
% navigate" in the command window, or the letter h on your keyboard). 
% When you see a data region you want to keep, click on the center of the
% region (if mode is 'fixed') or click on the beginning and end (if the
% mode is 'unfixed'). The interval will plot in an orange color. If you
% want to keep the interval, hit 'Enter'. The interval will now appear in
% green. Once you've hit Enter there's no way to undo the choice, so don't 
% mess up. When an interval appears in orange, clicking elsewhere on the
% figure will make it disappear.
% 
% Use the Spectrogram button to plot a spectrogram under the current
% viewing window. Change the frequency range and z axis using the
% uicontrols below the Spectrogram button. Note that ManualIV will refuse 
% to do spectrograms for window sizes that are large (because ManualIV's 
% author had a bad experience one time), and will warn you for intermediate 
% window sizes that the spectrogram burden is unfavorable.
%
%   INPUTS:
%       cfg: config struct with fields controlling function behavior
%         S: spiketrain struct. Output from LoadSpikes.
%       CSC: timestamped data (LFP, ouput from LoadCSC)
%
%   OUTPUT
%       Output is saved directly to a directory specified by the user.
%       The variable name is "IVann"
%       IVann: iv struct with fields:
%           .tstart  - [num x 1 double] start times
%           .tend    - [num x 1 double] end times
%           .label   - the CSC used (if applicable) 
%
%   CFG OPTIONS:
%
%       cfg.mode - default 'fixed'; How the manually identified intervals 
%           are defined by the user. 
%           'fixed':  all events have the same duration set by cfg.trapwin, 
%                     and the user clicks the center time of the event to
%                     define the interval
%         'unfixed':  events will not have the same duration, instead the 
%                     user must define start and end times for the events.
%
%       cfg.trapwin - default 0.06 seconds (60 milliseconds). Applies to
%                     'fixed' mode only.
%       cfg.segments - default []; iv struct containing start and end
%                      times for the segments you want to focus on. This
%                      allows you to navigate between regions quickly by
%                      using ui control buttons. Patch objects are plotted
%                      in the "anti" regions (this also oddly speeds up
%                      plotting).
%       cfg.resume  - default []; iv struct containing previously identified
%                     intervals . (If you don't want to do it all in one
%                     sitting, save the progress and continue later by
%                     inputting the intervals here). Note: does not verify
%                     previous configs or whether the resume intervals are
%                     from the correct session.
%       cfg.overplot - {}; send inputs to overplot() in a {1 x nArg} array.
%                      ex: {cfg_overplot,tsd1,tsd2,iv1,tsd3}. See overplot
%                      for more information about overplot's plotting.
%
%       cfg.clickColor - plot color for undecided intervals; [r g b] values 
%                        or short string like 'r' or 'b' (default orange-ish)
%       cfg.keepColor  - plot color for kept intervals; [r g b] values or
%                        short string (default green)
%       cfg.EnableRobot - Java robot automatically returns focus to figure
%                         window after user interaction with UI controls. 
%                         If there is something strange in the neighborhood, 
%                         disable robot by setting cfg.EnableRobot = 0.
%       cfg.hdr - default []; Input struct containing information you want
%                       to keep with the output. It becomes IVann.hdr.
%
% For plot appearance options, see the config specification for MultiRaster
%
% known bug: if patch objects are plotted, spectrogram for windows 8.2 s
% and above does not plot.
%
% (proposed mundane name for ducktrap: ManualIV)
% aacarey, Oct 2015 (complete rewrite from original ducktrap, Jan 2015)
% -- Dec 2015
% aacarey Dec 2017 renamed to ManualIV

%% Set cfg parameters and check inputs

% ManualIV-specific cfg options
cfg_def.mode = 'fixed'; % 'fixed' or 'unfixed'
cfg_def.segments = [];
cfg_def.trapwin = 0.06; % window size in x axis units
cfg_def.clickColor = [255/255 99/255 71/255]; % color of intervals when initially plotted
cfg_def.keepColor = [113/255 198/255 113/255]; % color of intervals that have been kept
cfg_def.resume = []; % iv struct containing previously identified intervals
cfg_def.overplot = [];
cfg_def.EnableRobot = 1;
cfg_def.hdr = [];
%cfg_def.nansub = 4; % Every nth tsd sample is replaced by nan to speed navigation. But looks bad.

% MR-specific cfg options
cfg_def.SpikeHeight = 0.4;
cfg_def.axisflag = 'spandex';
cfg_def.spkColor = 'k';
cfg_def.ivColor = 'r';
cfg_def.lfpColor = 'k';
cfg_def.lfpHeight = 15;
cfg_def.lfpMax = 15;
cfg_def.axislabel = 'on';
cfg_def.windowSize = 1;
cfg_def.openNewFig = 0;

mfun = mfilename;
cfg = ProcessConfig2(cfg_def,cfg_in); % use ProcessConfig2 because there's complications with the MR fields on cfg_in

S = []; % spike trains
cfg.lfp  = []; % continuously sampled channel 
for iVarg = 1:length(varargin)   
    if isfield(varargin{iVarg},'data') && isfield(varargin{iVarg},'label') % then it's a CSC
        cfg.lfp = varargin{iVarg}; % pass it into MultiRaster
        %cfg.lfp.data(1:cfg.nansub:end) = nan;
                
    elseif isfield(varargin{iVarg},'t')
        S = varargin{iVarg};
    end
end

if isempty(S) && ~isempty(cfg.lfp) % then user wants to see the LFP only
    S = ts;
    S.t{1}(1,1) = cfg.lfp.tvec(1); % make a fake S because MultiRaster requires this as an input in order to work
    S.t{1}(2,1) = cfg.lfp.tvec(end);
    cfg.spkColor = 'w'; % make the fake S invisible, assuming figure background is white ^_^
elseif ~isempty(S) && isempty(cfg.lfp)
    cfg = rmfield(cfg,'lfp');
elseif isempty(S) && isempty(cfg.lfp)
    error('Require CSC and/or S as inputs')
end

%% initialize some things, set global variables (any variables that are 
% here and inside of the nested functions are automatically global)

figure; subplot_nRows = 20; subplot_nCols = 1;

%~~~~~~~ MULTIRASTER; main figure plotted here ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
subplot(subplot_nRows,subplot_nCols,2:subplot_nRows)
hMR = MultiRaster(cfg,S); box on; hold on;
ax_main = gca; 
if ~isempty(cfg.overplot)
   overplot(cfg.overplot{:});
end

LFP = cfg.lfp; cfg = rmfield(cfg,'lfp'); % lfp is huge. don't let it be saved in config history

% ~~~~~~ SEGMENTS; plot boundaries for regions of interest ~~~~~~~~~~~~~~~~~
if ~isempty(cfg.segments) && ~isIV(cfg.segments)
    error('cfg.segments muct be an iv datatype')
elseif ~isempty(cfg.segments) && isIV(cfg.segments)
    % then plot interval boundaries as vertical lines
    PlotPatchObjects  
end

set(ax_main,'layer','top')
hfig = gcf;
set(hfig,'Name',mfilename,'KeyPressFcn',@keystuff,'WindowButtonDownFcn',@clickstuff,'CloseRequestFcn',@leaveme);

% I'm pulling some things out of cfg so I can "trace" them easier if I want to
mode = cfg.mode;
trapwin = cfg.trapwin;
clickColor = cfg.clickColor;
keepColor = cfg.keepColor;

% initialize some global variables
numKept = 0; % number of user-defined intervals
numPrev = 0;% number of events from a previous bout of identification (see cfg.resume)

switch cfg.mode
    case 'fixed'
        clicktimes = []; % locations of x-axis clicks
    case 'unfixed'
        clicktimes.tstart = []; clicktimes.tend = [];
end

state = 'start'; % 'start','once','twice': state changes while function is running

x1 = []; x2 = []; y1 = []; y2 = []; H = []; % click spots and plot handle

quitRequested = 0;
%~~~~~~~~~~~~~~~~~~~~~~~ PLOT PROGRESS BAR ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

subplot(subplot_nRows,subplot_nCols,1); box on

% Get axes limits for MultiRaster
startTime = ax_main.XLim(1);
endTime = ax_main.XLim(2);

% Some settings for progress bar plot
ax_progressBar = gca;
set(ax_progressBar,'XTick',[]); set(ax_progressBar,'YTick',[])
set(ax_progressBar,'XLim',[startTime endTime])

% Add patch obj to bar, if exist
if ~isempty(cfg.segments)
    PlotPatchObjects
end

UpdateProgressBar

set(hfig,'CurrentAxes',ax_main) % change current axes back to MultiRaster

%~~~~~~~~~~~ RESUME from previous session, if wanted ~~~~~~~~~~~~~~~~~~~~~~
if ~isempty(cfg.resume)
    resCol = [30/255 144/255 255/255]; % The color for previously identified intervals
    plot([cfg.resume.tstart cfg.resume.tend],[0 0],'LineWidth',3,'Color',resCol)
    plot([cfg.resume.tstart cfg.resume.tend],[0 0],'o','MarkerFaceColor',resCol,'Color',resCol,'MarkerSize',8)
    % go to the last interval (assume they went start -> end)
    lastTime = mean([cfg.resume.tstart(end) cfg.resume.tend(end)]);
    set(ax_main,'XLim',[lastTime-0.5 lastTime+0.5])   
    numPrev = length(cfg.resume.tstart); % count the number of events from before
end

updateCount % displays how many intervals have been identified

%% ui control buttons

uipressed = 0; % this keeps track of when the focus is removed from the 
% figure axes; if you add new callbacks that use uicontrols, make sure you 
% keep track of uipressed and call RoboClick at the end of the function to
% return focus to the axes so the user doesn't have to do this with their
% own clicks

% save button
uicontrol('Style', 'pushbutton', 'String', 'Save',...
    'TooltipString','Save the intervals you have identified',...
    'Units','normalized','Position', [0.93 0.25 0.05 0.05],...
    'FontUnits','normalized','Callback', @saveme);

% quit button
uicontrol('Style', 'pushbutton', 'String', 'Quit',...
    'TooltipString',['Exit ',mfilename],...
    'Units','normalized','Position', [0.93 0.125 0.05 0.05],...
    'FontUnits','normalized','Callback', @leaveme);

if ~isempty(cfg.segments) && isIV(cfg.segments)
    
    % next button for segment navigation
    uicontrol('Style', 'pushbutton', 'String', 'Go to',...
        'TooltipString','Jump to another segment',...
        'Units','normalized','Position', [0.92 0.88 0.078 0.05],...
        'FontUnits','normalized','Callback', @teleport);
    
    % teleport drop down option for which segment to go to
    hSegNum = uicontrol('Style','popupmenu','String',cellstr(num2str((1:length(cfg.segments.tstart))'))',...
        'TooltipString','Choose segment number',...
        'Units','normalized','Position',[0.92 0.826 0.078 0.05]);
    
    % teleport drop down option for where to go inside of a segment
    hDest = uicontrol('Style','popupmenu','String',{'beginning','center','end'},...
        'TooltipString','Choose segment destination',...
        'Units','normalized','Position',[0.92 0.822 0.078 0.03]);
    
    segmentCenters = IVcenters(cfg.segments); % for segment center navigation
end

if exist('LFP','var')
    % spectrogram button
    uicontrol('Style', 'pushbutton', 'String', 'Spectrogram',...
        'TooltipString','Plot spectrogram for current window',...
        'Units','normalized','Position', [0.01 0.88 0.1 0.05],...
        'FontUnits','normalized','Callback', @spectraxis);
    
    % barcode button
    uicontrol('Style', 'pushbutton', 'String', 'Barcode',...
        'TooltipString','Show LFP as pattern of stripes',...
        'Units','normalized','Position', [0.01 0.71 0.1 0.05],...
        'FontUnits','normalized','Callback', @barcode);
    
    % spectrogram z scale drop down option
    zPop = uicontrol('Style','popupmenu','String',{'root','decibel-watt','raw'},...
        'TooltipString','Choose colour axis scaling',...
        'Units','normalized','Position',[0.01 0.76 0.1 0.05]);
    
    % spectrogram frequency range 
    frange(1) = uicontrol('Style','edit','String','50',...
        'TooltipString','Pass band lower frequency',...
        'Units','normalized','Position',[0.01 0.82 0.04 0.04]);
    frange(2) = uicontrol('Style','edit','String','300',...
        'TooltipString','Pass band higher frequency',...
        'Units','normalized','Position',[0.07 0.82 0.04 0.04]);
    
    % create axes for a spectrogram. These do not move with navigate, unlike the main
    % axes, and instead are set to invisible unless a spectrogram is plotted
    ax_spec = axes('Position', get(gca, 'Position'),'Visible','off');
    set(hfig,'CurrentAxes',ax_main)
end

%% helper functions

    function updateCount
        % how many intervals have been indentified. Displays text.
        txt = ['Count: ',num2str(numKept + numPrev)];
        
        set(ax_progressBar.Title,'String',txt,'FontSize',18)
             
    end % of updateCount

    function RoboClick
        % use java robot to help return focus to the axes after interacting with a uicontrol
        % RoboClick and uipressed work together to produce the desired behaviour
        
        if cfg.EnableRobot
            % get original location of mouse cursor
            ml_orig = get(0,'PointerLocation');
            
            % get center of figure window
            figLoc = get(hfig,'Position');
            ml_new = [figLoc(1)+figLoc(3)/2 figLoc(2)+figLoc(4)/2];
            
            % set new mouse location for the robot
            set(hfig,'Pointer','custom','PointerShapeCData',NaN(16,16)) % make it invisible
            set(0,'PointerLocation',ml_new) 
            
            % robot!
            drawnow
            robot = java.awt.Robot ;
            robot.mousePress(java.awt.event.InputEvent.BUTTON1_MASK);
            robot.mouseRelease(java.awt.event.InputEvent.BUTTON1_MASK);
            
            % now return pointer location to where the user last had it
            set(hfig,'Pointer','arrow') % make it visible again
            set(0,'PointerLocation',ml_orig)
            
        end
    end % of RoboClick

% ~~~~~~ HIDE SPECTRAXIS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function HideSpectraxis
        % hide spectrogram axis
        specObj = findobj(ax_spec); % use findobj, otherwise can't make imagesc invisible (just axes)
        set(specObj,'Visible','off'); set(ax_main,'Color','w')
        
        % return color of LFP/spikes/intervals to have nice contrast with white background
        %if isfield(hMR,'S'); set(hMR.S(:),'Color',cfg.spkColor); end
        if isfield(hMR,'LFP'); set(hMR.LFP,'Color',cfg.lfpColor); end
        if isfield(hMR,'LFP_iv'); set(hMR.LFP_iv,'Color',cfg.ivColor); end
    end % of HideSpectraxis

% ~~~~~~ PLOT PATCH OBJECT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    function PlotPatchObjects
        cfg_temp.showLegend = 0;
        cfg_temp.Color = [0 0 0; 1 1 1]; % black first, then white
        cfg_temp.patch = 0;
        hSK = overplot(cfg_temp,cfg.segments,cfg.segments);
        set(hSK(1),'LineWidth',3.5) % make the black line thicker than the white line
        
        % make transparent patch objects to place over the regions we are not
        % interested in
        ylims = get(gca,'YLim');
        alph = 0.4;
        patchCol = [155/255 48/255 255/255];
        patchX = [LFP.tvec(1); LFP.tvec(1); cfg.segments.tstart(1); cfg.segments.tstart(1)];
        patchY = [ylims(1); ylims(2); ylims(2); ylims(1)];
        patch(patchX,patchY,patchCol,'EdgeColor','none','FaceAlpha',alph)
        
        for ii = 1:length(cfg.segments.tstart)-1
            patchX = [cfg.segments.tend(ii); cfg.segments.tend(ii); cfg.segments.tstart(ii+1); cfg.segments.tstart(ii+1)];
            patch(patchX,patchY,patchCol,'EdgeColor','none','FaceAlpha',alph)
        end
        
        patchX = [cfg.segments.tend(end); cfg.segments.tend(end); LFP.tvec(end); LFP.tvec(end)];
        patch(patchX,patchY,patchCol,'EdgeColor','none','FaceAlpha',alph)
    end % of PlotPatchObjects

% ~~~~~~ UPDATE PROGRESS BAR ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function UpdateProgressBar
        global hProg
        set(hfig,'CurrentAxes',ax_progressBar)
        % Make patch object reflecting current window width
        if exist('hProg','var')
            delete(hProg)
        end
        patchX = [ax_main.XLim(1); ax_main.XLim(1); ax_main.XLim(2); ax_main.XLim(2)];
        patchY = [ax_progressBar.YLim(1); ax_progressBar.YLim(2); ax_progressBar.YLim(2); ax_progressBar.YLim(1)];
        hProg = patch(patchX,patchY,'k','FaceAlpha',0.4);
        set(hfig,'CurrentAxes',ax_main)
    end % of UpdateProgressBar

%% callback functions

% ~~~~~~ CLICK STUFF ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function clickstuff(~,~)
        % handles mouse input
        
        if ~uipressed
            clickpoint = get(gca,'CurrentPoint');
            x = clickpoint(1,1); y = clickpoint(1,2);
            
            switch state
                case 'start'
                    switch mode
                        case 'fixed' % interval is defined by trapwin around click location
                            state = 'twice';
                            x1 = x; y1 = y;
                            x_plot = [x1-trapwin/2 x1+trapwin/2];
                            H(1) = plot(gca,x_plot,[y1 y1],'s','MarkerFaceColor',clickColor,'Color',clickColor,'MarkerSize',8);
                            H(2) = plot(gca,x_plot,[y1 y1],'LineWidth',3,'Color',clickColor);
                            
                        case 'unfixed' % interval start and stop are defined by user
                            state = 'once';
                            x1 = x;
                            y1 = y;
                            H(1) = plot(gca,x1,y1,'s','MarkerFaceColor',clickColor,'Color',clickColor,'MarkerSize',8);
                            
                        otherwise
                            error('Unrecognized mode')
                    end
                    
                case 'once'
                    assert(strcmp(mode,'unfixed'))
                    state = 'twice';
                    x2 = x; y2 = y;
                    H(2) = plot(gca,x2,y2,'s','MarkerFaceColor',clickColor,'Color',clickColor,'MarkerSize',8);
                    H(3) = plot(gca,[x1 x2],[y1 y2],'LineWidth',3,'Color',clickColor);
                    
                case 'twice'
                    state = 'start';
                    delete(H);
            end
        end
        uipressed = 0;
    end % of clickstuff

% ~~~~~~ KEY STUFF ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function keystuff(source,event)
        % handles keyboard input
        if strcmp(event.Key,'return')
            switch state
                case 'start'
                    %Do nothing...
                    
                case 'once'
                    state = 'start';
                    delete(H)
                    
                case 'twice'
                    state = 'start';
                    switch mode
                        case 'fixed' % interval is defined by trapwin around click location
                            set(H(1),'Color',keepColor,'Marker','o','MarkerFaceColor',keepColor); set(H(2),'Color',keepColor)
                            numKept = numKept + 1;
                            clicktimes(numKept) = x1;
                                                                                
                            % update count display
                            updateCount
                            
                        case 'unfixed' % interval start and stop are defined by user
                            
                            set(H,'Marker','o','Color',keepColor,'MarkerFaceColor',keepColor);
                            numKept = numKept + 1;
                            
                            % make sure tstart is before tend
                            if x1 < x2
                                clicktimes.tstart(numKept) = x1;
                                clicktimes.tend(numKept) = x2;
                            else
                                clicktimes.tstart(numKept) = x2;
                                clicktimes.tend(numKept) = x1;
                            end
                                                       
                            % update count display
                            updateCount
                            
                        otherwise
                            error('Unrecognized mode')
                    end
            end
            H = [];
        else
            if exist('LFP','var')              
                HideSpectraxis
            end
            navigate(source,event)
            title(' ')
        end
        UpdateProgressBar
    end % of keystuff

% ~~~~~~ LEAVE ME ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    function leaveme(~,~)
        % quit request function
        uipressed = 1;
        choice = questdlg('Are you sure you want to close the figure? Any unsaved data will be lost.','Quit Requested','Save and Quit','Quit','Cancel','Cancel');
        switch choice
            case 'Quit'
                delete(gcf)
            case 'Save and Quit'
                quitRequested = 1;
                saveme
            case 'Cancel'
                RoboClick
                return
        end
    end % of leaveme

% ~~~~~~ SAVE ME ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function saveme(~,~)
        % save request function
        uipressed = 1;
        choice = questdlg('Would you like to save the data?','Save Requested','Yes','No','No');
        switch choice
            case 'Yes'
                switch mode
                    case 'fixed'
                        if ~isempty(cfg.resume)
                           centers = [clicktimes IVcenters(cfg.resume)]; 
                        else
                            centers = clicktimes;
                        end
                        centers = sort(centers);
                        IVann = iv(centers - trapwin/2,centers + trapwin/2);
                        if exist('LFP','var')
                            IVann.label = LFP.label;
                        end
                        
                    case 'unfixed'
                        if ~isempty(cfg.resume)
                           intervals.tstart = [clicktimes.tstart cfg.resume.tstart']; 
                           intervals.tend = [clicktimes.tend cfg.resume.tend'];
                        else
                            intervals = iv(clicktimes.tstart,clicktimes.tend);
                        end
                        [intervals.tstart,idx] = sort(intervals.tstart);
                        intervals.tend = intervals.tend(idx);
                        IVann = iv(intervals.tstart,intervals.tend);  
                        if exist('LFP','var')
                            IVann.label = LFP.label;
                        end
                end
                
                % check that there aren't any doubles
                discardTstart = find(diff(IVann.tstart)== 0);
                discardTend = find(diff(IVann.tend) == 0);
                if any(discardTend ~= discardTstart)
                    warning('Some intervals have the same start or end times.')
                elseif ~isempty(discardTstart)
                    disp([mfilename,': doubles found, removing.'])
                    IVann.tstart(discardTstart) = [];
                    IVann.tend(discardTstart) = [];
                end
                
                IVann.hdr = cfg.hdr;
                
                % housekeeping
                IVann = History(IVann,mfun,cfg);
                
                [~,name,~] = fileparts(pwd);
                uisave('IVann',[name,'-manualIV']) % opens window for saving stuff
               
                if quitRequested
                    delete(hfig)
                else
                    RoboClick
                end
                
            case 'No'
                if quitRequested
                    delete(hfig)
                else
                    RoboClick
                    return
                end
        end
    end % of saveme

% ~~~~~~ TELEPORT ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    function teleport(~,~)
        % jump to another segment of interest
        
        uipressed = 1; % focus has been taken off of axes because of ui button press
        RoboClick
        
        if exist('LFP','var')            
            HideSpectraxis
        end
        
        % get info about current viewing window
        xlims = get(ax_main,'XLim');
        flank = diff(xlims)/2;
        
        % get segment number from uicontrol
        string = get(hSegNum,'String'); choice = get(hSegNum,'Value');
        number = str2double(string{choice});
        
        % get segment destination from uicontrol
        string = get(hDest,'String'); choice = get(hDest,'Value');
        destination = string{choice};
        
        % get lookup values for nearest segment
        switch destination
            case 'beginning'
                newLocation = cfg.segments.tstart(number);
            case 'center'
                newLocation = segmentCenters(number);
            case 'end'
                newLocation = cfg.segments.tend(number);
        end
        
        % set new viewing window
        set(ax_main,'XLim',[newLocation-flank newLocation+flank])
        
        % display title fyi, but also to cover up a navigate "bug" that
        % happens if you teleport while an event number is displayed (if
        % you do this, then navigate doesn't know you moved and it leaves
        % the title there since the movement is done outside of navigate)
        titl = ['Segment ',num2str(number),', ',destination];
        title(titl,'FontSize',14)
        
    end % of teleport

% ~~~~~~ SPECTRAXIS ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function spectraxis(~,~)
        % create a new set of axes and plot a spectrogram behind the raster plot
        uipressed = 1;
        
        xlims = get(gca,'XLim');
        xticks = get(gca,'XTick');
        
        CSCr = restrict(LFP,xlims(1),xlims(2)); % restrict to count the numbers of samples in viewing window
        
        if length(CSCr.tvec) > 50000
            % outright refuse
            msgbox('Unsupported window size for spectrogram.','Bad things can happen','error')
            RoboClick
            return
        end
        
        if length(CSCr.tvec) > 18000
            choice = questdlg('Creating a spectrogram for this amount of data may take a long time. Are you sure you want to continue?','This might take a long time...','I like waiting','Cancel','Cancel');
          
            switch choice
                case 'I like waiting'
                case 'Cancel'
                    RoboClick
                    return  
            end
        end
        
        set(gca,'color','none')
        set(hfig,'CurrentAxes',ax_spec) % now change current axes
        
        nSamples = 102; % the number of samples to use in the spectrogram
        
        fs = length(CSCr.data)/(xlims(2)-xlims(1)); % get the local approx sampling frequency
        
        buffer = (nSamples/2)/fs; % how much time buffer is needed so that the spectrogram lines up with the data in viewing window
        CSCr = restrict(LFP,xlims(1)-buffer,xlims(2)+buffer); % re-restrict with buffer
        
        % get frequencies of interest
        foi = str2double(get(frange(1),'String')):str2double(get(frange(2),'String')); % don't be evil..numbers only
        
        [~,F,T,P] = spectrogram(CSCr.data,hanning(nSamples),100,foi,fs);
       
        % get z scale option (see uicontrol zPop)
        string = get(zPop,'String'); choice = get(zPop,'Value');
        zscale = string{choice};
        switch zscale
            case 'root'
                P = sqrt(P); % rescale power
                %col = [0.09*10^-6 18*10^-6]; % some arbitrary range for the color scaling
                maxP = max(max(P)); minP = min(min(P));
                col = [minP maxP];
                
                % change colors of LFP/spikes/intervals for contrast with spectrogram
                %if isfield(hMR,'S'); set(hMR.S,'Color',[1 1 1 0.5]); end
                if isfield(hMR,'LFP'); set(hMR.LFP,'Color','w'); end
                if isfield(hMR,'LFP_iv'); set(hMR.LFP_iv,'Color','r'); end
                
            case 'decibel-watt'
                P = 10*log10(P); % rescale power
                %col = [-170 -80]; % some arbitrary range for the color scaling
                maxP = max(max(P)); minP = min(min(P));
                col = [minP+0.6*(maxP-minP) maxP-0.01*(maxP-minP)]; 
                
                % change colors of LFP/spikes/intervals for contrast with spectrogram
                %if isfield(hMR,'S'); set(hMR.S(:),'Color','k'); end
                if isfield(hMR,'LFP'); set(hMR.LFP,'Color','k'); end
                if isfield(hMR,'LFP_iv'); set(hMR.LFP_iv,'Color','b'); end
                
            case 'raw'
                %col = [0.09*10^-10 3*10^-10]; % some arbitrary range for the color scaling
                
                maxP = max(max(P)); minP = min(min(P));
                col = [minP maxP];
                
                % change colors of LFP/spikes/intervals for contrast with spectrogram
                %if isfield(hMR,'S'); set(hMR.S(:),'Color','k'); end
                if isfield(hMR,'LFP'); set(hMR.LFP,'Color','w'); end
                if isfield(hMR,'LFP_iv'); set(hMR.LFP_iv,'Color','r'); end
        end
        %P = P./max(max(P)); %Scale so max is 1, avoids some bug with spectrogram updating... >_<
        
        imagesc(T,F,P,col); colormap('jet');
        set(ax_spec,'YAxisLocation','right','XTick',xticks,'XTickLabel',[],'YDir','normal')
        
        ylabel(ax_spec,'Frequency (Hz)')
        grid on
        uistack(ax_spec,'bottom') % send it to the very back; other axes in front
        
        % return to main axes (for navigation and stuff)
        set(hfig,'CurrentAxes',ax_main) 
        
        RoboClick
        
    end % of spectraxis

% ~~~~~~ BARCODE ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    function barcode(~,~)
        % create a new set of axes and plot a barcode behind the raster plot
        uipressed = 1;
        
        xlims = get(gca,'XLim');
        xticks = get(gca,'XTick');
%         for iCell = 1:length(hMR.S)
%             set(hMR.S{iCell},'Color','g')
%         end
        
        CSCr = restrict(LFP,xlims(1),xlims(2)); % restrict to count the numbers of samples in viewing window
        % filter CSC in the ripple band
        cfg_filter.f = [140 250];
        cfg_filter.type = 'fdesign';
        cfg_filter.verbose = 0;
        CSCr = FilterLFP(cfg_filter,CSCr);
               
        set(gca,'color','none')
        set(hfig,'CurrentAxes',ax_spec) % now change current axes
                       
        imagesc(CSCr.data); colormap('gray');
        set(ax_spec,'YAxisLocation','right','XTick',xticks,'XTickLabel',[],'YDir','normal')
        
        uistack(ax_spec,'bottom') % send it to the very back; other axes in front
        
        % return to main axes (for navigation and stuff)
        set(hfig,'CurrentAxes',ax_main) 
        
        RoboClick
        
    end % of spectraxis

end

