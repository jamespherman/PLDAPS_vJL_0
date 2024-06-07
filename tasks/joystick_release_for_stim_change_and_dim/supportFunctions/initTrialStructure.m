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

    case 'joystick_release_for_stim_dim_and_orient_change_cued'
        table = tableDef_stimDimPlusOrientChange_cued;
        
    case 'joystick_release_for_stim_dim_and_orient_change_psycho'
        table = tableDef_stimDimPlusOrientChange_psycho;

    case 'joystick_release_for_stim_dim_and_orient_change_learn_cue'
        table = tableDef_stimDimPlusOrientChange_learn_cue;

    case 'joystick_release_for_stim_dim_and_orient_change_learn_cue_multi'
        table = tableDef_stimDimPlusOrientChange_learn_cue_multi;

    case 'joystick_release_for_stim_dim_and_orient_change_learn_chg'
        table = tableDef_stimDimPlusOrientChange_learn_chg;

    case 'joystick_release_for_stim_dim_and_hue_change_TEST'
        table = tableDef_fixAndStimDim_test;

    case 'joystick_release_for_stim_dim_and_orient_change_9010'
        table = tableDef_stimDimPlusOrientChange_9010;

    case 'joystick_release_for_stim_dim_and_orient_change_7030'
        table = tableDef_stimDimPlusOrientChange_7030;

    case 'joystick_release_for_stim_dim_and_orient_change_6040'
        table = tableDef_stimDimPlusOrientChange_6040;
        
    case 'joystick_release_for_stim_dim_and_orient_change_6040_SINGLELOCATION'
        table = tableDef_stimDimPlusOrientChange_6040_SINGLELOCATION;

    case 'joystick_release_for_stim_dim_and_orient_change_1to4_train_step1'
        table = tableDef_1to4stim_step1;

    case 'joystick_release_for_stim_dim_and_orient_change_1to4_train_step2'
        table = tableDef_1to4stim_step2;

    case 'joystick_release_for_stim_dim_and_orient_change_1to4_train_step2_allChg'
        table = tableDef_1to4stim_step2_allChg;

    case 'joystick_release_for_stim_dim_and_orient_change_1stim_allChg'
        table = tableDef_1stim_allChg;

    case 'joystick_release_for_stim_dim_and_hue_change_9010'
        table = tableDef_stimDimPlusHueChange_9010;

    case 'joystick_release_for_stim_dim_and_hue_change_7030'
        table = tableDef_stimDimPlusHueChange_7030;

    case 'joystick_release_for_stim_dim_and_hue_change_6040'
        table = tableDef_stimDimPlusHueChange_6040;

    case 'joystick_release_for_fix_and_stim_dim_1000'
        table = tableDef_fixAndStimDim_1000;

    case 'joystick_release_for_fix_and_stim_dim_9010'
        table = tableDef_fixAndStimDim_9010;

    case 'joystick_release_for_fix_and_stim_dim_7030'
        table = tableDef_fixAndStimDim_7030;

    case 'joystick_release_for_fix_and_stim_dim_6040'
        table = tableDef_fixAndStimDim_6040;

    case 'joystick_release_for_stim_dim_and_orient_change_TEST'
        table = tableDef_all_num_stimuli_orient_change;

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

% column descriptions (19 columns) REMINDER
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

% Orientation change detection - cued task version 1: single-stimulus
% trials at 1 (cued) location followed by 4-stimulus trials with a strong
% bias towards 1 (cued) location; cued location alternates from contra to
% ipsi after a fixed number of trials.
%
% 11 1-stimulus trials (8 change, 3 no-change = 73%:27%)
% 77 4-stimulus trials (57 change, 20 no-change = 74%:26%)
% 88 trials per cue location total
function table = tableDef_stimDimPlusOrientChange_cued
table =         [

                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   1   12  23301; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 1
                 1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   5   23302; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   2   12  23203; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 1
                 1   4   1   1   1   1   0   0   0   0   0   0   0   0   2   5   23204; % four stimuli at all locations; stimulus loc 2 is "primary", no orientation change
                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   3   12  23205; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 1
                 1   4   1   1   1   1   0   0   0   0   0   0   0   0   3   5   23206; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   4   12  23207; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 1
                 1   4   1   1   1   1   0   0   0   0   0   0   0   0   4   5   23208; % four stimuli at all locations; stimulus loc 4 is "primary", no orientation change

                 1   4   1   1   1   1   2   0   1   0   0   0   1   0   1   1   23209; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 2
                 1   4   1   1   1   1   2   0   1   0   0   0   1   0   2   1   23211; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 2
                 1   4   1   1   1   1   2   0   1   0   0   0   1   0   4   1   23215; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 2

                 1   4   1   1   1   1   3   0   1   0   0   0   1   0   2   1   23219; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 3
                 1   4   1   1   1   1   3   0   1   0   0   0   1   0   3   1   23221; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 3
                 1   4   1   1   1   1   3   0   1   0   0   0   1   0   4   1   23223; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 3

                 1   4   1   1   1   1   4   0   1   0   0   0   1   0   1   1   23225; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 4
                 1   4   1   1   1   1   4   0   1   0   0   0   1   0   2   1   23227; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 4
                 1   4   1   1   1   1   4   0   1   0   0   0   1   0   3   1   23329; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 4


                 3   4   1   1   1   1   1   0   1   0   0   0   1   0   1   1   23301; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 1
                 3   4   1   1   1   1   1   0   1   0   0   0   1   0   2   1   23203; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 1
                 3   4   1   1   1   1   1   0   1   0   0   0   1   0   4   1   23207; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 1

                 3   4   1   1   1   1   3   0   1   0   0   0   1   0   1   12  23217; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 3
                 3   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23218; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                 3   4   1   1   1   1   3   0   1   0   0   0   1   0   2   12  23219; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 3
                 3   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23220; % four stimuli at all locations; stimulus loc 2 is "primary", no orientation change
                 3   4   1   1   1   1   3   0   1   0   0   0   1   0   3   12  23221; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 3
                 3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23222; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                 3   4   1   1   1   1   3   0   1   0   0   0   1   0   4   12  23223; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 3
                 3   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23224; % four stimuli at all locations; stimulus loc 4 is "primary", no orientation change

                 3   4   1   1   1   1   2   0   1   0   0   0   1   0   2   1   23211; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 2
                 3   4   1   1   1   1   2   0   1   0   0   0   1   0   3   1   23213; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 2
                 3   4   1   1   1   1   2   0   1   0   0   0   1   0   4   1   23215; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 2

                 3   4   1   1   1   1   4   0   1   0   0   0   1   0   1   1   23225; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 4
                 3   4   1   1   1   1   4   0   1   0   0   0   1   0   2   1   23227; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 4
                 3   4   1   1   1   1   4   0   1   0   0   0   1   0   3   1   23329; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 4

                 ];
end

% Psychometric orientation change detection task: 
% single-stimulus trials at 1 location. Orient delta fluctuates randomly 
% between 4 values.

function table = tableDef_stimDimPlusOrientChange_psycho
table =         [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   2   23001; % single stimulus at location 1; orientation change at location 1
                 1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1   23002; % single stimulus at location 1; no change
                 1   1   1   0   0   0   1   0   1   0   0   0   1   0   2   2   23001; % single stimulus at location 1; orientation change at location 1
                 1   1   1   0   0   0   0   0   0   0   0   0   0   0   2   1   23002; % single stimulus at location 1; no change
                 1   1   1   0   0   0   1   0   1   0   0   0   1   0   3   2   23001; % single stimulus at location 1; orientation change at location 1
                 1   1   1   0   0   0   0   0   0   0   0   0   0   0   3   1   23002; % single stimulus at location 1; no change
                 1   1   1   0   0   0   1   0   1   0   0   0   1   0   4   2   23001; % single stimulus at location 1; orientation change at location 1

                 1   1   0   1   0   0   2   0   1   0   0   0   1   0   1   2   23001; % single stimulus at location 2; orientation change at location 2
                 1   1   0   1   0   0   0   0   0   0   0   0   0   0   1   1   23002; % single stimulus at location 2; no change
                 1   1   0   1   0   0   2   0   1   0   0   0   1   0   2   2   23001; % single stimulus at location 2; orientation change at location 2
                 1   1   0   1   0   0   0   0   0   0   0   0   0   0   2   1   23002; % single stimulus at location 2; no change
                 1   1   0   1   0   0   2   0   1   0   0   0   1   0   3   2   23001; % single stimulus at location 2; orientation change at location 2
                 1   1   0   1   0   0   0   0   0   0   0   0   0   0   3   1   23002; % single stimulus at location 2; no change
                 1   1   0   1   0   0   2   0   1   0   0   0   1   0   4   2   23001; % single stimulus at location 2; orientation change at location 2

                 1   1   0   0   1   0   3   0   1   0   0   0   1   0   1   3   23005; % single stimulus at location 3; orientation change at location 3
                 1   1   0   0   1   0   0   0   0   0   0   0   0   0   1   1   23006; % single stimulus at location 3; no change
                 1   1   0   0   1   0   3   0   1   0   0   0   1   0   2   3   23005; % single stimulus at location 3; orientation change at location 3
                 1   1   0   0   1   0   3   0   1   0   0   0   1   0   3   3   23005; % single stimulus at location 3; orientation change at location 3
                 1   1   0   0   1   0   0   0   0   0   0   0   0   0   3   1   23006; % single stimulus at location 3; no change
                 1   1   0   0   1   0   3   0   1   0   0   0   1   0   4   3   23005; % single stimulus at location 3; orientation change at location 3
                 1   1   0   0   1   0   0   0   0   0   0   0   0   0   4   1   23006; % single stimulus at location 3; no change

                 1   1   0   0   0   1   4   0   1   0   0   0   1   0   1   3   23005; % single stimulus at location 4; orientation change at location 4
                 1   1   0   0   0   1   0   0   0   0   0   0   0   0   1   1   23006; % single stimulus at location 4; no change
                 1   1   0   0   0   1   4   0   1   0   0   0   1   0   2   3   23005; % single stimulus at location 4; orientation change at location 4
                 1   1   0   0   0   1   4   0   1   0   0   0   1   0   3   3   23005; % single stimulus at location 4; orientation change at location 4
                 1   1   0   0   0   1   0   0   0   0   0   0   0   0   3   1   23006; % single stimulus at location 4; no change
                 1   1   0   0   0   1   4   0   1   0   0   0   1   0   4   3   23005; % single stimulus at location 4; orientation change at location 4
                 1   1   0   0   0   1   0   0   0   0   0   0   0   0   4   1   23006; % single stimulus at location 4; no change

                 ];
end

% Orientation change detection - training
% Only cued locations will change -- 100% prob. cue.
% No change trials have an 'empty cue' -- cued location does not have a
% stimulus.

function table = tableDef_stimDimPlusOrientChange_learn_cue
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   36   23001; % cue at location 1 % single stimulus at location 1; orientation change at location 1
                   1   1   0   1   0   0   0   0   0   0   0   0   0   0   1   8    23002; % cue at location 1 % single stimulus at location 2; no change
                   1   1   0   0   1   0   0   0   0   0   0   0   0   0   1   8    23005; % cue at location 1 % single stimulus at location 3; no change
                   1   1   0   0   0   1   0   0   0   0   0   0   0   0   1   8    23006; % cue at location 1 % single stimulus at location 4; no change

                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   1   36   23001; % cue at location 2 % single stimulus at location 1; orientation change at location 2
                   2   1   1   0   0   0   0   0   0   0   0   0   0   0   1   8    23002; % cue at location 2 % single stimulus at location 2; no change
                   2   1   0   0   1   0   0   0   0   0   0   0   0   0   1   8    23005; % cue at location 2 % single stimulus at location 3; no change
                   2   1   0   0   0   1   0   0   0   0   0   0   0   0   1   8    23006; % cue at location 2 % single stimulus at location 4; no change

                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   1   36   23001; % cue at location 3 % single stimulus at location 1; orientation change at location 3
                   3   1   1   0   0   0   0   0   0   0   0   0   0   0   1   8    23002; % cue at location 3 % single stimulus at location 2; no change
                   3   1   0   1   0   0   0   0   0   0   0   0   0   0   1   8    23005; % cue at location 3 % single stimulus at location 3; no change
                   3   1   0   0   0   1   0   0   0   0   0   0   0   0   1   8    23006; % cue at location 3 % single stimulus at location 4; no change

                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   1   36   23001; % cue at location 4 % single stimulus at location 1; orientation change at location 4
                   4   1   0   0   1   0   0   0   0   0   0   0   0   0   1   8    23002; % cue at location 4 % single stimulus at location 2; no change
                   4   1   0   1   0   0   0   0   0   0   0   0   0   0   1   8    23005; % cue at location 4 % single stimulus at location 3; no change
                   4   1   1   0   0   0   0   0   0   0   0   0   0   0   1   8    23006; % cue at location 4 % single stimulus at location 4; no change
                 ];
end

function table = tableDef_stimDimPlusOrientChange_learn_cue_multi
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   29   23001; % cue at location 1 % single stimulus at location 1; orientation change at location 1
                   1   4   1   1   1   1   1   0   1   0   0   0   1   0   1   7    23301; % cue at location 1 % four stimuli at all locations; orientation change at location 1
                   1   1   0   1   0   0   0   0   0   0   0   0   0   0   1   6    23002; % cue at location 1 % single stimulus at location 2; no change
                   1   1   0   0   1   0   0   0   0   0   0   0   0   0   1   6    23005; % cue at location 1 % single stimulus at location 3; no change
                   1   1   0   0   0   1   0   0   0   0   0   0   0   0   1   6    23006; % cue at location 1 % single stimulus at location 4; no change
                   1   4   1   1   1   1   0   0   0   0   0   0   1   0   1   5    23301; % cue at location 1 % four stimuli at all locations; no change

                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   1   29   23001; % cue at location 2 % single stimulus at location 1; orientation change at location 2
                   2   4   1   1   1   1   2   0   1   0   0   0   1   0   1   7    23301; % cue at location 2 % four stimuli at all locations; orientation change at location 2
                   2   1   1   0   0   0   0   0   0   0   0   0   0   0   1   6    23002; % cue at location 2 % single stimulus at location 2; no change
                   2   1   0   0   1   0   0   0   0   0   0   0   0   0   1   6    23005; % cue at location 2 % single stimulus at location 3; no change
                   2   1   0   0   0   1   0   0   0   0   0   0   0   0   1   6    23006; % cue at location 2 % single stimulus at location 4; no change
                   2   4   1   1   1   1   0   0   0   0   0   0   1   0   1   5    23301; % cue at location 2 % four stimuli at all locations; no change

                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   1   29   23001; % cue at location 3 % single stimulus at location 1; orientation change at location 3
                   3   4   1   1   1   1   3   0   1   0   0   0   1   0   1   7    23301; % cue at location 3 % four stimuli at all locations; orientation change at location 3
                   3   1   1   0   0   0   0   0   0   0   0   0   0   0   1   6    23002; % cue at location 3 % single stimulus at location 2; no change
                   3   1   0   1   0   0   0   0   0   0   0   0   0   0   1   6    23005; % cue at location 3 % single stimulus at location 3; no change
                   3   1   0   0   0   1   0   0   0   0   0   0   0   0   1   6    23006; % cue at location 3 % single stimulus at location 4; no change
                   3   4   1   1   1   1   0   0   0   0   0   0   1   0   1   5    23301; % cue at location 3 % four stimuli at all locations; no change

                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   1   29   23001; % cue at location 4 % single stimulus at location 1; orientation change at location 4
                   4   4   1   1   1   1   4   0   1   0   0   0   1   0   1   7    23301; % cue at location 3 % four stimuli at all locations; orientation change at location 3
                   4   1   0   0   1   0   0   0   0   0   0   0   0   0   1   6    23002; % cue at location 4 % single stimulus at location 2; no change
                   4   1   0   1   0   0   0   0   0   0   0   0   0   0   1   6    23005; % cue at location 4 % single stimulus at location 3; no change
                   4   1   1   0   0   0   0   0   0   0   0   0   0   0   1   6    23006; % cue at location 4 % single stimulus at location 4; no change
                   4   4   1   1   1   1   0   0   0   0   0   0   1   0   1   5    23301; % cue at location 3 % four stimuli at all locations; no change
                 ];
end

% Orientation change detection - training
% Only cued locations will change -- 100% prob. cue.
% No change trials have an 'empty cue' -- cued location does not have a
% stimulus.

function table = tableDef_stimDimPlusOrientChange_learn_cue_f
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   40   23001; % cue at location 1 % single stimulus at location 1; orientation change at location 1
                   1   1   0   1   0   0   0   0   0   0   0   0   0   0   1   1    23002; % cue at location 1 % single stimulus at location 2; no change
                   1   1   0   0   1   0   0   0   0   0   0   0   0   0   1   1    23005; % cue at location 1 % single stimulus at location 3; no change
                   1   1   0   0   0   1   0   0   0   0   0   0   0   0   1   1    23006; % cue at location 1 % single stimulus at location 4; no change

                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   1   40   23001; % cue at location 1 % single stimulus at location 1; orientation change at location 1
                   2   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1    23002; % cue at location 1 % single stimulus at location 2; no change
                   2   1   0   0   1   0   0   0   0   0   0   0   0   0   1   1    23005; % cue at location 1 % single stimulus at location 3; no change
                   2   1   0   0   0   1   0   0   0   0   0   0   0   0   1   1    23006; % cue at location 1 % single stimulus at location 4; no change

                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   1   40   23001; % cue at location 1 % single stimulus at location 1; orientation change at location 1
                   3   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1    23002; % cue at location 1 % single stimulus at location 2; no change
                   3   1   0   1   0   0   0   0   0   0   0   0   0   0   1   1    23005; % cue at location 1 % single stimulus at location 3; no change
                   3   1   0   0   0   1   0   0   0   0   0   0   0   0   1   1    23006; % cue at location 1 % single stimulus at location 4; no change

                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   1   40   23001; % cue at location 1 % single stimulus at location 1; orientation change at location 1
                   4   1   0   0   1   0   0   0   0   0   0   0   0   0   1   1    23002; % cue at location 1 % single stimulus at location 2; no change
                   4   1   0   1   0   0   0   0   0   0   0   0   0   0   1   1    23005; % cue at location 1 % single stimulus at location 3; no change
                   4   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1    23006; % cue at location 1 % single stimulus at location 4; no change
                 ];
end

% Same as learn_cue (above), but only change trials
% (No no change trials)
function table = tableDef_stimDimPlusOrientChange_learn_chg
table =         [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   2   23001; % single stimulus at location 1; orientation change at location 1
                 1   1   1   0   0   0   1   0   1   0   0   0   1   0   2   2   23001; % single stimulus at location 1; orientation change at location 1
                 1   1   1   0   0   0   1   0   1   0   0   0   1   0   3   2   23001; % single stimulus at location 1; orientation change at location 1
                 1   1   1   0   0   0   1   0   1   0   0   0   1   0   4   2   23001; % single stimulus at location 1; orientation change at location 1

                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   1   12  23301; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 1
                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   2   12  23203; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 1
                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   3   12  23205; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 1
                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   4   12  23207; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 1

                 3   1   0   0   1   0   3   0   1   0   0   0   1   0   1   3   23005; % single stimulus at location 3; orientation change at location 3
                 3   1   0   0   1   0   3   0   1   0   0   0   1   0   2   3   23005; % single stimulus at location 3; orientation change at location 3
                 3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   3   23005; % single stimulus at location 3; orientation change at location 3
                 3   1   0   0   1   0   3   0   1   0   0   0   1   0   4   3   23005; % single stimulus at location 3; orientation change at location 3

                 3   4   1   1   1   1   3   0   1   0   0   0   1   0   1   12  23217; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 3
                 3   4   1   1   1   1   3   0   1   0   0   0   1   0   2   12  23219; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 3
                 3   4   1   1   1   1   3   0   1   0   0   0   1   0   3   12  23221; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 3
                 3   4   1   1   1   1   3   0   1   0   0   0   1   0   4   12  23223; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 3

                 ];
end


% Orientation change detection - training progression from 1 stimulus to 4
% stimuli - step 1
function table = tableDef_1to4stim_step1
table =         [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   6   23001; % single stimulus at location 1; orientation change at location 1
                 1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   4   23002; % single stimulus at location 1; no change
                 2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   6   23003; % single stimulus at location 2; orientation change at location 2
                 2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   4   23004; % single stimulus at location 2; no change
                 3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   6   23005; % single stimulus at location 3; orientation change at location 3
                 3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   4   23006; % single stimulus at location 3; no change
                 4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   6   23007; % single stimulus at location 4; orientation change at location 4
                 4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   4   23008; % single stimulus at location 4; no change

                 1   2   1   0   1   0   1   0   1   0   0   0   1   0   1   3   23101; % two stimuli at locations 1 & 3; stimulus loc 1 is "primary", orientation change at location 1
                 1   2   1   0   1   0   0   0   0   0   0   0   0   0   1   2   23102; % two stimuli at locations 1 & 3; stimulus loc 1 is "primary", no orientation change
                 3   2   1   0   1   0   3   0   1   0   0   0   1   0   3   3   23103; % two stimuli at locations 1 & 3; stimulus loc 3 is "primary", orientation change at location 3
                 3   2   1   0   1   0   0   0   0   0   0   0   0   0   3   2   23104; % two stimuli at locations 1 & 3; stimulus loc 3 is "primary", no orientation change
                 2   2   0   1   0   1   2   0   1   0   0   0   1   0   2   3   23105; % two stimuli at locations 2 & 4; stimulus loc 2 is "primary", orientation change at location 2
                 2   2   0   1   0   1   0   0   0   0   0   0   0   0   2   2   23106; % two stimuli at locations 2 & 4; stimulus loc 2 is "primary", no orientation change
                 4   2   0   1   0   1   4   0   1   0   0   0   1   0   4   3   23107; % two stimuli at locations 2 & 4; stimulus loc 4 is "primary", orientation change at location 4
                 4   2   0   1   0   1   0   0   0   0   0   0   0   0   4   2   23108; % two stimuli at locations 2 & 4; stimulus loc 4 is "primary", no orientation change

                 1   3   1   1   1   0   1   0   1   0   0   0   1   0   1   1   23201; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", orientation change at location 1
                 1   3   1   1   1   0   0   0   0   0   0   0   0   0   1   1   23202; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", no orientation change
                 1   3   1   1   1   0   2   0   1   0   0   0   1   0   1   1   23207; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", orientation change at location 2
                 1   3   1   1   1   0   0   0   0   0   0   0   0   0   1   1   23208; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", no orientation change
                 1   3   1   1   1   0   3   0   1   0   0   0   1   0   1   1   23213; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", orientation change at location 3

                 2   3   0   1   1   1   2   0   1   0   0   0   1   0   2   1   23219; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", orientation change at location 2
                 2   3   0   1   1   1   0   0   0   0   0   0   0   0   2   1   23220; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", no orientation change
                 2   3   0   1   1   1   3   0   1   0   0   0   1   0   2   1   23225; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", orientation change at location 3
                 2   3   0   1   1   1   0   0   0   0   0   0   0   0   2   1   23226; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", no orientation change
                 2   3   0   1   1   1   4   0   1   0   0   0   1   0   2   1   23231; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", orientation change at location 4

                 3   3   1   0   1   1   1   0   1   0   0   0   1   0   3   1   23239; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", orientation change at location 1
                 3   3   1   0   1   1   0   0   0   0   0   0   0   0   3   1   23240; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", no orientation change
                 3   3   1   0   1   1   3   0   1   0   0   0   1   0   3   1   23245; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", orientation change at location 3
                 3   3   1   0   1   1   0   0   0   0   0   0   0   0   3   1   23246; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", no orientation change
                 3   3   1   0   1   1   4   0   1   0   0   0   1   0   3   1   23251; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", orientation change at location 4

                 4   3   1   1   0   1   1   0   1   0   0   0   1   0   4   1   23259; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", orientation change at location 1
                 4   3   1   1   0   1   0   0   0   0   0   0   0   0   4   1   23260; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", no orientation change
                 4   3   1   1   0   1   2   0   1   0   0   0   1   0   4   1   23265; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", orientation change at location 2
                 4   3   1   1   0   1   0   0   0   0   0   0   0   0   4   1   23266; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", no orientation change
                 4   3   1   1   0   1   4   0   1   0   0   0   1   0   4   1   23271; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", orientation change at location 4

                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   1   1   23301; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 1
                 1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23302; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                 2   4   1   1   1   1   1   0   1   0   0   0   1   0   2   1   23203; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 1

                 3   4   1   1   1   1   2   0   1   0   0   0   1   0   3   1   23213; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 2
                 3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23214; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                 4   4   1   1   1   1   2   0   1   0   0   0   1   0   4   1   23215; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 2

                 1   4   1   1   1   1   3   0   1   0   0   0   1   0   1   1   23217; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 3
                 1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23218; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                 2   4   1   1   1   1   3   0   1   0   0   0   1   0   2   1   23219; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 3

                 3   4   1   1   1   1   4   0   1   0   0   0   1   0   3   1   23329; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 4
                 3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23330; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                 4   4   1   1   1   1   4   0   1   0   0   0   1   0   4   1   23331; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 4

                 ];
end

% Orientation change detection - training progression from 1 stimulus to 4
% stimuli - step 1
function table = tableDef_1to4stim_step2
table =         [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   2   23001; % single stimulus at location 1; orientation change at location 1
                 1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1   23002; % single stimulus at location 1; no change
                 2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   2   23003; % single stimulus at location 2; orientation change at location 2
                 2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   1   23004; % single stimulus at location 2; no change
                 3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   2   23005; % single stimulus at location 3; orientation change at location 3
                 3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   1   23006; % single stimulus at location 3; no change
                 4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   2   23007; % single stimulus at location 4; orientation change at location 4
                 4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   1   23008; % single stimulus at location 4; no change

                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   1   4   23301; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 1
                 1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   2   23302; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                 2   4   1   1   1   1   1   0   1   0   0   0   1   0   2   4   23203; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 1
                 2   4   1   1   1   1   0   0   0   0   0   0   0   0   2   2   23204; % four stimuli at all locations; stimulus loc 2 is "primary", no orientation change

                 3   4   1   1   1   1   2   0   1   0   0   0   1   0   3   4   23213; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 2
                 3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   2   23214; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                 4   4   1   1   1   1   2   0   1   0   0   0   1   0   4   4   23215; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 2
                 4   4   1   1   1   1   0   0   0   0   0   0   0   0   4   2   23216; % four stimuli at all locations; stimulus loc 4 is "primary", no orientation change

                 1   4   1   1   1   1   3   0   1   0   0   0   1   0   1   4   23217; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 3
                 1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   2   23218; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                 2   4   1   1   1   1   3   0   1   0   0   0   1   0   2   4   23219; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 3
                 2   4   1   1   1   1   0   0   0   0   0   0   0   0   2   2   23220; % four stimuli at all locations; stimulus loc 2 is "primary", no orientation change

                 3   4   1   1   1   1   4   0   1   0   0   0   1   0   3   4   23329; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 4
                 3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   2   23330; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                 4   4   1   1   1   1   4   0   1   0   0   0   1   0   4   4   23331; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 4
                 4   4   1   1   1   1   0   0   0   0   0   0   0   0   4   2   23332; % four stimuli at all locations; stimulus loc 4 is "primary", no orientation change

                 ];
end

% Orientation change detection - training progression from 1 stimulus to 4
% stimuli - step 2
function table = tableDef_1to4stim_step2_allChg
table =         [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   2   23001; % single stimulus at location 1; orientation change at location 1

                 2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   2   23003; % single stimulus at location 2; orientation change at location 2

                 3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   2   23005; % single stimulus at location 3; orientation change at location 3

                 4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   2   23007; % single stimulus at location 4; orientation change at location 4


                 1   4   1   1   1   1   1   0   1   0   0   0   1   0   1   4   23301; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 1

                 2   4   1   1   1   1   1   0   1   0   0   0   1   0   2   4   23203; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 1

                 3   4   1   1   1   1   2   0   1   0   0   0   1   0   3   4   23213; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 2

                 4   4   1   1   1   1   2   0   1   0   0   0   1   0   4   4   23215; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 2


                 1   4   1   1   1   1   3   0   1   0   0   0   1   0   1   4   23217; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 3

                 2   4   1   1   1   1   3   0   1   0   0   0   1   0   2   4   23219; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 3


                 3   4   1   1   1   1   4   0   1   0   0   0   1   0   3   4   23329; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 4

                 4   4   1   1   1   1   4   0   1   0   0   0   1   0   4   4   23331; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 4


                 ];
end

% Orientation change detection - training progression from 1 stimulus to 4
% stimuli - step 1
function table = tableDef_1stim_allChg
table =         [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   2   23001; % single stimulus at location 1; orientation change at location 1

                 2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   2   23003; % single stimulus at location 2; orientation change at location 2

                 3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   2   23005; % single stimulus at location 3; orientation change at location 3

                 4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   2   23007; % single stimulus at location 4; orientation change at location 4
                 ];
end

% Stimulus orientation change trial types, including single stimulus, two
% stimulus, three stimulus, and four stimulus trials. Not really used for
% an experiment, but for a master list of trial types / codes.
function table = tableDef_all_num_stimuli_orient_change
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   1   23001; % single stimulus at location 1; orientation change at location 1
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1   23002; % single stimulus at location 1; no change
                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   1   23003; % single stimulus at location 2; orientation change at location 2
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   1   23004; % single stimulus at location 2; no change
                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   1   23005; % single stimulus at location 3; orientation change at location 3
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   1   23006; % single stimulus at location 3; no change
                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   1   23007; % single stimulus at location 4; orientation change at location 4
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   1   23008; % single stimulus at location 4; no change

                   1   2   1   0   1   0   1   0   1   0   0   0   1   0   1   1   23101; % two stimuli at locations 1 & 3; stimulus loc 1 is "primary", orientation change at location 1
                   1   2   1   0   1   0   0   0   0   0   0   0   0   0   1   1   23102; % two stimuli at locations 1 & 3; stimulus loc 1 is "primary", no orientation change
                   3   2   1   0   1   0   3   0   1   0   0   0   1   0   3   1   23103; % two stimuli at locations 1 & 3; stimulus loc 3 is "primary", orientation change at location 3
                   3   2   1   0   1   0   0   0   0   0   0   0   0   0   3   1   23104; % two stimuli at locations 1 & 3; stimulus loc 3 is "primary", no orientation change
                   2   2   0   1   0   1   2   0   1   0   0   0   1   0   2   1   23105; % two stimuli at locations 2 & 4; stimulus loc 2 is "primary", orientation change at location 2
                   2   2   0   1   0   1   0   0   0   0   0   0   0   0   2   1   23106; % two stimuli at locations 2 & 4; stimulus loc 2 is "primary", no orientation change
                   4   2   0   1   0   1   4   0   1   0   0   0   1   0   4   1   23107; % two stimuli at locations 2 & 4; stimulus loc 4 is "primary", orientation change at location 4
                   4   2   0   1   0   1   0   0   0   0   0   0   0   0   4   1   23108; % two stimuli at locations 2 & 4; stimulus loc 4 is "primary", no orientation change

                   1   3   1   1   1   0   1   0   1   0   0   0   1   0   1   1   23201; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", orientation change at location 1
                   1   3   1   1   1   0   0   0   0   0   0   0   0   0   1   1   23202; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", no orientation change
                   2   3   1   1   1   0   1   0   1   0   0   0   1   0   2   1   23203; % three stimuli at locations 1, 2, 3; stimulus loc 2 is "primary", orientation change at location 1
                   2   3   1   1   1   0   0   0   0   0   0   0   0   0   2   1   23204; % three stimuli at locations 1, 2, 3; stimulus loc 2 is "primary", no orientation change
                   3   3   1   1   1   0   1   0   1   0   0   0   1   0   3   1   23205; % three stimuli at locations 1, 2, 3; stimulus loc 3 is "primary", orientation change at location 1
                   3   3   1   1   1   0   0   0   0   0   0   0   0   0   3   1   23206; % three stimuli at locations 1, 2, 3; stimulus loc 3 is "primary", no orientation change
                   1   3   1   1   1   0   2   0   1   0   0   0   1   0   1   1   23207; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", orientation change at location 2
                   1   3   1   1   1   0   0   0   0   0   0   0   0   0   1   1   23208; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", no orientation change
                   2   3   1   1   1   0   2   0   1   0   0   0   1   0   2   1   23209; % three stimuli at locations 1, 2, 3; stimulus loc 2 is "primary", orientation change at location 2
                   2   3   1   1   1   0   0   0   0   0   0   0   0   0   2   1   23210; % three stimuli at locations 1, 2, 3; stimulus loc 2 is "primary", no orientation change
                   3   3   1   1   1   0   2   0   1   0   0   0   1   0   3   1   23211; % three stimuli at locations 1, 2, 3; stimulus loc 3 is "primary", orientation change at location 2
                   3   3   1   1   1   0   0   0   0   0   0   0   0   0   3   1   23212; % three stimuli at locations 1, 2, 3; stimulus loc 3 is "primary", no orientation change
                   1   3   1   1   1   0   3   0   1   0   0   0   1   0   1   1   23213; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", orientation change at location 3
                   1   3   1   1   1   0   0   0   0   0   0   0   0   0   1   1   23214; % three stimuli at locations 1, 2, 3; stimulus loc 1 is "primary", no orientation change
                   2   3   1   1   1   0   3   0   1   0   0   0   1   0   2   1   23215; % three stimuli at locations 1, 2, 3; stimulus loc 2 is "primary", orientation change at location 3
                   2   3   1   1   1   0   0   0   0   0   0   0   0   0   2   1   23216; % three stimuli at locations 1, 2, 3; stimulus loc 2 is "primary", no orientation change
                   3   3   1   1   1   0   3   0   1   0   0   0   1   0   3   1   23217; % three stimuli at locations 1, 2, 3; stimulus loc 3 is "primary", orientation change at location 3
                   3   3   1   1   1   0   0   0   0   0   0   0   0   0   3   1   23218; % three stimuli at locations 1, 2, 3; stimulus loc 3 is "primary", no orientation change

                   2   3   0   1   1   1   2   0   1   0   0   0   1   0   2   1   23219; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", orientation change at location 2
                   2   3   0   1   1   1   0   0   0   0   0   0   0   0   2   1   23220; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", no orientation change
                   3   3   0   1   1   1   2   0   1   0   0   0   1   0   3   1   23221; % three stimuli at locations 2, 3, 4; stimulus loc 3 is "primary", orientation change at location 2
                   3   3   0   1   1   1   0   0   0   0   0   0   0   0   3   1   23222; % three stimuli at locations 2, 3, 4; stimulus loc 3 is "primary", no orientation change
                   4   3   0   1   1   1   2   0   1   0   0   0   1   0   4   1   23223; % three stimuli at locations 2, 3, 4; stimulus loc 4 is "primary", orientation change at location 2
                   4   3   0   1   1   1   0   0   0   0   0   0   0   0   4   1   23224; % three stimuli at locations 2, 3, 4; stimulus loc 4 is "primary", no orientation change
                   2   3   0   1   1   1   3   0   1   0   0   0   1   0   2   1   23225; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", orientation change at location 3
                   2   3   0   1   1   1   0   0   0   0   0   0   0   0   2   1   23226; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", no orientation change
                   3   3   0   1   1   1   3   0   1   0   0   0   1   0   3   1   23227; % three stimuli at locations 2, 3, 4; stimulus loc 3 is "primary", orientation change at location 3
                   3   3   0   1   1   1   0   0   0   0   0   0   0   0   3   1   23228; % three stimuli at locations 2, 3, 4; stimulus loc 3 is "primary", no orientation change
                   4   3   0   1   1   1   3   0   1   0   0   0   1   0   4   1   23229; % three stimuli at locations 2, 3, 4; stimulus loc 4 is "primary", orientation change at location 3
                   4   3   0   1   1   1   0   0   0   0   0   0   0   0   4   1   23230; % three stimuli at locations 2, 3, 4; stimulus loc 4 is "primary", no orientation change
                   2   3   0   1   1   1   4   0   1   0   0   0   1   0   2   1   23231; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", orientation change at location 4
                   2   3   0   1   1   1   0   0   0   0   0   0   0   0   2   1   23232; % three stimuli at locations 2, 3, 4; stimulus loc 2 is "primary", no orientation change
                   3   3   0   1   1   1   4   0   1   0   0   0   1   0   3   1   23233; % three stimuli at locations 2, 3, 4; stimulus loc 3 is "primary", orientation change at location 4
                   3   3   0   1   1   1   0   0   0   0   0   0   0   0   3   1   23234; % three stimuli at locations 2, 3, 4; stimulus loc 3 is "primary", no orientation change
                   4   3   0   1   1   1   4   0   1   0   0   0   1   0   4   1   23235; % three stimuli at locations 2, 3, 4; stimulus loc 4 is "primary", orientation change at location 4
                   4   3   0   1   1   1   0   0   0   0   0   0   0   0   4   1   23236; % three stimuli at locations 2, 3, 4; stimulus loc 4 is "primary", no orientation change

                   1   3   1   0   1   1   1   0   1   0   0   0   1   0   1   1   23237; % three stimuli at locations 3, 4, 1; stimulus loc 1 is "primary", orientation change at location 1
                   1   3   1   0   1   1   0   0   0   0   0   0   0   0   1   1   23238; % three stimuli at locations 3, 4, 1; stimulus loc 1 is "primary", no orientation change
                   3   3   1   0   1   1   1   0   1   0   0   0   1   0   3   1   23239; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", orientation change at location 1
                   3   3   1   0   1   1   0   0   0   0   0   0   0   0   3   1   23240; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", no orientation change
                   4   3   1   0   1   1   1   0   1   0   0   0   1   0   4   1   23241; % three stimuli at locations 3, 4, 1; stimulus loc 4 is "primary", orientation change at location 1
                   4   3   1   0   1   1   0   0   0   0   0   0   0   0   4   1   23242; % three stimuli at locations 3, 4, 1; stimulus loc 4 is "primary", no orientation change
                   1   3   1   0   1   1   3   0   1   0   0   0   1   0   1   1   23243; % three stimuli at locations 3, 4, 1; stimulus loc 1 is "primary", orientation change at location 3
                   1   3   1   0   1   1   0   0   0   0   0   0   0   0   1   1   23244; % three stimuli at locations 3, 4, 1; stimulus loc 1 is "primary", no orientation change
                   3   3   1   0   1   1   3   0   1   0   0   0   1   0   3   1   23245; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", orientation change at location 3
                   3   3   1   0   1   1   0   0   0   0   0   0   0   0   3   1   23246; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", no orientation change
                   4   3   1   0   1   1   3   0   1   0   0   0   1   0   4   1   23247; % three stimuli at locations 3, 4, 1; stimulus loc 4 is "primary", orientation change at location 3
                   4   3   1   0   1   1   0   0   0   0   0   0   0   0   4   1   23248; % three stimuli at locations 3, 4, 1; stimulus loc 4 is "primary", no orientation change
                   1   3   1   0   1   1   4   0   1   0   0   0   1   0   1   1   23249; % three stimuli at locations 3, 4, 1; stimulus loc 1 is "primary", orientation change at location 4
                   1   3   1   0   1   1   0   0   0   0   0   0   0   0   1   1   23250; % three stimuli at locations 3, 4, 1; stimulus loc 1 is "primary", no orientation change
                   3   3   1   0   1   1   4   0   1   0   0   0   1   0   3   1   23251; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", orientation change at location 4
                   3   3   1   0   1   1   0   0   0   0   0   0   0   0   3   1   23252; % three stimuli at locations 3, 4, 1; stimulus loc 3 is "primary", no orientation change
                   4   3   1   0   1   1   4   0   1   0   0   0   1   0   4   1   23253; % three stimuli at locations 3, 4, 1; stimulus loc 4 is "primary", orientation change at location 4
                   4   3   1   0   1   1   0   0   0   0   0   0   0   0   4   1   23254; % three stimuli at locations 3, 4, 1; stimulus loc 4 is "primary", no orientation change

                   1   3   1   1   0   1   1   0   1   0   0   0   1   0   1   1   23255; % three stimuli at locations 4, 1, 2; stimulus loc 1 is "primary", orientation change at location 1
                   1   3   1   1   0   1   0   0   0   0   0   0   0   0   1   1   23256; % three stimuli at locations 4, 1, 2; stimulus loc 1 is "primary", no orientation change
                   2   3   1   1   0   1   1   0   1   0   0   0   1   0   2   1   23257; % three stimuli at locations 4, 1, 2; stimulus loc 2 is "primary", orientation change at location 1
                   2   3   1   1   0   1   0   0   0   0   0   0   0   0   2   1   23258; % three stimuli at locations 4, 1, 2; stimulus loc 2 is "primary", no orientation change
                   4   3   1   1   0   1   1   0   1   0   0   0   1   0   4   1   23259; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", orientation change at location 1
                   4   3   1   1   0   1   0   0   0   0   0   0   0   0   4   1   23260; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", no orientation change
                   1   3   1   1   0   1   2   0   1   0   0   0   1   0   1   1   23261; % three stimuli at locations 4, 1, 2; stimulus loc 1 is "primary", orientation change at location 2
                   1   3   1   1   0   1   0   0   0   0   0   0   0   0   1   1   23262; % three stimuli at locations 4, 1, 2; stimulus loc 1 is "primary", no orientation change
                   2   3   1   1   0   1   2   0   1   0   0   0   1   0   2   1   23263; % three stimuli at locations 4, 1, 2; stimulus loc 2 is "primary", orientation change at location 2
                   2   3   1   1   0   1   0   0   0   0   0   0   0   0   2   1   23264; % three stimuli at locations 4, 1, 2; stimulus loc 2 is "primary", no orientation change
                   4   3   1   1   0   1   2   0   1   0   0   0   1   0   4   1   23265; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", orientation change at location 2
                   4   3   1   1   0   1   0   0   0   0   0   0   0   0   4   1   23266; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", no orientation change
                   1   3   1   1   0   1   4   0   1   0   0   0   1   0   1   1   23267; % three stimuli at locations 4, 1, 2; stimulus loc 1 is "primary", orientation change at location 4
                   1   3   1   1   0   1   0   0   0   0   0   0   0   0   1   1   23268; % three stimuli at locations 4, 1, 2; stimulus loc 1 is "primary", no orientation change
                   2   3   1   1   0   1   4   0   1   0   0   0   1   0   2   1   23269; % three stimuli at locations 4, 1, 2; stimulus loc 2 is "primary", orientation change at location 4
                   2   3   1   1   0   1   0   0   0   0   0   0   0   0   2   1   23270; % three stimuli at locations 4, 1, 2; stimulus loc 2 is "primary", no orientation change
                   4   3   1   1   0   1   4   0   1   0   0   0   1   0   4   1   23271; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", orientation change at location 4
                   4   3   1   1   0   1   0   0   0   0   0   0   0   0   4   1   23272; % three stimuli at locations 4, 1, 2; stimulus loc 4 is "primary", no orientation change

                   1   4   1   1   1   1   1   0   1   0   0   0   1   0   1   1   23301; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 1
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23302; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                   2   4   1   1   1   1   1   0   1   0   0   0   1   0   2   1   23203; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 1
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23204; % four stimuli at all locations; stimulus loc 2 is "primary", no orientation change
                   3   4   1   1   1   1   1   0   1   0   0   0   1   0   3   1   23205; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 1
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23206; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change                   
                   4   4   1   1   1   1   1   0   1   0   0   0   1   0   4   1   23207; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 1
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23208; % four stimuli at all locations; stimulus loc 4 is "primary", no orientation change

                   1   4   1   1   1   1   2   0   1   0   0   0   1   0   1   1   23209; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 2
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23210; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                   2   4   1   1   1   1   2   0   1   0   0   0   1   0   2   1   23211; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 2
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23212; % four stimuli at all locations; stimulus loc 2 is "primary", no orientation change
                   3   4   1   1   1   1   2   0   1   0   0   0   1   0   3   1   23213; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 2
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23214; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                   4   4   1   1   1   1   2   0   1   0   0   0   1   0   4   1   23215; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 2
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23216; % four stimuli at all locations; stimulus loc 4 is "primary", no orientation change

                   1   4   1   1   1   1   3   0   1   0   0   0   1   0   1   1   23217; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 3
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23218; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                   2   4   1   1   1   1   3   0   1   0   0   0   1   0   2   1   23219; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 3
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23220; % four stimuli at all locations; stimulus loc 2 is "primary", no orientation change
                   3   4   1   1   1   1   3   0   1   0   0   0   1   0   3   1   23221; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 3
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23222; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                   4   4   1   1   1   1   3   0   1   0   0   0   1   0   4   1   23223; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 3
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23224; % four stimuli at all locations; stimulus loc 4 is "primary", no orientation change

                   1   4   1   1   1   1   4   0   1   0   0   0   1   0   1   1   23225; % four stimuli at all locations; stimulus loc 1 is "primary", orientation change at location 4
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23226; % four stimuli at all locations; stimulus loc 1 is "primary", no orientation change
                   2   4   1   1   1   1   4   0   1   0   0   0   1   0   2   1   23227; % four stimuli at all locations; stimulus loc 2 is "primary", orientation change at location 4
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23328; % four stimuli at all locations; stimulus loc 2 is "primary", no orientation change
                   3   4   1   1   1   1   4   0   1   0   0   0   1   0   3   1   23329; % four stimuli at all locations; stimulus loc 3 is "primary", orientation change at location 4
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23330; % four stimuli at all locations; stimulus loc 3 is "primary", no orientation change
                   4   4   1   1   1   1   4   0   1   0   0   0   1   0   4   1   23331; % four stimuli at all locations; stimulus loc 4 is "primary", orientation change at location 4
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23332; % four stimuli at all locations; stimulus loc 4 is "primary", no orientation change
                 ];
end

% Peripheral stimulus dimming + orientation change with mostly change trials.
function table = tableDef_stimDimPlusOrientChange_9010
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   9   23001; % single stimulus at location 1; orientation change at location 1
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1   23002; % single stimulus at location 1; no change
                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   9   23003; % single stimulus at location 2; orientation change at location 2
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   1   23004; % single stimulus at location 2; no change
                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   9   23005; % single stimulus at location 3; orientation change at location 3
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   1   23006; % single stimulus at location 3; no change
                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   9   23007; % single stimulus at location 4; orientation change at location 4
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   1   23008; % single stimulus at location 4; no change
                 ];
end

% Peripheral stimulus dimming + orientation change with mostly change trials.
function table = tableDef_stimDimPlusOrientChange_7030
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   7   23001; % single stimulus at location 1; orientation change at location 1
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   3   23002; % single stimulus at location 1; no change
                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   7   23003; % single stimulus at location 2; orientation change at location 2
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   3   23004; % single stimulus at location 2; no change
                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   7   23005; % single stimulus at location 3; orientation change at location 3
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   3   23006; % single stimulus at location 3; no change
                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   7   23007; % single stimulus at location 4; orientation change at location 4
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   3   23008; % single stimulus at location 4; no change
                 ];
end

% Peripheral stimulus dimming + orientation change with mostly change trials.
function table = tableDef_stimDimPlusOrientChange_6040
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   6   23001; % single stimulus at location 1; orientation change at location 1
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   4   23002; % single stimulus at location 1; no change
                   2   1   0   1   0   0   2   0   1   0   0   0   1   0   2   6   23003; % single stimulus at location 2; orientation change at location 2
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   4   23004; % single stimulus at location 2; no change
                   3   1   0   0   1   0   3   0   1   0   0   0   1   0   3   6   23005; % single stimulus at location 3; orientation change at location 3
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   4   23006; % single stimulus at location 3; no change
                   4   1   0   0   0   1   4   0   1   0   0   0   1   0   4   6   23007; % single stimulus at location 4; orientation change at location 4
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   4   23008; % single stimulus at location 4; no change
                 ];
end

% Peripheral stimulus dimming in one of multiple possible stimuli:
function table = tableDef_fixAndStimDim_test
table =           [1   4   1   1   1   1   1   0   0   0   0   1   1   0   1   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   2   0   0   0   0   1   1   0   1   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   3   0   0   0   0   1   1   0   1   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   4   0   0   0   0   1   1   0   1   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   1   0   0   0   0   1   1   0   2   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   2   0   0   0   0   1   1   0   2   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   3   0   0   0   0   1   1   0   2   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   4   0   0   0   0   1   1   0   2   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   1   0   0   0   0   1   1   0   3   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   2   0   0   0   0   1   1   0   3   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   3   0   0   0   0   1   1   0   3   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   4   0   0   0   0   1   1   0   3   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   1   0   0   0   0   1   1   0   4   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   2   0   0   0   0   1   1   0   4   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   3   0   0   0   0   1   1   0   4   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   4   0   0   0   0   1   1   0   4   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   4   1   1   1   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Peripheral stimulus dimming + hue change with mostly change trials.
function table = tableDef_stimDimPlusHueChange_9010
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

% Peripheral stimulus dimming + hue change with mostly change trials.
function table = tableDef_stimDimPlusHueChange_7030
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

% Peripheral stimulus dimming + hue change with mostly change trials.
function table = tableDef_stimDimPlusHueChange_6040
table =           [1   1   1   0   0   0   1   0   0   0   0   1   1   0   1   6   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   4   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   0   0   0   1   1   0   2   6   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   4   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   0   0   0   1   1   0   3   6   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   4   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   0   0   0   1   1   0   4   6   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   4   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Peripheral stimulus dimming + orientation change with mostly change trials.
function table = tableDef_stimDimPlusOrientChange_6040_SINGLELOCATION
table =           [1   1   1   0   0   0   1   0   1   0   0   0   1   0   1   6   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   4   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Fixation + peripheral stimulus dimming
function table = tableDef_fixAndStimDim_6040
table =           [1   1   1   0   0   0   1   0   0   0   0   0   1   0   1   6   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   4   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   0   0   0   0   1   0   2   6   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   4   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   0   0   0   0   1   0   3   6   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   4   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   0   0   0   0   1   0   4   6   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   4   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Fixation + peripheral stimulus dimming
function table = tableDef_fixAndStimDim_7030
table =           [1   1   1   0   0   0   1   0   0   0   0   0   1   0   1   7   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   3   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   0   0   0   0   1   0   2   7   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   3   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   0   0   0   0   1   0   3   7   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   3   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   0   0   0   0   1   0   4   7   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   3   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Fixation + peripheral stimulus dimming with mostly change trials.
function table = tableDef_fixAndStimDim_9010
table =           [1   1   1   0   0   0   1   0   0   0   0   0   1   0   1   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   1   1   1   0   0   0   0   0   0   0   0   0   0   0   1   1   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   0   0   0   0   1   0   2   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   0   0   0   0   0   0   0   0   2   1   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   0   0   0   0   1   0   3   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   0   0   0   0   0   0   0   0   3   1   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   0   0   0   0   1   0   4   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   0   0   0   0   0   0   0   0   4   1   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
                 ];
end

% Fixation + peripheral stimulus dimming with mostly change trials.
function table = tableDef_fixAndStimDim_1000
table =           [1   1   1   0   0   0   1   0   0   0   0   0   1   0   1   9   23001; % cue loc 1, single stimulus, luminance decrease on side 1, side 1 starts purple
                   2   1   0   1   0   0   2   0   0   0   0   0   1   0   2   9   23001; % cue loc 2, single stimulus, luminance decrease on side 1, side 1 starts purple
                   3   1   0   0   1   0   3   0   0   0   0   0   1   0   3   9   23001; % cue loc 3, single stimulus, luminance decrease on side 1, side 1 starts purple
                   4   1   0   0   0   1   4   0   0   0   0   0   1   0   4   9   23001; % cue loc 4, single stimulus, luminance decrease on side 1, side 1 starts purple
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