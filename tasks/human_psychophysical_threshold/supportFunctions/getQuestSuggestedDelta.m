function p = getQuestSuggestedDelta(p)
%
% p = getQuestSuggestedDelta(p)
% 

% if we haven't yet created a "questObj" structure, do it now
if ~isfield(p.init, 'questObj')
    
    % initial threshold guess (mean of the prior)
    initThresholdGuess = 25^(1/10);
    
    % SD of initial threshold guess (SD of the prior)
    initThresholdGuessSD = 10^(1/10);
    
    % what %-correct do we want to estimate threshold at?
    thresholdPctCorr = 0.8;
    
    % initial "slope" guess
    betaInit    = 3.5;
    
    % initial "lapse rate" guess
    deltaInit   = 0.1;
    
    % initial "guess rate" guess
    gammaInit   = 0.05;
    
    % create QUEST object
    p.init.questObj = QuestCreate(initThresholdGuess, ...
        initThresholdGuessSD, thresholdPctCorr, ...
        betaInit, deltaInit, gammaInit);
    
    % set the questObj to normalize the PDF
    p.init.questObj.normalizePdf   = 1;

    % add a field to the quest struct that tracks how long it's been since
    % we did a beta analysis
    p.init.questObj.trialsSinceBetaAnalysis = 0;
end

% get a recommended test-value
testValRec = max([p.trVars.minSignalStrength, ...
    QuestQuantile(p.init.questObj)^10]);

% on some percentage of trials, it's useful to set the delta to a
% suprathreshold value so we can estimate the lapse rate. We assume the
% value in the GUI
if rand < 0.1
    p.trVars.signalStrength;
end

% assign the recommended (or occasional suprathreshold) delta.
p.trVars.signalStrength = testValRec;

end