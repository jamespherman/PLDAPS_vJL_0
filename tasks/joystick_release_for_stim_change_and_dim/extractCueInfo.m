function info = extractCueInfo(trialData)
% info = extractCueInfo(trialData)
%
% Extracts cue information and change event type from a single trial's data.
% This function is designed to work with the .mat output files from the
% 'joystick_release_for_stim_change_and_dim' task in PLDAPS.
%
% INPUT:
%   trialData - A structure containing the variables saved for a single trial.
%               This is typically obtained by loading a 'trialXXXX.mat' file.
%               The structure must contain the fields: 'trVars' and 'init'.
%
% OUTPUT:
%   info - A structure containing the extracted information:
%       .cueLocIndex      - Integer (1-4). The index of the cued location.
%       .stimChgIndex     - Integer (0-4). The index of the changing stimulus.
%                           0 indicates no change (catch trial).
%       .isCuedChange     - Boolean. True if the change occurred at the cued location.
%       .isUncuedChange   - Boolean. True if the change occurred at an uncued location.
%       .isNoChange       - Boolean. True if no change occurred.
%       .cueCoordsDeg     - [x, y] coordinates of the cue in degrees of visual angle.
%                           (Cartesian coordinates).
%       .cueCoordsPix     - [x, y] coordinates of the cue center in pixels (relative to screen center, Y inverted).
%       .stimCoordsDeg    - [n x 2] matrix of all stimulus locations in degrees.
%
% EXAMPLE USE:
%   % Load a trial file
%   data = load('trial0005.mat');
%
%   % Extract info
%   trialInfo = extractCueInfo(data);
%
%   if trialInfo.isCuedChange
%       disp(['Trial was a CUED change at location ' num2str(trialInfo.cueLocIndex)]);
%       disp(['Cue coordinates (deg): ' num2str(trialInfo.cueCoordsDeg)]);
%   elseif trialInfo.isUncuedChange
%       disp(['Trial was an UNCUED change at location ' num2str(trialInfo.stimChgIndex)]);
%   else
%       disp('Trial was a NO CHANGE trial.');
%   end

    if ~isfield(trialData, 'trVars') || ~isfield(trialData, 'init')
        error('Input structure must contain ''trVars'' and ''init'' fields.');
    end

    init = trialData.init;
    trVars = trialData.trVars;

    % Get the row index for the current trial in the trialsArray
    % Note: trVars.currentTrialsArrayRow is saved in trVars.
    if ~isfield(trVars, 'currentTrialsArrayRow')
        error('trVars does not contain ''currentTrialsArrayRow''.');
    end
    rowIdx = trVars.currentTrialsArrayRow;

    % Find column indices in trialsArray
    colNames = init.trialArrayColumnNames;
    cueLocCol = find(strcmp(colNames, 'cue loc'));
    stimChgCol = find(strcmp(colNames, 'stim chg'));

    if isempty(cueLocCol)
        error('Could not find ''cue loc'' column in trialArrayColumnNames.');
    end
    if isempty(stimChgCol)
        error('Could not find ''stim chg'' column in trialArrayColumnNames.');
    end

    % Extract indices from trialsArray
    cueLocIndex = init.trialsArray(rowIdx, cueLocCol);
    stimChgIndex = init.trialsArray(rowIdx, stimChgCol);

    % Determine trial type
    isNoChange = (stimChgIndex == 0);
    isCuedChange = (~isNoChange) && (cueLocIndex == stimChgIndex);
    isUncuedChange = (~isNoChange) && (cueLocIndex ~= stimChgIndex);

    % Extract Coordinates
    % trVars.stimLocCart contains Cartesian coordinates in degrees [x, y] for each location
    % trVars.stimLocCartPix contains pixel coordinates

    if isfield(trVars, 'stimLocCart')
        stimCoordsDeg = trVars.stimLocCart;
        if cueLocIndex > 0 && cueLocIndex <= size(stimCoordsDeg, 1)
            cueCoordsDeg = stimCoordsDeg(cueLocIndex, :);
        else
            cueCoordsDeg = [NaN, NaN];
            warning('Cue location index is out of bounds for stimLocCart.');
        end
    else
        stimCoordsDeg = [];
        cueCoordsDeg = [NaN, NaN];
        warning('trVars does not contain ''stimLocCart''.');
    end

    if isfield(trVars, 'stimLocCartPix')
        if cueLocIndex > 0 && cueLocIndex <= size(trVars.stimLocCartPix, 1)
            cueCoordsPix = trVars.stimLocCartPix(cueLocIndex, :);
        else
            cueCoordsPix = [NaN, NaN];
        end
    else
        cueCoordsPix = [NaN, NaN];
    end

    % Populate output structure
    info.cueLocIndex = cueLocIndex;
    info.stimChgIndex = stimChgIndex;
    info.isCuedChange = isCuedChange;
    info.isUncuedChange = isUncuedChange;
    info.isNoChange = isNoChange;
    info.cueCoordsDeg = cueCoordsDeg;
    info.cueCoordsPix = cueCoordsPix;
    info.stimCoordsDeg = stimCoordsDeg;

end
