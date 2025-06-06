function p = getQuestSuggestedDelta(p)
% 
% p = getQuestSuggestedDelta(p)
%
% Gets a QUEST-suggested orientation change in degrees.
%

if ~isfield(p.init, 'questObj')
    % Use the initial values from the settings file, NOT hard-coded ones.
    p.init.questObj = QuestCreate(p.init.quest.tGuess, ...
        p.init.quest.tGuessSd, p.init.quest.pThreshold, ...
        p.init.quest.beta, p.init.quest.delta, p.init.quest.gamma, ...
        p.init.quest.grain, p.init.quest.range);

    p.init.questObj.normalizePdf = 1;
    p.init.questObj.trialsSinceBetaAnalysis = 0;
    disp('Orientation QUEST object created and initialized.');
end

if p.trVars.isStimChangeTrial % Formerly isCueChangeTrial
    % Get a recommended test-value from QUEST in linear degrees.
    testValRec = QuestQuantile(p.init.questObj);

    % On ~10% of trials, use a suprathreshold value to estimate lapse rate.
    % This value should be defined in the settings file, e.g., p.trVars.orientDeltaLapse
    if rand < 0.1
        testValRec = p.init.quest.maxVal; % e.g., 45 degrees
    end

    % Store the recommended value in a new orientation-specific variable.
    % We will use this value later in trialTypeInfo.m.
    p.trVars.oriChangeQuestValue = testValRec;
else
    % On no-change trials, this variable can be set to NaN or 0.
    p.trVars.oriChangeQuestValue = 0;
end
end