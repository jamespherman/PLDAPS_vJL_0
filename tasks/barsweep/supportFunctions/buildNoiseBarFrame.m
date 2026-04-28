function tex = buildNoiseBarFrame(p, nChecksY, nChecksX)
% tex = buildNoiseBarFrame(p, nChecksY, nChecksX)
%
% Build one binary-noise bar texture (one frame of the per-flip noise
% pattern). Returns a PTB texture handle. Pixel values are CLUT slot
% indices (uint8) corresponding to the configured low/high noise indices.
%
% Texture orientation matches buildBarTexture.m: width = nChecksX runs
% along the bar's long axis; height = nChecksY runs along the bar's
% short axis (thickness). Screen('DrawTexture') will apply rotation and
% nearest-neighbor scaling (filterMode=0) at draw time to keep the
% binary checker grain crisp through scale + rotate.

lowVal  = p.stim.luminanceLevels(p.trVars.noiseLumLowIdx);
highVal = p.stim.luminanceLevels(p.trVars.noiseLumHighIdx);

% Random binary pattern at noise grain. uint8 so the texture is a
% direct CLUT-index buffer.
mask = rand(nChecksY, nChecksX) > 0.5;
texData = repmat(uint8(lowVal), nChecksY, nChecksX);
texData(mask) = uint8(highVal);

tex = Screen('MakeTexture', p.draw.window, texData);

end
