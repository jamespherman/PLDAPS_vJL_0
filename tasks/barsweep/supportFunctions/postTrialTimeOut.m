function p = postTrialTimeOut(p)
% p = postTrialTimeOut(p)
%
% Apply post-trial waits per the canonical timeline:
%   - reward branch: postRewardDuration, then iti
%   - abort branch (fixBreak / nonStart): timeoutAfterFixBreak, then iti
%
% trialEnd has already been strobed in barsweep_finish.m before this is
% called; iti is imposed for every outcome.

if p.trData.trialEndState == p.state.trialComplete
    WaitSecs(p.trVars.postRewardDuration);
elseif p.trData.trialEndState == p.state.fixBreak || ...
        p.trData.trialEndState == p.state.nonStart
    WaitSecs(p.trVars.timeoutAfterFixBreak);
end

% Inter-trial interval — applied on every outcome.
WaitSecs(p.trVars.iti);

end
