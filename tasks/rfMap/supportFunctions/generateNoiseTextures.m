function p = generateNoiseTextures(p)
% p = generateNoiseTextures(p)
%
% Create PTB textures for this trial's noise frames from the pre-generated
% noise movie. Each texture is a small grid (nChecksY x nChecksX) that
% gets scaled up to fill the screen via Screen('DrawTexture') with
% nearest-neighbor filtering.
%
% CLUT indices used:
%   Dense (uint8 0/1):      {0, 1} -> {black, white}
%   Sparse (int8 -1/0/+1):  {-1, 0, +1} -> {black, background, white}

nFrames    = p.trVars.nFramesThisTrial;
startFrame = p.trVars.trialStartFrame;

blackIdx = p.draw.clutIdx.expBlack_subBlack;  % 0
whiteIdx = p.draw.clutIdx.expWhite_subWhite;  % 4
bgIdx    = p.draw.clutIdx.expBg_subBg;        % 2

isSparse = isa(p.init.noiseMovie, 'int8');

% Pre-allocate texture handle array
p.trVars.noiseTextures = zeros(1, nFrames);

for f = 1:nFrames
    globalIdx = startFrame + f - 1;
    frameData = p.init.noiseMovie(:, :, globalIdx);

    if isSparse
        % Sparse: values are -1, 0, +1 (int8).
        texData = repmat(uint8(bgIdx), size(frameData));
        texData(frameData == -1) = uint8(blackIdx);
        texData(frameData == +1) = uint8(whiteIdx);
    else
        % Dense: values are 0, 1 (uint8). Linear map.
        texData = uint8(blackIdx + frameData * (whiteIdx - blackIdx));
    end

    % Create PTB texture
    p.trVars.noiseTextures(f) = Screen('MakeTexture', ...
        p.draw.window, texData);
end

end
