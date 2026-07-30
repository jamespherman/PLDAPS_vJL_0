function p = initTrialStructure(p)
%INITTRIALSTRUCTURE Define the SRS block schedule format.
%
% The schedule is rebuilt at the beginning of every reward block by
% buildSrsBlockSchedule.m. This function only defines the column layout and
% initializes empty holders.
%
% Side convention used throughout SRS_Task:
%   1 = right
%   2 = left
%
% Target identity is independent of side:
%   T1 = horizontal rectangle
%   T2 = vertical rectangle

%% Compact condition table
% One row describes one condition and its required number of repetitions.
p.init.trialsTableColumnNames = { ...
    'conditionID', ...       % unique condition identifier
    'nStim', ...             % 1 = single target, 2 = two targets
    'singleTargetID', ...    % 0 = dual, 1 = T1 only, 2 = T2 only
    'T1Side', ...            % 1 = right, 2 = left
    'T2Side', ...            % 1 = right, 2 = left
    'trialType', ...         % 0 = instruction, 1 = congruent, 2 = conflict
    'schedulePhase', ...     % 1 = first single group, 2 = second single group, 3 = choice
    'noOfTrials'};           % number of repetitions in the block

p.init.trialsTableCols = makeColumnStruct(p.init.trialsTableColumnNames);

%% Expanded trial array
% One row corresponds to one trial that must be completed successfully.
p.init.trialArrayColumnNames = { ...
    'conditionID', ...
    'nStim', ...
    'singleTargetID', ...
    'T1Side', ...
    'T2Side', ...
    'trialType', ...
    'schedulePhase', ...
    'trialSeed'};

p.init.trialCols = makeColumnStruct(p.init.trialArrayColumnNames);

p.init.trialsTable = zeros(0, numel(p.init.trialsTableColumnNames));
p.init.trialsArray = zeros(0, numel(p.init.trialArrayColumnNames));
p.init.blockLength = 0;

p.status.trialsArrayRowsPossible = false(0, 1);
p.status.blockScheduleComplete = true;

end

function cols = makeColumnStruct(columnNames)
%MAKECOLUMNSTRUCT Convert valid column names to a lookup struct.

cols = struct();
for iCol = 1:numel(columnNames)
    fieldName = matlab.lang.makeValidName(columnNames{iCol});
    cols.(fieldName) = iCol;
end

end
