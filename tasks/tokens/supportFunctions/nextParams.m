function p = nextParams(p)
%
% p = nextParams(p)
%
% Defines all non-visual parameters for the upcoming 'tokens' trial. This
% function selects a trial from the pool and sets up variables like reward
% amount and ITI.

    % Choose a row from the trials array for the upcoming trial
    p = chooseRow(p);

    % Set up trial-specific parameters based on the chosen row
    p = trialTypeInfo(p);

end

%% Sub-functions

function p = chooseRow(p)
% Selects the next trial by sampling without replacement from the
% p.init.trialsArray.
%
% Note: Block transitions are handled by updateTrialsList.m, which calls
% generateTrialsArray() to regenerate the trialsArray from trialsTable.

% if we're not repeating the previous trial.
if ~p.status.repeatLast
    % Get a list of all currently available trials
    available_trials = find(p.status.trialsArrayRowsPossible);

    % Shuffle the list of available trials and pick the first one
    shuffled_list = shuff(available_trials);
    p.trVars.currentTrialsArrayRow = shuffled_list(1);
else
    p.trVars.currentTrialsArrayRow = p.status.lastTrialRow;
end

end


function p = trialTypeInfo(p)
% Extracts trial parameters from the selected row in the trials array and
% calculates trial-specific values like ITI.
%
% Note: rewardAmt is now pre-specified in trialsArray (see initTrialStructure.m)
% rather than being generated at runtime. This guarantees that both Normal
% and Uniform distributions span the same range [1-9] with the same mean (5).

    % Get the row number for the current trial
    row = p.trVars.currentTrialsArrayRow;

    % Get column indices by name for clarity and robustness
    colNames = p.init.trialArrayColumnNames;
    distCol      = strcmp(colNames, 'dist');
    cueFileCol   = strcmp(colNames, 'cueFile');
    fixReqCol    = strcmp(colNames, 'isFixationRequired');
    isTokenCol   = strcmp(colNames, 'isToken');
    rewardAmtCol = strcmp(colNames, 'rewardAmt');

    % Extract the parameters for this trial from the cell array
    p.trVars.dist                = p.init.trialsArray{row, distCol};
    p.trVars.cueFile             = p.init.trialsArray{row, cueFileCol};
    p.trVars.isFixationRequired  = p.init.trialsArray{row, fixReqCol};
    p.trVars.isToken             = p.init.trialsArray{row, isTokenCol};
    p.trVars.rewardAmt           = p.init.trialsArray{row, rewardAmtCol};

    % If the experiment type is 'tokens_AV', handle the AV trial logic
    if strcmp(p.init.exptType, 'tokens_AV')

        % Get the column index for 'avProbability'
        avProbCol = strcmp(colNames, 'avProbability');

        % Extract the 'avProbability' for the current trial
        avProbability = p.init.trialsArray{row, avProbCol};

        % Initialize the trial variable
        p.trVars.isAVTrial = false;

        % Determine if this is an AV trial based on the probability
        if avProbability == 1
            p.trVars.isAVTrial = true;
        elseif avProbability == 0.5 && rand < 0.5
            p.trVars.isAVTrial = true;
        end
    end
    
    % --- Set timing info for the current trial ---
    % Calculate the ITI that will occur BEFORE this trial starts
    % This logic is from your colleague's script
    e = makedist('Exponential', 'mu', p.trVars.itiMean);
    t = truncate(e, p.trVars.itiMin, p.trVars.itiMax);
    
    % The ITI is set in seconds
    p.trVars.iti = random(t,1);

    % --- Create token position matrix ---
    % Dynamically create the p.stim.token.pos matrix for each trial. This
    % logic loops from 1 to 10, calculating the [X, Y] coordinate for each
    % token. The Y-coordinate is constant, read from p.trVars.tokenBaseY,
    % while the X-coordinate is p.trVars.tokenBaseX plus an offset
    % calculated using the loop index and p.trVars.tokenSpacing.
    p.stim.token.pos = zeros(10, 2);
    for i = 1:10
        p.stim.token.pos(i, 1) = p.trVars.tokenBaseX + (i - 1) * p.trVars.tokenSpacing;
        p.stim.token.pos(i, 2) = p.trVars.tokenBaseY;
    end
end


function y = shuff(x)
% Shuffles the elements of vector x
    y = x(randperm(length(x)));
end