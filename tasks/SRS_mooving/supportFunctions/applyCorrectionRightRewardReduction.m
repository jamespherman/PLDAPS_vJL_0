function p = applyCorrectionRightRewardReduction(p)
%APPLYCORRECTIONRIGHTREWARDREDUCTION Reduce the trigger target's reward.
%
% In SRS_mooving, "right" refers to the ACTUAL randomized screen position.
% The correction trigger stores the identity that was incorrectly chosen on
% the physical right. On forced repeats, this function reduces that target's
% reward while preserving the base task's internal slot variables used for
% reward delivery.

p.trVars.correctionOriginalRightRewardMs = 0;
p.trVars.correctionRightRewardAppliedMs = 0;

active = getLogical(p.trVars, 'correctionTrialActive', false);
reduce = getLogical(p.trVars, 'correctionReduceRightReward', false);
if ~active || ~reduce
    return
end

% This option is specifically a RIGHT-reward manipulation. If bilateral
% correction is enabled and the active correction was triggered by a LEFT
% error, do not alter either reward.
triggerSide = getNumeric(p.status, 'correctionTrialTriggerSide', 0);
if triggerSide ~= 1
    return
end

triggerTargetID = getNumeric(p.status, 'correctionTrialTriggerTargetID', 0);
if ~any(triggerTargetID == [1 2])
    warning('SRS_mooving:MissingCorrectionTriggerTarget', ...
        ['Cannot reduce physical-right reward because the correction ', ...
         'trigger target identity is unavailable.']);
    return
end

if triggerTargetID == 1
    originalRight = getNumeric(p.trVars, 'rewardDurationT1', NaN);
else
    originalRight = getNumeric(p.trVars, 'rewardDurationT2', NaN);
end
if ~isfinite(originalRight)
    return
end

multiplier = min(max(getNumeric( ...
    p.trVars, 'correctionRightRewardMultiplier', 0.50), 0), 1);
minimumMs = max(0, round(getNumeric( ...
    p.trVars, 'correctionRightRewardMinimumMs', 1)));
reducedRight = max(minimumMs, round(originalRight * multiplier));

p.trVars.correctionOriginalRightRewardMs = originalRight;
p.trVars.correctionRightRewardAppliedMs = reducedRight;

% Update identity-linked reward.
if triggerTargetID == 1
    p.trVars.rewardDurationT1 = reducedRight;
else
    p.trVars.rewardDurationT2 = reducedRight;
end

% Update the base task's internal slot-linked reward fields so
% srsSmooth_run delivers the same reduced identity reward.
T1Side = getNumeric(p.trVars, 'T1Side', NaN);
T2Side = getNumeric(p.trVars, 'T2Side', NaN);
if triggerTargetID == 1
    triggerSlot = T1Side;
else
    triggerSlot = T2Side;
end
if triggerSlot == 1
    p.trVars.rewardDurationRight = reducedRight;
elseif triggerSlot == 2
    p.trVars.rewardDurationLeft = reducedRight;
end

% Keep reward status/strobes synchronized with what will be delivered.
highRewardTargetID = getNumeric(p.status, 'highRewardTargetID', NaN);
if triggerTargetID == highRewardTargetID
    p.status.ActualRichReward = reducedRight;
else
    p.status.ActualPoorReward = reducedRight;
end

end

function value = getNumeric(s, name, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, name)
    candidate = s.(name);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end

function value = getLogical(s, name, defaultValue)
value = logical(getNumeric(s, name, double(defaultValue)));
end
