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

    case 'human_psychophysics_hue_discrimination'

        table = tableDef_humanPsychophysicsHueDiscrimination;

    case 'human_psychophysics_orientation_discrimination'

        table = tableDef_humanPsychophysicsOrientationDiscrimination;

    case 'human_psychophysics_speed_discrimination'

        table = tableDef_humanPsychophysicsSpeedDiscrimination;

        % if this is "speed 2" we're doing speed decrements rather than
        % increments.
        if strcmp(p.init.settingsFile(end), '2')
        table(:, strcmp(p.init.trialArrayColumnNames, 'speed')) = ...
            table(:, strcmp(p.init.trialArrayColumnNames, 'speed')) * -1;
        end

    case 'human_psychophysics_rfFreq_discrimination'

        table = tableDef_humanPsychophysicsRfGratDiscrimination;

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
dupExpts = {'nfl', 'saturation increase no single', 'nfl_50', ...
    'nfl_shortBlocks', 'human_psychophysics_hue_discrimination'};
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

% Four stimulus patches, one might have a different hue than the others (on
% average). Human psychophysics:
function table = tableDef_humanPsychophysicsHueDiscrimination
table =            [1   4   1   1   1   1   1   0   0   0   0   1   0   0   1   10   23901;
                    2   4   1   1   1   1   2   0   0   0   0   1   0   0   2   10   23902;
                    3   4   1   1   1   1   3   0   0   0   0   1   0   0   3   10   23903;
                    4   4   1   1   1   1   4   0   0   0   0   1   0   0   4   10   23904;];
end

% Four stimulus patches, one might have a different hue than the others (on
% average). Human psychophysics:
function table = tableDef_humanPsychophysicsOrientationDiscrimination
table =            [1   4   1   1   1   1   1   0   1   0   0   0   0   0   1   10   23901;
                    2   4   1   1   1   1   2   0   1   0   0   0   0   0   2   10   23902;
                    3   4   1   1   1   1   3   0   1   0   0   0   0   0   3   10   23903;
                    4   4   1   1   1   1   4   0   1   0   0   0   0   0   4   10   23904;];
end

% Four stimulus patches, one might have a different hue than the others (on
% average). Human psychophysics:
function table = tableDef_humanPsychophysicsSpeedDiscrimination
table =            [1   4   1   1   1   1   1   1   0   0   0   0   0   0   1   10   23901;
                    2   4   1   1   1   1   2   1   0   0   0   0   0   0   2   10   23902;
                    3   4   1   1   1   1   3   1   0   0   0   0   0   0   3   10   23903;
                    4   4   1   1   1   1   4   1   0   0   0   0   0   0   4   10   23904;];
end

% Four stimulus patches, one might have a different hue than the others (on
% average). Human psychophysics:
function table = tableDef_humanPsychophysicsRfGratDiscrimination
table =            [1   4   1   1   1   1   1   0   0   1   0   0   0   0   1   10   23901;
                    2   4   1   1   1   1   2   0   0   1   0   0   0   0   2   10   23902;
                    3   4   1   1   1   1   3   0   0   1   0   0   0   0   3   10   23903;
                    4   4   1   1   1   1   4   0   0   1   0   0   0   0   4   10   23904;];
end