function p = nextParams(p)
% p = nextParams(p)
%
% Set per-trial parameters for rfMap. Stim-type-conditional; the
% noise-movie modes (denseAchromatic, denseChromatic, sparse) chunk a
% pre-generated movie, while checkerboard picks (checkSize, contrast)
% from the trial array.

if strcmp(p.init.stimType, 'checkerboard')
    p = nextParams_checkerboard(p);
else
    p = nextParams_noiseMovie(p);
end

end


function p = nextParams_noiseMovie(p)
% Movie-mode trial setup. Frame-range chunking is the same for all
% three movie modes; chromatic additionally generates this trial's
% noise movie + drive tensor on the fly from the trial's per-trial
% seed (saved on the trial array at session init).

%% Wrap the playback cursor if we've walked past the end of the movie.
% The noise movie is statistically white; replaying it does not bias
% STA, it just gives each unique frame multiple (frame, spike) pairs.
% The cycle counter is strobed (rfMapNoiseCycleCount) so offline
% analysis can reconstruct exactly what was shown -- combined with the
% RNG seed and nNoiseFrames, the (cycleCount, trialStartFrame,
% trialEndFrame) trio is sufficient. For denseChromatic, wrapping the
% cursor also wraps the trial-array index, so the same per-trial seeds
% are reused and the same noise is regenerated.
if p.init.noiseFrameIdx > p.init.nNoiseFrames
    p.init.noiseFrameIdx   = 1;
    p.init.noiseCycleCount = p.init.noiseCycleCount + 1;
    fprintf('*** rfMap: noise movie wrapped (cycle %d). ***\n', ...
        p.init.noiseCycleCount);
end

%% Noise frame range for this trial
frameDurS = p.trVars.noiseFrameHold * p.rig.frameDuration;
framesPerTrial = round(p.trVars.trialDurationS / frameDurS);

p.trVars.trialStartFrame  = p.init.noiseFrameIdx;
p.trVars.trialEndFrame    = min(p.trVars.trialStartFrame + framesPerTrial - 1, ...
                                p.init.nNoiseFrames);
p.trVars.nFramesThisTrial = p.trVars.trialEndFrame - p.trVars.trialStartFrame + 1;
p.trVars.noiseFrameDurS   = frameDurS;

%% Chromatic per-trial generation
if strcmp(p.init.stimType, 'denseChromatic')
    % Pull this trial's seed from the trial array. Trial-array index
    % matches p.status.iTrial since rows aren't permuted in noise-movie
    % mode (still presented in order). NB: failed trials repeat the
    % current frame range without advancing iTrial-bound seed lookup --
    % we use trialStartFrame as the canonical row identifier.
    trialIdx = ceil(p.trVars.trialStartFrame / framesPerTrial);
    cols = p.init.trialArrayColumnNames;
    seedColIdx = find(strcmp(cols, 'chromaticSeed'), 1);
    if isempty(seedColIdx)
        error('rfMap_next:noChromaticSeed', ...
            ['p.init.trialsArray has no chromaticSeed column. ' ...
             'Phase-2 v2+ requires per-trial seeds; bumped via ' ...
             'p.init.sessionFormatVersion = 2.']);
    end
    trialIdx = max(1, min(trialIdx, size(p.init.trialsArray, 1)));
    trialSeed = p.init.trialsArray(trialIdx, seedColIdx);

    [p.trVars.thisTrialNoiseMovie, p.trVars.thisTrialDklDrive] = ...
        generateStim_denseChromatic( ...
            p.init.noiseGridSize(1), p.init.noiseGridSize(2), ...
            p.trVars.nFramesThisTrial, ...
            p.trVarsInit.dklAxes, p.trVarsInit.dklContrasts, ...
            double(trialSeed));
    p.trVars.chromaticTrialSeed = trialSeed;
end

%% Fixation point + window in pixels (shared)
p = setupFixationGeometry(p);

%% Noise texture destination rect (full screen, centered)
checkSizePix = pds.deg2pix(p.trVars.checkSizeDeg, p);
if checkSizePix < 1, checkSizePix = 1; end
destW = p.init.noiseGridSize(2) * checkSizePix;
destH = p.init.noiseGridSize(1) * checkSizePix;
p.draw.noiseDestRect = CenterRectOnPoint([0 0 destW destH], ...
    p.draw.middleXY(1), p.draw.middleXY(2));

%% Reset noise presentation state
p.trVars.currentNoiseIdx   = 1;
p.trVars.noiseIsOn         = false;
p.trVars.noiseStartFlipIdx = 0;

%% Strobe-related derived values
p.trVars.checkSizeDeg_x100 = round(p.trVars.checkSizeDeg * 100);

fprintf('Trial %d: frames %d-%d of %d (%.1f%% complete)\n', ...
    p.status.iTrial, p.trVars.trialStartFrame, p.trVars.trialEndFrame, ...
    p.init.nNoiseFrames, ...
    100 * p.trVars.trialStartFrame / p.init.nNoiseFrames);

end


function p = nextParams_checkerboard(p)
% Pick (checkSize, contrast) from the trial array. Trial duration
% counted in DISPLAY frames (1/refresh), since polarity reversal is
% per-flip.

%% Pull this trial's row from the trial array.
remaining = p.status.trialsArrayRowsPossible;
if isempty(remaining)
    fprintf('*** rfMap (checkerboard): trial array exhausted. ***\n');
    p.trVars.movieExhausted   = true;
    p.trVars.nFramesThisTrial = 0;
    return;
end

% Peek at the next remaining row without popping. _finish.m pops it
% on success; aborts leave it in the pool for re-presentation.
rowIdx = remaining(1);

cols = p.init.trialArrayColumnNames;
sizeIdx     = p.init.trialsArray(rowIdx, strcmp(cols, 'checkSizeIdx'));
contrastIdx = p.init.trialsArray(rowIdx, strcmp(cols, 'contrastIdx'));

p.trVars.checkerboardTrialRow = rowIdx;
p.trVars.checkSizeIdx         = sizeIdx;
p.trVars.contrastIdx          = contrastIdx;

%% Trial duration in DISPLAY frames.
displayFrameDurS = p.rig.frameDuration;
nFramesTrial     = round(p.trVars.trialDurationS / displayFrameDurS);
p.trVars.trialStartFrame  = 1;
p.trVars.trialEndFrame    = nFramesTrial;
p.trVars.nFramesThisTrial = nFramesTrial;
p.trVars.noiseFrameDurS   = displayFrameDurS;

%% Polarity-reversal scheduling: build the per-display-frame polarity
% sequence (+1 / -1) in advance. Polarity flips every framesPerReversal
% frames; initial polarity is +1.
framesPerRev = p.init.checkInfo.framesPerReversal;
% revBlock: which reversal-block does each frame belong to (0-based)?
revBlock = floor((0:nFramesTrial - 1) / framesPerRev);
p.trVars.checkPolaritySequence = int8(1 - 2 * mod(revBlock, 2));  % +1, -1, +1, ...

%% Fixation geometry (shared)
p = setupFixationGeometry(p);

%% Destination rect = full screen.
p.draw.noiseDestRect = p.draw.screenRect;

%% Reset presentation state
p.trVars.currentNoiseIdx   = 1;
p.trVars.noiseIsOn         = false;
p.trVars.noiseStartFlipIdx = 0;

%% Strobe-related derived values
p.trVars.checkSizeDeg_x100 = round( ...
    p.trVarsInit.checkSizesDva(sizeIdx) * 100);

fprintf('Trial %d: checkerboard sz=%.2fdeg ct=%.2f (cond %d/%d), %d frames, fpr=%d\n', ...
    p.status.iTrial, p.trVarsInit.checkSizesDva(sizeIdx), ...
    p.trVarsInit.checkContrasts(contrastIdx), ...
    rowIdx, size(p.init.trialsArray, 1), ...
    nFramesTrial, framesPerRev);

end


function p = setupFixationGeometry(p)
p.draw.fixPointPix = [p.draw.middleXY(1) + pds.deg2pix(p.trVars.fixDegX, p), ...
                      p.draw.middleXY(2) - pds.deg2pix(p.trVars.fixDegY, p)];
p.draw.fixWinWidthPix  = pds.deg2pix(p.trVars.fixWinWidthDeg,  p);
p.draw.fixWinHeightPix = pds.deg2pix(p.trVars.fixWinHeightDeg, p);
if p.trVars.clearPatchDeg > 0
    clearSizePix = pds.deg2pix(p.trVars.clearPatchDeg, p);
    p.draw.clearPatchRect = CenterRectOnPoint( ...
        [0 0 clearSizePix clearSizePix], ...
        p.draw.fixPointPix(1), p.draw.fixPointPix(2));
else
    p.draw.clearPatchRect = [];
end
end
