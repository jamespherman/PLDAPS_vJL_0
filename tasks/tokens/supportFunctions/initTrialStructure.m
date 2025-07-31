function p = initTrialStructure(p)
%
% p = initTrialStructure(p)
% 
% Defines the trial structure for the 'tokens' Pavlovian task.
% Uses a switch statement on p.init.exptType to select a table of
% trial conditions, which is then used to generate the block.

    % (1) Define the column names for the trial conditions table.
    % This is useful for accessing columns by name instead of index.
    p.init.trialArrayColumnNames = {'dist', 'cueFile', 'isFixationRequired', 'isToken', 'nReps'};

    % (2) Use a switch statement to select the trial table based on experiment type.
    % This allows for different versions of the experiment to be run from the same task.
    % For now, we will define one main version.
    switch p.init.exptType
        case 'tokens_main'
            table = tableDef_TokensMain(p);
            
        % You could add other cases here for different versions of the task
        % case 'tokens_familiar_only'
        %     table = tableDef_TokensFamiliarOnly(p);
            
        otherwise
            % Default to the main experiment type if not specified
            warning('p.init.exptType not specified, using ''tokens_main''.');
            table = tableDef_TokensMain(p);
    end
    
    % (3) Unpack the table into a list of trials based on the 'nReps' column.
    % This creates the full, unshuffled list of all trials in the block.
    
    % Find the column that specifies the number of repetitions
    repCol = contains(p.init.trialArrayColumnNames, 'nReps');
    
    % Initialize a cell array to hold the list of all trials
    trialList = {};
    
    % Loop through each row of the defined table
    for i = 1:size(table, 1)
        nReps = table{i, repCol};
        % Append the current trial type to the list nReps times
        for j = 1:nReps
            trialList(end+1, :) = table(i, 1:end-1); % Exclude the nReps column
        end
    end
    
    % (4) Randomize the trial list and create the final p.status.block struct array.
    % This is the final, shuffled sequence of trials that PLDAPS will run.
    nTotalTrials = size(trialList, 1);
    shuffledIndices = randperm(nTotalTrials);
    
    % Get column indices by name for clarity
    distCol     = contains(p.init.trialArrayColumnNames, 'dist');
    cueFileCol  = contains(p.init.trialArrayColumnNames, 'cueFile');
    fixReqCol   = contains(p.init.trialArrayColumnNames, 'isFixationRequired');
    isTokenCol  = contains(p.init.trialArrayColumnNames, 'isToken');
    
    for i = 1:nTotalTrials
        % Get the next trial's properties from the shuffled list
        idx = shuffledIndices(i);
        
        p.status.block(i).dist                = trialList{idx, distCol};
        p.status.block(i).cueFile             = trialList{idx, cueFileCol};
        p.status.block(i).isFixationRequired  = trialList{idx, fixReqCol};
        p.status.block(i).isToken             = trialList{idx, isTokenCol};
        
        p.status.block(i).trialNum = i;
    end
    
    p.status.numTrials = nTotalTrials;

    % (5) Store table for subsequent use:
    p.init.trialsTable = table;
end


% --- Sub-functions for defining trial tables ---

function table = tableDef_TokensMain(p)
% Defines the 8 core conditions for the main tokens experiment.
% The last column, nReps, is the number of trials of this type per block.

    % Get the number of repetitions from the settings file
    % This makes it easy to change without editing this function
    nReps = p.init.trialsPerCondition;

    % Columns: {dist, cueFile, isFixationRequired, isToken, nReps}
    table = { ...
        % Normal Distribution Cues (dist=1)
        1, 'famNorm_01.jpg', true, true, nReps; ...
        1, 'famNorm_02.jpg', true, true, nReps; ...
        1, 'novNorm.jpg',    true, true, nReps; ...
        % Uniform Distribution Cues (dist=2)
        2, 'famUni_01.jpg',  true, true, nReps; ...
        2, 'famUni_02.jpg',  true, true, nReps; ...
        2, 'novUni.jpg',     true, true, nReps; ...
        % Free Reward, Tokens (dist=0)
        0, 'blank.jpg',      false, true, nReps; ...
        % Free Reward, No Tokens (dist=0)
        0, 'blank.jpg',      false, false, nReps; ...
    };
end