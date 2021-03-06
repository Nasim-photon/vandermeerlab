function [redraw, rekey, undoable] = RunKKwik(iClust)

% RunKlustaKwik(iClust)
%
% Runs KlustaKwik on a single cluster
% 
%
% INPUTS
%    iClust
%
% OUTPUTS
%
% NONE
% TO USE WITH MCLUST, put this in the MClust/ClusterOptions folder

% NCST 2003 
% 
% simple mods ADR 208

redraw = false; rekey = false; undoable = true;

global MClust_Directory MClust_FeatureNames

RunKKwikFigure = figure('Name','Run KlustaKwik','Units', 'Normalized', 'UserData', iClust, 'Tag', 'RunKlustaKwik');
%-------------------------------
% Alignment variables

uicHeight = 0.04;
uicWidth  = 0.25;
dX = 0.3;
XLocs = 0.1:dX:0.9;
dY = 0.04;
YLocs = 0.9:-dY:0.0;
FrameBorder = 0.01;

% Create Feature Listboxes
uicontrol('Parent', RunKKwikFigure,...
	'Style', 'text', 'String', 'FEATURES', 'Units', 'Normalized', 'Position', [XLocs(1) YLocs(4) 2*uicWidth uicHeight]);
uicontrol('Parent', RunKKwikFigure,...
	'Style', 'text', 'String', 'Available', 'Units', 'Normalized', 'Position', [XLocs(1) YLocs(5) uicWidth uicHeight]);
ui_featuresIgnoreLB =  uicontrol('Parent', RunKKwikFigure,...
	'Units', 'Normalized', 'Position', [XLocs(1) YLocs(17) uicWidth 12*uicHeight],...
	'Style', 'listbox', 'Tag', 'FeaturesIgnoreListbox',...
	'Callback', 'TransferBetweenListboxes',...
	'HorizontalAlignment', 'right', ...
	'Enable','on', ...
	'String', MClust_FeatureNames, ...
	'TooltipString', 'These are features which are not included but are also available.');
uicontrol('Parent',RunKKwikFigure,...
	'Style', 'text', 'String', 'Use', 'Units', 'Normalized', 'Position', [XLocs(1)+uicWidth YLocs(5) uicWidth uicHeight]);
ui_featuresUseLB = uicontrol('Parent', RunKKwikFigure,...
	'Units', 'Normalized', 'Position', [XLocs(1)+uicWidth YLocs(17) uicWidth 12*uicHeight],...
	'Style', 'listbox', 'Tag', 'FeaturesUseListbox',...
	'Callback', 'TransferBetweenListboxes',...
	'HorizontalAlignment', 'right', ...
	'Enable','on', ...
	'TooltipString', 'These features will be used for cluster separation.');

set(ui_featuresIgnoreLB, 'UserData', ui_featuresUseLB);
set(ui_featuresUseLB,    'UserData', ui_featuresIgnoreLB);

uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1) + uicWidth/2 YLocs(1) uicWidth/2 uicHeight], ...
	'Style', 'text','Tag', 'RunKlustaKwikiClust', 'String', num2str(iClust), ...
	'TooltipString', 'Cluster 1');	
uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1) + uicWidth/2 YLocs(2) uicWidth/2 uicHeight], ...
	'Style', 'edit', 'String', num2str(2), ...
	'TooltipString', 'Mininum number of clusters', 'Tag','RunKlustaKwikMinClust');
uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1) + uicWidth/2 YLocs(3) uicWidth/2 uicHeight], ...
	'Style', 'edit', 'String', num2str(7), ...
	'TooltipString', 'Maximum number of clusters', 'Tag','RunKlustaKwikMaxClust');

uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1) YLocs(1) uicWidth/2 uicHeight], ...
	'Style', 'text','String', 'Cluster');	
uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1) YLocs(2) uicWidth/2 uicHeight], ...
	'Style', 'text','String', 'minClusters');	
uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1) YLocs(3) uicWidth/2 uicHeight], ...
	'Style', 'text','String', 'maxClusters');	

uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1) YLocs(20) uicWidth/2 uicHeight], ...
	'Style' ,'text', 'String', 'OtherParms');
uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1)+uicWidth/2 YLocs(20) 0.9-uicWidth/2 uicHeight], ...
	'Style' ,'edit', 'String', '', 'HorizontalAlignment', 'Left',...
	'Tag', 'OtherParms', ...
	'TooltipString', 'Other parameters to pass to KlustaKwik');

uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1) YLocs(22) uicWidth uicHeight*2], ...
	'Style', 'pushbutton','Tag', 'AcceptFeatures_FBS', 'String', 'GO', 'Callback', 'RunKKwik_Callbacks', ...
	'TooltipString', 'Accept features to use clustering the current cluster');
uicontrol('Parent',RunKKwikFigure, ...
	'Units', 'Normalized', 'Position', [XLocs(1)+uicWidth YLocs(22) uicWidth uicHeight*2], ...
	'Style', 'pushbutton', 'String', 'CANCEL', 'Callback', 'close');