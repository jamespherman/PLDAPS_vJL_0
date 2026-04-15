function p = generateNoiseTextures(p)
% p = generateNoiseTextures(p)
%
% Create PTB textures for this trial's noise frames from the pre-generated
% noise movie. Each texture is a small grid (nChecksY x nChecksX) that
% gets scaled up to fill the screen via Screen('DrawTexture') with
% nearest-neighbor filtering.
%
% Pixel values use CLUT indices:
%   0 = expBlack_subBlack (black checks)
%   4 = expWhite_subWhite (white checks)

nFrames    = p.trVars.nFramesThisTrial;
startFrame = p.trVars.trialStartFrame;

blackIdx = p.draw.clutIdx.expBlack_subBlack;  % 0
whiteIdx = p.draw.clutIdx.expWhite_subWhite;  % 4

% Pre-allocate texture handle array
p.trVars.noiseTextures = zeros(1, nFrames);

for f = 1:nFrames
    globalIdx = startFrame + f - 1;

    % noiseMovie values are 0 or 1 (uint8). Map to CLUT indices.
    frameData = p.init.noiseMovie(:, :, globalIdx);
    texData = uint8(blackIdx + frameData * (whiteIdx - blackIdx));

    % Create PTB texture
    p.trVars.noiseTextures(f) = Screen('MakeTexture', ...
        p.draw.window, texData);
end

end
