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

% --- In nextParams.m ---

function p = redefClut(p)
% redefClut (TRANSPARENCY TEST VERSION)
% Sets the background color and stores the target color for modulation.

% 1. Select the Target and Background Hues for this trial
dkl_palette_rgb = p.draw.colors.dklPalette_rgb;

if p.trVars.targetColor == 1, target_hue_idx = 1; else, target_hue_idx = 5; end
if p.trVars.salience == 1, bg_hue_idx = mod(target_hue_idx + 4 - 1, 8) + 1; else, bg_hue_idx = mod(target_hue_idx + 1 - 1, 8) + 1; end

targetHue_rgb = dkl_palette_rgb(target_hue_idx, :);
backgroundHue_rgb = dkl_palette_rgb(bg_hue_idx, :);

% 2. Store the target color for the run function to use for tinting
p.stim.modulateColor = targetHue_rgb;

% 3. Set the dynamic background color in the CLUT
% Get the current CLUT, modify only the background, and re-upload.
expCLUT = p.draw.clut.expCLUT;
subCLUT = p.draw.clut.subCLUT;

expCLUT(p.draw.clutIdx.expBg_subBg + 1, :) = backgroundHue_rgb;
subCLUT(p.draw.clutIdx.expBg_subBg + 1, :) = backgroundHue_rgb;
% Also make invisible elements match the new background
subCLUT(p.draw.clutIdx.expGrey25_subBg + 1, :) = backgroundHue_rgb;
subCLUT(p.draw.clutIdx.expGrey70_subBg + 1, :) = backgroundHue_rgb;

Datapixx('SetVideoClut', [subCLUT; expCLUT]);
end

% function p = redefClut(p)
% % redefClut
% %
% % Defines and uploads the CLUTs for the upcoming trial. It now generates
% % the stimulus ramp in DKL space to ensure it is truly isoluminant.
% 
% %% 1. Select the Target and Background Hues for this trial
% dkl_palette_dkl = p.draw.colors.dklPalette_dkl; % Use DKL coordinates
% dkl_palette_rgb = p.draw.colors.dklPalette_rgb; % Use final RGB values for background
% 
% if p.trVars.targetColor == 1, target_hue_idx = 1; else, target_hue_idx = 5; end % 0 or 180 deg
% 
% if p.trVars.salience == 1, bg_hue_idx = mod(target_hue_idx + 4 - 1, 8) + 1; else, bg_hue_idx = mod(target_hue_idx + 1 - 1, 8) + 1; end
% 
% % We need the final RGB value for the background entry in the CLUT
% backgroundHue_rgb = dkl_palette_rgb(bg_hue_idx, :);
% 
% %% 2. Generate the "Single Hue Ramp" in DKL space
% n_stim_levels = 238;
% 
% % Define the endpoints of the ramp in DKL coordinates
% isolum_gray_dkl = [mean(p.rig.dklLum), 0, 0];
% targetHue_dkl   = dkl_palette_dkl(target_hue_idx, :);
% 
% % Interpolate the two chromatic axes (L-M and S) from gray to the target hue
% lm_axis_ramp = linspace(isolum_gray_dkl(2), targetHue_dkl(2), n_stim_levels);
% s_axis_ramp  = linspace(isolum_gray_dkl(3), targetHue_dkl(3), n_stim_levels);
% 
% % Keep the luminance axis CONSTANT
% lum_axis = ones(1, n_stim_levels) * isolum_gray_dkl(1);
% 
% % Combine axes and convert each DKL step back to RGB
% dkl_ramp = [lum_axis; lm_axis_ramp; s_axis_ramp];
% stim_ramp_rgb = zeros(n_stim_levels, 3);
% for i = 1:n_stim_levels
%     [r,g,b] = dkl2rgb(dkl_ramp(:,i));
%     stim_ramp_rgb(i,:) = [r,g,b];
% end
% 
% %% 3. Explicitly define the full CLUTs
% % Pre-allocate full 256x3 matrices
% expCLUT = zeros(256, 3);
% subCLUT = zeros(256, 3);
% 
% % Define named colors for static entries, for clarity
% mutGreen    = [0.5 0.9 0.4];
% redISH      = [225 0 76]/255;
% orangeISH   = [255 146 0]/255;
% blueISH     = [11 97 164]/255;
% oldGreen    = [0.45, 0.63, 0.45];
% 
% % Get the struct of CLUT indices from the settings file
% idx = p.draw.clutIdx;
% 
% % --- Fill static entries (indices 0-16) ---
% % Experimenter CLUT (most elements are visible)
% expCLUT(idx.expBlack_subBlack + 1, :)       = [0 0 0];
% expCLUT(idx.expGrey25_subBg + 1, :)         = [0.25 0.25 0.25];
% expCLUT(idx.expBg_subBg + 1, :)             = backgroundHue_rgb; % DYNAMIC
% expCLUT(idx.expGrey70_subBg + 1, :)         = [0.7 0.7 0.7];
% expCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
% expCLUT(idx.expRed_subBg + 1, :)            = redISH;
% expCLUT(idx.expOrange_subBg + 1, :)         = orangeISH;
% expCLUT(idx.expBlue_subBg + 1, :)           = blueISH;
% expCLUT(idx.expCyan_subCyan + 1, :)         = [0 1 1];
% expCLUT(idx.expOldGreen_subOldGreen + 1, :) = oldGreen;
% % ... (add any other static colors as needed) ...
% 
% % Subject CLUT (many elements are made invisible by matching the DYNAMIC background)
% subCLUT(idx.expBlack_subBlack + 1, :)       = [0 0 0];
% subCLUT(idx.expGrey25_subBg + 1, :)         = backgroundHue_rgb;
% subCLUT(idx.expBg_subBg + 1, :)             = backgroundHue_rgb;
% subCLUT(idx.expGrey70_subBg + 1, :)         = backgroundHue_rgb;
% subCLUT(idx.expWhite_subWhite + 1, :)       = [1 1 1];
% subCLUT(idx.expRed_subBg + 1, :)            = backgroundHue_rgb;
% subCLUT(idx.expOrange_subBg + 1, :)         = backgroundHue_rgb;
% subCLUT(idx.expBlue_subBg + 1, :)           = backgroundHue_rgb;
% subCLUT(idx.expCyan_subCyan + 1, :)         = [0 1 1];
% subCLUT(idx.expOldGreen_subOldGreen + 1, :) = oldGreen;
% % ... (add any other static colors as needed) ...
% 
% 
% % --- Fill dynamic entries (indices 17-255) ---
% % Index 17 is the background color for the stimulus area
% expCLUT(18, :) = backgroundHue_rgb;
% subCLUT(18, :) = backgroundHue_rgb;
% 
% % Indices 18-255 (MATLAB indices 19-256) are the stimulus ramp
% expCLUT(19:256, :) = stim_ramp_rgb;
% subCLUT(19:256, :) = stim_ramp_rgb;
% 
% 
% %% 4. Upload the CLUTs to the VIEWPixx
% Datapixx('SetVideoClut', [subCLUT; expCLUT]);
% 
% end

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
