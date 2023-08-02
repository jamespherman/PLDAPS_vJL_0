function p = getQuestSuggestedDelta(p)
%
% p = getQuestSuggestedDelta(p)
% 

% if we haven't yet created a "questObj" structure, do it now
if ~isfield(p.init, 'questObj')
    
    % initial threshold guess (mean of the prior)
    initThresholdGuess = 30;
    
    % SD of initial threshold guess (SD of the prior)
    initThresholdGuessSD = 10;
    
    % what %-correct do we want to estimate threshold at?
    thresholdPctCorr = 0.75;
    
    % initial "slope" guess
    betaInit    = 10;
    
    % initial "lapse rate" guess
    deltaInit   = 0.05;
    
    % initial "guess rate" guess
    gammaInit   = 0.05;
    
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

% assign the recommended (or occasional suprathreshold) delta.
p.trVars.signalStrength = testValRec;

end