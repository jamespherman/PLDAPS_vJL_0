function p = initTrialStructure(p)

%
% p = initTrialStructure(p)
% 
% Define the trial types for a single "block" of trials - this includes
% trials with the cue at one angle of elevation and at the diametrically
% opposed elevation (180 degrees away).
%

% there are 7 features:
% (1) speed
% (2) orientation
% (3) spatial frequency
% (4) saturation
% (5) hue
% (6) luminance
% (7) contrast

% column descriptions (19 columns)
p.init.trialArrayColumnNames = {...
    'cue loc', ...              % 1 which stimulus location is the cued location on this trial?
    'n stim', ...               % 2 how many stimulus patches to show on this trial?
    'stim1 on', ...             % 3 is the 1st stimulus presented on this trial?
    'stim2 on', ...             % 4 is the 2nd stimulus presented on this trial?
    'stim3 on', ...             % 5 is the 3rd stimulus presented on this trial?
    'stim4 on', ...             % 6 is the 4th stimulus presented on this trial?
    'stim chg', ...             % 7 which stimulus changes? (1 - n)
    'speed', ...                % 8 does speed change?
    'orientation', ...          % 9 does ... change?
    'spatial frequency', ...    % 10 ...
    'saturation', ...           % 11
    'hue', ...                  % 12
    'luminance', ...            % 13
    'contrast', ...             % 14
    'primary', ...              % 15 for making sure the stimuli have different start values
    'no of trials', ...         % 16
    'trialCode', ...            % 17
    'trial seed', ...           % 18 seed value to make trial params reproducible
    'stim seed'};               % 19 seed value to make stimulus properties reproducible

% how many columns will the trials array have?
nCols   = length(p.init.trialArrayColumnNames);

% which column tells us how many repetitions of a given trial type will be
% included?
repCol = find(strcmp(p.init.trialArrayColumnNames, 'no of trials'));

% table definition
switch p.init.exptType

    case 'joystick_release_for_stim_dim_and_feature_change_9010'
        table = tableDef_stimDimPlusChange_9010;

    case 'joystick_release_for_stim_dim_and_feature_change_7030'
        table = tableDef_stimDimPlusChange_7030;

    case 'joystick_release_for_stim_dim_and_feature_change_6040'
        table = tableDef_stimDimPlusChange_6040;

    case 'joystick_release_for_fix_and_stim_dim_9010'
        table = tableDef_fixAndStimDim_9010;

    case 'joystick_release_for_fix_and_stim_dim_1000'
        table = tableDef_fixAndStimDim_1000;

    case 'joystick_release_for_fix_and_stim_dim_7030'
        table = tableDef_fixAndStimDim_7030;

    case 'joystick_release_for_fix_and_stim_dim_6040'
        table = tableDef_fixAndStimDim_6040;

    case 'saturationIncreasePsychometric'   % YGC 04/03/19
        table = tableDefSatIncPsychometric;
        
    case 'saturationIncrease'
        table = tableDefSatInc;
        
    case 'nfl'
        % in this case, we need to define two tables, one for the 1st block
        % and one for subsequent blocks.
        table1 = tableDefSatInc_noSingle;
        table2 = tableDef_66SatInc_33CtstInc_noSingle;
        
    case 'nfl_50'
        % in this case, we need to define two tables, one for the 1st block
        % and one for subsequent blocks.
        table1 = tableDefSatInc_noSingle;
        table2 = tableDef_50SatInc_50CtstInc_noSingle;
        
    case 'nfl_shortBlocks'
        
        % in this case, we need to define two tables, one for the odd
        % blocks and one for the even blocks (alternating).
        table1 = tableDef_shortSatIncBlock;
        table2 = tableDef_shortCtrstIncBlock;
        
    case 'saturation increase no single'
        table = tableDefSatInc_noSingle;
        
    case 'saturation increase no single cue chg only'
        table = tableDefSatInc_noSingle_cueChgOnly;
        
    otherwise
        table = tableDefault;
end
    

% depending on experiment type, do a couple things differently
if strncmp(p.init.exptType, 'nfl', 3)
    
    % store the tables used to generate "trialsArray"
    p.init.trialsTable1 = table1;
    p.init.trialsTable2 = table2;
    
    % in this experiment we have two different trial tables for different
    % blocks - in this function ("initTrialStructure") only table1 is used.
    % For backwards-compatibility, store "table1" as "table".
    table = table1;
else
    % store the tables used to generate "trialsArray"
    p.init.trialsTable = table;
end

% make an empty "trialsArray"
trialsArray = zeros(sum(table(:, repCol)), nCols);

% initate index tracking what row of the trials array has been generated as
% we loop through the trials table.
currentRow = 1;

% loop over each row of the table.
for i = 1:size(table, 1)
    
    % how many repetitions of the current row do we need?
    nReps = table(i, repCol);
    
    % place the repeated row into the "trials" array.
    trialsArray(currentRow:(currentRow + nReps - 1), :) = ...
        repmat([table(i, :), 0, 0], nReps, 1);

    % iterate the "currentRow" variable.
    currentRow = currentRow + nReps;
end

% add trial seed and stim seed values
trialsArray(:, strcmp(p.init.trialArrayColumnNames, 'trial seed')) = ...
    randi(2^15-1, sum(table(:, repCol)), 1);
trialsArray(:, strcmp(p.init.trialArrayColumnNames, 'stim seed')) = ...
    randi(2^15-1, sum(table(:, repCol)), 1);

% if this is one of the versions of NFL where we want repeats of trial
% conditions (reverse-correlation purposes), duplicate the trials table;
dupExpts = {'nfl', 'saturation increase no single', 'nfl_50', 'nfl_shortBlocks'};
if any(strcmp(dupExpts, p.init.exptType))
    trialsArray = repmat(trialsArray, 2, 1);
end

% store trialsarray
p.init.trialsArray = trialsArray;

% store length of block
p.init.blockLength = size(p.init.trialsArray, 1);

% keyboard
end

% Peripheral stimulus dimming in one of multiple possible stimuli:
function table = tableDef_fixAndStimDim_test
table =           [1   4   1   1   1   1   1   0   0   0   0   0   1   0   1   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   1   0   0   0   0   0   0   0   1   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   2   0   0   0   0   0   1   0   1   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   3   0   0   0   0   0   1   0   1   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   4   0   0   0   0   0   1   0   1   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   1   0   0   0   0   0   1   0   2   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   2   0   0   0   0   0   1   0   2   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   3   0   0   0   0   0   1   0   2   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   4   0   0   0   0   0   1   0   2   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   1   0   0   0   0   0   1   0   3   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   2   0   0   0   0   0   1   0   3   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   3   0   0   0   0   0   1   0   3   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   4   0   0   0   0   0   1   0   3   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   1   0   0   0   0   0   1   0   4   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   2   0   0   0   0   0   1   0   4   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   3   0   0   0   0   0   1   0   4   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   4   0   0   0   0   0   1   0   4   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Peripheral stimulus dimming + change with mostly change trials.
function table = tableDef_stimDimPlusChange_9010
table =           [1   1   1   0   0   0   1   0   0   0   0   1   1   0   1   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   0   0   0   1   1   0   2   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   0   0   0   1   1   0   3   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   0   0   0   1   1   0   4   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Peripheral stimulus dimming + change with mostly change trials.
function table = tableDef_stimDimPlusChange_7030
table =           [1   1   1   0   0   0   1   0   0   0   0   1   1   0   1   7   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   3   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   0   0   0   1   1   0   2   7   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   3   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   0   0   0   1   1   0   3   7   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   3   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   0   0   0   1   1   0   4   7   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   3   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Peripheral stimulus dimming + change with mostly change trials.
function table = tableDef_stimDimPlusChange_6040
table =           [1   1   1   0   0   0   1   0   1   0   0   1   1   0   1   6   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   1   0   0   0   0   0   1   4   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   1   0   0   1   1   0   2   6   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   1   0   0   0   0   0   2   4   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   1   0   0   1   1   0   3   6   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   1   0   0   0   0   0   3   4   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   1   0   0   1   1   0   4   6   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   1   0   0   0   0   0   4   4   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Fixation + peripheral stimulus dimming
function table = tableDef_fixAndStimDim_6040
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   6   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   1   0   0   0   0   0   1   4   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   6   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   1   0   0   0   0   0   2   4   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   6   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   1   0   0   0   0   0   3   4   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   6   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   1   0   0   0   0   0   4   4   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Fixation + peripheral stimulus dimming
function table = tableDef_fixAndStimDim_7030
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   7   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   1   0   0   0   0   0   1   3   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   7   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   1   0   0   0   0   0   2   3   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   7   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   1   0   0   0   0   0   3   3   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   7   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   1   0   0   0   0   0   4   3   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Fixation + peripheral stimulus dimming with mostly change trials.
function table = tableDef_fixAndStimDim_9010
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   1   0   0   0   0   0   1   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   1   0   0   0   0   0   2   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   1   0   0   0   0   0   3   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   1   0   0   0   0   0   4   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Fixation + peripheral stimulus dimming with mostly change trials.
function table = tableDef_fixAndStimDim_1000
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% p.init.trialArrayColumnNames = {...
%     'cue loc', ...              % 1 which stimulus location is the cued location on this trial?
%     'n stim', ...               % 2 how many stimulus patches to show on this trial?
%     'stim1 on', ...             % 3 is the 1st stimulus presented on this trial?
%     'stim2 on', ...             % 4 is the 2nd stimulus presented on this trial?
%     'stim3 on', ...             % 5 is the 3rd stimulus presented on this trial?
%     'stim4 on', ...             % 6 is the 4th stimulus presented on this trial?
%     'stim chg', ...             % 7 which stimulus changes? (1 - n)
%     'speed', ...                % 8 does speed change?
%     'orientation', ...          % 9 does ... change?
%     'spatial frequency', ...    % 10 ...
%     'saturation', ...           % 11
%     'hue', ...                  % 12
%     'luminance', ...            % 13
%     'contrast', ...             % 14
%     'primary', ...              % 15 for making sure the stimuli have different start values
%     'no of trials', ...         % 16
%     'trialCode', ...            % 17
%     'trial seed', ...           % 18 seed value to make trial params reproducible
%     'stim seed'};               % 19 seed value to make stimulus properties reproducible

% saturation increases only & also for psychometric curve measurement  
% YGC 04/03/19
function table = tableDefSatIncPsychometric
table =           [     1   1   1   0   1   0   0   0   1   0   0   0   1   4   23001; % cue side 1, single stimulus, saturation increase on side 1, side 1 starts purple
                        1   1   1   0   1   0   0   0   1   0   0   0   2   4   23002; % cue side 1, single stimulus, saturation increase on side 1, side 2 starts purple
                        1   1   1   0   0   0   0   0   0   0   0   0   1   1   23003; % cue side 1, single stimulus, no change, side 1 starts purple
                        1   1   1   0   0   0   0   0   0   0   0   0   2   1   23004; % cue side 1, single stimulus, no change, side 2 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   1   12  23005; % cue side 1, two stimuli, saturation increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   2   12  23006; % cue side 1, two stimuli, saturation increase on side 1, side 2 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   1   3   23007; % cue side 1, two stimuli, saturation increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   2   3   23008; % cue side 1, two stimuli, saturation increase on side 2, side 2 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   1   2   23009; % cue side 1, two stimuli, no change, side 1 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   2   2   23010; % cue side 1, two stimuli, no change, side 2 starts purple
                        2   1   1   0   2   0   0   0   1   0   0   0   1   4   23011; % cue side 2, single stimulus, saturation increase on side 2, side 1 starts purple
                        2   1   1   0   2   0   0   0   1   0   0   0   2   4   23012; % cue side 2, single stimulus, saturation increase on side 2, side 2 starts purple
                        2   1   1   0   0   0   0   0   0   0   0   0   1   1   23013; % cue side 2, single stimulus, no change, side 1 starts purple
                        2   1   1   0   0   0   0   0   0   0   0   0   2   1   23014; % cue side 2, single stimulus, no change, side 2 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   1   12  23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   12  23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   1   3   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   3   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   1   2   23019; % cue side 2, two stimuli, no change, side 1 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   2   2   23020; % cue side 2, two stimuli, no change, side 2 starts purple
                 ];
end

% saturation increases only, no single patch trials
function table = tableDefSatInc_noSingle
table =           [
                        1   2   1   1   1   0   0   0   1   0   0   0   1   9   23005; % cue side 1, two stimuli, saturation increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   2   9   23006; % cue side 1, two stimuli, saturation increase on side 1, side 2 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   1   3   23007; % cue side 1, two stimuli, saturation increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   2   3   23008; % cue side 1, two stimuli, saturation increase on side 2, side 2 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   1   2   23009; % cue side 1, two stimuli, no change, side 1 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   2   2   23010; % cue side 1, two stimuli, no change, side 2 starts purple
                        
                        2   2   1   1   2   0   0   0   1   0   0   0   1   9   23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   9   23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   1   3   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   3   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   1   2   23019; % cue side 2, two stimuli, no change, side 1 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   2   2   23020; % cue side 2, two stimuli, no change, side 2 starts purple
                 ];
end

% saturation increases only, no single patch trials
function table = tableDefSatInc_noSingle_cueChgOnly
table =           [
                        1   2   1   1   1   0   0   0   1   0   0   0   1   10   23005; % cue side 1, two stimuli, saturation increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   2   10   23006; % cue side 1, two stimuli, saturation increase on side 1, side 2 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   1   1   23007; % cue side 1, two stimuli, saturation increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   2   1   23008; % cue side 1, two stimuli, saturation increase on side 2, side 2 starts purple
                        
                        2   2   1   1   2   0   0   0   1   0   0   0   1   10   23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   10   23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   1   1   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   1   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                 ];
end

% saturation increases only
function table = tableDefSatInc
table =           [     1   1   1   0   1   0   0   0   1   0   0   0   1   3   23001; % cue side 1, single stimulus, saturation increase on side 1, side 1 starts purple
                        1   1   1   0   1   0   0   0   1   0   0   0   2   3   23002; % cue side 1, single stimulus, saturation increase on side 1, side 2 starts purple
                        1   1   1   0   0   0   0   0   0   0   0   0   1   1   23003; % cue side 1, single stimulus, no change, side 1 starts purple
                        1   1   1   0   0   0   0   0   0   0   0   0   2   1   23004; % cue side 1, single stimulus, no change, side 2 starts purple
                        
                        1   2   1   1   1   0   0   0   1   0   0   0   1   9   23005; % cue side 1, two stimuli, saturation increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   2   9   23006; % cue side 1, two stimuli, saturation increase on side 1, side 2 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   1   3   23007; % cue side 1, two stimuli, saturation increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   2   3   23008; % cue side 1, two stimuli, saturation increase on side 2, side 2 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   1   2   23009; % cue side 1, two stimuli, no change, side 1 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   2   2   23010; % cue side 1, two stimuli, no change, side 2 starts purple
                        
                        2   1   1   0   2   0   0   0   1   0   0   0   1   3   23011; % cue side 2, single stimulus, saturation increase on side 2, side 1 starts purple
                        2   1   1   0   2   0   0   0   1   0   0   0   2   3   23012; % cue side 2, single stimulus, saturation increase on side 2, side 2 starts purple
                        2   1   1   0   0   0   0   0   0   0   0   0   1   1   23013; % cue side 2, single stimulus, no change, side 1 starts purple
                        2   1   1   0   0   0   0   0   0   0   0   0   2   1   23014; % cue side 2, single stimulus, no change, side 2 starts purple
                        
                        2   2   1   1   2   0   0   0   1   0   0   0   1   9   23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   9   23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   1   3   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   3   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   1   2   23019; % cue side 2, two stimuli, no change, side 1 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   2   2   23020; % cue side 2, two stimuli, no change, side 2 starts purple
                 ];
end

% 66% saturation increases, 33% contrast increases - includes only double patch trials
function table = tableDef_66SatInc_33CtstInc_noSingle
table =           [                        
                        1   2   1   1   1   0   0   0   1   0   0   0   1   6   23005; % cue side 1, two stimuli, saturation increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   2   6   23006; % cue side 1, two stimuli, saturation increase on side 1, side 2 starts purple
                        1   2   1   1   1   0   0   0   0   0   0   1   1   3   23005; % cue side 1, two stimuli, CONTRAST increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   0   0   0   1   2   3   23006; % cue side 1, two stimuli, CONTRAST increase on side 1, side 2 starts purple
                        
                        1   2   1   1   2   0   0   0   1   0   0   0   1   2   23007; % cue side 1, two stimuli, saturation increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   2   2   23008; % cue side 1, two stimuli, saturation increase on side 2, side 2 starts purple
                        1   2   1   1   2   0   0   0   0   0   0   1   1   1   23007; % cue side 1, two stimuli, CONTRAST increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   0   0   0   1   2   1   23008; % cue side 1, two stimuli, CONTRAST increase on side 2, side 2 starts purple
                        
                        1   2   1   1   0   0   0   0   0   0   0   0   1   2   23009; % cue side 1, two stimuli, no change, side 1 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   2   2   23010; % cue side 1, two stimuli, no change, side 2 starts purple
                        
                        2   2   1   1   2   0   0   0   1   0   0   0   1   6   23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   6   23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        2   2   1   1   2   0   0   0   0   0   0   1   1   3   23015; % cue side 2, two stimuli, CONTRAST increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   0   0   0   1   2   3   23016; % cue side 2, two stimuli, CONTRAST increase on side 2, side 2 starts purple
                        
                        2   2   1   1   1   0   0   0   1   0   0   0   1   2   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   2   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                        2   2   1   1   1   0   0   0   0   0   0   1   1   1   23017; % cue side 2, two stimuli, CONTRAST increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   0   0   0   1   2   1   23018; % cue side 2, two stimuli, CONTRAST increase on side 1, side 2 starts purple
                        
                        2   2   1   1   0   0   0   0   0   0   0   0   1   2   23019; % cue side 2, two stimuli, no change, side 1 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   2   2   23020; % cue side 2, two stimuli, no change, side 2 starts purple
                 ];
end

% 50% saturation increases, 50% contrast increases - includes only double patch trials
function table = tableDef_50SatInc_50CtstInc_noSingle
table =           [                        
                        1   2   1   1   1   0   0   0   1   0   0   0   1   5   23005; % cue side 1, two stimuli, saturation increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   2   5   23006; % cue side 1, two stimuli, saturation increase on side 1, side 2 starts purple
                        1   2   1   1   1   0   0   0   0   0   0   1   1   5   23005; % cue side 1, two stimuli, CONTRAST increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   0   0   0   1   2   5   23006; % cue side 1, two stimuli, CONTRAST increase on side 1, side 2 starts purple
                        
                        1   2   1   1   2   0   0   0   1   0   0   0   1   2   23007; % cue side 1, two stimuli, saturation increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   2   2   23008; % cue side 1, two stimuli, saturation increase on side 2, side 2 starts purple
                        1   2   1   1   2   0   0   0   0   0   0   1   1   2   23007; % cue side 1, two stimuli, CONTRAST increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   0   0   0   1   2   2   23008; % cue side 1, two stimuli, CONTRAST increase on side 2, side 2 starts purple
                        
                        1   2   1   1   0   0   0   0   0   0   0   0   1   2   23009; % cue side 1, two stimuli, no change, side 1 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   2   2   23010; % cue side 1, two stimuli, no change, side 2 starts purple
                        
                        2   2   1   1   2   0   0   0   1   0   0   0   1   5   23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   5   23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        2   2   1   1   2   0   0   0   0   0   0   1   1   5   23015; % cue side 2, two stimuli, CONTRAST increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   0   0   0   1   2   5   23016; % cue side 2, two stimuli, CONTRAST increase on side 2, side 2 starts purple
                        
                        2   2   1   1   1   0   0   0   1   0   0   0   1   2   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   2   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                        2   2   1   1   1   0   0   0   0   0   0   1   1   2   23017; % cue side 2, two stimuli, CONTRAST increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   0   0   0   1   2   2   23018; % cue side 2, two stimuli, CONTRAST increase on side 1, side 2 starts purple
                        
                        2   2   1   1   0   0   0   0   0   0   0   0   1   2   23019; % cue side 2, two stimuli, no change, side 1 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   2   2   23020; % cue side 2, two stimuli, no change, side 2 starts purple
                 ];
end

% reduced-length block of saturation increases - includes only double patch trials
function table = tableDef_shortSatIncBlock
table =           [                        
                        1   2   1   1   1   0   0   0   1   0   0   0   1   5   23005; % cue side 1, two stimuli, saturation increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   2   5   23006; % cue side 1, two stimuli, saturation increase on side 1, side 2 starts purple
                        
                        1   2   1   1   2   0   0   0   1   0   0   0   1   2   23007; % cue side 1, two stimuli, saturation increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   2   2   23008; % cue side 1, two stimuli, saturation increase on side 2, side 2 starts purple                
                        
                        2   2   1   1   2   0   0   0   1   0   0   0   1   5   23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   5   23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        
                        2   2   1   1   1   0   0   0   1   0   0   0   1   2   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   2   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                 ];
end

% reduced-length block of saturation increases - includes only double patch trials
function table = tableDef_shortCtrstIncBlock
table =           [                        
                        1   2   1   1   1   0   0   0   0   0   0   1   1   5   23005; % cue side 1, two stimuli, CONTRAST increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   0   0   0   1   2   5   23006; % cue side 1, two stimuli, CONTRAST increase on side 1, side 2 starts purple
                        
                        1   2   1   1   2   0   0   0   0   0   0   1   1   2   23007; % cue side 1, two stimuli, CONTRAST increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   0   0   0   1   2   2   23008; % cue side 1, two stimuli, CONTRAST increase on side 2, side 2 starts purple

                        2   2   1   1   2   0   0   0   0   0   0   1   1   5   23015; % cue side 2, two stimuli, CONTRAST increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   0   0   0   1   2   5   23016; % cue side 2, two stimuli, CONTRAST increase on side 2, side 2 starts purple

                        2   2   1   1   1   0   0   0   0   0   0   1   1   2   23017; % cue side 2, two stimuli, CONTRAST increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   0   0   0   1   2   2   23018; % cue side 2, two stimuli, CONTRAST increase on side 1, side 2 starts purple
                 ];
end

% 66% saturation increases, 33% contrast increases - includes single patch and double patch trials
function table = tableDef_66SatInc_33CtstInc
table =           [     1   1   1   0   1   0   0   0   1   0   0   0   1   2   23001; % cue side 1, single stimulus, saturation increase on side 1, side 1 starts purple
                        1   1   1   0   1   0   0   0   1   0   0   0   2   2   23002; % cue side 1, single stimulus, saturation increase on side 1, side 2 starts purple
                        1   1   1   0   1   0   0   0   0   0   0   1   1   1   23021; % cue side 1, single stimulus, CONTRAST increase on side 1, side 1 starts purple
                        1   1   1   0   1   0   0   0   0   0   0   1   2   1   23022; % cue side 1, single stimulus, CONTRAST increase on side 1, side 2 starts purple
                        
                        1   1   1   0   0   0   0   0   0   0   0   0   1   1   23003; % cue side 1, single stimulus, no change, side 1 starts purple
                        1   1   1   0   0   0   0   0   0   0   0   0   2   1   23004; % cue side 1, single stimulus, no change, side 2 starts purple
                        
                        1   2   1   1   1   0   0   0   1   0   0   0   1   6   23005; % cue side 1, two stimuli, saturation increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   1   0   0   0   2   6   23006; % cue side 1, two stimuli, saturation increase on side 1, side 2 starts purple
                        1   2   1   1   1   0   0   0   0   0   0   1   1   3   23005; % cue side 1, two stimuli, CONTRAST increase on side 1, side 1 starts purple
                        1   2   1   1   1   0   0   0   0   0   0   1   2   3   23006; % cue side 1, two stimuli, CONTRAST increase on side 1, side 2 starts purple
                        
                        1   2   1   1   2   0   0   0   1   0   0   0   1   2   23007; % cue side 1, two stimuli, saturation increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   1   0   0   0   2   2   23008; % cue side 1, two stimuli, saturation increase on side 2, side 2 starts purple
                        1   2   1   1   2   0   0   0   0   0   0   1   1   1   23007; % cue side 1, two stimuli, CONTRAST increase on side 2, side 1 starts purple
                        1   2   1   1   2   0   0   0   0   0   0   1   2   1   23008; % cue side 1, two stimuli, CONTRAST increase on side 2, side 2 starts purple
                        
                        1   2   1   1   0   0   0   0   0   0   0   0   1   2   23009; % cue side 1, two stimuli, no change, side 1 starts purple
                        1   2   1   1   0   0   0   0   0   0   0   0   2   2   23010; % cue side 1, two stimuli, no change, side 2 starts purple
                        
                        2   1   1   0   2   0   0   0   1   0   0   0   1   2   23011; % cue side 2, single stimulus, saturation increase on side 2, side 1 starts purple
                        2   1   1   0   2   0   0   0   1   0   0   0   2   2   23012; % cue side 2, single stimulus, saturation increase on side 2, side 2 starts purple
                        2   1   1   0   2   0   0   0   0   0   0   1   1   1   23023; % cue side 2, single stimulus, CONTRAST increase on side 2, side 1 starts purple
                        2   1   1   0   2   0   0   0   0   0   0   1   2   1   23024; % cue side 2, single stimulus, CONTRAST increase on side 2, side 2 starts purple
                        
                        2   1   1   0   0   0   0   0   0   0   0   0   1   1   23013; % cue side 2, single stimulus, no change, side 1 starts purple
                        2   1   1   0   0   0   0   0   0   0   0   0   2   1   23014; % cue side 2, single stimulus, no change, side 2 starts purple
                        
                        2   2   1   1   2   0   0   0   1   0   0   0   1   6   23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   6   23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        2   2   1   1   2   0   0   0   0   0   0   1   1   3   23015; % cue side 2, two stimuli, CONTRAST increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   0   0   0   1   2   3   23016; % cue side 2, two stimuli, CONTRAST increase on side 2, side 2 starts purple
                        
                        2   2   1   1   1   0   0   0   1   0   0   0   1   2   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   2   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                        2   2   1   1   1   0   0   0   0   0   0   1   1   1   23017; % cue side 2, two stimuli, CONTRAST increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   0   0   0   1   2   1   23018; % cue side 2, two stimuli, CONTRAST increase on side 1, side 2 starts purple
                        
                        2   2   1   1   0   0   0   0   0   0   0   0   1   2   23019; % cue side 2, two stimuli, no change, side 1 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   2   2   23020; % cue side 2, two stimuli, no change, side 2 starts purple
                 ];
end

% saturation increases only - cueSide 2 only for debugging
function table = tableDefSatIncCueSide2
table =           [     2   1   1   0   2   0   0   0   1   0   0   0   1   4   23011; % cue side 2, single stimulus, saturation increase on side 2, side 1 starts purple
                        2   1   1   0   2   0   0   0   1   0   0   0   2   4   23012; % cue side 2, single stimulus, saturation increase on side 2, side 2 starts purple
                        2   1   1   0   0   0   0   0   0   0   0   0   1   1   23013; % cue side 2, single stimulus, no change, side 1 starts purple
                        2   1   1   0   0   0   0   0   0   0   0   0   2   1   23014; % cue side 2, single stimulus, no change, side 2 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   1   9   23015; % cue side 2, two stimuli, saturation increase on side 2, side 1 starts purple
                        2   2   1   1   2   0   0   0   1   0   0   0   2   9   23016; % cue side 2, two stimuli, saturation increase on side 2, side 2 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   1   3   23017; % cue side 2, two stimuli, saturation increase on side 1, side 1 starts purple
                        2   2   1   1   1   0   0   0   1   0   0   0   2   3   23018; % cue side 2, two stimuli, saturation increase on side 1, side 2 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   1   2   23019; % cue side 2, two stimuli, no change, side 1 starts purple
                        2   2   1   1   0   0   0   0   0   0   0   0   2   2   23020; % cue side 2, two stimuli, no change, side 2 starts purple
                 ];
end


% an equal number of trials with cued changes of all features
function table = tableDefault
table =           [     1   2   1   1   0   0   0   0   0   0   1   4   23001; % cue in, speed increase in RF
                        1   2   1   0   1   0   0   0   0   0   1   4   23001; % cue in, orientation incrase in RF
                        1   2   1   0   0   1   0   0   0   0   1   4   23001; % cue in, spatial frequency increase in RF
                        1   2   1   0   0   0   1   0   0   0   1   4   23001; % cue in, saturation increase in RF
                        1   2   1   0   0   0   0   1   0   0   1   4   23001; % cue in, hue increase in RF
                        1   2   1   0   0   0   0   0   1   0   1   4   23001; % cue in, luminance increase in RF
                        1   2   1   0   0   0   0   0   0   1   1   4   23001; % cue in, contrast increase in RF
                 ];
end

% just speed changes
function table = tableDefSpeedChange
table =           [     1   2   1   1   0   0   0   0   0   0   1   100   23001; % cue in, speed increase in RF
                 ];
end

function table = colorOnlyTableDef
table =           [     1   2   1   0   0   0   1   0   0   0   1   4   23001; % cue in, saturation increase in RF
                 ];
end

function trialsArray = generateTrialsArray_psychometric(p, table)

% initate index tracking what row of the trials array has been generated as
% we loop through the trials table.
currentRow = 1;

% loop over each row of the table.
for i = 1:size(table, 1)
    % how many repetitions of the current row do we need?
    nReps = table(i, repCol);
    
    % Only Measure psychometric function during two patch & cue side stim change
    % conditions  YGC 04/03/19
    if strcmp(p.init.exptType, 'saturationIncreasePsychometric') && ...
            table(i,strcmp(p.init.trialArrayColumnNames, 'n stim')) == 2 && ...
            table(i,strcmp(p.init.trialArrayColumnNames, 'cue side')) == ...
            table(i,strcmp(p.init.trialArrayColumnNames, 'stim chg'))
        
        
        % Still need to consider what is the best way of setting gradient
        % for psychometric functions    YGC 04/03/19
        scalar = [];
        scalar = [0.2 repmat(linspace(0.5,1.5,(nReps-2)/2),1,2) 2];
        %         scalar = [0.02 0.04 0.05 0.06 0.08] / p.trVars.satDelta;
        
        % First replicate the mat based on the repetition of this condition
        % then find the column of saturation and multiply by the scalar
        pre_trialsArray = repmat(table(i,:), nReps, 1);
        saturation_column_index = find(strcmp(p.init.trialArrayColumnNames,'saturation'));
        %         keyboard
        pre_trialsArray(:,saturation_column_index) = pre_trialsArray(:,saturation_column_index).*scalar';
        p.init.trialsArray(currentRow:(currentRow + nReps - 1), :) = pre_trialsArray;
        
    else
        % place the repeated row into the "trials" array
        p.init.trialsArray(currentRow:(currentRow + nReps - 1), :) = ...
            repmat(table(i, :), nReps, 1);
    end
    % iterate the "currentRow" variable.
    currentRow = currentRow + nReps;
end

% store length of block
p.init.blockLength = size(p.init.trialsArray, 1);

end