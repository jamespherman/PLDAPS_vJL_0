function dklDriveTensor = recomputeDklDrive(nChecksY, nChecksX, ...
    nFrames, dklAxes, dklContrasts, rngSeed)
% recomputeDklDrive  Regenerate per-check DKL drive tensor from seed.
%
%   dklDriveTensor = recomputeDklDrive(nChecksY, nChecksX, nFrames, ...
%       dklAxes, dklContrasts, rngSeed)
%
%   Produces the per-check DKL drive tensor used for chromatic STA
%   accumulation. The tensor is NOT saved to the session folder; it is
%   reconstructed deterministically from the saved seed and parameters
%   by both online (rfMap_init / rfMap_finish) and offline analysis.
%
%   Inputs:
%     nChecksY     - grid height (number of checks)
%     nChecksX     - grid width  (number of checks)
%     nFrames      - total number of noise frames
%     dklAxes      - vector of active axes; subset of [1 2 3]
%                    (1 = L-M, 2 = S, 3 = achromatic). Inactive axes
%                    are set to zero in the output, so the STA on those
%                    axes will be zero by construction.
%     dklContrasts - per-axis contrast magnitude. Either a scalar
%                    applied to every axis in dklAxes, or a vector of
%                    length numel(dklAxes) (one per active axis).
%     rngSeed      - integer RNG seed (REQUIRED). The function pins
%                    rng(seed, 'twister') immediately before its first
%                    random draw and consumes a known number of values
%                    in a fixed order.
%
%   Output:
%     dklDriveTensor - [nChecksY, nChecksX, 3, nFrames] single-precision
%                      tensor of signed contrasts. Stored as `single`
%                      (not int8) so the STA accumulator can multiply by
%                      a contrast magnitude without an int-to-double
%                      cast on every spike. Memory cost for a typical
%                      session (24 x 40 x 3 x 60000) is ~692 MB; large
%                      but manageable, and the cost of recomputing per
%                      trial would be worse. The session-save path
%                      strips this tensor (along with the RGB movie)
%                      from p.init before write.
%
%   Convention (locked):
%     - Tri-noise: each (y, x, frame) draws 3 independent signs, one
%       per DKL axis. Inactive axes (not in dklAxes) are forced to 0.
%     - Sign distribution is balanced binary: rand() > 0.5 -> +contrast,
%       else -> -contrast. Each of the 3 axes is drawn from its own
%       block of the RNG stream, in axis order 1, 2, 3 (so adding/
%       removing axes from dklAxes does not perturb the bits drawn for
%       earlier axes).
%
%   Example:
%     drive = recomputeDklDrive(24, 40, 100, [1 2 3], 0.5, 12345);
%     % drive(:,:,1,:) is the L-M signed contrast tensor
%     % drive(:,:,2,:) is the S signed contrast tensor
%     % drive(:,:,3,:) is the achromatic signed contrast tensor

if nargin < 6 || isempty(rngSeed)
    error('recomputeDklDrive:missingSeed', ...
        ['rngSeed is required. Pass an explicit integer; do not ' ...
         'rely on the broken rng(''shuffle'')-and-grab-previous-' ...
         'state idiom.']);
end

% Validate axes
if any(~ismember(dklAxes, [1 2 3]))
    error('recomputeDklDrive:badAxes', ...
        'dklAxes must be a subset of [1 2 3] (1=L-M, 2=S, 3=Achro).');
end

% Resolve per-axis contrast magnitude into a length-3 vector indexed by
% absolute axis (1=L-M, 2=S, 3=Achro). Axes not in dklAxes get 0.
contrastVec = zeros(1, 3);
if isscalar(dklContrasts)
    contrastVec(dklAxes) = dklContrasts;
else
    if numel(dklContrasts) ~= numel(dklAxes)
        error('recomputeDklDrive:contrastSize', ...
            ['dklContrasts must be a scalar or a vector of length ' ...
             'numel(dklAxes) = %d.'], numel(dklAxes));
    end
    contrastVec(dklAxes) = dklContrasts(:)';
end

% Pin RNG state. The drive-tensor RNG is a separate logical stream from
% the RGB-movie texture RNG; they are derived from the same seed but
% drawn in a fixed order so any reuse downstream is reproducible.
rng(rngSeed, 'twister');

dklDriveTensor = zeros(nChecksY, nChecksX, 3, nFrames, 'single');

% Draw axes in fixed order 1, 2, 3. Axes not in dklAxes are skipped
% (drive stays 0 for those). A skipped axis still does NOT consume
% RNG values, because we use a deterministic sub-seed per axis derived
% from the master seed -- this lets the user toggle axes on/off
% without perturbing the others.
for axisIdx = 1:3
    if ~ismember(axisIdx, dklAxes)
        continue
    end
    % Per-axis sub-stream: pin a sub-seed so axis 1 and axis 3 are
    % independent of whether axis 2 was active.
    subSeed = uint32(mod(uint64(rngSeed) + uint64(axisIdx) * uint64(2654435761), ...
        uint64(2^32 - 1)));
    rng(double(subSeed), 'twister');

    signs = single((rand(nChecksY, nChecksX, nFrames) > 0.5) * 2 - 1);
    dklDriveTensor(:, :, axisIdx, :) = ...
        reshape(signs * contrastVec(axisIdx), nChecksY, nChecksX, 1, nFrames);
end

end
