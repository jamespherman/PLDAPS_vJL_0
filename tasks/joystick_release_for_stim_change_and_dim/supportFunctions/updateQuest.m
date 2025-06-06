function p = updateQuest(p)
%
% p = updateQuest(p)
%
% Correctly updates QUEST for the orientation task using linear degrees.

% Determine if we should update, allowing an exception for False Alarms
shouldUpdate = ~p.trData.trialRepeatFlag || ...
    (p.trData.trialEndState == p.state.fa);


% Make sure we should be running this function
if isfield(p.trVars, 'useQuest') && p.trVars.useQuest && ...
        shouldUpdate && isfield(p.init, 'questObj')
    
    % Get the stimulus intensity that was actually shown on screen.
    presentedValue = p.status.changeDelta;

    % This variable will be 1 for "signal seen" reports (joystick releases)
    % and 0 for "signal not seen" reports (joystick holds).
    signalWasReported = 0; % Default to "not seen"

    switch p.trData.trialEndState
        case p.state.hit
            signalWasReported = 1; % Correctly reported "seen"
        case p.state.fa
            signalWasReported = 1; % Incorrectly reported "seen"
        case p.state.miss
            signalWasReported = 0; % Incorrectly reported "not seen"
        case p.state.cr
            signalWasReported = 0; % Correctly reported "not seen"
    end

    % Update QUEST with the value that was presented and the subject's report.
    p.init.questObj = QuestUpdate(p.init.questObj, ...
        abs(presentedValue), signalWasReported);
    
    % Store the latest estimate for on-screen display
    p.init.questObj.currentEstimate = QuestMean(p.init.questObj);
    
    % Optional: Display latest estimate on the command line
    fprintf('QUEST Threshold Estimate: %.2f\n', ...
        p.init.questObj.currentEstimate);

    
    % --- Periodic Re-analysis Logic (This part needs the fix) ---
    p.init.questObj.trialsSinceBetaAnalysis = ...
        p.init.questObj.trialsSinceBetaAnalysis + 1;
    
    if p.init.questObj.trialsSinceBetaAnalysis >= 10

        p.init.questObj.beta = QuestBetaAnalysis(p.init.questObj);

        
        % Get the history of intensities and responses from QUEST
        allIntensities = p.init.questObj.intensity(...
            1:p.init.questObj.trialCount);
        allResponses = p.init.questObj.response(...
            1:p.init.questObj.trialCount);
        
        % --- THE FIX ---
        % Use the logged intensities directly (they are already in degrees).
        % DO NOT apply a .^10 transform.
        loggedIntensities = round(allIntensities);
        loggedResponses = round(allResponses);
        
        % Recompute gamma (guess rate) from no-change trials
        noChangeTrials = loggedIntensities == 0;
        if any(noChangeTrials)
            p.init.questObj.gamma = nnz(loggedResponses(...
                noChangeTrials)) / nnz(noChangeTrials);
        end
        
        % Recompute delta (lapse rate) from max-intensity trials
        % NOTE: Fixed a typo here. It now correctly assigns to .delta
        maxValTrials = loggedIntensities == round(p.init.quest.maxVal);
        if any(maxValTrials)
             p.init.questObj.delta = 1 - (nnz(loggedResponses(...
                 maxValTrials)) / nnz(maxValTrials));
        end
        
        % Reset count
        p.init.questObj.trialsSinceBetaAnalysis = 0;
        fprintf('QUEST re-analyzed beta/gamma/delta.\n');
    end
end
end