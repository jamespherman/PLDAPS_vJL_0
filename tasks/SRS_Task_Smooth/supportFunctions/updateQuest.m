function p = updateQuest(p)

%
% p = updateQuest(p)
%

% first make sure "useQuest" is a field of p.trVars
if isfield(p.trVars, 'useQuest')
    
    % if we're using quest, the just-completed trial was cue change or no
    % change, and it was good (no joy or fix breaks) compute the posterior and
    % update our parameter estimates. ALSO, make sure the quest object exists
    % (we didn't JUST turn on quest during the trial).
    if p.trVars.useQuest && ~p.trData.trialRepeatFlag && ...
            (p.trVars.isCueChangeTrial || p.trVars.isNoChangeTrial) && ...
            isfield(p.init, 'questObj')
        
        % was the joystick released on the last trial? If the last trial was a
        % hit, set "resp" to true and use p.trVars.cueMotionDelta as the signal
        % strength. If a (non-foil) false alarm happened, regardless of trial
        % type, this means he released the joystick with the stimulus on
        % without any stimulus change: set the signal strength to 0 and "resp"
        % to true.
        switch p.trData.trialEndState
            case p.state.hit
                resp = true;
                updateSignalValue = abs(p.trVars.cueMotionDelta)^(1/10);
            case p.state.fa
                resp = true;
                updateSignalValue = 0;
            otherwise
                resp = false;
                updateSignalValue = abs(p.trVars.cueMotionDelta)^(1/10);
        end
        
        % update the PDF
        p.init.questObj = QuestUpdate(p.init.questObj, updateSignalValue, resp);
        
        % increment the count of trials since the last beta analysis
        p.init.questObj.trialsSinceBetaAnalysis = ...
            p.init.questObj.trialsSinceBetaAnalysis + 1;
        
        % if it's been 10 trials since the last beta analysis, do it again.
        % Also update gamma & delta
        if p.init.questObj.trialsSinceBetaAnalysis >= 10
            try
                p.init.questObj.beta = QuestBetaAnalysis(p.init.questObj);
            catch me
            end
            
            % list of ROUNDED logged stimulus intensities
            loggedIntensities = round(p.init.questObj.intensity(1:p.init.questObj.trialCount).^10);
            
            % list of ROUNDED logged responses
            loggedResponses = round(p.init.questObj.response(1:p.init.questObj.trialCount));
            
            % recompute gamma
            p.init.questObj.gamma = nnz(loggedResponses(loggedIntensities == 0))/nnz(loggedIntensities == 0);
            
            % recomute delta
            p.init.questObj.gamma = 1 - nnz(loggedResponses(loggedIntensities == p.trVars.cueDelta))/nnz(loggedIntensities == p.trVars.cueDelta);
            
            % reset count
            p.init.questObj.trialsSinceBetaAnalysis = 0;
        end
    end
end

end