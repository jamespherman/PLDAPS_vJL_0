function p = updateStatusVariables(p)
% p = updateStatusVariables(p)
%
% Update outcome counters and last-trial duration after the trial outcome
% has been resolved. Called from barsweep_finish.m on real-trial cycles
% only (the post-completion no-op cycle bypasses this).

switch p.trData.trialEndState
    case p.state.trialComplete
        p.status.iGoodTrial   = p.status.iGoodTrial + 1;
        p.status.rewardCount  = p.status.rewardCount + 1;
    case p.state.fixBreak
        p.status.fixBreakCount = p.status.fixBreakCount + 1;
    case p.state.nonStart
        p.status.nonStartCount = p.status.nonStartCount + 1;
end

p.status.iAbortedTrial = p.status.iTrial - p.status.iGoodTrial;

% Last trial duration (trialBegin -> trialRunDone). Both are trial-relative.
if p.trData.timing.trialBegin >= 0 && p.trData.timing.trialRunDone >= 0
    p.status.lastTrialDurS = ...
        p.trData.timing.trialRunDone - p.trData.timing.trialBegin;
end

end
