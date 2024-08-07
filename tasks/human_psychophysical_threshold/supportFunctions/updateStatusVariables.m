function p = updateStatusVariables(p)
%
% p = updateStatusVariables(p)
%

% iterate "good trial" count
p.status.iGoodTrial = p.status.iGoodTrial + ...
    double(~p.trData.trialRepeatFlag);


% if we're using QUEST, update the estimated threshold and confidence
% interval:
if p.trVars.useQuest
    p.status.questThreshEst     = QuestQuantile(p.init.questObj, 0.5);
    p.status.questThreshCiLow   = QuestQuantile(p.init.questObj, 0.025);
    p.status.questThreshCiHigh  = QuestQuantile(p.init.questObj, 0.975);
end

end