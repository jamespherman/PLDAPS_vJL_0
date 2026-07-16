function p = nextParams(p)
%NEXTPARAMS Define parameters for the upcoming SRS trial.
%
% Reward is attached to target identity (T1/T2), not to screen side.
% The block schedule determines which identities are shown and where.

p = trialTypeInfo(p);
p = locationInfo(p);
p = setLocations(p);
p = timingInfo(p);

end

function p = trialTypeInfo(p)
%TRIALTYPEINFO Start a block when needed and select its next eligible row.

needsNewBlock = p.status.CurrentBlockNumber == 0 || ...
    p.status.blockScheduleComplete || ...
    isempty(p.status.trialsArrayRowsPossible) || ...
    ~any(p.status.trialsArrayRowsPossible);

if needsNewBlock
    p = startNewBlock(p);
end

p = chooseScheduledRow(p);
p = applyScheduledRow(p);
p = sampleTrialRewards(p);
p = assignTrialRewardsAndSalience(p);

end

function p = startNewBlock(p)
%STARTNEWBLOCK Alternate rich identity and construct a fresh block schedule.

if p.status.CurrentBlockNumber == 0
    p.status.CurrentBlockType = randi(2);
else
    p.status.CurrentBlockType = 3 - p.status.CurrentBlockType;
end

% Preserve the original 60-100 choice-trial range and require a multiple of 4
% so congruent/conflict and T1-left/T1-right can be exactly balanced.
nChoice = Inf;
while nChoice < 60 || nChoice > 100 || mod(nChoice, 4) ~= 0
    nChoice = 80 + round(5 * randn);
end

p.status.TotalChoiceTrialsPerBlock = nChoice;
p.status.CurrentBlockNumber = p.status.CurrentBlockNumber + 1;

if isfield(p.status, 'TotalBlocksTarget')
    p.status.RemainingBlock = max(0, ...
        p.status.TotalBlocksTarget - p.status.CurrentBlockNumber);
else
    p.status.RemainingBlock = max(0, p.status.RemainingBlock - 1);
end

p.status.highRewardTargetID = p.status.CurrentBlockType;
p = chooseBlockReward(p);
p = buildSrsBlockSchedule(p);

if p.status.TotalInstructionTrialsPerBlock > 0
    instructionOrderText = sprintf('T%d then T%d', ...
        p.status.FirstSingleTargetID, p.status.SecondSingleTargetID);
else
    instructionOrderText = 'none';
end
fprintf(['\nStarted block %d: T%d rich, %d instruction + %d choice trials ', ...
    '(instruction order: %s).\n'], ...
    p.status.CurrentBlockNumber, ...
    p.status.CurrentBlockType, ...
    p.status.TotalInstructionTrialsPerBlock, ...
    p.status.TotalChoiceTrialsPerBlock, ...
    instructionOrderText);

end

function p = chooseScheduledRow(p)
%CHOOSESCHEDULEDROW Randomly choose an eligible row with phase priority.

remaining = logical(p.status.trialsArrayRowsPossible(:));
if ~any(remaining)
    error('No eligible SRS schedule rows remain in the current block.');
end

cols = p.init.trialCols;
phase = p.init.trialsArray(:, cols.schedulePhase);

% Always exhaust the earliest remaining phase before moving on.
% Training blocks use:
%   phase 1 = first single-target identity group
%   phase 2 = second single-target identity group
%   phase 3 = two-target choice trials
% A failed trial remains eligible, so T1-only and T2-only groups cannot
% interleave and the choice phase cannot start early.
remainingPhases = phase(remaining);
if any(~isfinite(remainingPhases)) || any(remainingPhases < 1)
    error('SRS schedule contains an invalid schedulePhase value.');
end
currentPhase = min(remainingPhases);
eligible = remaining & phase == currentPhase;

possibleRows = find(eligible);
possibleRows = possibleRows(randperm(numel(possibleRows)));

p.trVars.currentTrialsArrayRow = possibleRows(1);
p.status.blockAttemptCount = p.status.blockAttemptCount + 1;

end

function p = applyScheduledRow(p)
%APPLYSCHEDULEDROW Copy schedule columns into current trial variables.

cols = p.init.trialCols;
row = p.init.trialsArray(p.trVars.currentTrialsArrayRow, :);

p.trVars.conditionID = row(cols.conditionID);
p.trVars.nStim = row(cols.nStim);
p.trVars.singleTargetID = row(cols.singleTargetID);
p.trVars.T1Side = row(cols.T1Side);
p.trVars.T2Side = row(cols.T2Side);
p.trVars.schedulePhase = row(cols.schedulePhase);
p.trVars.trialSeed = row(cols.trialSeed);

p.status.ActualTrialType = row(cols.trialType);
p.status.CurrentTrialType = p.status.ActualTrialType;
p.status.CurrentTrialPhase = p.trVars.schedulePhase;
p.status.CurrentNStim = p.trVars.nStim;
p.status.CurrentSingleTargetID = p.trVars.singleTargetID;

p.trVars.T1_present = p.trVars.nStim == 2 || p.trVars.singleTargetID == 1;
p.trVars.T2_present = p.trVars.nStim == 2 || p.trVars.singleTargetID == 2;
p.trVars.T1_visible = false;
p.trVars.T2_visible = false;

% Position is randomized/counterbalanced independently of target identity.
if isfield(p.trVars, 'targetHorizontalEccDeg')
    eccDeg = abs(p.trVars.targetHorizontalEccDeg);
else
    eccDeg = max(abs([p.trVars.T1_locDegX, p.trVars.T2_locDegX]));
end

p.trVars.T1_locDegX = sideToX(p.trVars.T1Side, eccDeg);
p.trVars.T2_locDegX = sideToX(p.trVars.T2Side, eccDeg);
p.trVars.T1_locDegY = 0;
p.trVars.T2_locDegY = 0;

end

function p = sampleTrialRewards(p)
%SAMPLETRIALREWARDS Add independent Gaussian noise around each block mean.
%
% Rich/Poor refer to the target's BLOCK MEAN. The two trial samples are
% independent, as in the original task description. Values are rounded for
% reward delivery and clamped to a positive duration.

sdMs = p.trVars.RewardSdGaussianNoiseMs;
richMean = p.status.BlockRichMeanDuration;
poorMean = p.status.BlockPoorMeanDuration;

richReward = max(1, round(richMean + sdMs * randn));
poorReward = max(1, round(poorMean + sdMs * randn));

p.status.ActualRichReward = richReward;
p.status.ActualPoorReward = poorReward;

end

function p = assignTrialRewardsAndSalience(p)
%ASSIGNTRIALREWARDSANDSALIENCE Map identity values to current screen sides.

% CurrentBlockType is the rich TARGET ID, not a spatial side.
p.status.highRewardTargetID = p.status.CurrentBlockType;

if p.status.highRewardTargetID == 1
    p.trVars.rewardDurationT1 = double(p.status.ActualRichReward);
    p.trVars.rewardDurationT2 = double(p.status.ActualPoorReward);
else
    p.trVars.rewardDurationT1 = double(p.status.ActualPoorReward);
    p.trVars.rewardDurationT2 = double(p.status.ActualRichReward);
end

% Translate identity-linked reward into left/right delivery durations.
if p.trVars.T1Side == 1
    p.trVars.rewardDurationRight = p.trVars.rewardDurationT1;
    p.trVars.rewardDurationLeft = p.trVars.rewardDurationT2;
else
    p.trVars.rewardDurationLeft = p.trVars.rewardDurationT1;
    p.trVars.rewardDurationRight = p.trVars.rewardDurationT2;
end

p.status.highRewardSide = sideOfTarget(p, p.status.highRewardTargetID);

if p.trVars.nStim == 1
    % The only visible target is made high-salience in instruction trials.
    % This keeps T1-only and T2-only trials equally easy to see while reward
    % remains determined solely by target identity.
    p.status.highSalienceTargetID = p.trVars.singleTargetID;
    p.status.highSalienceSide = sideOfTarget(p, p.trVars.singleTargetID);
else
    if p.status.ActualTrialType == 1
        % Congruent: salience and reward favor the same spatial target.
        p.status.highSalienceSide = p.status.highRewardSide;
    elseif p.status.ActualTrialType == 2
        % Conflict: salience and reward favor opposite spatial targets.
        p.status.highSalienceSide = 3 - p.status.highRewardSide;
    else
        error('Dual-target trial has invalid ActualTrialType.');
    end
    p.status.highSalienceTargetID = targetAtSide(p, p.status.highSalienceSide);
end

p = applySalience(p);

end

function p = applySalience(p)
%APPLYSALIENCE Apply luminance or hue contrast by TARGET ID.

if ~isfield(p.trVars, 'salienceType')
    p.trVars.salienceType = 2;
end

highTargetID = p.status.highSalienceTargetID;

switch p.trVars.salienceType
    case 2
        %% Luminance mode
        meanLum = p.trVars.luminanceMeanCdM2;
        minLum = p.trVars.luminanceMinCdM2;
        maxLum = p.trVars.luminanceMaxCdM2;

        % The scheduled design fixes which target is high salience on each
        % congruent/conflict trial. Sampling |T1-T2| directly avoids the
        % near-constant extreme differences produced when a log-uniform
        % draw is sorted into high/low values. It preserves the pair mean,
        % target bounds, and a centered signed difference across balanced
        % T1-high and T2-high trials.
        samplingMode = 'uniformDifference';
        if isfield(p.trVars, 'luminancePairSamplingMode')
            samplingMode = char(p.trVars.luminancePairSamplingMode);
        end

        switch lower(samplingMode)
            case 'uniformdifference'
                maxValidDifference = min([ ...
                    2 * (meanLum - minLum), ...
                    2 * (maxLum - meanLum), ...
                    maxLum - minLum]);

                minDifference = 0;
                if isfield(p.trVars, 'luminanceDifferenceMinCdM2') && ...
                        isfinite(p.trVars.luminanceDifferenceMinCdM2)
                    minDifference = max(0, ...
                        p.trVars.luminanceDifferenceMinCdM2);
                end

                maxDifference = maxValidDifference;
                if isfield(p.trVars, 'luminanceDifferenceMaxCdM2') && ...
                        isfinite(p.trVars.luminanceDifferenceMaxCdM2)
                    maxDifference = min(maxValidDifference, ...
                        p.trVars.luminanceDifferenceMaxCdM2);
                end

                if maxDifference < minDifference
                    error(['luminanceDifferenceMaxCdM2 must be greater ', ...
                        'than or equal to luminanceDifferenceMinCdM2.']);
                end

                differenceMagnitude = minDifference + ...
                    rand * (maxDifference - minDifference);
                highLum = meanLum + differenceMagnitude / 2;
                lowLum = meanLum - differenceMagnitude / 2;

            case 'dubeyloguniform'
                validPair = false;
                while ~validPair
                    lumA = exp(log(minLum) + ...
                        rand * (log(maxLum) - log(minLum)));
                    lumB = 2 * meanLum - lumA;
                    validPair = isfinite(lumA) && isfinite(lumB) && ...
                        lumA >= minLum && lumA <= maxLum && ...
                        lumB >= minLum && lumB <= maxLum;
                end
                highLum = max(lumA, lumB);
                lowLum = min(lumA, lumB);

            otherwise
                error(['Unknown luminancePairSamplingMode: ' samplingMode]);
        end

        if highTargetID == 1
            p.trVars.ActualLuminanceT1 = highLum;
            p.trVars.ActualLuminanceT2 = lowLum;
        elseif highTargetID == 2
            p.trVars.ActualLuminanceT1 = lowLum;
            p.trVars.ActualLuminanceT2 = highLum;
        else
            error('Invalid highSalienceTargetID for luminance mode.');
        end

        % These values are the nominal sampling coordinates inherited from
        % the Dubey/Pesaran design. They select a position on the measured
        % red CLUT ramp, but they are not themselves the physical cd/m^2
        % emitted by this display.
        p.trVars.NominalLuminanceT1 = p.trVars.ActualLuminanceT1;
        p.trVars.NominalLuminanceT2 = p.trVars.ActualLuminanceT2;
        p.trVars.LuminanceDifferenceT1MinusT2 = ...
            p.trVars.ActualLuminanceT1 - p.trVars.ActualLuminanceT2;
        p.trVars.NominalLuminanceDifferenceT1MinusT2 = ...
            p.trVars.LuminanceDifferenceT1MinusT2;
        p.trVars.LuminanceDifferenceMagnitude = ...
            abs(p.trVars.LuminanceDifferenceT1MinusT2);
        p.trVars.LuminancePairMean = mean([ ...
            p.trVars.ActualLuminanceT1, ...
            p.trVars.ActualLuminanceT2]);
        p.trVars.ActualLuminanceT1_x1000 = round(1000 * p.trVars.ActualLuminanceT1);
        p.trVars.ActualLuminanceT2_x1000 = round(1000 * p.trVars.ActualLuminanceT2);
        p.trVars.LuminanceDifferenceT1MinusT2_x1000 = ...
            round(1000 * p.trVars.LuminanceDifferenceT1MinusT2);

        % Map task-level luminance values onto the precomputed red DKL ramp.
        redLumStart = p.draw.clutIdx.redLumStart;
        redLumN = p.draw.clutIdx.redLumN;
        lumRange = maxLum - minLum;

        T1Norm = (p.trVars.ActualLuminanceT1 - minLum) / lumRange;
        T2Norm = (p.trVars.ActualLuminanceT2 - minLum) / lumRange;
        T1Norm = min(max(T1Norm, 0), 1);
        T2Norm = min(max(T2Norm, 0), 1);

        T1Level = round(1 + T1Norm * (redLumN - 1));
        T2Level = round(1 + T2Norm * (redLumN - 1));
        T1Level = min(max(T1Level, 1), redLumN);
        T2Level = min(max(T2Level, 1), redLumN);

        p.trVars.T1_colorIdx = redLumStart + T1Level - 1;
        p.trVars.T2_colorIdx = redLumStart + T2Level - 1;

        if isfield(p.draw, 'clut') && isfield(p.draw.clut, 'dklRedLumValues')
            p.trVars.ActualDklRedLuminanceT1 = p.draw.clut.dklRedLumValues(T1Level);
            p.trVars.ActualDklRedLuminanceT2 = p.draw.clut.dklRedLumValues(T2Level);
            p.trVars.DklRedLuminanceDifferenceT1MinusT2 = ...
                p.trVars.ActualDklRedLuminanceT1 - p.trVars.ActualDklRedLuminanceT2;
            p.trVars.ActualDklRedLuminanceT1_x1000 = ...
                round(1000 * p.trVars.ActualDklRedLuminanceT1);
            p.trVars.ActualDklRedLuminanceT2_x1000 = ...
                round(1000 * p.trVars.ActualDklRedLuminanceT2);
            p.trVars.DklRedLuminanceDifferenceT1MinusT2_x1000 = ...
                round(1000 * p.trVars.DklRedLuminanceDifferenceT1MinusT2);
        end

        % Recover the physical luminance measured with the i1Pro 3 for the
        % exact CLUT entries selected on this trial.
        p.trVars.MeasuredLuminanceT1CdM2 = ...
            lookupMeasuredRedLuminance(p, p.trVars.T1_colorIdx);
        p.trVars.MeasuredLuminanceT2CdM2 = ...
            lookupMeasuredRedLuminance(p, p.trVars.T2_colorIdx);
        p.trVars.MeasuredLuminanceDifferenceT1MinusT2CdM2 = ...
            p.trVars.MeasuredLuminanceT1CdM2 - ...
            p.trVars.MeasuredLuminanceT2CdM2;
        p.trVars.MeasuredLuminanceT1_x100 = ...
            round(100 * p.trVars.MeasuredLuminanceT1CdM2);
        p.trVars.MeasuredLuminanceT2_x100 = ...
            round(100 * p.trVars.MeasuredLuminanceT2CdM2);
        p.trVars.BackgroundDklLuminance = ...
            p.draw.clut.srsBackgroundDklLum;
        p.trVars.BackgroundMeasuredLuminanceCdM2 = ...
            p.draw.clut.srsBackgroundMeasuredCdM2;

        % Restore the normal achromatic background and clear stale hue data.
        p.draw.color.background = p.draw.clutIdx.expBg_subBg;
        p.trVars.backgroundHueIdx = NaN;
        p.trVars.BackgroundHue = NaN;
        p.trVars.BackgroundHue_x1000 = NaN;
        p.trVars.ActualHueT1 = NaN;
        p.trVars.ActualHueT2 = NaN;
        p.trVars.ActualHueT1_x1000 = NaN;
        p.trVars.ActualHueT2_x1000 = NaN;
        p.trVars.HueContrastT1 = NaN;
        p.trVars.HueContrastT2 = NaN;
        p.trVars.HueContrastT1_x1000 = NaN;
        p.trVars.HueContrastT2_x1000 = NaN;

    case 1
        %% Hue / DKL contrast mode, unchanged in principle
        p.trVars.backgroundHueIdx = randi(2);

        if p.trVars.backgroundHueIdx == 1
            p.draw.color.background = p.draw.clutIdx.expDkl0_subDkl0;
            p.trVars.BackgroundHue = 0;
            highHueIdx = p.draw.clutIdx.expDkl180_subDkl180;
            highHueDeg = 180;
            lowHueIdx = p.draw.clutIdx.expDkl20_subDkl20;
            lowHueDeg = 20;
        else
            p.draw.color.background = p.draw.clutIdx.expDkl180_subDkl180;
            p.trVars.BackgroundHue = 180;
            highHueIdx = p.draw.clutIdx.expDkl0_subDkl0;
            highHueDeg = 0;
            lowHueIdx = p.draw.clutIdx.expDkl200_subDkl200;
            lowHueDeg = 200;
        end

        if highTargetID == 1
            p.trVars.T1_colorIdx = highHueIdx;
            p.trVars.T2_colorIdx = lowHueIdx;
            p.trVars.ActualHueT1 = highHueDeg;
            p.trVars.ActualHueT2 = lowHueDeg;
        elseif highTargetID == 2
            p.trVars.T1_colorIdx = lowHueIdx;
            p.trVars.T2_colorIdx = highHueIdx;
            p.trVars.ActualHueT1 = lowHueDeg;
            p.trVars.ActualHueT2 = highHueDeg;
        else
            error('Invalid highSalienceTargetID for hue mode.');
        end

        p.trVars.HueContrastT1 = absCircularDiffDeg( ...
            p.trVars.ActualHueT1, p.trVars.BackgroundHue);
        p.trVars.HueContrastT2 = absCircularDiffDeg( ...
            p.trVars.ActualHueT2, p.trVars.BackgroundHue);
        p.trVars.ActualHueT1_x1000 = round(1000 * p.trVars.ActualHueT1);
        p.trVars.ActualHueT2_x1000 = round(1000 * p.trVars.ActualHueT2);
        p.trVars.BackgroundHue_x1000 = round(1000 * p.trVars.BackgroundHue);
        p.trVars.HueContrastT1_x1000 = round(1000 * p.trVars.HueContrastT1);
        p.trVars.HueContrastT2_x1000 = round(1000 * p.trVars.HueContrastT2);

        p.trVars.ActualLuminanceT1 = NaN;
        p.trVars.ActualLuminanceT2 = NaN;
        p.trVars.NominalLuminanceT1 = NaN;
        p.trVars.NominalLuminanceT2 = NaN;
        p.trVars.NominalLuminanceDifferenceT1MinusT2 = NaN;
        p.trVars.ActualLuminanceT1_x1000 = NaN;
        p.trVars.ActualLuminanceT2_x1000 = NaN;
        p.trVars.LuminanceDifferenceT1MinusT2 = NaN;
        p.trVars.LuminanceDifferenceT1MinusT2_x1000 = NaN;
        p.trVars.ActualDklRedLuminanceT1 = NaN;
        p.trVars.ActualDklRedLuminanceT2 = NaN;
        p.trVars.DklRedLuminanceDifferenceT1MinusT2 = NaN;
        p.trVars.MeasuredLuminanceT1CdM2 = NaN;
        p.trVars.MeasuredLuminanceT2CdM2 = NaN;
        p.trVars.MeasuredLuminanceDifferenceT1MinusT2CdM2 = NaN;
        p.trVars.MeasuredLuminanceT1_x100 = NaN;
        p.trVars.MeasuredLuminanceT2_x100 = NaN;
        p.trVars.BackgroundDklLuminance = NaN;
        p.trVars.BackgroundMeasuredLuminanceCdM2 = NaN;

    otherwise
        error('Unknown salienceType. Use 1 for hue or 2 for luminance.');
end

end

function measuredCdM2 = lookupMeasuredRedLuminance(p, colorIdx)
%LOOKUPMEASUREDREDLUMINANCE Return the i1Pro 3 value for one CLUT entry.

if ~isfield(p.draw, 'clut') || ...
        ~isfield(p.draw.clut, 'redLumCalibration') || ...
        ~isfield(p.draw.clut.redLumCalibration, 'clutIdx')
    error('SRS red-luminance calibration was not loaded by initClut.');
end

calibration = p.draw.clut.redLumCalibration;
matchIdx = find(calibration.clutIdx == double(colorIdx), 1, 'first');
if isempty(matchIdx)
    error('No physical luminance calibration exists for CLUT index %d.', colorIdx);
end

measuredCdM2 = calibration.measuredCdM2(matchIdx);

end

function p = chooseBlockReward(p)
%CHOOSEBLOCKREWARD Choose rich and poor reward means for the new block.

rewardMeans = [0, 0];
while abs(diff(rewardMeans)) < 40
    rewardMeans = 37 + (191 - 37) * rand(1, 2);
end

p.status.BlockRichMeanDuration = max(rewardMeans);
p.status.BlockPoorMeanDuration = min(rewardMeans);

end

function p = locationInfo(p)
%LOCATIONINFO Define fixation geometry in pixels.

p.draw.fixPointPix = p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);
p.draw.fixPointRadius = p.trVars.fixPointRadPix;
p.draw.fixPointWidth = p.trVars.fixPointLinePix;
p.draw.fixPointRect = repmat(p.draw.fixPointPix, 1, 2) + ...
    p.draw.fixPointRadius * [-1 -1 1 1];

end

function p = timingInfo(p)
%TIMINGINFO Define trial timing values.

p.trVars.fix2StimOnIntvl = ...
    p.trVars.fix2CueIntvl + p.trVars.cueDur + p.trVars.cue2StimItvl;
p.trVars.cueChangeTime = p.trVars.fix2StimOnIntvl + ...
    p.trVars.stim2ChgIntvl + p.trVars.chgWinDur * rand;
p.trVars.foilChangeTime = p.trVars.fix2StimOnIntvl + ...
    p.trVars.stim2ChgIntvl + p.trVars.chgWinDur * rand;
p.trVars.hitRwdTime = p.trVars.cueChangeTime + p.trVars.rewardDelay;
p.trVars.corrRejRwdTime = p.trVars.foilChangeTime + ...
    p.trVars.joyMaxLatency + rand * (p.trVars.chgWinDur + ...
    p.trVars.stim2ChgIntvl + p.trVars.fix2StimOnIntvl - ...
    p.trVars.foilChangeTime - p.trVars.joyMaxLatency);

if p.trVars.isCueChangeTrial
    p.trVars.fix2StimOffIntvl = p.trVars.cueChangeTime + p.trVars.joyMaxLatency;
else
    p.trVars.fix2StimOffIntvl = p.trVars.corrRejRwdTime;
end

p.trVars.stimDur = ...
    p.trVars.stim2ChgIntvl + p.trVars.chgWinDur + p.trVars.joyMaxLatency;

if p.trVars.isCueChangeTrial
    stimOnToStimChgIntvl = p.trVars.cueChangeTime - p.trVars.fix2StimOnIntvl;
elseif p.trVars.isFoilChangeTrial
    stimOnToStimChgIntvl = p.trVars.foilChangeTime - p.trVars.fix2StimOnIntvl;
else
    stimOnToStimChgIntvl = p.trVars.cueChangeTime - p.trVars.fix2StimOnIntvl;
end

stimChgToStimOffIntvl = p.trVars.stimDur - stimOnToStimChgIntvl;
p.stim.epochFrames = fix([stimOnToStimChgIntvl, stimChgToStimOffIntvl] / ...
    p.rig.frameDuration);
p.stim.chgFrames = cumsum(p.stim.epochFrames(1:end - 1));
p.trVars.stimFrames = sum(p.stim.epochFrames);
p.trVars.nEpochs = length(p.stim.epochFrames);

p.trVars.fixDurReq = p.trVars.fixDurReqMin + ...
    (p.trVars.fixDurReqMax - p.trVars.fixDurReqMin) * rand;
p.trVars.targHoldDuration = p.trVars.targHoldDurationMin + ...
    (p.trVars.targHoldDurationMax - p.trVars.targHoldDurationMin) * rand;

end

function p = setLocations(p)
%SETLOCATIONS Convert target geometry from degrees to pixels.

p.draw.T1_locPixX = p.draw.middleXY(1) + ...
    pds.deg2pix(p.trVars.T1_locDegX, p);
p.draw.T1_locPixY = p.draw.middleXY(2) - ...
    pds.deg2pix(p.trVars.T1_locDegY, p);
p.draw.T1_longAxisPix = pds.deg2pix(p.trVars.T1_longAxisDeg, p);
p.draw.T1_shortAxisPix = pds.deg2pix(p.trVars.T1_shortAxisDeg, p);

p.draw.T2_locPixX = p.draw.middleXY(1) + ...
    pds.deg2pix(p.trVars.T2_locDegX, p);
p.draw.T2_locPixY = p.draw.middleXY(2) - ...
    pds.deg2pix(p.trVars.T2_locDegY, p);
p.draw.T2_longAxisPix = pds.deg2pix(p.trVars.T2_longAxisDeg, p);
p.draw.T2_shortAxisPix = pds.deg2pix(p.trVars.T2_shortAxisDeg, p);

end

function xDeg = sideToX(side, eccentricity)
if side == 1
    xDeg = abs(eccentricity);
elseif side == 2
    xDeg = -abs(eccentricity);
else
    error('SRS side must be 1 (right) or 2 (left).');
end
end

function side = sideOfTarget(p, targetID)
if targetID == 1
    side = p.trVars.T1Side;
elseif targetID == 2
    side = p.trVars.T2Side;
else
    error('SRS target ID must be 1 or 2.');
end
end

function targetID = targetAtSide(p, side)
if p.trVars.T1Side == side
    targetID = 1;
elseif p.trVars.T2Side == side
    targetID = 2;
else
    error('No SRS target is assigned to requested side.');
end
end

function d = absCircularDiffDeg(a, b)
d = abs(mod(a - b + 180, 360) - 180);
end
