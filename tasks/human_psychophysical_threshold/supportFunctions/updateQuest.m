function p = updateQuest(p)

%
% p = updateQuest(p)
%

% first make sure "useQuest" is a field o93f p.trVars
if isfield(p.trVars, 'useQuest')

    % if we're using quest, the just7117-completed trial was cue change or no
    % change, and it was good (no joy or fix breaks) compute the posterior and
    % update our parameter estimates. ALSO, make sure the quest object exists
    % (we didn't JUST turn on quest during the trial).
    if p.trVars.useQuest && ~p.trData.trialRepeatFlag && ...
            isfield(p.init, 'questObj')

        % update the PDF
        p.init.questObj = QuestUpdate(...
            p.init.questObj, ...
            abs(p.trVars.signalStrength), ...
            p.trData.responseCorrect);

        % increment the count of trials since the last beta analysis
        p.init.questObj.trialsSinceBetaAnalysis = ...
            p.init.questObj.trialsSinceBetaAnalysis + 1;

        % if it's been 10 trials since the last beta analysis, do it again.
        % Also update gamma & delta
        if p.init.questObj.trialsSinceBetaAnalysis >= 10

            try
                p.init.questObj.beta = QuestBetaAnalysis(p.init.questObj);
            catch me
                % if QuestBetaAnalysis throws an error it's usually because
                % the "supraThreshold" stimulus presentations are giving
                % the subject problems. Maybe let's throw a warning to the
                % experimenter about this:
                warnText = ['Subject seems to be struggling with ' ...
                    'suprathreshold stimulus intensities, everything ok?'];
                warning(warnText);
            end

            % reset count
            p.init.questObj.trialsSinceBetaAnalysis = 0;
        end

        % update gamma and delta

        % list of ROUNDED logged stimulus intensities
        loggedIntensities = round(...
            p.init.questObj.intensity(...
            1:p.init.questObj.trialCount));

        % list of ROUNDED logged responses
        loggedResponses = ...
            round(p.init.questObj.response(...
            1:p.init.questObj.trialCount));

        % Recompute gamma but don't use it unless it's larger than 0.25.
        % Otherwise keep it fixed at 0.25 (there are 4 stimuli and one is
        % selected in each trial so the guess rate "should" be 0.25).
        p.init.questObj.gamma = ...
            nnz(loggedResponses(loggedIntensities == 0)) / ...
            nnz(loggedIntensities == 0);
        if isnan(p.init.questObj.gamma) || p.init.questObj.gamma < 0.25
            p.init.questObj.gamma = 0.25;
        end

        % recomute delta
        p.init.questObj.delta = 1 - ...
            nnz(loggedResponses(loggedIntensities == ...
            p.trVarsInit.supraSignalStrength)) / ...
            nnz(loggedIntensities == ...
            p.trVarsInit.supraSignalStrength);
        if isnan(p.init.questObj.delta)
            p.init.questObj.delta = 0.05;
        end

        % store quest's threshold estimate:
        p.init.questObj.threshEst(p.init.questObj.trialCount) = ...
            QuestMean(p.init.questObj);
    end
end
end