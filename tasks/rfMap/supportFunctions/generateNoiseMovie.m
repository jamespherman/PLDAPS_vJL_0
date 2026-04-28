function [noiseMovie, rngSeed] = generateNoiseMovie(nChecksY, nChecksX, ...
    nFrames, colorMode, isBinary, rngSeed)
% generateNoiseMovie  Pre-generate a dense noise stimulus movie matrix.
%
%   [noiseMovie, rngSeed] = generateNoiseMovie(nChecksY, nChecksX, nFrames,
%       colorMode, isBinary, rngSeed)
%
%   Inputs:
%     nChecksY   - grid height (number of checks)
%     nChecksX   - grid width (number of checks)
%     nFrames    - total number of noise frames to generate
%     colorMode  - 'luminance' or 'rgb'
%     isBinary   - true for binary (0/1), false for uniform continuous (0-255)
%     rngSeed    - RNG seed (integer). If empty, uses rng('shuffle') and
%                  returns the seed used.
%
%   Outputs:
%     noiseMovie - uint8 matrix:
%                    luminance: [nChecksY, nChecksX, nFrames] values 0 or 1
%                    rgb:       [nChecksY, nChecksX, 3, nFrames] values 0 or 1
%                  For continuous mode, values range 0-255.
%     rngSeed    - the RNG seed used (for exact offline reconstruction)
%
%   The noise is spatiotemporally white: each check on each frame is drawn
%   independently. Binary luminance noise at 0/1 is the default mode for
%   STA-based RF mapping.

% Handle RNG seed
if nargin < 6 || isempty(rngSeed)
    rngState = rng('shuffle');
    rngSeed = rngState.Seed;
else
    rng(rngSeed, 'twister');
end

fprintf('Generating noise movie: %d x %d checks, %d frames...', ...
    nChecksY, nChecksX, nFrames);

switch colorMode
    case 'luminance'
        if isBinary
            noiseMovie = uint8(round(rand(nChecksY, nChecksX, nFrames)));
        else
            noiseMovie = uint8(255 * rand(nChecksY, nChecksX, nFrames));
        end

    case 'rgb'
        if isBinary
            noiseMovie = uint8(round(rand(nChecksY, nChecksX, 3, nFrames)));
        else
            noiseMovie = uint8(255 * rand(nChecksY, nChecksX, 3, nFrames));
        end

    otherwise
        error('generateNoiseMovie:badColorMode', ...
            'colorMode must be ''luminance'' or ''rgb'', got ''%s''', colorMode);
end

fprintf(' done. (%.1f MB)\n', numel(noiseMovie) / 1e6);

end
