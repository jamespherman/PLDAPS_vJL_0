function p = nextParams(p)
% p = nextParams(p)
%
% Set per-trial parameters for rfMap. Determines which slice of the
% pre-generated noise movie to present on this trial.

%% Check if movie is exhausted (must be FIRST, before computing frame range)
if p.init.noiseFrameIdx > p.init.nNoiseFrames
    fprintf('*** rfMap: noise movie exhausted. Ending session. ***\n');
    p.trVars.movieExhausted = true;
    p.trVars.nFramesThisTrial = 0;
    return;
end

%% Noise frame range for this trial
frameDurS = p.trVars.noiseFrameHold * p.rig.frameDuration;
framesPerTrial = round(p.trVars.trialDurationS / frameDurS);

% p.init.noiseFrameIdx tracks playback position (advances on success only)
p.trVars.trialStartFrame  = p.init.noiseFrameIdx;
p.trVars.trialEndFrame    = min(p.trVars.trialStartFrame + framesPerTrial - 1, ...
                                p.init.nNoiseFrames);
p.trVars.nFramesThisTrial = p.trVars.trialEndFrame - p.trVars.trialStartFrame + 1;
p.trVars.noiseFrameDurS   = frameDurS;

%% Fixation point position in pixels
p.draw.fixPointPix = [p.draw.middleXY(1) + pds.deg2pix(p.trVars.fixDegX, p), ...
                      p.draw.middleXY(2) - pds.deg2pix(p.trVars.fixDegY, p)];

%% Fixation window in pixels
p.draw.fixWinWidthPix  = pds.deg2pix(p.trVars.fixWinWidthDeg,  p);
p.draw.fixWinHeightPix = pds.deg2pix(p.trVars.fixWinHeightDeg, p);

%% Clearing patch rect (centered on fixation point)
if p.trVars.clearPatchDeg > 0
    clearSizePix = pds.deg2pix(p.trVars.clearPatchDeg, p);
    p.draw.clearPatchRect = CenterRectOnPoint( ...
        [0 0 clearSizePix clearSizePix], ...
        p.draw.fixPointPix(1), p.draw.fixPointPix(2));
else
    p.draw.clearPatchRect = [];
end

%% Noise texture destination rect (full screen, centered)
checkSizePix = pds.deg2pix(p.trVars.checkSizeDeg, p);
if checkSizePix < 1, checkSizePix = 1; end
destW = p.init.noiseGridSize(2) * checkSizePix;
destH = p.init.noiseGridSize(1) * checkSizePix;
p.draw.noiseDestRect = CenterRectOnPoint([0 0 destW destH], ...
    p.draw.middleXY(1), p.draw.middleXY(2));

%% Reset noise presentation state
p.trVars.currentNoiseIdx     = 1;
p.trVars.noiseIsOn           = false;
p.trVars.noiseStartFlipIdx   = 0;

%% Strobe-related derived values
p.trVars.checkSizeDeg_x100   = round(p.trVars.checkSizeDeg * 100);
if p.trVars.colorMode == 1
    p.trVars.noiseColorModeCode = 1;
else
    p.trVars.noiseColorModeCode = 2;
end

fprintf('Trial %d: frames %d-%d of %d (%.1f%% complete)\n', ...
    p.status.iTrial, p.trVars.trialStartFrame, p.trVars.trialEndFrame, ...
    p.init.nNoiseFrames, ...
    100 * p.trVars.trialStartFrame / p.init.nNoiseFrames);

end
