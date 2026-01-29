function p = nextParams(p)
%   p = nextParams(p)
%
% Defines all parameters for the upcoming trial in the Conflict Task.
% Called from conflict_task_next.m before each trial begins.
%
% Steps:
%   1. Choose a row from the trial array (determines condition)
%   2. Set trial parameters from the array
%   3. Compute target locations (A and B)
%   4. Set timing parameters (delta-t manipulation)

%% 1. Choose a row from the trial array
p = chooseRow(p);

% Exit early if trial array is exhausted (shouldn't happen - loops forever)
if p.trVars.exitWhileLoop
    return;
end

%% 2. Set trial parameters from the array
p = trialTypeInfo(p);

%% 3. Update CLUT for this trial's background color (based on salience)
p = updateTrialClut(p);

%% 4. Compute target locations
p = setLocations(p);

%% 5. Set timing parameters (including delta-t)
p = timingInfo(p);

end


%% ==================== SUBFUNCTIONS ====================

function p = chooseRow(p)
% Selects a trial from the trial array based on block structure.
% Progresses through blocks sequentially; within each block, selects
% randomly from remaining trials.

%% Get column indices
colNames = p.init.trialArrayColumnNames;
for i = 1:length(colNames)
    cols.(colNames{i}) = i;
end

%% Get block values and available trial mask
blockVals = p.init.trialsArray(:, cols.blockNumber);
rowsPossible = p.status.trialsArrayRowsPossible;

%% Determine which block to draw from
currentBlock = 0;
for iBlock = 1:6
    if any(blockVals == iBlock & rowsPossible)
        currentBlock = iBlock;
        break;
    end
end

if currentBlock == 0
    % All blocks complete - this shouldn't happen with trial repetition
    % Reset for new session loop
    fprintf('****************************************\n');
    fprintf('** All 6 blocks complete!             **\n');
    fprintf('** Resetting trial array.             **\n');
    fprintf('****************************************\n');

    p.status.trialsArrayRowsPossible = true(size(p.init.trialsArray, 1), 1);
    currentBlock = 1;
end

%% Update block counter
p.status.iBlock = currentBlock;

%% Select a random trial from the current block's available trials
pool = (blockVals == currentBlock & rowsPossible);
choiceIndices = find(pool);
p.trVars.currentTrialsArrayRow = ...
    choiceIndices(randi(length(choiceIndices)));

% Update trial-in-block counter
trialsCompleteInBlock = sum(blockVals == currentBlock & ~rowsPossible);
p.status.iTrialInBlock = trialsCompleteInBlock + 1;

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
p.trVars.blockNumber        = currentRow(cols.blockNumber);
p.trVars.trialInBlock       = currentRow(cols.trialInBlock);
p.trVars.trialType          = currentRow(cols.trialType);
p.trVars.deltaTIdx          = currentRow(cols.deltaTIdx);
p.trVars.deltaT             = currentRow(cols.deltaT);
p.trVars.highRewardLocation = currentRow(cols.highRewardLoc);
p.trVars.highSalienceLocation = currentRow(cols.highSalienceLoc);
p.trVars.hueType            = currentRow(cols.hueType);

%% Print trial info
if p.trVars.trialType == 1
    typeStr = 'CONFLICT';
else
    typeStr = 'CONGRUENT';
end

if p.trVars.highRewardLocation == 1
    rwdLocStr = 'A';
else
    rwdLocStr = 'B';
end

fprintf('Block %d, Trial %d: %s, deltaT=%+dms, HighRwd=%s, HueType=%d\n', ...
    p.trVars.blockNumber, p.status.iTrialInBlock, typeStr, ...
    p.trVars.deltaT, rwdLocStr, p.trVars.hueType);

end


function p = updateTrialClut(p)
% Updates the color lookup table (CLUT) for this trial.
% Sets background color based on hueType (NOT highSalienceLocation) to
% ensure background color is counterbalanced and not predictive of
% which target will be high salience.
%
% Salience contrast definition (matching gSac_4factors):
%   - High salience target: 180 degrees away from background
%   - Low salience target: 45 degrees away from background
%
% Color schemes (hueType determines background, independent of salience location):
%   hueType == 1:
%       Background = 0 deg DKL
%       High salience target = 180 deg DKL (180 deg contrast)
%       Low salience target = 45 deg DKL (45 deg contrast)
%
%   hueType == 2:
%       Background = 180 deg DKL
%       High salience target = 0 deg DKL (180 deg contrast)
%       Low salience target = 225 deg DKL (45 deg contrast)

% Get default CLUTs from initialization
expCLUT = p.draw.clut.expCLUT;
subCLUT = p.draw.clut.subCLUT;

% Determine background color based on hueType (counterbalanced across trials)
if p.trVars.hueType == 1
    % Hue scheme 1: 0 deg DKL background
    p.draw.color.background = p.draw.clutIdx.expDkl0_subDkl0;
else
    % Hue scheme 2: 180 deg DKL background
    p.draw.color.background = p.draw.clutIdx.expDkl180_subDkl180;
end

% Get RGB value for chosen background (CLUT is 0-indexed, MATLAB is 1)
current_bg_color_rgb = expCLUT(p.draw.color.background + 1, :);

% Update subject CLUT rows that should be invisible (match background)
% Uses pre-compiled list of row indices from initClut.m
subCLUT(p.draw.clut.subBg_rows, :) = ...
    repmat(current_bg_color_rgb, length(p.draw.clut.subBg_rows), 1);

% Upload updated CLUTs to VIEWPixx hardware
Datapixx('SetVideoClut', [subCLUT; expCLUT]);

% Store updated subCLUT for reference
p.draw.clut.subCLUT = subCLUT;

end


function p = setLocations(p)
% Computes target locations A and B.
% Location A is experimenter-specified (from GUI or settings).
% Location B is the 180-degree rotation of A.

%% Get Location A from settings/GUI
p.trVars.targA_degX = p.trVars.locationA_x;
p.trVars.targA_degY = p.trVars.locationA_y;

%% Compute Location B as 180-degree rotation of A
% B = -A (opposite side of fixation)
p.trVars.targB_degX = -p.trVars.targA_degX;
p.trVars.targB_degY = -p.trVars.targA_degY;

%% Convert fixation position from degrees to pixels
p.draw.fixPointPix = p.draw.middleXY + ...
    [1, -1] .* pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);

%% Convert target positions from degrees to pixels
p.draw.targAPointPix = p.draw.middleXY + ...
    [1, -1] .* pds.deg2pix([p.trVars.targA_degX, p.trVars.targA_degY], p);

p.draw.targBPointPix = p.draw.middleXY + ...
    [1, -1] .* pds.deg2pix([p.trVars.targB_degX, p.trVars.targB_degY], p);

%% Convert window sizes from degrees to pixels
p.draw.fixWinWidthPix = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix = pds.deg2pix(p.trVars.fixWinHeightDeg, p);
p.draw.targWinWidthPix = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix = pds.deg2pix(p.trVars.targWinHeightDeg, p);

%% Convert Location A to polar coordinates for strobing (same as gSac_4factors)
% Location B is always 180 deg opposite, so only A needs to be recorded
[tmpTheta, tmpRadius] = cart2pol(p.trVars.targA_degX, p.trVars.targA_degY);
p.trVars.targTheta_x10 = round(mod(rad2deg(tmpTheta), 360) * 10);
p.trVars.targRadius_x100 = round(tmpRadius * 100);

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
