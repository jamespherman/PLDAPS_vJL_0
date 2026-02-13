function p = nextParams(p)
%   p = nextParams(p)
%
% Defines all parameters for the upcoming trial in the Conflict Task.
% Called from conflict_task_next.m before each trial begins.
%
% Steps:
%   1. Choose a row from the trial array (determines condition)
%   2. Set trial parameters from the array
%   3. Compute target locations from angles
%   4. Calculate reward amounts based on current phase
%   5. Set background color based on hue and salience
%   6. Set timing parameters (delta-t manipulation)

%% 1. Choose a row from the trial array
p = chooseRow(p);

% Exit early if session is complete (448 trials done)
if p.trVars.exitWhileLoop
    return;
end

%% 2. Set trial parameters from the array
p = trialTypeInfo(p);

%% 3. Compute target locations from angles
p = setLocations(p);

%% 4. Calculate reward amounts for this phase
p = calculateRewards(p);

%% 5. Set background color based on hue and salience conditions
p = setBackgroundColor(p);

%% 6. Set timing parameters (including delta-t)
p = timingInfo(p);

end


%% ==================== SUBFUNCTIONS ====================

function p = chooseRow(p)
% Selects a trial from the trial array based on phase structure.
% Progresses through phases sequentially; within each phase, selects
% randomly from remaining trials.
%
% Phases:
%   1: 1:1 reward ratio (192 trials: 128 dual + 64 single-stim)
%   2: 1:2 reward ratio (128 trials)
%   3: 2:1 reward ratio (128 trials)

%% Get column indices
colNames = p.init.trialArrayColumnNames;
for i = 1:length(colNames)
    cols.(colNames{i}) = i;
end

%% Get phase values and available trial mask
phaseVals = p.init.trialsArray(:, cols.phaseNumber);
rowsPossible = p.status.trialsArrayRowsPossible;

%% Determine which phase to draw from
currentPhase = 0;
for iPhase = 1:p.init.nPhases
    if any(phaseVals == iPhase & rowsPossible)
        currentPhase = iPhase;
        break;
    end
end

if currentPhase == 0
    % All phases complete - session is done!
    fprintf('****************************************\n');
    fprintf('** All %d phases complete!            **\n', p.init.nPhases);
    fprintf('** Session finished: %d trials done.  **\n', p.init.totalTrials);
    fprintf('****************************************\n');

    p.trVars.exitWhileLoop = true;
    return;
end

%% Update phase tracking
p.status.currentPhase = currentPhase;
p.trVars.phaseNumber = currentPhase;

%% Select a random trial from the current phase's available trials
pool = (phaseVals == currentPhase & rowsPossible);
choiceIndices = find(pool);
p.trVars.currentTrialsArrayRow = ...
    choiceIndices(randi(length(choiceIndices)));

% Count completed trials in current phase
trialsCompleteInPhase = sum(phaseVals == currentPhase & ~rowsPossible);
p.status.completedTrialsInPhase = trialsCompleteInPhase;

end


function p = trialTypeInfo(p)
% Extracts trial parameters from the trial array and stores in p.trVars.

%% Build column name lookup struct
colNames = p.init.trialArrayColumnNames;
for i = 1:length(colNames)
    cols.(colNames{i}) = i;
end
currentRow = p.init.trialsArray(p.trVars.currentTrialsArrayRow, :);

%% Copy all trial parameters from array into p.trVars
p.trVars.phaseNumber        = currentRow(cols.phaseNumber);
p.trVars.trialInPhase       = currentRow(cols.trialInPhase);
p.trVars.leftLocIdx         = currentRow(cols.leftLocIdx);
p.trVars.rightLocIdx        = currentRow(cols.rightLocIdx);
p.trVars.backgroundHueIdx   = currentRow(cols.backgroundHueIdx);
p.trVars.highSalienceSide   = currentRow(cols.highSalienceSide);
p.trVars.deltaTIdx          = currentRow(cols.deltaTIdx);
p.trVars.deltaT             = currentRow(cols.deltaT);
p.trVars.singleStimSide     = currentRow(cols.singleStimSide);
p.trVars.rewardBigSide      = currentRow(cols.rewardBigSide);

%% Determine if this is a conflict trial
% Conflict = high salience side differs from high reward side
% For single-stim: N/A (only one target)
if p.trVars.singleStimSide > 0
    p.trVars.isConflict = false;  % N/A for single-stim
else
    p.trVars.isConflict = (p.trVars.rewardBigSide ~= p.trVars.highSalienceSide);
end

%% Print trial info
if p.trVars.highSalienceSide == 1
    salSideStr = 'LEFT';
else
    salSideStr = 'RIGHT';
end

if p.trVars.rewardBigSide == 1
    rwdSideStr = 'BigL';
else
    rwdSideStr = 'BigR';
end

if p.trVars.singleStimSide == 1
    singleStr = 'SINGLE-LEFT';
elseif p.trVars.singleStimSide == 2
    singleStr = 'SINGLE-RIGHT';
else
    singleStr = '';
end

if p.trVars.singleStimSide > 0
    conflictStr = '';
elseif p.trVars.isConflict
    conflictStr = 'CONFLICT';
else
    conflictStr = 'CONGRUENT';
end

R = p.trVars.rewardRatioBig;
if p.trVars.rewardBigSide == 1
    ratioStr = sprintf('%.1f:1', R);
else
    ratioStr = sprintf('1:%.1f', R);
end

trialsInThisPhase = p.init.trialsPerPhaseList(p.trVars.phaseNumber);
fprintf('Phase %d (%s), Trial %d/%d: HighSal=%s %s %s %s, dT=%+dms, Locs=[%d,%d]\n', ...
    p.trVars.phaseNumber, ratioStr, ...
    p.status.completedTrialsInPhase + 1, trialsInThisPhase, ...
    salSideStr, rwdSideStr, conflictStr, singleStr, ...
    p.trVars.deltaT, p.trVars.leftLocIdx, p.trVars.rightLocIdx);

end


function p = setLocations(p)
% Computes target locations from angles and eccentricity.
% Uses polar coordinates: angle (from rightward = 0) and eccentricity.

%% Get angle arrays
leftAngles = p.trVars.leftAngles;    % [135, 165, -165, -135]
rightAngles = p.trVars.rightAngles;  % [45, 15, -15, -45]

%% Get current target angles
leftAngle = leftAngles(p.trVars.leftLocIdx);
rightAngle = rightAngles(p.trVars.rightLocIdx);

%% Convert polar to Cartesian (degrees visual angle)
ecc = p.trVars.targetEccentricityDeg;

% Left target (in left visual field, so X will be negative)
p.trVars.leftTarg_degX = ecc * cosd(leftAngle);
p.trVars.leftTarg_degY = ecc * sind(leftAngle);

% Right target (in right visual field, so X will be positive)
p.trVars.rightTarg_degX = ecc * cosd(rightAngle);
p.trVars.rightTarg_degY = ecc * sind(rightAngle);

%% Convert fixation position from degrees to pixels
p.draw.fixPointPix = p.draw.middleXY + ...
    [1, -1] .* pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);

%% Convert target positions from degrees to pixels
p.draw.leftTargPointPix = p.draw.middleXY + ...
    [1, -1] .* pds.deg2pix([p.trVars.leftTarg_degX, p.trVars.leftTarg_degY], p);

p.draw.rightTargPointPix = p.draw.middleXY + ...
    [1, -1] .* pds.deg2pix([p.trVars.rightTarg_degX, p.trVars.rightTarg_degY], p);

%% Convert window sizes from degrees to pixels
p.draw.fixWinWidthPix = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix = pds.deg2pix(p.trVars.fixWinHeightDeg, p);
p.draw.targWinWidthPix = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix = pds.deg2pix(p.trVars.targWinHeightDeg, p);

end


function p = calculateRewards(p)
% Calculates reward durations based on per-trial rewardBigSide assignment.
%
% Uses rewardBigSide (from trial array) and rewardRatioBig (from settings)
% to determine left/right reward durations.
%   rewardBigSide=1: leftRatio=rewardRatioBig, rightRatio=1
%   rewardBigSide=2: leftRatio=1, rightRatio=rewardRatioBig

C = p.trVars.rewardDurationMs;
R = p.trVars.rewardRatioBig;

if p.trVars.rewardBigSide == 1
    leftRatio = R;
    rightRatio = 1;
else
    leftRatio = 1;
    rightRatio = R;
end

p.trVars.rewardRatioLeft = leftRatio;
p.trVars.rewardRatioRight = rightRatio;

totalRatio = leftRatio + rightRatio;
p.trVars.rewardDurationLeft = round(C * leftRatio / totalRatio);
p.trVars.rewardDurationRight = round(C * rightRatio / totalRatio);

end


function p = setBackgroundColor(p)
% Sets the background color and target hues based on backgroundHueIdx.
%
% Salience is created by hue contrast with background:
%   - High-salience target: hue 180° away from background (max contrast)
%   - Low-salience target: hue 45° away from background (low contrast)
%
% DKL Color Assignments:
%   backgroundHueIdx = 1 (Hue A):
%     - Background: 0° DKL
%     - High salience target: 180° DKL (180° from BG)
%     - Low salience target: 45° DKL (45° from BG)
%   backgroundHueIdx = 2 (Hue B):
%     - Background: 180° DKL
%     - High salience target: 0° DKL (180° from BG)
%     - Low salience target: 225° DKL (45° from BG)
%
% Which target (left or right) gets which hue is determined by
% p.trVars.highSalienceSide (1=left, 2=right).

bgHueIdx = p.trVars.backgroundHueIdx;

if bgHueIdx == 1
    % Hue A: Background at 0° DKL
    p.draw.color.background = p.draw.clutIdx.expDkl0_subDkl0;
    p.trVars.highSalienceHueIdx = p.draw.clutIdx.expDkl180_subDkl180;  % 180° from BG
    p.trVars.lowSalienceHueIdx = p.draw.clutIdx.expDkl45_subDkl45;      % 45° from BG
else
    % Hue B: Background at 180° DKL
    p.draw.color.background = p.draw.clutIdx.expDkl180_subDkl180;
    p.trVars.highSalienceHueIdx = p.draw.clutIdx.expDkl0_subDkl0;       % 180° from BG
    p.trVars.lowSalienceHueIdx = p.draw.clutIdx.expDkl225_subDkl225;    % 45° from BG
end

% Assign hues to left/right targets based on highSalienceSide
if p.trVars.highSalienceSide == 1
    % Left target is high salience
    p.trVars.leftTargHueIdx = p.trVars.highSalienceHueIdx;
    p.trVars.rightTargHueIdx = p.trVars.lowSalienceHueIdx;
else
    % Right target is high salience
    p.trVars.leftTargHueIdx = p.trVars.lowSalienceHueIdx;
    p.trVars.rightTargHueIdx = p.trVars.highSalienceHueIdx;
end

end


function p = timingInfo(p)
% Sets all timing parameters including the delta-t manipulation.
%
% Key timing relationships:
%   timeGoSignal = random fixation hold duration (1.0-1.4s from fixAq)
%   timeStimOnset = timeGoSignal + deltaT (deltaT in seconds)
%
% For negative deltaT: stimuli appear BEFORE go signal
% For positive deltaT: stimuli appear AFTER go signal

%% Random fixation hold duration (time to go signal from fixation acquisition)
p.trVars.timeGoSignal = unifrnd(...
    p.trVars.fixHoldDurationMin, p.trVars.fixHoldDurationMax);

%% Calculate stimulus onset time relative to fixation acquisition
% timeStimOnset = timeGoSignal + deltaT (convert deltaT from ms to s)
deltaTSec = p.trVars.deltaT / 1000;
p.trVars.timeStimOnset = p.trVars.timeGoSignal + deltaTSec;

% Note: timeStimOnset can be less than timeGoSignal (for negative deltaT),
% meaning stimuli appear before the go signal

%% Target hold duration (after saccade lands)
p.trVars.targHoldDuration = unifrnd(...
    p.trVars.targHoldDurationMin, p.trVars.targHoldDurationMax);

%% Initialize stimulus and fixation visibility
p.trVars.stimuliVisible = false;
p.trVars.fixationVisible = true;

%% Set response window (time allowed to initiate saccade after go signal)
% Already set in settings, but ensure goLatencyMax matches responseWindow
p.trVars.goLatencyMax = p.trVars.responseWindow;

end
