function p = updateStatusVariables(p)
%
% p = updateStatusVariables(p)
%

% iterate "good trial" count
p.status.iGoodTrial = p.status.iGoodTrial + double(~p.trData.trialRepeatFlag);

end