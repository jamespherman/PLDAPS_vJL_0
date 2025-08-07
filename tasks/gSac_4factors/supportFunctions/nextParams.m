function p = nextParams(p)
%
% p = nextParams(p)
%
% Define parameters for upcoming trial.

% if we're using p.init.trialsArray to determine target locations, do the
% book keeping for that here:
if p.trVars.setTargLocViaTrialArray
    p = chooseRow(p);
end

% Trial type information:
% vis- or mem-guided saccade
p = trialTypeInfo(p);

% set fixation and target locations for next trial:
p = setLocations(p);

% Timing info:
% target onset/offset time
p = timingInfo(p);

end

function p = redefClut(p)
% redefClut
%
% EFFICIENT VERSION: Only calculates the dynamic stimulus ramp and assembles
% the final CLUTs from pre-built static portions.

%% 1. Calculate dynamic colors and ramp for this trial
screenBackgroundColor = p.draw.colors.isolumGray;
dkl_palette_rgb = p.draw.colors.dklPalette_rgb;
dkl_palette_dkl = p.draw.colors.dklPalette_dkl;
% ... (The logic for generating the 'stim_ramp' based on salience remains the same)
if p.trVars.targetColor == 1, target_hue_idx = 1; else, target_hue_idx = 3; end
targetColor_dkl = dkl_palette_dkl(target_hue_idx, :)';
if p.trVars.salience == 1, ramp_start_idx = mod(target_hue_idx + 4 - 1, 8) + 1; else, ramp_start_idx = mod(target_hue_idx + 1 - 1, 8) + 1; end
rampStartColor_dkl = dkl_palette_dkl(ramp_start_idx, :)';
n_stim_levels = p.stim.nStimLevels;
dkl_origin = [mean(p.rig.dklLum); 0; 0];
if p.trVars.salience == 1
    dkl_ramp = interp1([0, 1], [rampStartColor_dkl, targetColor_dkl]', linspace(0, 1, n_stim_levels));
else
    half_ramp_levels = n_stim_levels / 2;
    ramp_part1 = interp1([0, 1], [rampStartColor_dkl, dkl_origin]', linspace(0, 1, half_ramp_levels));
    ramp_part2 = interp1([0, 1], [dkl_origin, targetColor_dkl]', linspace(0, 1, half_ramp_levels));
    dkl_ramp = [ramp_part1; ramp_part2];
end
stim_ramp_rgb = zeros(n_stim_levels, 3);
for i = 1:n_stim_levels, [r, g, b] = dkl2rgb(dkl_ramp(i, :)'); stim_ramp_rgb(i, :) = [r, g, b]; end

%% 2. Assemble the full CLUTs
% Start with the static portions we built in initClut
expCLUT = [p.draw.clut.static_expCLUT; zeros(239, 3)];
subCLUT = [p.draw.clut.static_subCLUT; zeros(239, 3)];

% Insert the dynamic background and ramp
idx = p.draw.clutIdx;
ramp_indices = (idx.stimStart:idx.stimEnd) + 1;

expCLUT(ramp_indices, :) = stim_ramp_rgb;
subCLUT(ramp_indices, :) = stim_ramp_rgb;
expCLUT(idx.stimBg + 1, :) = screenBackgroundColor;
subCLUT(idx.stimBg + 1, :) = screenBackgroundColor;

%% 3. Upload the final CLUTs to the VIEWPixx
Datapixx('SetVideoClut', [subCLUT; expCLUT]);

% Also update the p struct so the run function has the latest version
p.draw.clut.expCLUT = expCLUT;
p.draw.clut.subCLUT = subCLUT;

end

%
function p = trialTypeInfo(p)
% trialTypeInfo
%
% Reads all factorial conditions from the trialsArray for the current trial,
% copies them to p.trVars, and then calls redefClut to build the CLUT.

% For convenience, create a struct to access columns by name
colNames = p.init.trialArrayColumnNames;
for i = 1:length(colNames)
    cols.(colNames{i}) = i;
end
currentRow = p.init.trialsArray(p.trVars.currentTrialsArrayRow, :);

% Copy all factorial conditions into p.trVars for easy access and saving
p.trVars.halfBlock    = currentRow(cols.halfBlock);
p.trVars.targetLocIdx = currentRow(cols.targetLocIdx);
p.trVars.stimType     = currentRow(cols.stimType);
p.trVars.salience     = currentRow(cols.salience);
p.trVars.reward       = currentRow(cols.reward);
p.trVars.targetColor  = currentRow(cols.targetColor);
p.trVars.trialCode    = currentRow(cols.trialCode);

% --- Set Stimulus Parameters ---
p.stim.isProceduralSpot = false; % Default to texture-based stimulus

if p.trVars.stimType == 1 % Face
    rand_idx = randi(length(p.stim.faceTextures));
    p.stim.currentTexture = p.stim.faceTextures(rand_idx);
elseif p.trVars.stimType == 2 % Non-Face
    rand_idx = randi(length(p.stim.nonFaceTextures));
    p.stim.currentTexture = p.stim.nonFaceTextures(rand_idx);
elseif p.trVars.stimType == 3 % Spot
    % Set a flag to draw a procedural spot instead of a texture
    p.stim.isProceduralSpot = true;
    p.stim.currentTexture = [];
end

% This task is always memory-guided, not visually-guided
p.trVars.isVisSac = 0;

% Now that the trial conditions (p.trVars.salience, p.trVars.targetColor)
% are set, we can build and upload the specific CLUT for this trial.
p = redefClut(p);

end

% function p = setTargetLocation(p)
function p = setLocations(p)

% Convert base location to polar coordinates for easy rotation
[theta_rad, r] = cart2pol(p.trVars.targDegX, p.trVars.targDegY);

% --- Determine rotation direction based on quadrant ---
% If signs of X and Y are the same (upper-right or lower-left quadrants),
% the rotation is clockwise. Otherwise, it's counter-clockwise.
if sign(p.trVars.targDegX) == sign(p.trVars.targDegY)
    rotation_deg = -90; % Clockwise
else
    rotation_deg = 90;  % Counter-clockwise
end
rotation_rad = deg2rad(rotation_deg);

% --- Define the four potential target locations by rotation ---
locations = zeros(4, 2);
for i = 1:4
    % Rotation angles are 0, 1, 2, and 3 steps of the rotation amount
    current_rotation = theta_rad + ( (i-1) * rotation_rad );
    [x, y] = pol2cart(current_rotation, r);
    locations(i, :) = [x, y];
end

% Get the target location index for the current trial
locIdxCol = strcmp(p.init.trialArrayColumnNames, 'targetLocIdx');
currentTargetLocIdx = p.init.trialsArray(...
    p.trVars.currentTrialsArrayRow, locIdxCol);

% Set the final target position for this trial
currentTargDeg = locations(currentTargetLocIdx, :);
p.trVars.targDegX = currentTargDeg(1);
p.trVars.targDegY = currentTargDeg(2);

% --- Convert to pixels and strobe values (this logic is preserved) ---
p.draw.fixPointPix  = p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);
p.draw.targPointPix = p.draw.middleXY + [1, -1] .* ...
    pds.deg2pix([p.trVars.targDegX, p.trVars.targDegY], p);

% fixation window width and height in pixels.
p.draw.fixWinWidthPix       = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix      = pds.deg2pix(p.trVars.fixWinHeightDeg, p);

% target window width and height in pixels.
p.draw.targWinWidthPix      = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix     = pds.deg2pix(p.trVars.targWinHeightDeg, p);

[tmpTheta, tmpRadius] = cart2pol(p.trVars.targDegX, p.trVars.targDegY);
p.trVars.targTheta_x10  = round(mod(rad2deg(tmpTheta), 360) * 10);
p.trVars.targRadius_x100 = round(tmpRadius * 100);

end

%
function p = timingInfo(p)

% time of target onset wrt fixAcq:
p.trVars.timeTargOnset       = unifrnd(p.trVars.targOnsetMin, ...
    p.trVars.targOnsetMax);

% time of target offset wrt fixAcq:
% This is always a memory-guided saccade task with a fixed flash duration.
p.trVars.timeTargOffset = p.trVars.timeTargOnset + ...
    p.trVars.targetFlashDuration;

% time of fix offset wrt fix acquired:
p.trVars.timeFixOffset      = p.trVars.timeTargOnset + ...
    unifrnd(p.trVars.goTimePostTargMin, p.trVars.goTimePostTargMax);

% target fixation duration required
p.trVars.targHoldDuration =  unifrnd(p.trVars.targHoldDurationMin, ...
    p.trVars.targHoldDurationMax);

% --- timingInfo subfunction (inside nextParams.m) ---
% ... (top part of the function is unchanged) ...

% time of target offset wrt fixAcq:
% This is always a memory-guided saccade task with a fixed flash duration.
p.trVars.timeTargOffset = p.trVars.timeTargOnset + ...
    p.trVars.targetFlashDuration;

% ... (timeFixOffset and targHoldDuration are unchanged) ...

% reward duration depends on whether this is a "high" or "low" reward trial.
rewardCol = strcmp(p.init.trialArrayColumnNames, 'reward');
if p.init.trialsArray(p.trVars.currentTrialsArrayRow, rewardCol) == 1
    p.trVars.rewardDurationMs = p.trVars.rewardDurationHigh;
else
    p.trVars.rewardDurationMs = p.trVars.rewardDurationLow;
end

end

% --- Simplified chooseRow Subfunction ---
function p = chooseRow(p)

% On the first trial, initialize the half-block counter
if ~isfield(p.trVars, 'currentTrialsArrayRow') || isempty(p.trVars.currentTrialsArrayRow)
    p.trVars.halfBlockToCheck = 1;
end

% Find all possible trials for the current half-block
col_hb = strcmp(p.init.trialArrayColumnNames, 'halfBlock');
trialsPossible = p.status.trialsArrayRowsPossible & ...
    p.init.trialsArray(:, col_hb) == p.trVars.halfBlockToCheck;

% If no trials are left in this half-block, advance the counter and try again
if ~any(trialsPossible)
    p.trVars.halfBlockToCheck = p.trVars.halfBlockToCheck + 1;
    trialsPossible = p.status.trialsArrayRowsPossible & ...
        p.init.trialsArray(:, col_hb) == p.trVars.halfBlockToCheck;
end

% If no trials are left in the whole experiment, exit
if ~any(trialsPossible)
    p.trVars.exitWhileLoop = true;
    p.pldaps.finish = true;
    return;
end

% Select one of the possible trials for this half-block at random
choicePool = find(trialsPossible);
p.trVars.currentTrialsArrayRow = choicePool(randi(length(choicePool)));

end
