function [noiseMovie, dklDriveTensor] = generateStim_denseChromatic(...
    nChecksY, nChecksX, nFrames, dklAxes, dklContrasts, rngSeed)
% generateStim_denseChromatic  Pre-generate dense chromatic (DKL) noise.
%
%   [noiseMovie, dklDriveTensor] = generateStim_denseChromatic( ...
%       nChecksY, nChecksX, nFrames, dklAxes, dklContrasts, rngSeed)
%
%   Tri-noise dense chromatic stimulus: each check, each frame, draws an
%   independent sign on each active DKL axis. Output is an *indexed*
%   movie compatible with the VPixx L48 framebuffer mode used by PLDAPS:
%   each value 0..7 names one of the 8 binary tri-noise states. The
%   actual RGB colors live in the CLUT (palette built separately by
%   buildChromaticPalette and installed by rfMap_init.m).
%
%   Inputs:
%     nChecksY     - grid height (number of checks)
%     nChecksX     - grid width  (number of checks)
%     nFrames      - total number of noise frames to generate
%     dklAxes      - vector of active axes; subset of [1 2 3]
%                    (1 = L-M, 2 = S, 3 = achromatic)
%     dklContrasts - per-axis contrast magnitude (scalar or vector)
%     rngSeed      - integer RNG seed (REQUIRED)
%
%   Outputs:
%     noiseMovie     - [nChecksY, nChecksX, nFrames] uint8. Values are
%                      state indices 0..7:
%                        bit 0 = L-M sign (0 = -contrast, 1 = +contrast)
%                        bit 1 = S    sign
%                        bit 2 = Achr sign
%                      generateNoiseTextures.m maps these to actual CLUT
%                      slots by adding p.init.chromaticClutBase.
%     dklDriveTensor - [nChecksY, nChecksX, 3, nFrames] single tensor
%                      of signed DKL contrasts. Used by
%                      updateSTA_denseChromatic; can be regenerated
%                      offline via recomputeDklDrive(seed, ...).
%
%   Memory:
%     For a typical session (24 x 40 x 60000 frames):
%       noiseMovie    : ~57 MB  (uint8 indexed, same order as achromatic)
%       dklDriveTensor: ~692 MB (single)
%     Both are stripped from p.init before pds.saveP writes the session
%     file (recomputable from seed + params).

if nargin < 6 || isempty(rngSeed)
    error('generateStim_denseChromatic:missingSeed', ...
        'rngSeed is required.');
end

fprintf(['Generating dense chromatic noise: %d x %d checks, %d frames, ' ...
    'axes=[%s], contrasts=[%s]\n'], ...
    nChecksY, nChecksX, nFrames, num2str(dklAxes), ...
    num2str(dklContrasts));

% Drive tensor (signed contrasts on each active axis).
dklDriveTensor = recomputeDklDrive(nChecksY, nChecksX, nFrames, ...
    dklAxes, dklContrasts, rngSeed);

% Compute state index per check per frame from drive signs.
% bit_k = (drive_k > 0). For inactive axes (drive == 0), the bit is 0
% so those checks always land in the "all -1" half of that axis -- but
% the palette has the same color for both halves of an inactive axis,
% so display is correct.
bitLM    = uint8(dklDriveTensor(:, :, 1, :) > 0);
bitS     = uint8(dklDriveTensor(:, :, 2, :) > 0);
bitAchro = uint8(dklDriveTensor(:, :, 3, :) > 0);
noiseMovie = squeeze(bitLM + 2 * bitS + 4 * bitAchro);

fprintf(' done. noiseMovie %.1f MB, dklDriveTensor %.1f MB\n', ...
    numel(noiseMovie) / 1e6, numel(dklDriveTensor) * 4 / 1e6);

end
