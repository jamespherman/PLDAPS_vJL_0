function p = getQuestSuggestedDelta(p)
%
% p = getQuestSuggestedDelta(p)
%

% if we haven't yet created a "questObj" structure, do it now
if ~isfield(p.init, 'questObj')

    % initial threshold guess (mean of the prior)
    initThresholdGuess = p.trVarsInit.initQuestThreshGuess;

    % SD of initial threshold guess (SD of the prior)
    initThresholdGuessSD = p.trVarsInit.initQuestSD;

    % what %-correct do we want to estimate threshold at?
    thresholdPctCorr = 0.75;

    % initial "slope" guess
    betaInit    = p.trVarsInit.initQuestBetaGuess;

    % initial "lapse rate" guess
    deltaInit   = 0.05;

    % initial "guess rate" guess
    gammaInit   = 0.25;

    % create QUEST object
    p.init.questObj = QuestCreate(initThresholdGuess, ...
        initThresholdGuessSD, thresholdPctCorr, ...
        betaInit, deltaInit, gammaInit, 0.1, p.trVars.maxSignalStrength);

    % set the questObj to normalize the PDF
    p.init.questObj.normalizePdf   = 1;

    % add a field to the quest struct that tracks how long it's been since
    % we did a beta analysis
    p.init.questObj.trialsSinceBetaAnalysis = 0;
end

% after we use quest to estimate a threshold value, we want to present that
% fixed value for multiple trials consecutively. We use the variable named
% "p.status.fixSignalStrength" to decide whether we want quest to
% suggest a new stimulus strength or just to give us the threshold value:
if p.status.fixSignalStrength

    % check to see if we've stored a fixed signal strength. If we have, use
    % that, if not, define it and use it.
    if ~isfield(p.init.questObj, 'fixedSignalStrength')
        p.init.questObj.fixedSignalStrength = ...
            p.init.questObj.threshEst(end);
    end
    testValRec = p.init.questObj.fixedSignalStrength;
else

    % get a recommended test-value, keeping it in our desired min / max range:
    testValRec = min([max([p.trVars.minSignalStrength, ...
        QuestQuantile(p.init.questObj)]), p.trVars.maxSignalStrength]);

    % on some percentage of trials, it's useful to set the delta to a
    % suprathreshold value so we can estimate the lapse rate. On another
    % portion of trials it's useful to set the delta to zero to estimate the
    % guess rate.
    randVal = rand;
    if randVal < 0.1
        testValRec = p.trVars.supraSignalStrength;
    elseif randVal < 0.3
        testValRec = 0;
    end
end

% assign the recommended (or occasional suprathreshold) delta.
p.trVars.signalStrength = testValRec;

end