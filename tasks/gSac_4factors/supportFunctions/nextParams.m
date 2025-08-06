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
% Explicitly defines and uploads the Experimenter and Subject CLUTs for
% the upcoming trial based on the "Single Hue Ramp" model.

%% 1. Select the Target and Background Hues for this trial
dkl_palette = p.draw.colors.dklPalette;

% Map the 'targetColor' condition (1 or 2) to a DKL palette index
% Example: Color 1 -> 0 deg (Red-ish), Color 2 -> 90 deg (Green-ish)
if p.trVars.targetColor == 1
    target_hue_idx = 1; % 0 degrees
else
    target_hue_idx = 3; % 90 degrees
end
targetHue_rgb = dkl_palette(target_hue_idx, :);

% Determine the background hue index based on the salience condition
if p.trVars.salience == 1 % High Salience (180 deg rotation)
    bg_hue_idx = mod(target_hue_idx + 4 - 1, 8) + 1;
else % Low Salience (45 deg rotation)
    bg_hue_idx = mod(target_hue_idx + 1 - 1, 8) + 1;
end
backgroundHue_rgb = dkl_palette(bg_hue_idx, :);

%% 2. Generate the "Single Hue Ramp" for the stimulus
n_stim_levels = 238; % Reserving indices 18-255
isolum_gray = p.draw.colors.isolumGray;
stim_ramp = interp1([0, 1], [isolum_gray; targetHue_rgb], ...
    linspace(0, 1, n_stim_levels));

%% 3. Explicitly define the CLUTs
% Pre-allocate full 256x3 matrices
expCLUT = zeros(256, 3);
subCLUT = zeros(256, 3);

% Define some named colors for the static entries
mutGreen    = [0.5 0.9 0.4];
redISH      = [225 0 76]/255;
orangeISH   = [255 146 0]/255;
blueISH     = [11 97 164]/255;
oldGreen    = [0.45, 0.63, 0.45];

% --- Fill static entries (0-16) based on clutIdx from settings ---
% Note: MATLAB uses 1-based indexing, so we add 1 to each clutIdx
idx = p.draw.clutIdx;

% Experimenter CLUT (visible colors)
expCLUT(idx.expBlack_subBlack + 1, :)       = [0 0 0];
expCLUT(idx.expGrey25_subBg + 1, :)         = [0.25 0.25 0.25];
expCLUT(idx.expBg_subBg + 1, :)             = backgroundHue_rgb;
expCLUT(idx.expGrey70_subBg + 1, :)         = [0.7 0.7 0.7];
expCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
expCLUT(idx.expRed_subBg + 1, :)            = redISH;
expCLUT(idx.expOrange_subBg + 1, :)         = orangeISH;
expCLUT(idx.expBlue_subBg + 1, :)           = blueISH;
expCLUT(idx.expCyan_subCyan + 1, :)         = [0 1 1];
expCLUT(idx.expGrey90_subBg + 1, :)         = [0.9 0.9 0.9];
expCLUT(idx.expMutGreen_subBg + 1, :)       = mutGreen;
expCLUT(idx.expOldGreen_subOldGreen + 1, :) = oldGreen;
% ... Add any other static colors from your clutIdx here ...

% Subject CLUT (many elements are invisible, matching the background)
subCLUT(idx.expBlack_subBlack + 1, :)       = [0 0 0];
subCLUT(idx.expGrey25_subBg + 1, :)         = backgroundHue_rgb;
subCLUT(idx.expBg_subBg + 1, :)             = backgroundHue_rgb;
subCLUT(idx.expGrey70_subBg + 1, :)         = backgroundHue_rgb;
subCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
subCLUT(idx.expRed_subBg + 1, :)            = backgroundHue_rgb;
subCLUT(idx.expOrange_subBg + 1, :)         = backgroundHue_rgb;
subCLUT(idx.expBlue_subBg + 1, :)           = backgroundHue_rgb;
subCLUT(idx.expCyan_subCyan + 1, :)         = [0 1 1];
subCLUT(idx.expGrey90_subBg + 1, :)         = backgroundHue_rgb;
subCLUT(idx.expMutGreen_subBg + 1, :)       = backgroundHue_rgb;
subCLUT(idx.expOldGreen_subOldGreen + 1, :) = oldGreen;
% ... Add any other static colors from your clutIdx here ...

% --- Fill dynamic entries (17-255) ---
% Index 17 is the background for the stimulus image area
expCLUT(18, :) = backgroundHue_rgb;
subCLUT(18, :) = backgroundHue_rgb;

% Indices 18-255 (MATLAB indices 19-256) are the stimulus ramp
expCLUT(19:256, :) = stim_ramp;
subCLUT(19:256, :) = stim_ramp;


%% 4. Upload the CLUTs to the VIEWPixx
Datapixx('SetVideoClut', [subCLUT; expCLUT]);

end

%
function p = trialTypeInfo(p)

% decide whether this will be a visually or memory guided saccade:
if rand() <= p.trVars.propVis
    p.trVars.isVisSac = 1;
else
    p.trVars.isVisSac = 0;
end

% assuming we're using the trials array, determine which stimulus
% configuration (target and background color) we're using in this trial:
if p.trVars.setTargLocViaTrialArray
    p.trVars.stimConfigIdx = p.init.trialsArray(...
        p.trVars.currentTrialsArrayRow, ...
    strcmp(p.init.trialArrayColumnNames, 'tgtBkgndCond'));
else
    p.trVars.stimConfigIdx = randi(8);
end

% define colors of backround and target for upcoming trial:
switch p.trVars.stimConfigIdx
    case 1 % "high" saliency
        c1 = p.draw.clutIdx.dkl_0;
        c2 = p.draw.clutIdx.dkl_180;

    case 2 % "high" saliency
        c1 = p.draw.clutIdx.dkl_180;
        c2 = p.draw.clutIdx.dkl_0;

    case 3 % "high" saliency
        c1 = p.draw.clutIdx.dkl_90;
        c2 = p.draw.clutIdx.dkl_270;

    case 4 % "high" saliency
        c1 = p.draw.clutIdx.dkl_270;
        c2 = p.draw.clutIdx.dkl_90;

    case 5 % "low" saliency
        c1 = p.draw.clutIdx.dkl_0;
        c2 = p.draw.clutIdx.dkl_45;

    case 6 % "low" saliency
        c1 = p.draw.clutIdx.dkl_90;
        c2 = p.draw.clutIdx.dkl_135;

    case 7 % "low" saliency
        c1 = p.draw.clutIdx.dkl_180;
        c2 = p.draw.clutIdx.dkl_225;

    case 8 % "low" saliency
        c1 = p.draw.clutIdx.dkl_270;
        c2 = p.draw.clutIdx.dkl_315;
end

p.draw.color.targ       = c1;
p.draw.color.background = c2;
p.draw.color.fix          = p.draw.color.background;
p.draw.color.fixWin       = p.draw.color.background;

% redefine CLUT and upload to VIEWPixx:
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
if isempty(p.trVars.currentTrialsArrayRow)
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