function p = nextParams(p)
%   p = nextParams(p)
%
% Defines all parameters for the upcoming trial in the gSac_4factors task.
% Called from gSac_4factors_next.m before each trial begins.
%
% Steps:
%   1. Choose a row from the trial array (determines condition)
%   2. Set trial type info and select the stimulus
%   3. Set target locations in visual coordinates
%   4. Set timing parameters for this trial

%% 1. Choose a row from the trial array
p = chooseRow(p);

% Exit early if trial array is exhausted
if p.trVars.exitWhileLoop
    return;
end

%% 2. Set trial type info and select the stimulus
p = trialTypeInfo(p);

%% 3. Set target locations
p = setLocations(p);

%% 4. Set timing parameters
p = timingInfo(p);

end


%% ==================== SUBFUNCTIONS ====================

function p = trialTypeInfo(p)
% Sets stimulus type, selects texture, and updates CLUT for this trial.
% Reads factorial conditions from trial array and copies to trVars.

% Build column name lookup struct for readable array indexing
colNames = p.init.trialArrayColumnNames;
for i = 1:length(colNames)
    cols.(colNames{i}) = i;
end
currentRow = p.init.trialsArray(p.trVars.currentTrialsArrayRow, :);

% Copy all factorial conditions from trial array into p.trVars
p.trVars.halfBlock    = currentRow(cols.halfBlock);
p.trVars.targetLocIdx = currentRow(cols.targetLocIdx);
p.trVars.stimType     = currentRow(cols.stimType);
p.trVars.salience     = currentRow(cols.salience);
p.trVars.reward       = currentRow(cols.reward);
p.trVars.targetColor  = currentRow(cols.targetColor);
p.trVars.trialCode    = currentRow(cols.trialCode);

% Set stimulus parameters based on stimulus type
if p.trVars.stimType <= 2
    % Image trial (face or non-face)
    p.stim.isProcedural = false;
    if p.trVars.stimType == 1
        % Face stimulus - select random face texture
        rand_idx = randi(length(p.stim.faceTextures));
        p.stim.currentTexture = p.stim.faceTextures(rand_idx);
    else
        % Non-face stimulus - select random non-face texture
        rand_idx = randi(length(p.stim.nonFaceTextures));
        p.stim.currentTexture = p.stim.nonFaceTextures(rand_idx);
    end
else
    % Bullseye trial - procedurally drawn, no texture needed
    p.stim.isProcedural = true;
    p.stim.currentTexture = [];
end

% This task is always memory-guided (target disappears before go signal)
p.trVars.isVisSac = 0;

% Update CLUT for this trial's background color
p = updateTrialClut(p);

end


function p = updateTrialClut(p)
% Updates the color lookup table (CLUT) for this trial.
% Sets background color and ensures subject-invisible elements match
% the background so they remain hidden.

% Get default CLUTs from initialization
expCLUT = p.draw.clut.expCLUT;
subCLUT = p.draw.clut.subCLUT;

% Determine background color index based on stimulus type
switch p.trVars.stimType
    case {1, 2}
        % Image trial: grey background
        p.draw.color.background = p.draw.clutIdx.expGrey_subBg;
    case 3
        % Bullseye: High salience, Target 0 deg DKL hue
        p.draw.color.background = p.draw.clutIdx.expDkl180_subDkl180;
    case 4
        % Bullseye: Low salience, Target 0 deg DKL hue
        p.draw.color.background = p.draw.clutIdx.expDkl45_subDkl45;
    case 5
        % Bullseye: High salience, Target 180 deg DKL hue
        p.draw.color.background = p.draw.clutIdx.expDkl0_subDkl0;
    case 6
        % Bullseye: Low salience, Target 180 deg DKL hue
        p.draw.color.background = p.draw.clutIdx.expDkl225_subDkl225;
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


function p = chooseRow(p)
% Selects a trial from the trial array based on half-block structure.
% Progresses sequentially through half-blocks, resetting when complete.

%% Get half-block values and available trial mask
halfBlockCol = strcmp(p.init.trialArrayColumnNames, 'halfBlock');
halfBlockVals = p.init.trialsArray(:, halfBlockCol);
rowsPossible = p.status.trialsArrayRowsPossible;

%% Determine which half-block pool to draw from
if any(halfBlockVals == 1 & rowsPossible)
    % Half-block 1 has available trials
    pool = (halfBlockVals == 1 & rowsPossible);

elseif any(halfBlockVals == 2 & rowsPossible)
    % Half-block 2 has available trials
    pool = (halfBlockVals == 2 & rowsPossible);

elseif any(halfBlockVals == 3 & rowsPossible)
    % Half-block 3 has available trials
    pool = (halfBlockVals == 3 & rowsPossible);

elseif any(halfBlockVals == 4 & rowsPossible)
    % Half-block 4 has available trials
    pool = (halfBlockVals == 4 & rowsPossible);

else
    % All half-blocks complete - reset for next loop
    fprintf('****************************************\n');
    fprintf('** Full 2-block structure complete.  **\n');
    fprintf('** Resetting and starting next loop.  **\n');
    fprintf('****************************************\n');

    % Reset all trials to available
    p.status.trialsArrayRowsPossible = ...
        true(size(p.init.trialsArray, 1), 1);

    % Start from half-block 1
    pool = (halfBlockVals == 1);
end

%% Randomly select one trial from the pool
choiceIndices = find(pool);
p.trVars.currentTrialsArrayRow = ...
    choiceIndices(randi(length(choiceIndices)));

end


function p = setLocations(p)
% Computes target location based on base position and rotation scheme.
% Four locations are generated by rotating the base position in 90 deg
% increments. The targetLocIdx from the trial array selects which one.

% Get base target position from settings
baseX = p.trVars.targDegX_base;
baseY = p.trVars.targDegY_base;

% Convert to polar coordinates for rotation
[theta_rad, r] = cart2pol(baseX, baseY);

% Determine rotation direction based on quadrant
if sign(baseX) == sign(baseY)
    rotation_deg = -90;
else
    rotation_deg = 90;
end
rotation_rad = deg2rad(rotation_deg);

% Generate all 4 target locations by rotating base position
locations = zeros(4, 2);
for i = 1:4
    current_rotation = theta_rad + ((i-1) * rotation_rad);
    [x, y] = pol2cart(current_rotation, r);
    locations(i, :) = [x, y];
end

% Get target location index from trial array
locIdxCol = strcmp(p.init.trialArrayColumnNames, 'targetLocIdx');
p.trVars.targetLocIdx = ...
    p.init.trialsArray(p.trVars.currentTrialsArrayRow, locIdxCol);

% Store target position for this trial
p.stim.targetPos = locations(p.trVars.targetLocIdx, :);
p.trVars.targDegX = p.stim.targetPos(1);
p.trVars.targDegY = p.stim.targetPos(2);

% Convert fixation position from degrees to pixels
p.draw.fixPointPix = p.draw.middleXY + ...
    [1, -1] .* pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);

% Convert target position from degrees to pixels
p.draw.targPointPix = p.draw.middleXY + ...
    [1, -1] .* pds.deg2pix(p.stim.targetPos, p);

% Convert window sizes from degrees to pixels
p.draw.fixWinWidthPix = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix = pds.deg2pix(p.trVars.fixWinHeightDeg, p);
p.draw.targWinWidthPix = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix = pds.deg2pix(p.trVars.targWinHeightDeg, p);

% Convert target position to strobeable integer values
[tmpTheta, tmpRadius] = ...
    cart2pol(p.stim.targetPos(1), p.stim.targetPos(2));
p.trVars.targTheta_x10 = round(mod(rad2deg(tmpTheta), 360) * 10);
p.trVars.targRadius_x100 = round(tmpRadius * 100);

end


function p = timingInfo(p)
% Sets all timing parameters for the memory-guided saccade task.
% Times are in seconds, relative to fixation acquisition.

% Time from fixation acquisition to target onset (uniformly distributed)
p.trVars.timeTargOnset = unifrnd(...
    p.trVars.targOnsetMin, p.trVars.targOnsetMax);

% Time from fixation acquisition to target offset (fixed flash duration)
p.trVars.timeTargOffset = p.trVars.timeTargOnset + ...
    p.trVars.targetFlashDuration;

% Time from fixation acquisition to fixation offset (go signal)
% This defines the memory delay period
p.trVars.timeFixOffset = p.trVars.timeTargOnset + ...
    unifrnd(p.trVars.goTimePostTargMin, p.trVars.goTimePostTargMax);

% Duration to hold fixation on target after saccade lands
p.trVars.targHoldDuration = unifrnd(...
    p.trVars.targHoldDurationMin, p.trVars.targHoldDurationMax);

% Set reward duration based on trial condition (high or low reward)
rewardCol = strcmp(p.init.trialArrayColumnNames, 'reward');
p.trVars.reward = ...
    p.init.trialsArray(p.trVars.currentTrialsArrayRow, rewardCol);
if p.trVars.reward == 1
    p.trVars.rewardDurationMs = p.trVars.rewardDurationHigh;
else
    p.trVars.rewardDurationMs = p.trVars.rewardDurationLow;
end

% This task is always memory-guided (not visually-guided)
p.trVars.isVisSac = false;

end
