function varargout = saccadeGUI(varargin)

% make "uiData" object.
uiData = makeUiData;

% build UI elements
uiData = buildUiElements(uiData);

% store the initial list of target locations (tiling the area).
uiData          = initTargetLocs(uiData);

% Put some dummy data in the structure to plot the heatmap, IF no PDS has
% been supplied as input.
if nargin == 0
    uiData                  = dummyPDS(uiData);
else
    uiData.PDS = varargin{1};
end

addlistener(uiData, 'PLDAPSdata', 'PostSet', @(i1,i2)updatePlots(i1,i2,uiData));
addlistener(uiData, 'sacDataArray', 'PostSet', @(i1,i2)updateTargetsPlot(i1, i2, uiData));

% initial update to heatmap plot
updateHeatMap([], [], uiData);

% initial update to target locations plot
updateTargetsPlot([], [], uiData);

% update 'UserData' field with populated data structure.
set(uiData.handles.hGui, 'UserData', uiData);

% Define default output and return it if it is requested by users
mOutputArgs = {uiData.handles.hGui, uiData};

if nargout>0
    [varargout{1:nargout}] = mOutputArgs{1:nargout};
end

% set(hMainFigure, 'Position', [2561        1441        1600        1178]);
%set(hMainFigure, 'Position', [57           5        1287         720]);

end

%%%% Define callback functions
function hPlotAxes_ButtonDownFcn(hObject, eventdata, GUIfig)
% This function is used to grab user-input. A user clicks on this graph if
% they want to add points to the list of saccade targets. That list is
% stored in one field of the 'UserData' field of the GUI figure. This is
% why we have the 'GUIfig' argument to this function, so we can easily pass
% the figure handle.

% Grab data structure
uiData                          = get(GUIfig, 'UserData');

% grab last-clicked point
clickedPt                           = get(hObject, 'CurrentPoint');

% update list of targets: (1) find not-yet-completed targets, (2) increment
% their "order", (3) add the new point, placing it first in the "order".
uiData.sacDataArray             = [[clickedPt(1,1:2), 0, NaN, NaN]; uiData.sacDataArray];

% update data structure
set(GUIfig, 'UserData', uiData);
end

function hTimeWindow_Callback(hObject, eventdata)

newVal = str2double(get(hObject, 'String'));

if ~isempty(newVal)
    set(hObject, 'Value', newVal);
    updateHeatMap([], [], get(get(get(hObject, 'Parent'), 'Parent'), 'UserData'));
else
    set(hObject, 'String', num2str(get(hObject, 'Value')));
end

end

function hTrialMarkersMenu_Callback(hObject, eventdata)
updateHeatMap([], [], get(get(get(hObject, 'Parent'), 'Parent'), 'UserData'));
end

function HeatMapProps_Callback(hObject, eventdata, uiData)

% return a list of the panel's children so we have all the values we need.
pKids = get(uiData.handles.hHMPanel, 'Children');

% make a list of the tags for each of the uicontrols, we can use this to
% retreive the values of the controls.
editTags = {'DivPerDeg', 'XLow', 'XHigh', 'YLow', 'YHigh'};

% grab the values (note: I like this one-liner!)
vals = cellfun(@(x)str2double(get(pKids(arrayfun(@(y)strcmp(get(y,'Tag'), x), pKids)), 'String')), editTags)';

% delete old heatmap, contour, and color bar objects.
delete([uiData.handles.hHeatMap, uiData.handles.hCntr, uiData.handles.hColrBar])

% build new EMPTY ones
hTemp = buildHeatMap(vals(2:3)', vals(4:5)', vals(1), uiData.handles.hPlotAx, uiData.handles.hColBrAx);
uiData.handles.hHeatMap    = hTemp(1);
uiData.handles.hCntr    = hTemp(2);
uiData.handles.hColrBar = hTemp(3);

% set axis limits
set(uiData.handles.hPlotAx, 'XLim', vals(2:3)', 'YLim', vals(4:5)');

% reconstruct
updateHeatMap([], [], uiData)
end

function figSave_callback(hObject, eventdata, uiData)

kids = get(get(hObject, 'Parent'), 'Children');

fileBox = kids(strcmp(get(kids, 'Tag'), 'FileName'));

disp('Saving Figure file...')
hgsave(get(get(hObject, 'Parent'), 'Parent'), ['/Users/klab/Documents/amar/gui2/physiology/saccade_heatmaps/' get(fileBox, 'String') '.fig'])
disp('HeatMap Figure Saved!')
end

function hTargetLoc_ButtonDownFcn(hObject, eventdata, uiData)

ptXYs   = cell2mat(get(hObject, {'XData', 'YData'}));
whichPt = all(bsxfun(@eq, uiData.sacDataArray(:,1:2), ptXYs),2);
whPDS   = all(bsxfun(@eq, uiData.PDS.targXY, ptXYs), 2);

% label the trials with the locked target location as state 1.6 to avoid
% data from those trials being used in map building.
try
    uiData.badPoints(whPDS) = true;
catch me
    keyboard
end

uiData.sacDataArray(whichPt, 3:5) = repmat([0, NaN, NaN], nnz(whichPt),1);

updateTargetsPlot([],[],uiData);
updateHeatMap([],[],uiData);

end

function hHeatMapType_ButtonDownFcn(hObject, eventdata, uiData)
switch get(hObject, 'Value')
    case 0
        set(hObject, 'String', 'Spikes-Based HeatMap');
    case 1
        set(hObject, 'String', 'PkV-Based HeatMap');
end
updateHeatMap(hObject, eventdata, uiData);
end

function hHeatMapTgtOrSacXY_Callback(hObject, eventdata, uiData)

switch get(hObject, 'Value')
    case 0
        set(hObject, 'String', 'Tgt-Based XY');
    case 1
        set(hObject, 'String', 'Sac-Based XY');
end
updateHeatMap(hObject, eventdata, uiData);

end

function mapLoad_callback(hObject, eventdata, uiData)

fnobj = findobj(get(get(hObject, 'Parent'), 'Children'), 'Tag', 'FileName');
[f, p] = uigetfile('*.mat');
set(fnobj, 'String', f(1:find(f=='.', 1, 'first')-1));
data = load([p,f]);

data = data.data;

try
    F = TriScatteredInterp(data(:,1:2), data(:,3));
catch me
    keyboard
end

if ~isprop(uiData, 'vMap');
addprop(uiData, 'vMap');
end
uiData.vMap = F;
set(get(get(uiData.handles.hTPanel, 'Parent'), 'Parent'), 'UserData', uiData);
updateHeatMap(hObject, eventdata, uiData);
end

%%%% Define create functions
function hTrialMarkersMenu_CreateFcn(hObject, eventdata, uiData)

% if there's no data in the PDS yet, don't try to populate the menu with
% information.
if isempty(uiData.PDS)
    % do nothing
else
    % What are the fieldnames of the PDS?
    PDSfields   = fieldnames(uiData.PDS);
    
    % Which PDS fieldnames start with "time"?
    timeFields = cell2mat(cellfun(@(x)(~isempty(x) && x==1), strfind(PDSfields, 'time'),'UniformOutput',false));
    
    % if this is the object creation call, use the hObject input to set the
    % string of the menu, otherwise, use the handle stored in uiData.
    if ishandle(hObject)
        hUse = hObject;
    else
        hUse = uiData.handles.TMMenu;
    end
    
    % if this list matches the list that's already attached to the pulldown
    % menu, do nothing, otherwise populate the fieldnames into the menu,
    % and set one of them as active.
    if ~all(strcmp(PDSfields(timeFields), get(hUse, 'String')))
        % Put those fieldnames into the menu
        set(hUse, 'String', PDSfields(timeFields), 'Visible', 'on');
        
        % if the field "timetfon" is in the list (time that the target flash
        % happened), let's set the menu to this value.
        if any(strcmp(PDSfields(timeFields),'timetfon'))
            set(hUse, 'Value', find(strcmp(PDSfields(timeFields),'timetfon')))
        end
    end
    
end
end

%%%% Define other functions

function uiData = buildUiElements(uiData)

% GUI figure
uiData.handles.hGui =   figure(...       % the main GUI figure
    'MenuBar', 'none', ...
    'Toolbar', 'none', ...
    'HandleVisibility', 'callback', ...
    'Name', 'saccade GUI', ...
    'NumberTitle', 'off', ...
    'Color', get(0, 'defaultuicontrolbackgroundcolor'), ...
    'Position', [0 0 600 800], ...
    'NextPlot', 'Add');

uiData.handles.hPlotAxes   =   axes(...         % HeatMap plot axes
    'Tag', 'hPlotAxes', ...
    'Parent', uiData.handles.hGui, ...
    'Units', 'normalized', ...
    'HandleVisibility', 'callback', ...
    'Position', [0.05 0.455 0.63 0.525], ...
    'CLim', [0 1], ...
    'CLimMode', 'manual', ...
    'FontSize', 14, ...
    'TickDir', 'Out', ...
    'TickLength', [0.005 0.025], ...
    'LineWIdth', 1, ...
    'NextPlot', 'Add', ...
    'ButtonDownFcn', {@hPlotAxes_ButtonDownFcn, uiData.handles.hGui});

uiData.handles.hColorBarAxes       =   axes(...         % HeatMap colorbar axes
    'Tag', 'hColorBarAxes', ...
    'Parent', uiData.handles.hGui, ...
    'Units', 'normalized', ...
    'HandleVisibility', 'callback', ...
    'Position', [0.69 0.455 0.035 0.525], ...
    'CLim', [0 1], ...
    'CLimMode', 'manual', ...
    'FontSize', 14, ...
    'TickDir', 'Out', ...
    'TickLength', [0.005 0.025], ...
    'LineWIdth', 1, ...
    'NextPlot', 'Add', ...
    'XTickLabel', [], ...
    'YAxisLocation', 'right');

% an empty heatmap with default degree limits / divisions-per-degree
hmXLims             = [-30, 30];
hmYLims             = [-20, 20];
divPerDeg           = 0.5;
uiData.handles.hHeatMap = buildHeatMap(uiData, ...
    [hmXLims, hmYLims, divPerDeg]);

% make a gui-panel to store controls for modifying heatmap properties
% (limits, resolution, ...)
uiData          = makeHeatMapPropsPanel(uiData, [divPerDeg, hmXLims, hmYLims]);

% make a gui-panel to store controls selecting the target location
uiData          = makeTargetSelectPanel(uiData);

% make a gui-panel to store controls for saving the figure
uiData          = makeFigureSavePanel(uiData);

% make a gui-panel to store controls for loading a pre-existing peak
% velocity heatmap
uiData          = makePkVMapLoadPanel(uiData);

% target locations plot objects. first create an "unvisited target
% location" plot object. We'll hold on to this so that if/when the user
% adds new target locations, they retain the "unvisited" appearance. Also
% create a saccade endpoint graphics object for each target location, and a
% connecting line for them.

nPts                               = size(uiData.sacDataArray, 1);
uiData.handles.hTargetLocUnvis     = plot(uiData.handles.hPlotAxes, NaN, NaN, 'ko', ...
    'LineWidth', 2, ...
    'MarkerSize', 12, ...
    'ButtonDownFcn', {@hTargetLoc_ButtonDownFcn, uiData});
uiData.handles.hSacEndLoc          = plot(uiData.handles.hPlotAxes, NaN, NaN, 'ks', ...
    'LineWidth', 2, ...
    'HitTest','off');
uiData.handles.hTargSacConLine     = plot(uiData.handles.hPlotAxes, NaN(1,2), NaN(1,2), 'k', ...
    'HitTest', 'off');
uiData.handles.hTargetLocs         = copyobj(uiData.handles.hTargetLocUnvis, repmat(uiData.handles.hPlotAxes, nPts, 1));
uiData.handles.hSacEndLocs         = copyobj(uiData.handles.hSacEndLoc, repmat(uiData.handles.hPlotAxes, nPts, 1));
uiData.handles.hTargSacConLines    = copyobj(uiData.handles.hTargSacConLine, repmat(uiData.handles.hPlotAxes, nPts, 1));
end

function uiData = buildHeatMap(uiData, defProps)

hmXLims     = defProps(1:2);
hmYLims     = defProps(3:4);
divPerDeg   = defProps(5);

% define number sampling points for heatmap based on desired range and
% divisions per degree.
nXDiv                   = round(range(hmXLims)/divPerDeg) + 1;
nYDiv                   = round(range(hmYLims)/divPerDeg) + 1;

% make heatmap object
h = pcolor(uiData.handles.hPlotAxes, ...
    linspace(hmXLims(1),hmXLims(2), nXDiv), ...
    linspace(hmYLims(1),hmYLims(2),nYDiv), NaN(nYDiv,nXDiv));

% turn off warning about non-finite data
warning('off','MATLAB:contour:NonFiniteData')

% make contour object
[~, h(2)]   = contour(uiData.handles.hPlotAxes, ...
    linspace(hmXLims(1),hmXLims(2), nXDiv), ...
    linspace(hmYLims(1),hmYLims(2),nYDiv), ...
    NaN(nYDiv,nXDiv), 'LineWidth', 1.5, 'LineColor', [1 1 1]);

% make color bar object
h(3)        = pcolor(uiData.handles.hColorBarAxes, ...
    [0,1], linspace(0,1,100), NaN(100,2));

% don't let users click on heatmap objects (only the axes underneath).
set(h(1), 'HitTest', 'off', 'EdgeColor', 'none');
set(h(2), 'HitTest', 'off');
set(h(3), 'EdgeColor', 'none');

% assign handles to uiData.handles
uiData.handles.hHeatMap = h;
end

function uiData = makeHeatMapPropsPanel(uiData, defProps)
% make a uipanel to contain the controls for the appearance of the heatmap
uiData.handles.hHeatMapPropsPanel  = uipanel(...
    'Tag', 'hSpikeAxes3b', ...
    'Parent', uiData.handles.hGui, ...
    'Title','HeatMap Properties', ...
    'TitlePosition', 'centertop', ...
    'FontSize',12,...
    'ForeGroundColor', [0 0 0.6], ...
    'ShadowColor', [0 0 1], ...
    'Position',[0.76 0.8 0.235 0.1]);

uiData.handles.hHeatMapXLimText    = uicontrol(...
    'Tag', 'hHeatMapXLimText', ...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Style', 'text', ...
    'Position', [0.025 0.78 0.2 0.2], ...
    'String', 'X-Lims', ...
    'ForeGroundColor', [0 0 0.6], ...
    'FontSize', 11, ...
    'FontAngle', 'italic');

uiData.handles.hHeatMapYLimText    = uicontrol(...
    'Tag', 'hHeatMapYLimText', ...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Style', 'text', ...
    'Position', [0.175 0.78 0.2 0.2], ...
    'String', 'Y-Lims', ...
    'ForeGroundColor', [0 0 0.6], ...
    'FontSize', 11, ...
    'FontAngle', 'italic');

uiData.handles.hHeatMapDPDText     = uicontrol(...
    'Tag', 'hHeatMapDPDText', ...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Style', 'text', ...
    'Position', [0.4 0.78 0.2 0.2], ...
    'String', 'Div / Deg', ...
    'ForeGroundColor', [0 0 0.6], ...
    'FontSize', 11, ...
    'FontAngle', 'italic');

uiData.handles.hHeatMapXlimLow     =   uicontrol(...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Position',[0.05 0.35 0.15 0.2],...
    'HandleVisibility','callback', ...
    'Style','edit',...
    'String', num2str(defProps(2)), ...
    'Tag', 'XLow', ...
    'Callback', {@HeatMapProps_Callback, uiData});

uiData.handles.hHeatMapXlimHigh    =   uicontrol(...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Position',[0.05 0.55 0.15 0.2],...
    'HandleVisibility','callback', ...
    'Style','edit',...
    'String', num2str(defProps(3)), ...
    'Tag', 'XHigh', ...
    'Callback', {@HeatMapProps_Callback, uiData});

uiData.handles.hHeatMapYlimLow     =   uicontrol(...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Position',[0.21 0.35 0.15 0.2],...
    'HandleVisibility','callback', ...
    'Style','edit',...
    'String', num2str(defProps(4)), ...
    'Tag', 'YLow', ...
    'Callback', {@HeatMapProps_Callback, uiData});

uiData.handles.hHeatMapYlimHigh    =   uicontrol(...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Position',[0.21 0.55 0.15 0.2],...
    'HandleVisibility','callback', ...
    'Style','edit',...
    'String', num2str(defProps(5)), ...
    'Tag', 'YHigh', ...
    'Callback', {@HeatMapProps_Callback, uiData});

uiData.handles.hHeatMapDivPerDeg   =   uicontrol(...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Position',[0.425 0.55 0.15 0.2],...
    'HandleVisibility','callback', ...
    'Style','edit',...
    'String', num2str(defProps(1)), ...
    'Tag', 'DivPerDeg', ...
    'Callback', {@HeatMapProps_Callback, uiData});

uiData.handles.hHeatMapTgtOrSacXY   =   uicontrol(...
    'Parent', uiData.handles.hHeatMapPropsPanel, ...
    'Units','normalized',...
    'Position',[0.625 0.15 0.3 0.6],...
    'HandleVisibility','callback', ...
    'Style','togglebutton',...
    'String', 'Tgt-Based XY', ...
    'Tag', 'TgtOrSacXY', ...
    'Callback', {@hHeatMapTgtOrSacXY_Callback, uiData});
end

function uiData = makeTargetSelectPanel(uiData)
% make a uipanel to contain the controls for the appearance of the heatmap
uiData.handles.hTSelectPanel       = uipanel(...
    'Tag', 'uiData.handles.hTSelectPanel', ...
    'Parent', uiData.handles.hGui, ...
    'Title','Target Location Selection', ...
    'TitlePosition', 'centertop', ...
    'FontSize',12,...
    'ForeGroundColor', [0 0 0.6], ...
    'ShadowColor', [0 0 1], ...
    'Position',[0.76 0.455 0.235 0.125]);

uiData.handles.hRadioGrp1          = uibuttongroup('Parent', uiData.handles.hTSelectPanel, ...
    'Tag', 'uiData.handles.hRadioGrp1', ...
    'Units','normalized',...
    'Position', [0.025 0.525 0.4 0.4]);

uiData.handles.hRadioButton1       =   uicontrol(...
    'Tag', 'hRadioButton1', ...
    'Parent', uiData.handles.hRadioGrp1, ...
    'Units','normalized',...
    'Position',[0.025 0.55 0.95 0.5],...
    'Style','radiobutton',...
    'String', 'Multiple Locations');

uiData.handles.hRadioButton2       =   uicontrol(...
    'Tag', 'hRadioButton2', ...
    'Parent', uiData.handles.hRadioGrp1, ...
    'Units','normalized',...
    'Position',[0.025 0.05 0.95 0.5],...
    'Style','radiobutton',...
    'String', 'Single Location');

uiData.handles.hXText              = uicontrol(...
    'Tag', 'hXText', ...
    'Parent', uiData.handles.hTSelectPanel, ...
    'Units', 'Normalized', ...
    'Style', 'text', ...
    'String', 'X-Loc:', ...
    'FontSize', 14, ...
    'HorizontalAlignment', 'Right', ...
    'Position', [0.525 0.6 0.125 0.2]);

uiData.handles.hYText              = uicontrol(...
    'Tag', 'hYText', ...
    'Parent', uiData.handles.hTSelectPanel, ...
    'Units', 'Normalized', ...
    'Style', 'text', ...
    'String', 'Y-Loc:', ...
    'FontSize', 14, ...
    'HorizontalAlignment', 'Right', ...
    'Position', [0.525 0.15 0.125 0.2]);

uiData.handles.hXVal               = uicontrol(...
    'Tag', 'hXVal', ...
    'Parent', uiData.handles.hTSelectPanel, ...
    'Units', 'Normalized', ...
    'Style', 'edit', ...
    'String', '0', ...
    'FontSize', 14, ...
    'Position', [0.675 0.625 0.125 0.2]);

uiData.handles.hYVal              = uicontrol(...
    'Tag', 'hYVal', ...
    'Parent', uiData.handles.hTSelectPanel, ...
    'Units', 'Normalized', ...
    'Style', 'edit', ...
    'String', '0', ...
    'FontSize', 14, ...
    'Position', [0.675 0.175 0.125 0.2]);

end

function uiData = makeFigureSavePanel(uiData)

uiData.handles.hFigSavePanel       = uipanel(...
    'Tag','hFigSavePanel', ...
    'Parent', uiData.handles.hGui, ...
    'Units', 'Normalized', ...
    'Title','Figure Saving', ...
    'TitlePosition', 'centertop', ...
    'FontSize',12,...
    'ForeGroundColor', [0 0.6 0], ...
    'ShadowColor', [0 1 0], ...
    'Position',[0.825 0.03 0.125 0.175]);

uiData.handles.hFileNameText       = uicontrol(...
    'Tag','hFileNameText', ...
    'Parent', uiData.handles.hFigSavePanel, ...
    'Style', 'text', ...
    'String', 'File Name:', ...
    'FontSize', 14, ...
    'FontWeight', 'bold', ...
    'Units', 'Normalized', ...
    'Position', [0.025 0.65 0.4 0.1]);

uiData.handles.hFileNameBox        = uicontrol(...
    'Tag','hFileNameBox', ...
    'Parent', uiData.handles.hFigSavePanel, ...
    'Style', 'edit', ...
    'String', 'heatMapFig_', ...
    'FontSize', 14, ...
    'Units', 'Normalized', ...
    'Tag', 'FileName', ...
    'Position', [0.025 0.475 0.8 0.15]);

uiData.handles.hFigureSaveButton   = uicontrol(...
    'Tag','hFigureSaveButton', ...
    'Parent', uiData.handles.hFigSavePanel, ...
    'Style', 'pushbutton', ...
    'String', 'Save', ...
    'FontSize', 14, ...
    'FontWeight', 'bold', ...
    'Units', 'Normalized', ...
    'Position', [0.025 0.3 0.8 0.125], ...
    'Callback', {@figSave_callback, uiData});
end

function uiData = makePkVMapLoadPanel(uiData)

uiData.handles.hMapLoadPanel       = uipanel(...
    'Tag', 'hMapLoadPanel', ...
    'Parent', uiData.handles.hGui, ...
    'Units', 'Normalized', ...
    'Title','Peak Velocity Map Loading', ...
    'TitlePosition', 'centertop', ...
    'FontSize',12,...
    'ForeGroundColor', [0 0.6 0.6], ...
    'ShadowColor', [0 1 1], ...
    'Position',[0.675 0.03 0.125 0.175]);

uiData.handles.hFileNameText       = uicontrol(...
    'Tag', 'hFileNameText', ...
    'Parent', uiData.handles.hMapLoadPanel, ...
    'Style', 'text', ...
    'String', 'File Name:', ...
    'FontSize', 14, ...
    'FontWeight', 'bold', ...
    'Units', 'Normalized', ...
    'Position', [0.025 0.65 0.4 0.1]);

uiData.handles.hFileNameDisp        = uicontrol(...
    'Tag', 'hFileNameDisp', ...
    'Parent', uiData.handles.hMapLoadPanel, ...
    'Style', 'text', ...
    'String', 'No Map Loaded', ...
    'FontSize', 14, ...
    'Units', 'Normalized', ...
    'Tag', 'FileName', ...
    'Position', [0.025 0.475 0.8 0.15]);

uiData.handles.hFigureSaveButton   = uicontrol(...
    'Tag', 'hFigureSaveButton', ...
    'Parent', uiData.handles.hMapLoadPanel, ...
    'Style', 'pushbutton', ...
    'String', 'Load', ...
    'FontSize', 14, ...
    'FontWeight', 'bold', ...
    'Units', 'Normalized', ...
    'Position', [0.025 0.3 0.8 0.125], ...
    'Callback', {@mapLoad_callback, uiData});
end

function uiData = makeUiData

uiData              = SimpleClass;

dsProps(1)          = addprop(uiData, 'sacDataArray');
dsProps(2)          = addprop(uiData, 'handles');
dsProps(4)          = addprop(uiData, 'badPoints');

dsProps(1).SetObservable = true;
dsProps(4).SetObservable = true;

end

function uiData = dummyPDS(uiData)

% if we're making a dummy PDS, let's make a gmdistribution object to
% generate spikes with in a structured way.
rotMat = @(theta)[cosd(theta) -sind(theta); sind(theta) cosd(theta)];
tempRotMat = rotMat(rand*90);
uiData.PDS.gmObj = gmdistribution([sign(randn)*(7+rand*2) sign(randn)*(7+rand*2)], tempRotMat*[rand*5 + 3 0; 0 rand*5 + 3]*tempRotMat');
nTrials = 60;
uiData.sacDataArray         = [uiData.sacDataArray; [-20 + rand(nTrials-length(uiData.sacDataArray(:,1)),1)*40, -15 + rand(nTrials-length(uiData.sacDataArray(:,1)),1)*30, zeros(nTrials-length(uiData.sacDataArray(:,1)), 1), NaN(nTrials-length(uiData.sacDataArray(:,1)),2)]];
uiData.sacDataArray(:,3)    = 1;
uiData.PDS.targXY           = uiData.sacDataArray(:,1:2);
uiData.PDS.sptimes          = cellfun(@(x)x(x<5),cellfun(@(x)cumsum(exprnd(1/x, 1, 1000)), num2cell(100*uiData.PDS.gmObj.pdf(uiData.PDS.targXY)/uiData.PDS.gmObj.pdf(uiData.PDS.gmObj.mu)), 'UniformOutput', 0'), 'UniformOutput', 0');
uiData.PDS.spikes           = cellfun(@(x)ones(length(x),1), uiData.PDS.sptimes, 'UniformOutput',false);
uiData.PDS.state            = repmat([1.5, 1.5, 1.5, 1.5, 1.5, 1.5, 3, 3, 3.1, 3.2]', nTrials/10, 1);
uiData.PDS.timeTON          = randn(nTrials,1) + 1.5;
uiData.PDS.timeSCON         = randn(nTrials,1) + 1.5;
uiData.PDS.peakVel          = sqrt(uiData.PDS.targXY(:,1).^2 + uiData.PDS.targXY(:,2).^2)*50;
uiData.PDS.preSacXY         = normrnd(0, 0.1, nTrials, 2);
uiData.PDS.postSacXY        = uiData.PDS.targXY + normrnd(0,0.4, nTrials, 2);
end

function uiData = initTargetLocs(uiData)

% number of initial x & y target locations
nXpts                       = 5;
nYpts                       = 5;

% define initial dimensions of "sacDataArray", n target locations rows by 9
% columns: (1) target X location, (2) target Y location, (3) pre-saccade
% gaze location X, (4) pre-saccade gaze location Y, (5) post-saccade gaze
% X, (6) post-saccade gaze Y, (7) peak velocity, (8) reaction time, (9) has
% this target location been used (logical)?
uiData.sacDataArray         = zeros(nXpts * nYpts, 9);

% define initial target locations
uiData.sacDataArray(:, 1:2) = sortrows(...
    [repmat(linspace(-10, 10, nXpts)', nYpts, 1), ...
    reshape(repmat(linspace(-10, 10, nYpts), nXpts, 1), nYpts*nXpts, 1)]);

% get rid of location at center
oPt                         = all(...
    bsxfun(@eq, uiData.sacDataArray(:, 1:2), [0 0]), 2);
uiData.sacDataArray(oPt,:)  = [];

% randomize order
uiData.sacDataArray  = uiData.sacDataArray(randperm(nYpts*nXpts - 1)', :);
end

function uiData = updatePlots(hObject, eventdata, uiData)

% updates various plots with spike data after PDS is modified
updateHeatMap([], [], uiData);
updateRasters([], [], uiData);

end

function updateTargetsPlot(hObject, eventdata, uiData)

% Do we need to add a new plot object or just change colors? Compare number
% of plot objects to length of points-list.
nPnts   = size(uiData.sacDataArray,1);
nPlts   = size(uiData.handles.hTPlots,1);

% uiData.handles.hScPlt   = hSacEndLoc;
% uiData.handles.hScPlts  = hSacEndLocs;
% uiData.handles.hSTCL    = hTargSacConLine;
% uiData.handles.hSTCLs   = hTargSacConLines;

% add new plot objects if needed
if nPnts ~= nPlts
    uiData.handles.hTPlots = [copyobj(uiData.handles.hUnvisT, repmat(get(uiData.handles.hTPlots(1,1), 'Parent'), nPnts-nPlts, 1)); uiData.handles.hTPlots];
    uiData.handles.hScPlts = [copyobj(uiData.handles.hScPlt, repmat(get(uiData.handles.hScPlts(1,1), 'Parent'), nPnts-nPlts, 1)); uiData.handles.hScPlts];
    uiData.handles.hSTCLs  = [copyobj(uiData.handles.hSTCL, repmat(get(uiData.handles.hSTCLs(1,1), 'Parent'), nPnts-nPlts, 1)); uiData.handles.hSTCLs];
end

% position plot objects;
set(uiData.handles.hTPlots, ...
    {'XData'}, num2cell(uiData.sacDataArray(:,1)), ...
    {'YData'}, num2cell(uiData.sacDataArray(:,2)));

% fill in target locations that have been completed
doneGrp     = uiData.sacDataArray(:,3) == 1;
if nnz(doneGrp)
    set(uiData.handles.hTPlots(doneGrp), ...
        {'MarkerFaceColor'}, mat2cell(zeros(sum(doneGrp),3), ones(sum(doneGrp),1), 3));
    
    set(uiData.handles.hScPlts(doneGrp), ...
        {'MarkerFaceColor'}, mat2cell(zeros(sum(doneGrp),3), ones(sum(doneGrp),1), 3));
    
    set(uiData.handles.hScPlts(doneGrp), ...
        {'XData'}, num2cell(uiData.sacDataArray(doneGrp,4)), ...
        {'YData'}, num2cell(uiData.sacDataArray(doneGrp,5)));
    
    set(uiData.handles.hSTCLs(doneGrp), ...
        {'XData'}, mat2cell([uiData.sacDataArray(doneGrp,1), uiData.sacDataArray(doneGrp,4)], ones(nnz(doneGrp),1), 2), ...
        {'YData'}, mat2cell([uiData.sacDataArray(doneGrp,2), uiData.sacDataArray(doneGrp,5)], ones(nnz(doneGrp),1), 2));
end

if nnz(~doneGrp)
    set(uiData.handles.hTPlots(~doneGrp), ...
        {'MarkerFaceColor'}, mat2cell(ones(sum(~doneGrp),3), ones(sum(~doneGrp),1), 3));
end

% reassign data structure to figure handle
set(get(get(uiData.handles.hTPlots(1,1), 'Parent'), 'Parent'), 'UserData', uiData);

drawnow;
end

function updateHeatMap(hObject, eventdata, uiData)

flatten = @(x)x(:);
repPts  = @(x,y)repmat(x,y,1);
newCData    = [];

if isempty(uiData.PDS)
elseif  nnz(uiData.PDS.state == 1.5)>2
    
    
    if ~isempty(uiData.badPoints)
        uiData.PDS.state(find(uiData.badPoints)) = 1.6;
    end
    
    % only use at correctly performed trials.
    g           = uiData.PDS.state == 1.5;
    
    % determine desired time-window based on GUI objects
    posFields   = get(uiData.handles.TMMenu, 'String');
    currField   = posFields{get(uiData.handles.TMMenu, 'Value')};
    
    % how many trials are we dealing with?
    nTrials     = nnz(g);
    
    % if we have enough unique target-location trials, make a map
    if size(unique(uiData.PDS.targXY(g,:),'rows'),1) > 2
        
        % make sure we don't get an annoying warning from
        % triscatteredinterp
        warning('off', 'MATLAB:TriScatteredInterp:DupPtsAvValuesWarnId');
        
        % what type of map are we making?
        switch get(uiData.handles.hMapType, 'Value')
            case 0 % spike-based.
                
                % if we've got spikes
                if ~all(cellfun(@isempty, uiData.PDS.sptimes))
                    % calculate spike counts in desired window
                    spCounts    = cellfun(@(x,y,a,b)nnz(x>(y+a) & x<(y+b)), flatten(uiData.PDS.sptimes(g)), flatten(num2cell(uiData.PDS.(currField)(g))), num2cell(get(uiData.handles.TLow, 'Value')/1000*ones(nTrials,1)), num2cell(get(uiData.handles.THigh, 'Value')/1000*ones(nTrials,1)));
                    
                    % fit X / Y / spike-count data to linear-interpolant "F".
                    if get(uiData.handles.mapXYtog, 'Value')
                        X = uiData.PDS.postSacXY(g,1);
                        Y = uiData.PDS.postSacXY(g,2);
                    else 
                        X = uiData.PDS.targXY(g,1);
                        Y = uiData.PDS.targXY(g,2);
                    end
                    F           = TriScatteredInterp(X, Y, spCounts);
                    
                    % fit gaussian to spike count data, we're going to use the linear
                    % interpolant to guess the parameters. But we only want to do this if
                    % we have enough data points! We need at least 8 since we have 7
                    % parameters.
                    if size(unique(uiData.PDS.targXY(g,:),'rows'),1) > 7
                        fitParamsGuess = calcFitGuess(F, uiData);
                        uiData.rfFit = gauss2D.fit([uiData.PDS.targXY(g,1), uiData.PDS.targXY(g,2)], spCounts, fitParamsGuess);
                    end
                else
                    F = TriScatteredInterp([0 0; 1 0; 0 1], [0; 0; 0]);
                end
            case 1
                % fit X / Y / peak-velocity data to linear-interpolant "F".
                % We're using saccade end-point for this map, not target
                % location...
                F           = TriScatteredInterp(uiData.PDS.postSacXY(g,1), uiData.PDS.postSacXY(g,2), flatten(uiData.PDS.peakVel(g)));
        end
        
        % how many x / y points do we have?
        [nY, nX]    = size(get(uiData.handles.hHeatMap, 'CData'));
        
        % if we've got a pre-loaded vMap, and that's the type of map we're
        % presenting, use that preloaded vMap and take the difference
        % between the two for the result...
        if isprop(uiData, 'vMap') && get(uiData.handles.hMapType, 'Value')
            nc1    = reshape(F([flatten(repmat(get(uiData.handles.hHeatMap, 'XData'), nY, 1)), repmat(get(uiData.handles.hHeatMap, 'YData')', nX, 1)]), nY, nX);
            nc2    = reshape(uiData.vMap([flatten(repmat(get(uiData.handles.hHeatMap, 'XData'), nY, 1)), repmat(get(uiData.handles.hHeatMap, 'YData')', nX, 1)]), nY, nX);
            newCData = nc1-nc2;
        else
            % evaluate linear interpolant at grid-locations to get map intensity (color) data.
            newCData    = reshape(F([flatten(repmat(get(uiData.handles.hHeatMap, 'XData'), nY, 1)), repmat(get(uiData.handles.hHeatMap, 'YData')', nX, 1)]), nY, nX);
        end
        
        
        
        
        % update colorbar
        amin = nanmin(newCData(:));
        amax = nanmax(newCData(:));
        cmin = sign(amin)* abs(amin)/range(newCData(:));
        cmax = sign(amax)* abs(amax)/range(newCData(:));
        if all([cmin cmax] == 0) || all(isnan([cmin cmax]));
            cmin = 0;
            cmax = 1;
            amin = 0;
            amax = 1;
        end
        cBarData = repmat(linspace(cmin, cmax, 100)',1,2);
        cBarYTick = linspace(amin, amax, 11)';
        try
            set(uiData.handles.hColBrAx, 'YTickLabel', arrayfun(@(x)num2str(round(x*10)/10), cBarYTick, 'UniformOutput', false), 'CLim', [cmin cmax]);
        catch
            keyboard
        end
        set(uiData.handles.hColrBar, 'CData', cBarData);
        
        % update map with new color data
        set(uiData.handles.hHeatMap, 'CData', newCData / range(newCData(:)));
        set(get(uiData.handles.hHeatMap,'Parent'), 'CLim', [cmin cmax]);
        
        % reassign data structure to figure handle
        set(get(get(uiData.handles.hTPlots(1,1), 'Parent'), 'Parent'), 'UserData', uiData);
        drawnow;
    end
end

% if we just want to see the loaded PKV data.
if isempty(newCData) && isprop(uiData, 'vMap') && get(uiData.handles.hMapType, 'Value')
    % how many x / y points do we have?
    [nY, nX]    = size(get(uiData.handles.hHeatMap, 'CData'));
    newCData    = reshape(uiData.vMap([flatten(repmat(get(uiData.handles.hHeatMap, 'XData'), nY, 1)), repmat(get(uiData.handles.hHeatMap, 'YData')', nX, 1)]), nY, nX);
    
    % update map with new color data
    try
        set(uiData.handles.hHeatMap, 'CData', newCData / range(newCData(:)));
    catch me
        keyboard
    end
    
    
    % update colorbar
    cBarData = repmat(linspace(nanmin(newCData(:)) / max(flatten(newCData)), nanmax(newCData(:)) / max(flatten(newCData)), 100)', 1,2);
    cBarYTick = linspace(nanmin(newCData(:)), nanmax(newCData(:)), 11)';
    set(uiData.handles.hColBrAx, 'YTickLabel', arrayfun(@(x)num2str(round(x*10)/10), cBarYTick, 'UniformOutput', false));
    set(uiData.handles.hColrBar, 'CData', cBarData);
    
    % reassign data structure to figure handle
    set(get(get(uiData.handles.hTPlots(1,1), 'Parent'), 'Parent'), 'UserData', uiData);
    drawnow;
end

end

function updateRasters(hObject, eventdata, uiData)

flatten = @(x)x(:);

if isempty(uiData.PDS)
elseif uiData.PDS.state(end) == 1.5 && ~isempty(uiData.PDS.sptimes{end})
    
    % if we're here, there's a new raster line to plot, keep count of how
    % many raster lines we have...
    currRasterCount = get(uiData.handles.hRst, 'UserData');
    if isempty(currRasterCount)
        currRasterCount = 0;
    end
    newRasterCount = currRasterCount + 1;
    set(uiData.handles.hRst, 'UserData', newRasterCount);
    
    % with respect to which times are we interested in plotting spikes?
    relTimes = {'timetfon', 'timesacon', 'timereward'};
    
    %%% update spike-plot
    spTimes = uiData.PDS.sptimes{end}(logical(uiData.PDS.spikes{end}));
    
    % what do we want the half-length of the raster-lines to be?
    lineRad         = 0.4;
    
    % make new objects for the spikes.
    newRasters  = copyobj(uiData.handles.hRst, flipud(flatten(repmat([uiData.handles.hSpAx1, uiData.handles.hSpAx2, uiData.handles.hSpAx3], length(spTimes),1))));
    
    % set the properties of the new raster-objects
    set(newRasters, {'XData'}, mat2cell(repmat(spTimes(:),3,2) - repmat(flatten(repmat([uiData.PDS.timetfon(end), uiData.PDS.timesacon(end), uiData.PDS.timereward(end)], length(spTimes), 1)),1,2), ones(1,3*length(spTimes),1),2),...
        {'YData'}, mat2cell(repmat(newRasterCount,3*length(spTimes),2) + repmat([-1 1]*lineRad,3*length(spTimes),1), ones(1,3*length(spTimes),1),2));
    
    % bin all the spikes to plot an average
    for i = 1:length(relTimes)
        allSpTimes          = cell2mat(cellfun(@(x,y,z)x(logical(y))' - z, uiData.PDS.sptimes, uiData.PDS.spikes, num2cell(uiData.PDS.(relTimes{i})), 'UniformOutput', false)');
        [spBin{i}, binC{i}] = spikeBin(allSpTimes, 0.02);
    end
    
    % update the plots with the newly calculated data
    set([uiData.handles.hBSPlt1; uiData.handles.hBSPlt2; uiData.handles.hBSPlt3], {'XData'}, binC', {'YData'}, spBin');
    
    % update the x-limits on the binned-spike plotting axes
    set([uiData.handles.hSpAx1b; uiData.handles.hSpAx2b; uiData.handles.hSpAx3b], {'XLim'}, get([uiData.handles.hSpAx1; uiData.handles.hSpAx2; uiData.handles.hSpAx3], 'XLim'));
    
    % update the y-limits on the raster plots based on how many trials
    % we're plotting. If we've got 40 or fewer, keep the y-lims at 40,
    % otherwise, update...
    yplotmin = max([40 newRasterCount]);
    try
    set([uiData.handles.hSpAx1; uiData.handles.hSpAx2; uiData.handles.hSpAx3], {'YLim'},{[0 yplotmin]},{'YTick'},{0:10:yplotmin});
    catch
        keyboard
    end
    
    % reassign data structure to figure handle
    set(get(get(uiData.handles.hTPlots(1,1), 'Parent'), 'Parent'), 'UserData', uiData);
    drawnow;
end
end

function updateFit(hObject, eventdata, uiData)

% inline function definitions
flatten = @(x)x(:);
rotMat = @(theta)[cosd(theta) -sind(theta); sind(theta) cosd(theta)];

% grab children of the fit properties panel
fitKids = flipud(get(uiData.handles.hFitPanel,'Children'));

% grab X & Y data from contour plot, evaluate using current gaussian
% fit and update contour plot using result
[X, Y] = meshgrid(get(uiData.handles.hCntr, 'XData'), get(uiData.handles.hCntr, 'YData'));
[levels, radii] = uiData.rfFit.pctbound(cellfun(@str2double, get(fitKids(19:21), 'String'))/100);
set(uiData.handles.hCntr, 'ZData', reshape(uiData.rfFit.value([flatten(X), flatten(Y)]), size(X, 1), size(X, 2)), 'LevelList', levels,'HitTest','off');

% grab mean & sigma
mean = uiData.rfFit.mu;

% compute mean in polar coords.
meanpol = [norm(mean) atan2d(mean(2), mean(1))];
sigma = rotMat(uiData.rfFit.angle)*[uiData.rfFit.sigma(1) 0; 0 uiData.rfFit.sigma(2)]*rotMat(uiData.rfFit.angle)';
set(fitKids([2:5 7:10 12:17]), {'String'},arrayfun(@num2str,round(10*[mean(1) mean(2) meanpol(1) meanpol(2) sigma(1) sigma(2) sigma(3) sigma(4) radii']')/10,'UniformOutput',false));
end

function [n, binCenters] = spikeBin(spikeTimes, binWidth)

minTime     = floor(min(spikeTimes)*1000)/1000;
maxTime     = ceil(max(spikeTimes)*1000)/1000;
myEdges     = minTime:binWidth:maxTime;

if myEdges(end) < maxTime
    myEdges = [myEdges, maxTime];
end

n           = histc(spikeTimes, myEdges);
binCenters  = mean([myEdges(1:end-1); myEdges(2:end)]);
n           = n(1:end-1);
end

function c = myContourc(x,y,Z,level)
fh = figure('Visible','off');
c = contour(x,y,Z,level);
close(fh);
end

function pguess = calcFitGuess(F, uiData)

flatten = @(x)x(:);

% a grid of points to evaulate the linear interpolant "F" on.
[Xhm, Yhm] = meshgrid(get(uiData.handles.hHeatMap,'XData'), get(uiData.handles.hHeatMap,'YData'));

% find F's max.
interpMax = max(flatten(F(Xhm, Yhm)));

% the X/Y value corresponding to the maximum
[iPk,jPk] = ind2sub(size(Xhm), find(F(Xhm, Yhm) == interpMax));

% the guess for the mean is the coordinates of F's maximum
muGuess = [mean(flatten(Xhm(iPk, jPk))), mean(flatten(Yhm(iPk, jPk)))];

% calculate the contour of F at half it's max (for guessing sigma)
c2 = myContourc(linspace(min(flatten(Xhm)), max(flatten(Xhm)), length(unique(flatten(Xhm)))), linspace(min(flatten(Yhm)), max(flatten(Yhm)), length(unique(flatten(Yhm)))), F(Xhm, Yhm), interpMax/2);

% our guess for sigma is the max distance from the peak's coords to the
% halfmax contour.
sigmaGuess = max(sqrt(sum(bsxfun(@minus,c2(:,2:end), muGuess').^2)));

% put the guess together (we guess an angle of 1, an additive offset of 0,
% and a scaling factor based on the guess for mu/sigma.
pguess = [muGuess, sigmaGuess*[1, 1], 1, 0, interpMax/mvnpdf(muGuess,muGuess,sigmaGuess*eye(2))];
end