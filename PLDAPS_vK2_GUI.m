function varargout = PLDAPS_vK2_GUI(varargin)
%
% uiHandle = PLDAPS_vK2_GUI_jph(varargin)
%

% build ui elements
uiData = buildUiElements;

% get pldaps directory (ie directory of this function) and cd into it:
uiData.paths.pldapsDir = fileparts(mfilename('fullpath'));
cd(uiData.paths.pldapsDir)

% define location to start searching for a settings file:
uiData.paths.settingsFileSearchStart = uiData.paths.pldapsDir;

% Paths:
% Reset path to the defualt matlab path, and then add path of pldapsDir 
% (this adds all root directory packages, eg +pds, +rigConfigFiles)
path(pathdef);
addpath(uiData.paths.pldapsDir);

% Update handles structure
guidata(uiData.handles.hGui, uiData);


% if gui is called with an output, return the handle to the gui window
if nargout
    mOutputArgs = {uiData.handles.hGui};
    [varargout{1:nargout}] = mOutputArgs{1:nargout};
end

end

%% callbacks
% callback function for control parameter popups
function ctrlParamPopUp_callback(hObject, eventdata)

% grab uiData
uiData = guidata(hObject);

% which row's menu triggered the callback?
rowVal = get(hObject, 'UserData');

% get all the strings in the popup menu so we know what the name of the
% selected parameter is.
menuStrings = get(hObject, 'String');

% what is the value of the menu? (which item is selected)
menuVal = get(hObject, 'Value');

% what's the value of the newly selected parameter?
paramVal = uiData.p.trVarsGuiComm.(menuStrings{menuVal});

% make sure the parameter is a scalar, and return a string; if it's not a
% scalar, return 'NaN'.
if isnumeric(paramVal) && numel(paramVal) == 1 && ~isempty(paramVal)
    paramString = num2str(paramVal);
else
    paramString = 'NaN';
end

% set the row's "edit" uicontrol to the value in "p"
set(uiData.handles.ctrlParamEdit(rowVal), 'String', paramString);
drawnow;

% update uiData
guidata(hObject, uiData);

end

% callback function for control parameter editable text boxes
function ctrlParamEdit_callback(hObject, eventdata)

% grab uiData
uiData = guidata(hObject);

% which row's menu triggered the callback?
rowVal = get(hObject, 'UserData');

% get all the strings in the associated popup menu so we know what the name
% of the selected parameter is (and can assign it properly in
% uiData.p.trVarsGuiComm).
menuStrings = get(uiData.handles.ctrlParamPopUp(rowVal), 'String');

% what is the value of the popup menu? (which item is selected)
menuVal = get(uiData.handles.ctrlParamPopUp(rowVal), 'Value');

% get the string that was modified.
newParamValue = str2double(get(hObject, 'String'));

% if the value is a scalar, assign it to the appropriate place in
% uiData.p.trVarsGuiComm, otherwise, pull the current value from
% uiData.p.trVarsGuiComm and overwrite what the user input.
if isnumeric(newParamValue) && numel(newParamValue) == 1 && ...
        ~isempty(newParamValue) && ~isnan(newParamValue)
    uiData.p.trVarsGuiComm.(menuStrings{menuVal}) = newParamValue;
else
    overWriteString = num2str(...
        uiData.p.trVarsGuiComm.(menuStrings{menuVal}));
    
    % it's hard to imagine that the value in trVarsGuiComm could be
    % non-scalar, so it seems unnecessary to have a trap here to deal with
    % that eventuality, but if shit goes haywire, here's a good place to
    % look (jph - 7/2/2018).
    set(hObject, 'String', overWriteString);
end

%update display
drawnow;

% update uiData
guidata(hObject, uiData);

end

% callback function for status values popups
function statValPopUp_callback(hObject, eventdata)

% I don't think this actually needs to do anything... I'm going to leave it
% in for now in case... (jph - 6/28/2018).

end

% callback function for settings file popup menu
function settingsFilesPopUp_callback(hObject, eventdata)

% I don't think this actually needs to do anything... I'm going to leave it
% in for now in case... (jph - 6/28/2018).

end

% callback function for settings file browse button
function settingsFilesBrowse_callback(hObject, eventdata)

% first grab uiData: it contains the path where we want to start searching
% for settings files.
uiData = guidata(hObject);

% prompt user to select settings file, use temporary variables to hold
% file & path strings in case they press "cancel".
[tempFileName, tempPathName] = uigetfile(...
    [uiData.paths.settingsFileSearchStart '/*.m'], 'choose settings file');

% if they press "cancel" instead of "ok", we're done. Tell the user they
% pressed cancel.
if isequal(tempFileName,0)
    display('User Pressed Cancel!')
    
% if they didn't press cancel, we're going to store the name of the
% selected settings file and the path to the file.
else
    
    % is this the first time the browse button has been clicked? If so,
    % some relevant fields don't exist.
    if isfield(uiData.paths, 'settingsFileNames')
        
        % if the field exists, one or more settings files have already been
        % selected / stored.
        nSettingsFiles = length(uiData.paths.settingsFileNames);
    else
        nSettingsFiles = 0;
    end
    
    % store name & path of selected settings file
    uiData.paths.settingsFileNames{nSettingsFiles + 1} = tempFileName;
    uiData.paths.settingsFilePaths{nSettingsFiles + 1} = tempPathName;
    
    % update settings file popup string(s) and value
    set(uiData.handles.settingsFilesPopUp, ...
        'String', uiData.paths.settingsFileNames, ...
        'Value', nSettingsFiles + 1);
    
    % if the popup menu isn't yet visible, make it visible. Also, make the
    % initialize button visible.
    if strcmp(get(uiData.handles.settingsFilesPopUp, 'Visible'), 'off')
        set(uiData.handles.settingsFilesPopUp, 'Visible', 'on');
        set(uiData.handles.initializeButton, 'Visible', 'on');
    end

    % update gui status string
    set(uiData.handles.uiStatusString, 'String', 'Ready to Initialize');
    
    % make changes visible to user
    drawnow;
end

% Update handles structure
guidata(hObject, uiData);

end

% callback function for clear button
function clearButton_callback(hObject, eventdata)
Screen('CloseAll');
end

% callback function for initialize button
function initializeButton_callback(hObject, eventdata)

% grab uidata
uiData = guidata(hObject);

% tell the user we're doing the initialization
set(uiData.handles.uiStatusString, 'String', 'Initializing...');

% which settings file is currently selected in the settings files popup
% menu?
currentSettingsFileIndex = get(uiData.handles.settingsFilesPopUp, 'value');

% % log current directory before CDing into directory containing settings
% % file & initialization file.
% currentDirectory = pwd;

% % CD into directory containing settings file & initialization file 
% % (necessary for eval function).
% eval(['cd ' uiData.paths.settingsFilePaths{currentSettingsFileIndex}]);

% add paths to all sub-directories within the selected settings file 
% directory. This adds all associated actions to the path too. But wait!
% First, remove all previous paths by setting the path to defautl, and
% obviously, adding the main pldaps dir:
path(pathdef);
addpath(uiData.paths.pldapsDir);
addpath(genpath(uiData.paths.settingsFilePaths{currentSettingsFileIndex}));

% evaluate settings file function, returning "p"
eval(['uiData.p = ' ...
    uiData.paths.settingsFileNames{currentSettingsFileIndex}(1:end-2)]);

%% use "p" to populate ctrlParamPopup menus and ctrlParamEdit text boxes.

% how many control parameter "slots" (popup menu / box rows) are there?
nCtrlParamRows = length(uiData.handles.ctrlParamPopUp);

try
% Obtain all trial variable names in string form, and sort:
trVarsStrings = pds.setStringListForGui(uiData.p.trVarsGuiComm);
trVarsStrings = sort(trVarsStrings);
catch me
    keyboard
end

% If user has defined a list of variables to use as control parameters in
% "settings", use them to populate 'guiStrings':
guiStrings          = cell(nCtrlParamRows, 1);
ptr_trVarsStrings   = nan(nCtrlParamRows, 1);
for ii = 1:nCtrlParamRows
    % if 'guiVars' were defined by user:
    if ~isempty(uiData.p.rig.guiVars) && ...
            ~isempty(uiData.p.rig.guiVars{ii})
        
        % find match between input guiVar and trVarsStrings:
        guiVar  = uiData.p.rig.guiVars{ii};
        idx     = strcmp(guiVar, trVarsStrings);
        
        % if match:
        if sum(idx) == 1
            % get pointer to correct string in trVarsStrings
            ptr_trVarsStrings(ii) = find(idx); % pointer into trVarsStrings
            % and get the string:
            guiStrings{ii}          = trVarsStrings{ptr_trVarsStrings(ii)};
        else
            
            % if no match, assign first entries in trVarsStrings:
            warning([...
                'couldnt match guiVars ''' ...
                guiVar ''' ...with existing vars. Take note!']);
            guiStrings{ii}          = trVarsStrings{ii};
            ptr_trVarsStrings(ii) = ii;
        end
    else
        % % if empty, assign first entries in trVarsStrings:
        guiStrings{ii}              = trVarsStrings{ii};
        ptr_trVarsStrings(ii)     = ii;
    end
end

% populate each ctrlParamPopUp menu with the list of possible trial
% variable strings, the appropriate values, and make them visible.
set(uiData.handles.ctrlParamPopUp', ...
    {'String'}, {trVarsStrings}, ...
    {'Value'}, num2cell(ptr_trVarsStrings), ...
    'Visible', 'on');

% get all the values of the specified variables. In case some of them are
% anything other than scalars, keep them in a cell.
varValues = cellfun(@(x)uiData.p.trVarsGuiComm.(x), guiStrings, ...
    'UniformOutput', false);

% set any non-scalar values to "NaN"
scalarVals = cellfun(...
    @(x)isnumeric(x) && numel(x) == 1 && ~isempty(x), varValues);
varValues(~scalarVals) = {NaN};

% populate each ctrlParamEdit menu with the appropriate variable value (as
% a string), and make them all visible.
set(uiData.handles.ctrlParamEdit, ...
    {'String'}, cellfun(@num2str, varValues, ...
    'UniformOutput', false), ...
    'Visible', 'on');

% How many rows of status value ui elements do we have? 
nStatusValueRows = length(uiData.handles.statValPopUp);

% Grab the names of status values from "p". First, get the list of
% fieldnames in the order they appear in the structure, we assume this is
% the order that the 
statusValueNames = sort(fieldnames(uiData.p.status));

% in "p.rig.guiStatVals", the user specifies the order of the status values
% they'd like to see in the GUI. Find numerical indexes for them ...
statValPopUpNumericals = cellfun(@(x)find(strcmp(statusValueNames, x)), ...
    uiData.p.rig.guiStatVals);

% if the status value names specified by the user are not found, or if they
% speficy fewer than "nStatusValueRows", we need to pad this list so that
% all the popUps have values.
nStatValPopUpNumericals = length(statValPopUpNumericals);
if nStatValPopUpNumericals < nStatusValueRows
    statValPopUpNumericals = [statValPopUpNumericals; ...
        (1:(nStatusValueRows - nStatValPopUpNumericals))'];
end

% populate each statValPopUp menu with the list of possible status
% value strings, the appropriate values, and make them visible.
set(uiData.handles.statValPopUp(1:nStatusValueRows)', ...
    {'String'}, {statusValueNames}, ...
    {'Value'}, num2cell(statValPopUpNumericals), ...
    'Visible', 'on');

% get all the values of the specified satus values. In case some are
% anything other than scalars, keep them in a cell.
statValues = cellfun(@(x)uiData.p.status.(x), ...
    statusValueNames(statValPopUpNumericals), 'UniformOutput', false);

% set any non-scalar values to "NaN"
scalarVals = cellfun(...
    @(x)isnumeric(x) && numel(x) == 1 && ~isempty(x), ...
    statValues);
statValues(~scalarVals) = {NaN};

% populate each statValText menu with the appropriate variable value (as
% a string), and make them all visible.
set(uiData.handles.statValText(1:nStatusValueRows), ...
    {'String'}, cellfun(@num2str, statValues, ...
    'UniformOutput', false), ...
    'Visible', 'on');

% What do we have fewer of: rows of user-defined action buttons or
% user-defined actions to populate them with?
nUserActionRows = min([length(uiData.handles.userActionButton), ...
    length(uiData.p.init.taskActions)]);

% set button strings and make visible. But if they are part of the 
% +pdsActions package remove the string 'pdsActions.', for elegance: 
for ii = 1:numel(uiData.p.init.taskActions)
    uiData.p.init.taskActionsElegant{ii} = uiData.p.init.taskActions{ii};
    if strfind(uiData.p.init.taskActions{ii}, 'pdsActions.')
        uiData.p.init.taskActionsElegant{ii}(1:numel('pdsActions.')) = [];
    end
end
set(uiData.handles.userActionButton(1:nUserActionRows), ...
    {'String'}, uiData.p.init.taskActionsElegant', ...
    'Visible', 'on');

% set output path string from "p" and make it visible:
set(uiData.handles.outputPathString, ...
    'String', uiData.p.init.outputFolder, ...
    'Visible', 'on');

% make output path button and concatenate output button visible
set([uiData.handles.outputPathButton; ...
    uiData.handles.concatenateOutputButton], 'Visible', 'on');

% % % add task folder and subfolders to path
% % addpath(genpath(uiData.p.init.taskFolder))

% clear Screen, close DATAPixx / VIEWPixx, and eliminate Psychtoolbox 
% welcome screen before user-initialization function.
Screen('CloseAll');
if uiData.p.init.useDataPixxBool
    Datapixx('close');
end
Screen('Preference','VisualDebuglevel',3);


%% user-initialization

% first, make sure Datapixx is open:
try 
    if uiData.p.init.useDataPixxBool
        Datapixx('Open');
    end
catch me 
    error(['I BET YOU 1 MILLION DOLLARS THAT YOU FORGOT TO TURN DATAPIXX ON'...
        'no gow turn it on & hit Initialize before anyone notices your ignorance']); 
end

% and now, run the task's init file:
eval(['uiData.p = ' uiData.p.init.taskFiles.init(1:end-2) ...
    '(uiData.p);']);

% make clear and run buttons visible.
set([uiData.handles.clearButton; ...
    uiData.handles.runButton], 'Visible', 'on');

% provide message to user on gui about status
tstring = sprintf('%s: Initialized with file %s', ...
    uiData.p.init.protocol_title, ...
    uiData.paths.settingsFileNames{currentSettingsFileIndex});
set(uiData.handles.uiStatusString, 'String', tstring);

% Update handles structure so data are shared
guidata(hObject, uiData);

%% Tell the user what they've won:

fprintf('\r')
disp('============================================')
disp('=======  PLDAPS vK2, AT YOUR SERVICE!')
disp('============================================')
disp('==========  Initializing settings file: ')
disp(['==========  ' uiData.paths.settingsFileNames{currentSettingsFileIndex}])
disp(['==========  ' datestr(now)])
disp('============================================')
fprintf('\r')

end

% callback function for run button button
function runButton_callback(hObject, eventdata)

% get uiData
uiData = guidata(hObject);

% have we just toggled the run button on or off?
uiData.p.runFlag = get(hObject, 'Value');

% store "runFlag" state:
guidata(hObject, uiData);

% if we just toggled the button "on" (down), do one thing, if we just
% toggled the button "off" (up), do another...
if uiData.p.runFlag
    
    % find out how large the button is in pixels (first set its units to
    % pixels, then get its size, then set its units back to normalized.
    set(hObject, 'Units', 'Pixels');
    buttonPosPix = get(hObject, 'Position');
    set(hObject, 'Units', 'Normalized');
    
    % make the button green and the text of the button white.
    tempImage = 0.6*ones(floor(buttonPosPix(4)), floor(buttonPosPix(3)), 3);
    tempImage(:,:,[1,3]) = 0;
    set(hObject, 'CData', tempImage, 'ForegroundColor', [1 1 1], ...
        'FontWeight', 'normal');
    
    % tell the user we're RUNNING
    set(uiData.handles.uiStatusString, 'String', 'Running...');
    drawnow;
else
    % reset button appearance and tell user we're no longer running
    set(hObject, 'CData', [], 'ForegroundColor', [0 0 0], ...
        'FontWeight', 'bold')
    
    % tell the user we're RUNNING
    set(uiData.handles.uiStatusString, 'String', 'Idle.');
    drawnow;
end
drawnow;

% go into the directory containing the currently relevant run-files.
% First, determine which protocol is presently initialized (pipi :
% presently initialized protocol index). First get current directory so we
% can return when done.
currentDirectory = pwd;

% if the run button is toggled ON, do steps neccessary prior to entering
% the "run while loop"
if get(hObject, 'Value')
    
    % tell the user we're RUNNING
    set(uiData.handles.uiStatusString, 'String', 'Running...');
    drawnow;
    
    % which settings file is currently selected in the settings files popup
    % menu? (for choosing the directory to CD into for the "run", "next",
    % and "finish" files).
    currentSettingsFileIndex = get(uiData.handles.settingsFilesPopUp, 'value');
% 
%     % CD into directory containing settings file & initialization file
%     % (necessary for eval function).
%     eval(['cd ' uiData.paths.settingsFilePaths{currentSettingsFileIndex}]);

    while true
        
        % get the latest "p" values from the gui
        uiData = guidata(hObject);
        
        % evaluate "next" file function, returning "p"
        eval(['uiData.p = ' uiData.p.init.taskFiles.next(1:end-2) '(uiData.p);']);
        
        % update uiData, update the status values being displayed in the
        % gui, then pul uiData back down (in case it's been changed by the
        % user? Is this really necessary to do in between next/run,
        % run/finish, finish/next? I'd think pulling uiData between
        % finish/next would be all that's needed...
        guidata(hObject, uiData);
        updateStatusValues(uiData);
        drawnow;
        uiData = guidata(hObject);

        % evaluate "run" file function, returning "p"
        eval(['uiData.p = ' uiData.p.init.taskFiles.run(1:end-2) '(uiData.p);']);
        
        % update uiData, update the status values being displayed in the
        % gui, then pul uiData back down.
        guidata(hObject, uiData);
        updateStatusValues(uiData);
        drawnow;
        uiData = guidata(hObject);
        
        % evaluate "finish" file function, returning "p"
        eval(['uiData.p = ' uiData.p.init.taskFiles.finish(1:end-2) '(uiData.p);']);
        
        % update uiData, update the status values being displayed in the
        % gui, then pul uiData back down.
        guidata(hObject, uiData);
        updateStatusValues(uiData);
        drawnow;
        uiData = guidata(hObject);
        
        % must execute drawnow each loop to allow the toggling OFF of the
        % run button to be registered
        drawnow;
        if ~get(hObject, 'Value')
            break
        end
    end
else
end

% update uiData, update the status values being displayed in the
% gui, then pul uiData back down.
guidata(hObject, uiData);
updateStatusValues(uiData);
drawnow;

% % % go back to original directory
% % cd(currentDirectory)

end

% callback function for output path browse button button
function outputPathButton_callback(hObject, eventdata)

% get uiData
uiData = guidata(hObject);

% prompt user to select a new output directory
newOutputFolderName = uigetdir(uiData.p.init.outputFolder, ...
    'Select an output folder...');

% update output folder in "p"
uiData.p.init.outputFolder = newOutputFolderName;

% update output folder string
set(uiData.handles.outputPathString, 'String', newOutputFolderName);
drawnow;

% update guidata
guidata(hObject, uiData);

end

% callback function for output concatenate button button
function concatenateOutputButton_callback(hObject, eventdata)

% grab uiData
uiData = guidata(hObject);

% tell the user we're loading P
set(uiData.handles.uiStatusString, 'String', 'Loading session data...');
drawnow;

% load session's data
p = pds.loadP(uiData.p.init.sessionFolder);

% tell user we're saving session's data
set(uiData.handles.uiStatusString, 'String', 'Saving session data...');
drawnow;

% save session data
sessionFileName = [uiData.p.init.outputFolder filesep ...
    uiData.p.init.sessionId '.mat'];
save(sessionFileName, '-struct', 'p');
[~, lmid] = lastwarn;
if strcmp(lmid, 'MATLAB:save:sizeTooBigForMATFile')
    save(sessionFileName, '-v7.3', '-struct', 'p');
end

% tell user we're back to "idle"
set(uiData.handles.uiStatusString, 'String', 'Idle.');
drawnow;

end

% callback function for user action buttons
function userActionButton_callback(hObject, eventdata)

% get uiData
uiData = guidata(hObject);

% each button has an index value associated with the files listed in
% uiData.p.init.taskActions, grab that value:
taskIdx = get(hObject, 'UserData');

% fileparts of the user action
[pathString, nameString] = ...
    fileparts(which(uiData.p.init.taskActions{taskIdx}));

% hack: some actions are in +pdsActions folder. In order to call them I
% need to add 'pdsActions.' to the call function, so I do that here:
if strfind(pathString, 'pdsActions')
    nameString = ['pdsActions.' nameString];
end

% run action
eval(['uiData.p = ' nameString '(uiData.p);']);

% % cd back to previous directory
% eval(['cd ' currentDirectory]);

% update uiData
guidata(hObject, uiData);

end
%% other functions

% --- gui closing function
function guiCloseFunction(hObject, eventdata)
Screen('CloseAll');
Screen('CloseMovie');
end

% --- function for updating status values
function updateStatusValues(uiData)

% grab the names of status values parameters from "p" - NOTE: this may
% differ from the names listed in the 'String' property of a given
% statValPopUp menu uicontrol. If they do differ, we're going to use this
% set of names to update the list stored in the uicontrols, but we need
% the other list as well to grab parameter values.
statusValueNames = sort(fieldnames(uiData.p.status));

% grab the list of status value parameter names stored in the statValPopUp
% menu ui control
statusValueNamesUI = get(uiData.handles.statValPopUp(1), 'String');

% make a list of the value each statValPopUp menu is set to; we need this
% because the list of names stored in the uicontrols is longer than the
% number of rows of uicontrols, so we only want the ones that are actually
% currently selected in a popup menu.
statusValueValues = cell2mat(get(uiData.handles.statValPopUp, 'Value'));

% get all the values of the specified satus value parameters. In case some
% are anything other than scalars, keep them in a cell.
statValues = cellfun(@(x)uiData.p.status.(x), ...
    statusValueNamesUI(statusValueValues), 'UniformOutput', false);

% set any non-scalar values to "NaN"
scalarVals = cellfun(...
    @(x)isnumeric(x) && numel(x) == 1 && ~isempty(x), ...
    statValues);
statValues(~scalarVals) = {NaN};

% populate each statValText menu with the appropriate variable value (as
% a string), and make them all visible.
set(uiData.handles.statValText, ...
    {'String'}, cellfun(@num2str, statValues, ...
    'UniformOutput', false));

% find numerical indexes "A" for each status value parameter that's
% currently selected in a statValPopUp menu (the list is 
% statusValueNamesUI), in statusValueNames such that:
% statusValueNamesUI = statusValueNames(A). Force it to be a cell because
% it's easier to set the values of all of the uicontrols at once with the
% cell.
statValNameIdx = cellfun(@(x)find(strcmp(statusValueNames, x)), ...
    statusValueNamesUI(statusValueValues), 'UniformOutput', false);

% redefine the list of menu items for each statValPupUp menu, and redefine
% the value each is set to so that the selected menu item remains unchanged
set(uiData.handles.statValPopUp, ...
    'String', statusValueNames, ...
    {'Value'}, statValNameIdx);

end

%% build helpers

% --- build ui elements 
function uiData = buildUiElements(uiData)

% Build main figure, make it invisble until uielements are all built
uiData.handles.hGui             = figure(...
    'MenuBar', 'none', ...
    'Toolbar', 'none', ...
    'HandleVisibility', 'callback', ...
    'Name', 'PLDAPS_vK2_GUI', ...
    'NumberTitle', 'off', ...
    'Color', get(0, 'defaultuicontrolbackgroundcolor'), ...
    'Position', [0 0 800 500], ...
    'Visible', 'Off', ...
    'DeleteFcn', @guiCloseFunction);

% build uistatus string uicontrol - this lives in the main figure, not in a
% panel, so build it here.
uiData.handles.uiStatusString   = uicontrol(...
    'Tag', 'uiStatusString', ...
    'Parent', uiData.handles.hGui, ...
    'Units','normalized', ...
    'Style', 'Text', ...
    'Position', [0.01 0.94 1 0.05], ...
    'String', 'Ready to a select a Settings File', ...
    'ForeGroundColor', [0 0 0], ...
    'FontSize', 12, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'Left', ...
    'FontUnits', 'normalized');

% build uiPanels
% 1 - settings files
% 2 - standard actions
% 3 - user-defined actions
% 4 - control parameters
% 5 - status values
% 6 - output files
uiData = buildUiPanels(uiData);

% build uicontrols in settings file panel
uiData = buildSettingsFilesUiControls(uiData);

% build uicontrols in standard actions panel
uiData = buildStandardActionsUiControls(uiData);

% build uicontrols in user-defined actions panel
uiData = buildUserActionsUiControls(uiData);

% % build uicontrols in control parameters panel
uiData = buildControlParametersUiControls(uiData);

% build uicontrols in status values panel
uiData = buildStatusValuesUiControls(uiData);

% build uicontrols in output files panel
uiData = buildOutputFilesUiControls(uiData);

% now that uielements are build, make figure window visible
set(uiData.handles.hGui, 'Visible', 'On');
drawnow;

end

% --- build ui panels
function uiData = buildUiPanels(uiData)

% build uiPanels
% 1 - settings files
% 2 - standard actions
% 3 - user-defined actions
% 4 - control parameters
% 5 - status values
% 6 - output files

uiData.handles.panels.settingsFiles     = uipanel(...
    'Tag', 'settingsFilesPanel', ...
    'Parent', uiData.handles.hGui, ...
    'Title', 'Settings Files', ...
    'TitlePosition', 'lefttop', ...
    'FontSize', 10, ...
    'ForeGroundColor', [0 0 1], ...
    'ShadowColor', [0 0 0], ...
    'Position',[0.01 0.78 0.3 0.16]);

uiData.handles.panels.standardActions   = uipanel(...
    'Tag', 'standardActionsPanel', ...
    'Parent', uiData.handles.hGui, ...
    'Title', 'Standard Actions', ...
    'TitlePosition', 'lefttop', ...
    'FontSize', 10, ...
    'ForeGroundColor', [0 0 1], ...
    'ShadowColor', [0 0 0], ...
    'Position', [0.01 0.6 0.3 0.18]);

uiData.handles.panels.userActions       = uipanel(...
    'Tag', 'userActionsPanel', ...
    'Parent', uiData.handles.hGui, ...
    'Title', 'User Actions', ...
    'TitlePosition', 'lefttop', ...
    'FontSize', 10, ...
    'ForeGroundColor', [0 0 1], ...
    'ShadowColor', [0 0 0], ...
    'Position', [0.01 0.01 0.3 0.58]);

uiData.handles.panels.controlParameters  = uipanel(...
    'Tag', 'controlParametersPanel', ...
    'Parent', uiData.handles.hGui, ...
    'Title', 'Control Parameters', ...
    'TitlePosition', 'lefttop', ...
    'FontSize', 10, ...
    'ForeGroundColor', [0 0 1], ...
    'ShadowColor', [0 0 0], ...
    'Position', [0.32 0.01 0.33 0.93]);

uiData.handles.panels.statusValues      = uipanel(...
    'Tag', 'statusValuesPanel', ...
    'Parent', uiData.handles.hGui, ...
    'Title', 'Status Values', ...
    'TitlePosition', 'lefttop', ...
    'FontSize', 10, ...
    'ForeGroundColor', [0 0 1], ...
    'ShadowColor', [0 0 0], ...
    'Position', [0.66 0.2 0.33 0.74]);

uiData.handles.panels.outputFiles       = uipanel(...
    'Tag', 'outputFilesPanel', ...
    'Parent', uiData.handles.hGui, ...
    'Title', 'Output Files', ...
    'TitlePosition', 'lefttop', ...
    'FontSize', 10, ...
    'ForeGroundColor', [0 0 1], ...
    'ShadowColor', [0 0 0], ...
    'Position', [0.66 0.01 0.33 0.18]);
end

% --- build uicontrol elements in the settings file panel
function uiData = buildSettingsFilesUiControls(uiData)

% build popup menu containing the name of each loaded settings file
uiData.handles.settingsFilesPopUp = uicontrol(...
    'Tag', 'settingsFilesPopUp', ...
    'Parent', uiData.handles.panels.settingsFiles, ...
    'Units','normalized', ...
    'Position', [0.025 0.375 0.95 0.475], ...
    'HandleVisibility','callback', ...
    'Visible', 'Off', ...
    'Style', 'popupmenu', ...
    'String', {'settings_file1', 'settings_file1'}, ...
    'FontSize', 16, ...
    'FontUnits', 'normalized', ...
    'Callback', @settingsFilesPopUp_callback);

% build button to browse for & select settings files
uiData.handles.settingsFilesButton = uicontrol(...
    'Tag', 'settingsFilesButton', ...
    'Parent', uiData.handles.panels.settingsFiles, ...
    'Units','normalized', ...
    'Position', [0.025 0.025 0.95 0.4], ...
    'HandleVisibility','callback', ...
    'Visible', 'On', ...
    'Style', 'pushbutton', ...
    'String', 'Browse', ...
    'FontSize', 18, ...
    'FontUnits', 'normalized', ...
    'Callback', @settingsFilesBrowse_callback);

end

% --- build uicontrol elements in the control parameters panel
function uiData = buildControlParametersUiControls(uiData)

% there will be 12 "popup" menus and 12 corresponding "edit" boxes
nControlRows = 12;

% space at the top and the bottom of the panel
verticalOffset = (1-(nControlRows/(nControlRows + 1)))/2;

% vertical positions of bottom left corners of each row of elements
bottomLefts = fliplr(linspace(0.015, verticalOffset + ...
    (nControlRows - 1)/(nControlRows+1), nControlRows));

% row height
rowHeight = 1/(nControlRows + 1);

% loop through and build; each "popup" and "edit" item in a given row have
% their 'UserData' property set to "i". This makes having a single callback
% for all of the ui elements (across rows) easier to deal with.
for i = 1:nControlRows
    
    uiData.handles.ctrlParamPopUp(i) = uicontrol(...
        'Tag', ['ctrlParamPopUp_' sprintf('%02d', i)], ...
        'Parent', uiData.handles.panels.controlParameters, ...
        'Units','normalized', ...
        'Position', [0.025 bottomLefts(i) 0.6 rowHeight], ...
        'HandleVisibility','callback', ...
        'Visible', 'Off', ...
        'Style', 'popupmenu', ...
        'String', {'dummy_param1', 'dummy_param2'}, ...
        'FontUnits', 'normalized', ...
        'UserData', i, ...
        'Callback', @ctrlParamPopUp_callback);
    
    uiData.handles.ctrlParamEdit(i) = uicontrol(...
        'Tag', ['ctrlParamEdit_' sprintf('%02d', i)], ...
        'Parent', uiData.handles.panels.controlParameters, ...
        'Units','normalized', ...
        'Position', [0.65 bottomLefts(i) + 0.0175 0.3 rowHeight], ...
        'HandleVisibility','callback', ...
        'Visible', 'Off', ...
        'Style', 'edit', ...
        'String', 'dummy_val', ...
        'FontUnits', 'normalized', ...
        'UserData', i, ...
        'Callback', @ctrlParamEdit_callback);
end

end

% --- build uicontrol elements in the status values panel
function uiData = buildStatusValuesUiControls(uiData)

% there will be 12 "popup" menus and 12 corresponding "edit" boxes
nStatusRows = 12;

% space at the top and the bottom of the panel
verticalOffset = (1-(nStatusRows/(nStatusRows + 1)))/2;

% vertical positions of bottom left corners of each row of elements
bottomLefts = fliplr(linspace(0.015, verticalOffset + ...
    (nStatusRows - 1)/(nStatusRows+1), nStatusRows));

% row height
rowHeight = 1/(nStatusRows + 1);

% loop through and build
for i = 1:nStatusRows
    
    % 
    uiData.handles.statValPopUp(i) = uicontrol(...
        'Tag', ['statValPopUp_' sprintf('%02d', i)], ...
        'Parent', uiData.handles.panels.statusValues, ...
        'Units','normalized', ...
        'Position', [0.0375 bottomLefts(i) 0.6 rowHeight], ...
        'HandleVisibility','callback', ...
        'Visible', 'Off', ...
        'Style', 'popupmenu', ...
        'String', {'dummy_param1', 'dummy_param2'}, ...
        'FontUnits', 'normalized', ...
        'Callback', @statValPopUp_callback);
    
    uiData.handles.statValText(i) = uicontrol(...
        'Tag', ['statValText_' sprintf('%02d', i)], ...
        'Parent', uiData.handles.panels.statusValues, ...
        'Units','normalized', ...
        'Position', [0.65 bottomLefts(i) 0.3 1/13], ...
        'HandleVisibility','callback', ...
        'Visible', 'Off', ...
        'Style', 'text', ...
        'String', 'dummy_val', ...
        'FontUnits', 'normalized');
end

end

% --- build uicontrol elements in the standard actions panel
function uiData = buildStandardActionsUiControls(uiData)

% build button to clear and close psychtoolbox screen
uiData.handles.clearButton = uicontrol(...
    'Tag', 'clearButton', ...
    'Parent', uiData.handles.panels.standardActions, ...
    'Units','normalized', ...
    'Position', [0.025 0.0375 0.4625 0.45], ...
    'HandleVisibility','callback', ...
    'Visible', 'Off', ...
    'Style', 'pushbutton', ...
    'String', 'Clear', ...
    'FontSize', 18, ...
    'FontUnits', 'normalized', ...
    'Callback', @clearButton_callback);

% build button to initialize selected protocol (settings file).
uiData.handles.initializeButton = uicontrol(...
    'Tag', 'initializeButton', ...
    'Parent', uiData.handles.panels.standardActions, ...
    'Units','normalized', ...
    'Position', [0.025 0.525 0.4625 0.45], ...
    'HandleVisibility','callback', ...
    'Visible', 'Off', ...
    'Style', 'pushbutton', ...
    'String', 'Initialize', ...
    'FontSize', 18, ...
    'FontUnits', 'normalized', ...
    'Callback', @initializeButton_callback);

% build button to run protocol (settings file)
uiData.handles.runButton = uicontrol(...
    'Tag', 'runButton', ...
    'Parent', uiData.handles.panels.standardActions, ...
    'Units','normalized', ...
    'Position', [0.5125 0.0375 0.4625 0.95], ...
    'HandleVisibility','callback', ...
    'Visible', 'Off', ...
    'Style', 'togglebutton', ...
    'String', 'Run', ...
    'FontSize', 18, ...
    'FontUnits', 'normalized', ...
    'Callback', @runButton_callback);

end

% --- build uicontrol elements in the user actions panel
function uiData = buildUserActionsUiControls(uiData)

% there will be 12 "popup" menus and 12 corresponding "edit" boxes
nUserActionRows = 10;

% space at the top and the bottom of the panel
verticalOffset = (1-(nUserActionRows/(nUserActionRows + 1)))/2;

% vertical positions of bottom left corners of each row of elements
bottomLefts = fliplr(linspace(0.015, verticalOffset + ...
    (nUserActionRows - 1)/(nUserActionRows+1), nUserActionRows));

% button height
buttonHeight = 1/(nUserActionRows + 1);

% loop through and build
for i = 1:nUserActionRows
    
    uiData.handles.userActionButton(i) = uicontrol(...
        'Tag', ['userActionButton_' sprintf('%02d', i)], ...
        'Parent', uiData.handles.panels.userActions, ...
        'Units','normalized', ...
        'Position', [0.025 bottomLefts(i) 0.95 buttonHeight], ...
        'HandleVisibility','callback', ...
        'Visible', 'Off', ...
        'Style', 'pushbutton', ...
        'String', ['dummy_action' sprintf('%02d', i)], ...
        'FontUnits', 'normalized', ...
        'UserData', i, ...
        'Callback', @userActionButton_callback);
end

end

% --- build uicontrol elements in the output files panel
function uiData = buildOutputFilesUiControls(uiData)

% build text uicontrol to indicate where output files are being saved
uiData.handles.outputPathString = uicontrol(...
    'Tag', 'outputPathString', ...
    'Parent', uiData.handles.panels.outputFiles, ...
    'Units','normalized', ...
    'Position', [0.025 0.5375 0.95 0.45], ...
    'HandleVisibility','callback', ...
    'Visible', 'Off', ...
    'Style', 'text', ...
    'String', 'defined in settings file or by "output path" button', ...
    'FontUnits', 'normalized', ...
    'FontSize', 10);

% build button to browse for & select an output path
uiData.handles.outputPathButton = uicontrol(...
    'Tag', 'outputPathButton', ...
    'Parent', uiData.handles.panels.outputFiles, ...
    'Units','normalized', ...
    'Position', [0.025 0.0375 0.4625 0.45], ...
    'HandleVisibility','callback', ...
    'Visible', 'Off', ...
    'Style', 'pushbutton', ...
    'String', 'Output Path', ...
    'FontSize', 14, ...
    'FontUnits', 'normalized', ...
    'Callback', @outputPathButton_callback);

% build button to concatenate individual-trial ".mat" files into a single
% ".mat" file.
uiData.handles.concatenateOutputButton = uicontrol(...
    'Tag', 'concatenateOutputButton', ...
    'Parent', uiData.handles.panels.outputFiles, ...
    'Units','normalized', ...
    'Position', [0.5125 0.0375 0.4625 0.45], ...
    'HandleVisibility','callback', ...
    'Visible', 'Off', ...
    'Style', 'pushbutton', ...
    'String', 'Concatenate Output', ...
    'FontSize', 10, ...
    'FontUnits', 'normalized', ...
    'Callback', @concatenateOutputButton_callback);

end