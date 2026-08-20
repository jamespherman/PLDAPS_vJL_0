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

% A forced correction must repeat the exact stochastic condition, not only
% the same schedule row. Restore the reward samples, stimulus salience,
% direct-RGB values and any per-trial CLUT entries captured on the trigger
% trial. Normal trials continue to sample a fresh condition.
if getLogicalScalar(p.trVars, 'correctionTrialActive', false) && ...
        isfield(p.status, 'correctionTrialSnapshotValid') && ...
        p.status.correctionTrialSnapshotValid
    p = restoreCorrectionTrialSnapshot(p);
else
    p = sampleTrialRewards(p);
    p = assignTrialRewardsAndSalience(p);
    p.trVars.correctionSnapshotValid = 0;
end

% Optional anti-right-bias manipulation applied only after restoring the
% exact condition. The stored snapshot remains unchanged across repeats.
p = applyCorrectionRightRewardReduction(p);

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

minMultiple = ceil(p.trVars.minTrialsPerBlock / 4);
maxMultiple = floor(p.trVars.maxTrialsPerBlock / 4);

if minMultiple > maxMultiple
    error('SRS:InvalidTrialRange', ...
        ['No multiple of 4 exists between minTrialsPerBlock=%g ' ...
         'and maxTrialsPerBlock=%g.'], ...
        p.trVars.minTrialsPerBlock, ...
        p.trVars.maxTrialsPerBlock);
end

nChoice = 4 * randi([minMultiple, maxMultiple]);

p.status.TotalChoiceTrialsPerBlock = nChoice;
p.status.CurrentBlockNumber = p.status.CurrentBlockNumber + 1;

if isfield(p.status, 'TotalBlocksTarget')
    p.status.RemainingBlock = max(0, ...
        p.status.TotalBlocksTarget - p.status.CurrentBlockNumber);
else
    p.status.RemainingBlock = max(0, p.status.RemainingBlock - 1);
end

p.status.highRewardTargetID = p.status.CurrentBlockType;
% A correction sequence must never carry into a new reward block.
p.status.correctionTrialActive = false;
p.status.correctionTrialRow = NaN;
p.status.correctionTrialRepetition = 0;
p.status.correctionTrialLastOutcome = 'new block';
p.status.correctionTrialSnapshot = struct();
p.status.correctionTrialSnapshotValid = false;
p = chooseBlockReward(p);
p = buildSrsBlockSchedule(p);

if p.status.TotalInstructionTrialsPerBlock > 0
    instructionOrderText = 'mixed T1-only / T2-only';
else
    instructionOrderText = 'none';
end
fprintf(['\nStarted block %d: T%d rich, %d instruction + %d choice trials ', ...
    '(instruction schedule: %s).\n'], ...
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

% Correction mode can force the exact same schedule row after a rightward
% low-reward choice on a conflict trial. The maximum is read from the GUI
% copy on every trial, so it can be changed while the task is running.
p = ensureCorrectionStatusFields(p);
correctionEnabled = getLogicalScalar(p.trVars, 'correctionTrial', false);
maxRepetition = max(0, round(getNumericScalar( ...
    p.trVars, 'correctionTrialMaxRepetition', 15)));

if p.status.correctionTrialActive && (~correctionEnabled || maxRepetition == 0)
    activeRow = p.status.correctionTrialRow;
    if isfinite(activeRow) && activeRow >= 1 && activeRow <= numel(remaining)
        p.status.trialsArrayRowsPossible(activeRow) = false;
        remaining(activeRow) = false;
    end
    p.status.correctionTrialActive = false;
    p.status.correctionTrialRow = NaN;
    p.status.correctionTrialRepetition = 0;
    p.status.correctionTrialLastOutcome = 'disabled';
    p.status.correctionTrialSnapshot = struct();
    p.status.correctionTrialSnapshotValid = false;
    if ~any(remaining)
        p = startNewBlock(p);
        remaining = logical(p.status.trialsArrayRowsPossible(:));
    end
end

% If the repetition cap is lowered from the GUI while a correction series
% is active, apply the new cap before selecting another forced attempt.
if p.status.correctionTrialActive && correctionEnabled && ...
        p.status.correctionTrialRepetition >= maxRepetition
    activeRow = p.status.correctionTrialRow;
    if isfinite(activeRow) && activeRow >= 1 && activeRow <= numel(remaining)
        p.status.trialsArrayRowsPossible(activeRow) = false;
        remaining(activeRow) = false;
    end
    p.status.correctionTrialActive = false;
    p.status.correctionTrialRow = NaN;
    p.status.correctionTrialRepetition = 0;
    p.status.correctionTrialMaxReachedCount = ...
        p.status.correctionTrialMaxReachedCount + 1;
    p.status.correctionTrialLastOutcome = 'maximum changed/reached';
    p.status.correctionTrialSnapshot = struct();
    p.status.correctionTrialSnapshotValid = false;
    if ~any(remaining)
        p = startNewBlock(p);
        remaining = logical(p.status.trialsArrayRowsPossible(:));
    end
end

if p.status.correctionTrialActive
    forcedRow = round(p.status.correctionTrialRow);
    if forcedRow < 1 || forcedRow > numel(remaining) || ~remaining(forcedRow)
        warning('Active correction row is no longer eligible; correction was cancelled.');
        p.status.correctionTrialActive = false;
        p.status.correctionTrialRow = NaN;
        p.status.correctionTrialRepetition = 0;
        p.status.correctionTrialLastOutcome = 'invalid row';
    p.status.correctionTrialSnapshot = struct();
    p.status.correctionTrialSnapshotValid = false;
    else
        p.trVars.currentTrialsArrayRow = forcedRow;
        p.status.blockAttemptCount = p.status.blockAttemptCount + 1;
        p.status.correctionTrialRepetition = ...
            p.status.correctionTrialRepetition + 1;
        p.trVars.correctionTrialActive = 1;
        p.trVars.correctionTrialRepetition = ...
            p.status.correctionTrialRepetition;
        p.trVars.correctionTrialMaxRepetition = maxRepetition;
        return
    end
end

p.trVars.correctionTrialActive = 0;
p.trVars.correctionTrialRepetition = 0;
p.trVars.correctionTrialMaxRepetition = maxRepetition;

cols = p.init.trialCols;
phase = p.init.trialsArray(:, cols.schedulePhase);

% Always exhaust the earliest remaining phase before moving on.
% Training blocks use:
%   phase 1 = mixed T1-only and T2-only instruction trials
%   phase 2 = two-target choice trials
% A failed instruction row remains eligible, but T1-only and T2-only rows
% are free to interleave within phase 1.
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


function p = ensureCorrectionStatusFields(p)
defaults = struct( ...
    'correctionTrialActive', false, ...
    'correctionTrialRow', NaN, ...
    'correctionTrialRepetition', 0, ...
    'correctionTrialTriggerCount', 0, ...
    'correctionTrialSuccessCount', 0, ...
    'correctionTrialMaxReachedCount', 0, ...
    'correctionTrialLastOutcome', 'inactive', ...
    'correctionTrialSnapshot', struct(), ...
    'correctionTrialSnapshotValid', false);
fields = fieldnames(defaults);
for iField = 1:numel(fields)
    name = fields{iField};
    if ~isfield(p.status, name)
        p.status.(name) = defaults.(name);
    end
end
end

function value = getNumericScalar(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName)
    candidate = s.(fieldName);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end

function value = getLogicalScalar(s, fieldName, defaultValue)
value = logical(defaultValue);
if isstruct(s) && isfield(s, fieldName)
    candidate = s.(fieldName);
    if (isnumeric(candidate) || islogical(candidate)) && isscalar(candidate)
        value = logical(candidate);
    end
end
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

% The two coordinates entered in settings define the two physical target
% locations. Identity-to-side randomization swaps the complete [X,Y] pairs
% instead of rebuilding them from an eccentricity and forcing Y to zero.
% Therefore changing T1_locDegX/Y and T2_locDegX/Y in the settings or GUI
% directly changes the locations used by the task.
configuredLocation1 = [p.trVars.T1_locDegX, p.trVars.T1_locDegY];
configuredLocation2 = [p.trVars.T2_locDegX, p.trVars.T2_locDegY];
[side1Location, side2Location] = configuredSideLocations( ...
    configuredLocation1, configuredLocation2);

p.trVars.T1_locDegX = locationForSide( ...
    p.trVars.T1Side, side1Location, side2Location, 1);
p.trVars.T1_locDegY = locationForSide( ...
    p.trVars.T1Side, side1Location, side2Location, 2);
p.trVars.T2_locDegX = locationForSide( ...
    p.trVars.T2Side, side1Location, side2Location, 1);
p.trVars.T2_locDegY = locationForSide( ...
    p.trVars.T2Side, side1Location, side2Location, 2);

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

% Absolute ceiling on a single solenoid opening, independent of how the
% block means were arrived at. The block-level clamps in chooseBlockReward
% bound the scale and the separation, but not the product of scale and
% range, so this is the one guarantee that holds for every parameter
% combination reachable from the GUI. 400 ms is ~0.44 ml at 0.0011 ml/ms,
% already a large single reward; raise it deliberately if a study needs to.
maxSingleMs = getNumericScalar(p.trVars, 'maxSingleRewardMs', 400);

richReward = min(maxSingleMs, max(1, round(richMean + sdMs * randn)));
poorReward = min(maxSingleMs, max(1, round(poorMean + sdMs * randn)));

if richReward >= maxSingleMs || poorReward >= maxSingleMs
    warning('SRS:RewardCeilingReached', ...
        ['A sampled reward hit the %g ms ceiling (rich mean %.0f, poor ' ...
         'mean %.0f). Check rewardScale and the block mean range.'], ...
        maxSingleMs, richMean, poorMean);
end

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
    % Instruction trials use the same high/low salience assignment rule as
    % two-target trials, but independently of reward, target identity and
    % screen side. Because only one target is displayed, this makes the
    % visible target receive the sampled high or low salience value with
    % equal probability.
    p.status.highSalienceTargetID = randi(2);
    p.status.highSalienceSide = sideOfTarget( ...
        p, p.status.highSalienceTargetID);
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
        %% DKL / CLUT luminance mode
        assertL48DisplayMode(p, 2);
        p = clearDirectRgbTrialFields(p);
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
        % Luminance targets use static red-bank CLUT entries, so no per-trial
        % CLUT push is needed.
        p.trVars.updateClutThisTrial = false;
        p.draw.color.background = p.draw.clutIdx.expBg_subBg;
        p.trVars.backgroundHueIdx = NaN;
        p.trVars.BackgroundHue = NaN;
        p.trVars.BackgroundHue_x10 = NaN;
        p.trVars.ActualHueT1 = NaN;
        p.trVars.ActualHueT2 = NaN;
        p.trVars.ActualHueT1_x10 = NaN;
        p.trVars.ActualHueT2_x10 = NaN;
        p.trVars.HueContrastT1 = NaN;
        p.trVars.HueContrastT2 = NaN;
        p.trVars.HueContrastT1_x10 = NaN;
        p.trVars.HueContrastT2_x10 = NaN;
        p.trVars.HighSalienceHueDeg = NaN;
        p.trVars.LowSalienceHueDeg = NaN;
        p.trVars.HueContrastDifferenceT1MinusT2 = NaN;
        p.trVars.HueContrastDifferenceMagnitude = NaN;
        p.trVars.hueModeCode = NaN;

    case 3
        %% Direct RGB luminance mode (DATAPixx C24)
        p = applyDirectRgbLuminance(p, highTargetID);

    case 1
        %% Hue / DKL contrast mode
        assertL48DisplayMode(p, 1);
        p = clearDirectRgbTrialFields(p);
        % Background stays at the classic 0 or 180 deg DKL hue. In smooth
        % mode, each target's hue is (background + offset), where the offset
        % is the circular hue contrast against the background, sampled per
        % trial (Dubey-style, see chooseContinuousHuePair). Classic mode
        % keeps the fixed 0/20/180/200 deg hues. DKL luminance and
        % saturation are fixed in both modes.

        p.trVars.backgroundHueIdx = randi(2);
        hueMode = 'smooth';
        if isfield(p.trVars, 'hueSamplingMode') && ...
                ~isempty(p.trVars.hueSamplingMode)
            hueMode = lower(char(p.trVars.hueSamplingMode));
        end

        if p.trVars.backgroundHueIdx == 1
            p.draw.color.background = p.draw.clutIdx.expDkl0_subDkl0;
            p.trVars.BackgroundHue = 0;
        else
            p.draw.color.background = p.draw.clutIdx.expDkl180_subDkl180;
            p.trVars.BackgroundHue = 180;
        end

        % Only smooth mode rewrites CLUT rows; classic uses static entries.
        p.trVars.updateClutThisTrial = false;

        switch hueMode
            case 'classic'
                p.trVars.hueModeCode = 1;
                if p.trVars.backgroundHueIdx == 1
                    highHueIdx = p.draw.clutIdx.expDkl180_subDkl180;
                    highHueDeg = 180;
                    lowHueIdx = p.draw.clutIdx.expDkl20_subDkl20;
                    lowHueDeg = 20;
                else
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

            case 'smooth'
                p.trVars.hueModeCode = 2;
                p = chooseContinuousHuePair(p, highTargetID);

            otherwise
                error('Unknown hueSamplingMode: %s', hueMode);
        end

        % Salience-referenced hues (absolute deg) for reporting.
        if highTargetID == 1
            p.trVars.HighSalienceHueDeg = p.trVars.ActualHueT1;
            p.trVars.LowSalienceHueDeg = p.trVars.ActualHueT2;
        else
            p.trVars.HighSalienceHueDeg = p.trVars.ActualHueT2;
            p.trVars.LowSalienceHueDeg = p.trVars.ActualHueT1;
        end

        p.trVars.HueContrastT1 = absCircularDiffDeg( ...
            p.trVars.ActualHueT1, p.trVars.BackgroundHue);
        p.trVars.HueContrastT2 = absCircularDiffDeg( ...
            p.trVars.ActualHueT2, p.trVars.BackgroundHue);
        p.trVars.HueContrastDifferenceT1MinusT2 = ...
            p.trVars.HueContrastT1 - p.trVars.HueContrastT2;
        p.trVars.HueContrastDifferenceMagnitude = ...
            abs(p.trVars.HueContrastDifferenceT1MinusT2);

        % Angles strobed scaled by 10 (0..3600) to fit the 15-bit strobe.
        p.trVars.ActualHueT1_x10 = round(10 * p.trVars.ActualHueT1);
        p.trVars.ActualHueT2_x10 = round(10 * p.trVars.ActualHueT2);
        p.trVars.BackgroundHue_x10 = round(10 * p.trVars.BackgroundHue);
        p.trVars.HueContrastT1_x10 = round(10 * p.trVars.HueContrastT1);
        p.trVars.HueContrastT2_x10 = round(10 * p.trVars.HueContrastT2);

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
        error(['Unknown salienceType. Use 1 for hue, 2 for DKL/CLUT ', ...
            'luminance, or 3 for direct RGB luminance.']);
end

end

function p = applyDirectRgbLuminance(p, highTargetID)
%APPLYDIRECTRGBLUMINANCE Select measured red RGBs in C24 mode.
%
% Desired luminances follow the Dubey pair rule. The displayed target is
% then chosen from the nearest actually measured family-15 RGB row. Desired
% and measured values are stored separately because the calibration is
% currently sampled every eight red-channel levels.

if ~isfield(p.draw, 'isDirectRgb') || ~logical(p.draw.isDirectRgb)
    error(['salienceType 3 requires a C24 window. Select a direct-RGB ', ...
        'settings file and reinitialize the task.']);
end
if ~isfield(p.draw, 'directRgbCalibration') || ...
        ~isfield(p.draw.directRgbCalibration, 'targetTable')
    error('Direct-RGB calibration was not loaded during initialization.');
end
if ~any(highTargetID == [1 2])
    error('Invalid highSalienceTargetID for direct RGB mode.');
end

minLum = p.trVars.directRgbLuminanceMinCdM2;
maxLum = p.trVars.directRgbLuminanceMaxCdM2;
meanLum = p.trVars.directRgbLuminanceMeanCdM2;
if abs((minLum + maxLum) / 2 - meanLum) > 1e-6
    error(['Direct-RGB luminance bounds must be symmetric around the ', ...
        'configured pair mean.']);
end

calTable = p.draw.directRgbCalibration.targetTable;
maxAttempts = round(p.trVars.directRgbMaximumSamplingAttempts);
if ~isfinite(maxAttempts) || maxAttempts < 1
    maxAttempts = 1000;
end

% Use the same log-uniform pair sampling on instruction and choice trials.
% On instruction trials, assignTrialRewardsAndSalience independently decides
% whether the visible target receives the sampled high or low luminance.
validPair = false;
for iAttempt = 1:maxAttempts
    lumA = exp(log(minLum) + rand * (log(maxLum) - log(minLum)));
    lumB = 2 * meanLum - lumA;
    highDesired = max(lumA, lumB);
    lowDesired = min(lumA, lumB);
    [highEntry, lowEntry] = mapDirectRgbPair(calTable, ...
        highDesired, lowDesired);

    % Require distinct displayed colors so the assigned high-salience
    % identity is physically brighter on every trial.
    validPair = highEntry.measuredCdM2 > lowEntry.measuredCdM2 && ...
        highEntry.redLevel ~= lowEntry.redLevel;
    if validPair
        break
    end
end
if ~validPair
    error(['Could not obtain two distinct direct-RGB luminance ', ...
        'levels after %d attempts.'], maxAttempts);
end

if highTargetID == 1
    desiredT1 = highDesired;
    desiredT2 = lowDesired;
    entryT1 = highEntry;
    entryT2 = lowEntry;
else
    desiredT1 = lowDesired;
    desiredT2 = highDesired;
    entryT1 = lowEntry;
    entryT2 = highEntry;
end

p.trVars.ActualLuminanceT1 = desiredT1;
p.trVars.ActualLuminanceT2 = desiredT2;
p.trVars.NominalLuminanceT1 = desiredT1;
p.trVars.NominalLuminanceT2 = desiredT2;
p.trVars.LuminanceDifferenceT1MinusT2 = desiredT1 - desiredT2;
p.trVars.NominalLuminanceDifferenceT1MinusT2 = ...
    p.trVars.LuminanceDifferenceT1MinusT2;
p.trVars.LuminanceDifferenceMagnitude = ...
    abs(p.trVars.LuminanceDifferenceT1MinusT2);
p.trVars.LuminancePairMean = mean([desiredT1 desiredT2]);
p.trVars.ActualLuminanceT1_x1000 = round(1000 * desiredT1);
p.trVars.ActualLuminanceT2_x1000 = round(1000 * desiredT2);
p.trVars.LuminanceDifferenceT1MinusT2_x1000 = ...
    round(1000 * p.trVars.LuminanceDifferenceT1MinusT2);

p.trVars.T1_colorRGB255 = entryT1.rgb255;
p.trVars.T2_colorRGB255 = entryT2.rgb255;
p.trVars.T1_color = entryT1.rgb255 / 255;
p.trVars.T2_color = entryT2.rgb255 / 255;
p.trVars.T1_redLevel = entryT1.redLevel;
p.trVars.T2_redLevel = entryT2.redLevel;
p.trVars.DirectRgbT1R = entryT1.rgb255(1);
p.trVars.DirectRgbT1G = entryT1.rgb255(2);
p.trVars.DirectRgbT1B = entryT1.rgb255(3);
p.trVars.DirectRgbT2R = entryT2.rgb255(1);
p.trVars.DirectRgbT2G = entryT2.rgb255(2);
p.trVars.DirectRgbT2B = entryT2.rgb255(3);

p.trVars.MeasuredLuminanceT1CdM2 = entryT1.measuredCdM2;
p.trVars.MeasuredLuminanceT2CdM2 = entryT2.measuredCdM2;
p.trVars.MeasuredLuminanceDifferenceT1MinusT2CdM2 = ...
    entryT1.measuredCdM2 - entryT2.measuredCdM2;
p.trVars.MeasuredLuminanceT1_x100 = round(100 * entryT1.measuredCdM2);
p.trVars.MeasuredLuminanceT2_x100 = round(100 * entryT2.measuredCdM2);
p.trVars.DirectRgbPairDesiredMeanCdM2 = mean([desiredT1 desiredT2]);
p.trVars.DirectRgbPairMeasuredMeanCdM2 = ...
    mean([entryT1.measuredCdM2 entryT2.measuredCdM2]);

p.trVars.BackgroundDklLuminance = NaN;
p.trVars.BackgroundMeasuredLuminanceCdM2 = ...
    p.draw.directRgbCalibration.backgroundMeasuredCdM2;
p.trVars.DirectRgbBackgroundCdM2_x1000 = round(1000 * ...
    p.trVars.BackgroundMeasuredLuminanceCdM2);
p.draw.color.background = ...
    double(p.draw.directRgbCalibration.backgroundRGB255);

% These are explicit legacy placeholders, not CLUT indices in C24 mode.
p.trVars.T1_colorIdx = 0;
p.trVars.T2_colorIdx = 0;
p.trVars.displayModeCode = 3;
p.trVars.updateClutThisTrial = false;

% Clear DKL and hue variables so saved data cannot confuse the two modes.
p.trVars.ActualDklRedLuminanceT1 = NaN;
p.trVars.ActualDklRedLuminanceT2 = NaN;
p.trVars.DklRedLuminanceDifferenceT1MinusT2 = NaN;
p.trVars.ActualDklRedLuminanceT1_x1000 = 0;
p.trVars.ActualDklRedLuminanceT2_x1000 = 0;
p.trVars.DklRedLuminanceDifferenceT1MinusT2_x1000 = 0;
p.trVars.backgroundHueIdx = 0;
p.trVars.BackgroundHue = NaN;
p.trVars.BackgroundHue_x10 = 0;
p.trVars.ActualHueT1 = NaN;
p.trVars.ActualHueT2 = NaN;
p.trVars.ActualHueT1_x10 = 0;
p.trVars.ActualHueT2_x10 = 0;
p.trVars.HueContrastT1 = NaN;
p.trVars.HueContrastT2 = NaN;
p.trVars.HueContrastT1_x10 = 0;
p.trVars.HueContrastT2_x10 = 0;
p.trVars.HighSalienceHueDeg = NaN;
p.trVars.LowSalienceHueDeg = NaN;
p.trVars.HueContrastDifferenceT1MinusT2 = NaN;
p.trVars.HueContrastDifferenceMagnitude = NaN;
p.trVars.hueModeCode = 0;

end

function [highEntry, lowEntry] = mapDirectRgbPair(calTable, highDesired, lowDesired)
%MAPDIRECTRGBPAIR Map desired luminances to nearest measured RGB rows.

highEntry = nearestDirectRgbEntry(calTable, highDesired);
lowEntry = nearestDirectRgbEntry(calTable, lowDesired);

end

function entry = nearestDirectRgbEntry(calTable, desiredCdM2)
%NEARESTDIRECTRGBENTRY Return one measured direct-RGB calibration row.

[~, rowIdx] = min(abs(calTable.measuredCdM2 - desiredCdM2));
entry = struct();
entry.redLevel = double(calTable.redLevel(rowIdx));
entry.rgb255 = double([calTable.rgbR_255(rowIdx), ...
    calTable.rgbG_255(rowIdx), calTable.rgbB_255(rowIdx)]);
entry.measuredCdM2 = double(calTable.measuredCdM2(rowIdx));

end

function p = clearDirectRgbTrialFields(p)
%CLEARDIRECTRGBTRIALFIELDS Reset C24-only fields in L48 modes.

p.trVars.displayModeCode = 1;
p.trVars.T1_colorRGB255 = [0 0 0];
p.trVars.T2_colorRGB255 = [0 0 0];
p.trVars.T1_redLevel = 0;
p.trVars.T2_redLevel = 0;
p.trVars.DirectRgbT1R = 0;
p.trVars.DirectRgbT1G = 0;
p.trVars.DirectRgbT1B = 0;
p.trVars.DirectRgbT2R = 0;
p.trVars.DirectRgbT2G = 0;
p.trVars.DirectRgbT2B = 0;
p.trVars.DirectRgbPairDesiredMeanCdM2 = NaN;
p.trVars.DirectRgbPairMeasuredMeanCdM2 = NaN;
p.trVars.DirectRgbBackgroundCdM2_x1000 = 0;

end

function assertL48DisplayMode(p, salienceType)
%ASSERTL48DISPLAYMODE Prevent display-mode changes without reinitializing.

if isfield(p.draw, 'isDirectRgb') && logical(p.draw.isDirectRgb)
    error(['salienceType %d requires the L48 window, but the task was ', ...
        'initialized in C24 direct-RGB mode. Change settings and ', ...
        'reinitialize.'], salienceType);
end

end

function p = chooseContinuousHuePair(p, highTargetID)
%CHOOSECONTINUOUSHUEPAIR Sample continuous DKL target hues (Dubey-style).
%
% Each target's hue is (background + offset), where the offset is the
% circular hue contrast against the background, in degrees. Offsets lie in
% [minHueAngleDeg, maxHueAngleDeg] (0 < min < max <= 180) and their pair
% mean is fixed at the symmetric midpoint, mirroring how Dubey fixed the
% two-target mean luminance. The exact target RGB is written into the two
% reserved CLUT slots (both experimenter and subject sides), and the
% combined CLUT is rebuilt so srsSmooth_run can push it this trial.

minOff = p.trVars.minHueAngleDeg;
maxOff = p.trVars.maxHueAngleDeg;
if ~(isfinite(minOff) && isfinite(maxOff)) || ...
        minOff <= 0 || maxOff <= minOff || maxOff > 180
    error(['minHueAngleDeg/maxHueAngleDeg must satisfy ', ...
        '0 < min < max <= 180.']);
end
pairMean = (minOff + maxOff) / 2;

% Instruction and choice trials use exactly the same contrast-pair sampler.
% On an instruction trial, only one member of the pair is displayed, and
% assignTrialRewardsAndSalience independently randomizes whether that visible
% target receives the high or low member.
minDiff = 0;
if isfield(p.trVars, 'hueContrastDiffMinDeg') && ...
        isfinite(p.trVars.hueContrastDiffMinDeg)
    minDiff = max(0, p.trVars.hueContrastDiffMinDeg);
end

samplingMode = 'dubeyloguniform';
if isfield(p.trVars, 'hueContrastSamplingMode') && ...
        ~isempty(p.trVars.hueContrastSamplingMode)
    samplingMode = lower(char(p.trVars.hueContrastSamplingMode));
end

switch samplingMode
    case 'dubeyloguniform'
        % Draw one offset log-uniform in [min,max], set the partner so
        % the pair mean equals the midpoint. Because the mean is the
        % midpoint, the partner is always within [min,max].
        valid = false;
        attempts = 0;
        while ~valid
            offA = exp(log(minOff) + ...
                rand * (log(maxOff) - log(minOff)));
            offB = 2 * pairMean - offA;
            valid = offB >= minOff - 1e-9 && ...
                offB <= maxOff + 1e-9 && ...
                abs(offA - offB) >= minDiff;
            attempts = attempts + 1;
            if attempts > 1000
                error(['Could not satisfy hueContrastDiffMinDeg ', ...
                    'for the hue offset pair.']);
            end
        end
        offHigh = max(offA, offB);
        offLow = min(offA, offB);

    case 'uniformdifference'
        % Sample the offset difference uniformly with the mean fixed.
        maxDiff = min(2 * (pairMean - minOff), 2 * (maxOff - pairMean));
        if maxDiff < minDiff
            error(['hueContrastDiffMinDeg exceeds the maximum valid ', ...
                'offset difference.']);
        end
        differenceMagnitude = minDiff + rand * (maxDiff - minDiff);
        offHigh = pairMean + differenceMagnitude / 2;
        offLow = pairMean - differenceMagnitude / 2;

    otherwise
        error('Unknown hueContrastSamplingMode: %s', samplingMode);
end

% Map the high/low offsets to targets by salience identity.
if highTargetID == 1
    offT1 = offHigh;
    offT2 = offLow;
elseif highTargetID == 2
    offT1 = offLow;
    offT2 = offHigh;
else
    error('Invalid highSalienceTargetID for hue mode.');
end

% Always background + offset (single rotational direction).
bgHue = p.trVars.BackgroundHue;
hueT1 = mod(bgHue + offT1, 360);
hueT2 = mod(bgHue + offT2, 360);

p.trVars.ActualHueT1 = hueT1;
p.trVars.ActualHueT2 = hueT2;

% Write exact DKL RGB into the reserved target CLUT slots (exp + sub sides).
rgbT1 = srsHueToRgb(p, hueT1);
rgbT2 = srsHueToRgb(p, hueT2);
rowT1 = p.draw.clutIdx.srsTargetT1 + 1;
rowT2 = p.draw.clutIdx.srsTargetT2 + 1;
p.draw.clut.expCLUT(rowT1, :) = rgbT1;
p.draw.clut.subCLUT(rowT1, :) = rgbT1;
p.draw.clut.expCLUT(rowT2, :) = rgbT2;
p.draw.clut.subCLUT(rowT2, :) = rgbT2;
p.trVars.T1_colorIdx = p.draw.clutIdx.srsTargetT1;
p.trVars.T2_colorIdx = p.draw.clutIdx.srsTargetT2;

% Rebuild the combined CLUT and flag it for pushing this trial.
p.draw.clut.combinedClut = [p.draw.clut.subCLUT; p.draw.clut.expCLUT];
p.trVars.updateClutThisTrial = true;

end

function rgb = srsHueToRgb(p, hueDeg)
%SRSHUETORGB Convert an absolute DKL hue angle to RGB at the fixed
% smooth-hue luminance and (gamut-safe) saturation radius.

meanLum = p.draw.clut.smoothHueMeanLuminance;
satRad = p.draw.clut.smoothHueSaturationRadius;
dklVec = [meanLum; satRad * cosd(hueDeg); satRad * sind(hueDeg)];
[r, g, b] = dkl2rgb(dklVec);
rgb = [r, g, b];

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
%
% Dubey et al. 2023 (Neuron 111:3321) hold the mean reward of each target
% constant across a block and draw the two means independently from
% 0.04-0.21 ml/trial, i.e. 37-191 ms of solenoid time at 0.0011 ml/ms. The
% two means are required to differ by at least blockMeanRewardMinSepMs so
% every block presents a discriminable contrast.
%
% rewardScale multiplies both means. Scaling rather than re-centering keeps
% the properties the design depends on: rich and poor values still overlap
% across blocks, so the size of a single reward does not by itself identify
% the rich target, and the rich/poor ratio driving choice is unchanged.

% Parameters are clamped, not validated with error(). The GUI trial loop
% (PLDAPS_vK2_GUI.m:491-520) calls this through _next with no try/catch, so
% throwing here would end a running session with Psychtoolbox, DataPixx and
% ephys schedules still live. It would also leave block bookkeeping half
% applied: startNewBlock flips CurrentBlockType (line 55) and increments
% CurrentBlockNumber (line 75) before calling this, so restarting after an
% error would flip the rich target a second time and skip an alternation.
% Clamping keeps the session running at safe values and says what it did.
REWARD_SCALE_MIN = 0.1;
REWARD_SCALE_MAX = 3;       % a mistyped 15 cannot reach the solenoid
SEPARATION_MIN_MS = 1;      % 0 or less would leave both block means at zero
SEPARATION_MAX_FRACTION = 0.9;   % keeps rejection sampling from stalling
BLOCK_MEAN_FLOOR_MS = 1;

minMs = clampRewardParam(p, 'blockMeanRewardMinMs', 37, BLOCK_MEAN_FLOOR_MS, Inf);
maxMs = clampRewardParam(p, 'blockMeanRewardMaxMs', 191, BLOCK_MEAN_FLOOR_MS, Inf);
rewardScale = clampRewardParam(p, 'rewardScale', 1.5, ...
    REWARD_SCALE_MIN, REWARD_SCALE_MAX);

% An inverted or empty range cannot be clamped into something sensible, and
% editing the two ends one at a time transiently inverts it, so fall back to
% the published range rather than guessing at intent.
if maxMs <= minMs
    warning('SRS:InvalidBlockRewardRange', ...
        ['blockMeanRewardMaxMs (%g) must exceed blockMeanRewardMinMs ' ...
         '(%g). Using the default 37-191 ms range for this block.'], ...
        maxMs, minMs);
    minMs = 37;
    maxMs = 191;
end

% Bounded above so the rejection loop keeps a usable acceptance rate, and
% below so the loop cannot exit immediately with both means still zero.
minSepMs = clampRewardParam(p, 'blockMeanRewardMinSepMs', 40, ...
    SEPARATION_MIN_MS, SEPARATION_MAX_FRACTION * (maxMs - minMs));

rewardMeans = [0, 0];
while abs(diff(rewardMeans)) < minSepMs
    rewardMeans = minMs + (maxMs - minMs) * rand(1, 2);
end

p.status.BlockRichMeanDuration = rewardScale * max(rewardMeans);
p.status.BlockPoorMeanDuration = rewardScale * min(rewardMeans);

end

function value = clampRewardParam(p, fieldName, defaultValue, lowerBound, upperBound)
%CLAMPREWARDPARAM Read one reward parameter, forcing it into a safe range.

value = getNumericScalar(p.trVars, fieldName, defaultValue);
clamped = min(max(value, lowerBound), upperBound);

if clamped ~= value
    warning('SRS:RewardParameterClamped', ...
        '%s = %g is outside [%g %g]; using %g for this block.', ...
        fieldName, value, lowerBound, upperBound, clamped);
end

value = clamped;

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

function [side1Location, side2Location] = configuredSideLocations(location1, location2)
%CONFIGUREDSIDELOCATIONS Assign the two user-defined coordinates to sides.
%
% Side 1 is the rightmost configured location and side 2 is the leftmost.
% When both X coordinates are equal, the T1 setting is treated as side 1
% and the T2 setting as side 2. This preserves vertical or oblique layouts.

if any(~isfinite([location1, location2]))
    error('T1_locDegX/Y and T2_locDegX/Y must contain finite values.');
end

if location1(1) >= location2(1)
    side1Location = location1;
    side2Location = location2;
else
    side1Location = location2;
    side2Location = location1;
end

end

function coordinate = locationForSide(side, side1Location, side2Location, dimension)
%LOCATIONFORSIDE Return X or Y from the complete coordinate assigned to a side.

if side == 1
    location = side1Location;
elseif side == 2
    location = side2Location;
else
    error('SRS side must be 1 (right) or 2 (left).');
end
coordinate = location(dimension);

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
