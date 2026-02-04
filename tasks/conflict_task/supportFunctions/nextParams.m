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

% Exit early if session is complete (384 trials done)
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
%   1: 1:1 reward ratio (trials 1-128)
%   2: 1:2 reward ratio (trials 129-256)
%   3: 2:1 reward ratio (trials 257-384)

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

%% Determine if this is a conflict trial (for phases 2-3)
% Phase 2: high reward on RIGHT, so conflict = high salience LEFT
% Phase 3: high reward on LEFT, so conflict = high salience RIGHT
if p.trVars.phaseNumber == 1
    p.trVars.isConflict = false;  % N/A for phase 1 (equal rewards)
elseif p.trVars.phaseNumber == 2
    % 1:2 ratio: high reward RIGHT
    p.trVars.isConflict = (p.trVars.highSalienceSide == 1);  % conflict if sal LEFT
elseif p.trVars.phaseNumber == 3
    % 2:1 ratio: high reward LEFT
    p.trVars.isConflict = (p.trVars.highSalienceSide == 2);  % conflict if sal RIGHT
end

%% Print trial info
if p.trVars.highSalienceSide == 1
    salSideStr = 'LEFT';
else
    salSideStr = 'RIGHT';
end

if p.trVars.phaseNumber == 1
    conflictStr = '';
    ratioStr = '1:1';
elseif p.trVars.phaseNumber == 2
    conflictStr = p.trVars.isConflict * 'CONFLICT' + ~p.trVars.isConflict * 'CONGRUENT';
    if p.trVars.isConflict
        conflictStr = 'CONFLICT';
    else
        conflictStr = 'CONGRUENT';
    end
    ratioStr = '1:2';
else
    if p.trVars.isConflict
        conflictStr = 'CONFLICT';
    else
        conflictStr = 'CONGRUENT';
    end
    ratioStr = '2:1';
end

fprintf('Phase %d (%s), Trial %d/%d: HighSal=%s %s, dT=%+dms, Locs=[%d,%d]\n', ...
    p.trVars.phaseNumber, ratioStr, ...
    p.status.completedTrialsInPhase + 1, p.init.trialsPerPhase, ...
    salSideStr, conflictStr, ...
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
% Calculates reward durations based on the current phase's ratio.
%
% Phase 1: 1:1 -> 195ms : 195ms
% Phase 2: 1:2 -> 130ms : 260ms
% Phase 3: 2:1 -> 260ms : 130ms

%% Get reward ratios for current phase
ratios = p.init.phaseRewardRatios(p.trVars.phaseNumber, :);
leftRatio = ratios(1);
rightRatio = ratios(2);

%% Store current ratios
p.trVars.rewardRatioLeft = leftRatio;
p.trVars.rewardRatioRight = rightRatio;

%% Calculate reward durations
C = p.trVars.rewardDurationMs;  % Total budget (390ms)
totalRatio = leftRatio + rightRatio;

p.trVars.rewardDurationLeft = round(C * leftRatio / totalRatio);
p.trVars.rewardDurationRight = round(C * rightRatio / totalRatio);

end


function p = setBackgroundColor(p)
% Sets the background color based on backgroundHueIdx and highSalienceSide.
%
% Background Hue System (DKL color space):
%   backgroundHueIdx = 1 (Hue A): Target hue is 0 deg DKL
%     - High salience background: 180 deg DKL (max contrast)
%     - Low salience background: 45 deg DKL (low contrast)
%   backgroundHueIdx = 2 (Hue B): Target hue is 180 deg DKL
%     - High salience background: 0 deg DKL (max contrast)
%     - Low salience background: 225 deg DKL (low contrast)
%
% The background is set to create high salience for one target and
% low salience for the other. Since both targets have the same hue,
% the background determines which appears more salient.

bgHueIdx = p.trVars.backgroundHueIdx;
highSalSide = p.trVars.highSalienceSide;

% Determine which background hue creates the desired salience pattern
% The background should be 180 deg offset from the high-salience target's hue

if bgHueIdx == 1
    % Hue A condition: target hue = 0 deg DKL
    % High salience needs background at 180 deg (opposite)
    % We use 180 deg background so target at 0 deg has high contrast
    p.draw.color.background = p.draw.clutIdx.expDkl180_subDkl180;
    p.trVars.targetHueIdx = p.draw.clutIdx.expDkl0_subDkl0;
else
    % Hue B condition: target hue = 180 deg DKL
    % High salience needs background at 0 deg (opposite)
    p.draw.color.background = p.draw.clutIdx.expDkl0_subDkl0;
    p.trVars.targetHueIdx = p.draw.clutIdx.expDkl180_subDkl180;
end

% Store which side has high/low salience for drawing
p.trVars.highSalienceSide = highSalSide;  % 1=left, 2=right

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
