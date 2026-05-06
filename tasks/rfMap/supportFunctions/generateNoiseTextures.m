function p = generateNoiseTextures(p)
% p = generateNoiseTextures(p)
%
% Create PTB textures for this trial's noise frames from the pre-generated
% noise movie. All three stim types use single-channel 8-bit indexed
% textures, compatible with the VPixx L48 framebuffer mode (R-byte is
% the CLUT index).
%
% Movie layouts and index mappings:
%   denseAchromatic (uint8 0/1):       [nY, nX, nFrames]
%       0 -> expBlack_subBlack, 1 -> expWhite_subWhite.
%   sparse (int8 -1/0/+1):             [nY, nX, nFrames]
%       -1 -> expBlack_subBlack, 0 -> expBg_subBg, +1 -> expWhite_subWhite.
%   denseChromatic (uint8 0..7):       [nY, nX, nFrames]
%       k -> CLUT slot (chromaticClutBase + k). The 8 entries were
%       installed by rfMap_init/installChromaticClut from the
%       buildChromaticPalette output.
%
% Each texture is a small grid (nChecksY x nChecksX) that gets scaled up
% to fill the screen via Screen('DrawTexture') with nearest-neighbor
% filtering.

nFrames    = p.trVars.nFramesThisTrial;
startFrame = p.trVars.trialStartFrame;

p.trVars.noiseTextures = zeros(1, nFrames);

% Checkerboard mode: textures are pre-rendered once at session init
% (p.init.checkInfo.textures, persistent across trials). Nothing to do
% per trial. _run.m looks up the right texture by (sizeIdx, contrastIdx,
% polarityIdx) at draw time.
if strcmp(p.init.stimType, 'checkerboard')
    return
end

isChromatic = strcmp(p.init.stimType, 'denseChromatic');
isSparse    = ~isChromatic && isa(p.init.noiseMovie, 'int8');

if isChromatic
    % Chromatic mode regenerates the trial's movie per trial (lives on
    % p.trVars.thisTrialNoiseMovie, indexed 1..nFrames -- not by global
    % frame index, since there's no session-level tensor).
    clutBase  = uint8(p.init.chromaticClutBase);
    movieTrial = p.trVars.thisTrialNoiseMovie;
    for f = 1:nFrames
        frameData = movieTrial(:, :, f);              % uint8 0..7
        texData   = clutBase + frameData;             % uint8
        p.trVars.noiseTextures(f) = Screen('MakeTexture', ...
            p.draw.window, texData);
    end
    return
end

% CLUT-indexed path (achromatic dense / sparse).
blackIdx = p.draw.clutIdx.expBlack_subBlack;
whiteIdx = p.draw.clutIdx.expWhite_subWhite;
bgIdx    = p.draw.clutIdx.expBg_subBg;

for f = 1:nFrames
    globalIdx = startFrame + f - 1;
    frameData = p.init.noiseMovie(:, :, globalIdx);

    if isSparse
        texData = repmat(uint8(bgIdx), size(frameData));
        texData(frameData == -1) = uint8(blackIdx);
        texData(frameData == +1) = uint8(whiteIdx);
    else
        texData = uint8(blackIdx + frameData * (whiteIdx - blackIdx));
    end

    p.trVars.noiseTextures(f) = Screen('MakeTexture', ...
        p.draw.window, texData);
end

end
