function p = applyCorrectionRightRewardReduction(p)
%APPLYCORRECTIONRIGHTREWARDREDUCTION Optionally reduce repeated RIGHT reward.
%
% The exact original condition is restored first. This function then
% applies a cumulative multiplier to the reward delivered for the target
% currently located on the right. The saved snapshot is never altered.

p.trVars.correctionOriginalRightRewardMs = 0;
p.trVars.correctionRightRewardAppliedMs = 0;

active = getLogical(p.trVars, 'correctionTrialActive', false);
reduce = getLogical(p.trVars, 'correctionReduceRightReward', false);
triggerSide = getNumeric(p.status, 'correctionTrialTriggerSide', NaN);

% This is an explicitly anti-right-bias manipulation. When a bilateral
% correction was triggered by an incorrect LEFT choice, the HIGH-reward
% target is on the right and its reward must not be reduced.
if ~active || ~reduce || triggerSide ~= 1
    return
end

originalRight = getNumeric(p.trVars, 'rewardDurationRight', NaN);
if ~isfinite(originalRight)
    return
end
originalRight = max(0, round(originalRight));

multiplier = min(max(getNumeric( ...
    p.trVars, 'correctionRightRewardMultiplier', 0.50), 0), 1);
minimumMs = max(0, round(getNumeric( ...
    p.trVars, 'correctionRightRewardMinimumMs', 1)));
reductionLevel = max(1, round(getNumeric( ...
    p.trVars, 'correctionRightRewardReductionLevel', 1)));
reducedRight = computeCorrectionRightReward( ...
    originalRight, multiplier, reductionLevel, minimumMs);

p.trVars.correctionOriginalRightRewardMs = originalRight;
p.trVars.correctionRightRewardAppliedMs = reducedRight;
p.trVars.correctionRightRewardReductionLevel = reductionLevel;
p.trVars.rewardDurationRight = reducedRight;

T1Side = getNumeric(p.trVars, 'T1Side', NaN);
T2Side = getNumeric(p.trVars, 'T2Side', NaN);
if T1Side == 1
    p.trVars.rewardDurationT1 = reducedRight;
elseif T2Side == 1
    p.trVars.rewardDurationT2 = reducedRight;
end

% RIGHT-triggered correction implies that the high-reward target is on the
% left, so the right reward is the poor reward. Keep status/strobes aligned
% with the value that will actually be delivered.
highRewardSide = getNumeric(p.status, 'highRewardSide', NaN);
if highRewardSide == 1
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
