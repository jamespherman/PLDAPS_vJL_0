function p = nextParams(p)
%
% p = nextParams(p)
%
% FINAL VERSION for gSac_4factors. Defines all parameters for the upcoming trial.

%% 1. Choose a row from the trial array
p = chooseRow(p);
if p.trVars.exitWhileLoop, return; end

%% 2. Set trial type info and select the stimulus
p = trialTypeInfo(p);

%% 3. Set target locations
p = setLocations(p);

%% 4. Set timing parameters
p = timingInfo(p);

end


%% --- SUBFUNCTIONS ---

function p = trialTypeInfo(p)
% Reads trial conditions, selects the stimulus, and calls updateTrialClut.

colNames = p.init.trialArrayColumnNames;
for i = 1:length(colNames), cols.(colNames{i}) = i; end
currentRow = p.init.trialsArray(p.trVars.currentTrialsArrayRow, :);

% Copy all factorial conditions into p.trVars
p.trVars.stimType = currentRow(cols.stimType);
% ... (and any other variables you need in p.trVars)

% Set Stimulus Parameters
if p.trVars.stimType <= 2 % Image Trial
    p.stim.isProcedural = false;
    if p.trVars.stimType == 1, rand_idx = randi(length(p.stim.faceTextures)); p.stim.currentTexture = p.stim.faceTextures(rand_idx);
    else, rand_idx = randi(length(p.stim.nonFaceTextures)); p.stim.currentTexture = p.stim.nonFaceTextures(rand_idx); end
else % Bullseye Trial
    p.stim.isProcedural = true;
    p.stim.currentTexture = [];
end

% Now that trial conditions are set, update the CLUT for this trial
p = updateTrialClut(p);

end


function p = updateTrialClut(p)
% This function runs ONCE per trial to set the correct background color and
% update the subject's CLUT to ensure elements are invisible.

idx = p.draw.clutIdx;

% Start with the default CLUTs created in initClut
expCLUT = p.draw.clut.expCLUT;
subCLUT = p.draw.clut.subCLUT;

% 1. Determine the correct background color INDEX for this trial
switch p.trVars.stimType
    case {1, 2} % Image Trial
        p.draw.color.background = idx.bg_image;
    case 3 % Bullseye: High Salience, Target 0 deg
        p.draw.color.background = idx.dkl_180;
    case 4 % Bullseye: Low Salience, Target 0 deg
        p.draw.color.background = idx.dkl_45;
    case 5 % Bullseye: High Salience, Target 180 deg
        p.draw.color.background = idx.dkl_0;
    case 6 % Bullseye: Low Salience, Target 180 deg
        p.draw.color.background = idx.dkl_225;
end

% 2. Get the actual [R G B] value for the chosen background
current_bg_color_rgb = expCLUT(p.draw.color.background + 1, :);

% 3. CRITICAL STEP: Update the Subject's CLUT
% Make all '_subBg' elements invisible by setting their color to match the
% current trial's background color.
subCLUT(idx.gridLines + 1, :) = current_bg_color_rgb;
subCLUT(idx.fixWin + 1, :)    = current_bg_color_rgb;
% (Add any other indices here that need to be invisible)

% 4. Upload the newly updated CLUTs to the VIEWPixx
Datapixx('SetVideoClut', [subCLUT; expCLUT]);

% Store the updated subCLUT in the p struct for use by the drawing functions
p.draw.clut.subCLUT = subCLUT;

end


function p = chooseRow(p)
% Selects the next trial row, progressing sequentially through half-blocks.
if ~isfield(p.trVars, 'halfBlockToCheck'), p.trVars.halfBlockToCheck = 1; end
col_hb = strcmp(p.init.trialArrayColumnNames, 'halfBlock');
trialsPossible = p.status.trialsArrayRowsPossible & p.init.trialsArray(:, col_hb) == p.trVars.halfBlockToCheck;
if ~any(trialsPossible)
    p.trVars.halfBlockToCheck = p.trVars.halfBlockToCheck + 1;
    trialsPossible = p.status.trialsArrayRowsPossible & p.init.trialsArray(:, col_hb) == p.trVars.halfBlockToCheck;
end
if ~any(trialsPossible), p.trVars.exitWhileLoop = true; p.pldaps.finish = true; return; end
choicePool = find(trialsPossible);
p.trVars.currentTrialsArrayRow = choicePool(randi(length(choicePool)));
end


function p = setLocations(p)
% Sets target locations based on a rotational scheme.
baseX = p.trVarsInit.targDegX; baseY = p.trVarsInit.targDegY;
[theta_rad, r] = cart2pol(baseX, baseY);
if sign(baseX) == sign(baseY), rotation_deg = -90; else, rotation_deg = 90; end
rotation_rad = deg2rad(rotation_deg);
locations = zeros(4, 2);
for i = 1:4
    current_rotation = theta_rad + ( (i-1) * rotation_rad );
    [x, y] = pol2cart(current_rotation, r);
    locations(i, :) = [x, y];
end
locIdxCol = strcmp(p.init.trialArrayColumnNames, 'targetLocIdx');
p.trVars.targetLocIdx = p.init.trialsArray(p.trVars.currentTrialsArrayRow, locIdxCol);
p.stim.targetPos = locations(p.trVars.targetLocIdx, :);
p.draw.fixPointPix      = p.draw.middleXY + [1, -1] .* pds.deg2pix([p.trVars.fixDegX, p.trVars.fixDegY], p);
p.draw.targPointPix = p.draw.middleXY + [1, -1] .* pds.deg2pix(p.stim.targetPos, p);
p.draw.fixWinWidthPix = pds.deg2pix(p.trVars.fixWinWidthDeg, p);
p.draw.fixWinHeightPix = pds.deg2pix(p.trVars.fixWinHeightDeg, p);
p.draw.targWinWidthPix = pds.deg2pix(p.trVars.targWinWidthDeg, p);
p.draw.targWinHeightPix = pds.deg2pix(p.trVars.targWinHeightDeg, p);

% Convert final target X & Y into strobe-able radius and theta values
[tmpTheta, tmpRadius]   = cart2pol(p.stim.targetPos(1), p.stim.targetPos(2));
p.trVars.targTheta_x10  = round(mod(rad2deg(tmpTheta), 360) * 10);
p.trVars.targRadius_x100 = round(tmpRadius * 100);
end


function p = timingInfo(p)
% timingInfo
%
% DEFINITIVE VERSION: Defines all state durations for the memory-guided
% saccade task using only the pre-existing variables from the settings file.

% --- All times are in seconds, relative to Fixation Acquisition ---

% Time from fixation acquisition to target onset (variable delay)
p.trVars.timeTargOnset = unifrnd(p.trVarsInit.targOnsetMin, ...
    p.trVarsInit.targOnsetMax);

% Time from fixation acquisition to target offset (a fixed 400ms flash)
% Note: p.trVarsInit.targetFlashDuration is already in seconds (0.4)
p.trVars.timeTargOffset = p.trVars.timeTargOnset + ...
    p.trVarsInit.targetFlashDuration;

% Time from fixation acquisition to fixation offset (the "go" signal).
% This uses the goTimePostTarg variables to define the memory delay.
p.trVars.timeFixOffset = p.trVars.timeTargOnset + ...
    unifrnd(p.trVarsInit.goTimePostTargMin, p.trVarsInit.goTimePostTargMax);

% Duration to hold fixation on the target after the saccade lands
p.trVars.targHoldDuration =  unifrnd(p.trVarsInit.targHoldDurationMin, ...
    p.trVarsInit.targHoldDurationMax);

% Set reward duration based on the trial condition
rewardCol = strcmp(p.init.trialArrayColumnNames, 'reward');
p.trVars.reward = p.init.trialsArray(p.trVars.currentTrialsArrayRow, rewardCol);
if p.trVars.reward == 1
    p.trVars.rewardDurationMs = p.trVarsInit.rewardDurationHigh;
else
    p.trVars.rewardDurationMs = p.trVarsInit.rewardDurationLow;
end

p.trVars.isVisSac = false;

end