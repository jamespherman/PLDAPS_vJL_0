function p = enforceCorrectionRewardDelivery(p)
%ENFORCECORRECTIONREWARDDELIVERY Validate and record reward before delivery.
%
% On an active correction trial, a completed RIGHT choice must receive the
% cumulative reward calculated by applyCorrectionRightRewardReduction. This
% guard detects identity/side mismatches, repairs a stale duration if one is
% encountered, and stores enough information to audit the delivered value.

currentRewardMs = getNumeric(p.trVars, 'currentRewardDuration', NaN);
if ~isfinite(currentRewardMs)
    error('SRS:InvalidRewardDuration', ...
        'The selected reward duration is missing or non-finite.');
end
currentRewardMs = max(0, round(currentRewardMs));

p.trData.expectedCorrectionRightRewardMs = NaN;
p.trData.correctionRewardConsistencyPassed = -1;

active = getLogical(p.trVars, 'correctionTrialActive', false);
reduceRight = getLogical( ...
    p.trVars, 'correctionReduceRightReward', false);
chosenSide = getNumeric(p.trData, 'chosenSide', NaN);
chosenTargetID = getNumeric(p.trData, 'chosenTargetID', NaN);

if active && reduceRight && chosenSide == 1
    if chosenTargetID == 1
        targetSide = getNumeric(p.trVars, 'T1Side', NaN);
        targetRewardMs = getNumeric(p.trVars, 'rewardDurationT1', NaN);
    elseif chosenTargetID == 2
        targetSide = getNumeric(p.trVars, 'T2Side', NaN);
        targetRewardMs = getNumeric(p.trVars, 'rewardDurationT2', NaN);
    else
        error('SRS:CorrectionRewardInvalidTarget', ...
            'A RIGHT correction choice has no valid chosenTargetID.');
    end

    if targetSide ~= 1
        error('SRS:CorrectionRewardSideMismatch', ...
            ['chosenSide is RIGHT, but chosenTargetID T%d is mapped to ', ...
             'side %g. Reward was not delivered.'], chosenTargetID, targetSide);
    end

    expectedRewardMs = getNumeric( ...
        p.trVars, 'correctionRightRewardAppliedMs', NaN);
    if ~isfinite(expectedRewardMs)
        error('SRS:MissingCorrectionReward', ...
            'No computed RIGHT reward exists for this correction trial.');
    end
    expectedRewardMs = max(0, round(expectedRewardMs));
    rightRewardMs = getNumeric(p.trVars, 'rewardDurationRight', NaN);

    consistent = currentRewardMs == expectedRewardMs && ...
        round(targetRewardMs) == expectedRewardMs && ...
        round(rightRewardMs) == expectedRewardMs;
    p.trData.expectedCorrectionRightRewardMs = expectedRewardMs;
    p.trData.correctionRewardConsistencyPassed = double(consistent);

    if ~consistent
        warning('SRS:CorrectionRewardRepaired', ...
            ['Correction RIGHT reward mismatch repaired before delivery: ', ...
             'selected=%g, target=%g, right=%g, expected=%g ms.'], ...
            currentRewardMs, targetRewardMs, rightRewardMs, expectedRewardMs);
        currentRewardMs = expectedRewardMs;
        p.trVars.rewardDurationRight = expectedRewardMs;
        if chosenTargetID == 1
            p.trVars.rewardDurationT1 = expectedRewardMs;
        else
            p.trVars.rewardDurationT2 = expectedRewardMs;
        end
    end

    fprintf(['Correction RIGHT reward: level=%d, original=%g ms, ', ...
        'delivered=%g ms, minimum=%g ms.\n'], ...
        round(getNumeric(p.trVars, ...
            'correctionRightRewardReductionLevel', 1)), ...
        getNumeric(p.trVars, 'correctionOriginalRightRewardMs', NaN), ...
        currentRewardMs, ...
        getNumeric(p.trVars, 'correctionRightRewardMinimumMs', NaN));
end

p.trVars.currentRewardDuration = currentRewardMs;
p.trData.deliveredRewardDurationMs = currentRewardMs;

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
