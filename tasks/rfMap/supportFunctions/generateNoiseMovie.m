function [noiseMovie, rngSeed] = generateNoiseMovie(nChecksY, nChecksX, ...
    nFrames, colorMode, isBinary, rngSeed, stimMode, nSparseSpots)
% generateNoiseMovie  Pre-generate a noise stimulus movie matrix.
%
%   [noiseMovie, rngSeed] = generateNoiseMovie(nChecksY, nChecksX, nFrames,
%       colorMode, isBinary, rngSeed, stimMode, nSparseSpots)
%
%   Inputs:
%     nChecksY   - grid height (number of checks)
%     nChecksX   - grid width (number of checks)
%     nFrames    - total number of noise frames to generate
%     colorMode  - 'luminance' or 'rgb'
%     isBinary   - true for binary (0/1), false for uniform continuous (0-255)
%     rngSeed    - RNG seed (integer). If empty, uses rng('shuffle') and
%                  returns the seed used.
%     stimMode     - (optional) 'dense' (default) or 'sparse'
%     nSparseSpots - (optional) number of spots per frame in sparse mode (default 1)
%
%   Outputs:
%     noiseMovie - Dense mode  (uint8):
%                    luminance: [nY, nX, nFrames] values 0 or 1
%                    rgb:       [nY, nX, 3, nFrames] values 0 or 1 (or 0-255)
%                  Sparse mode (int8):
%                    [nY, nX, nFrames] values in {-1, 0, +1}, mostly 0,
%                    with nSparseSpots non-overlapping spots per frame at
%                    random locations and random polarity.
%     rngSeed    - the RNG seed used (for exact offline reconstruction)
%
%   Dense mode: spatiotemporally white, every check randomized each frame.
%   Appropriate for reverse-correlation in visual areas with small RFs
%   (LGN, V1) where the cell responds to local contrast despite surround
%   drive.
%
%   Sparse mode: a small number of isolated spots on an otherwise zero
%   (background) frame. Appropriate for areas with large RFs and strong
%   surround suppression (e.g., SC), where dense noise fails because the
%   surround is constantly driven. Zero-mean by construction; STA needs
%   no mean-subtraction.

% Handle RNG seed
if nargin < 6 || isempty(rngSeed)
    rngState = rng('shuffle');
    rngSeed = rngState.Seed;
else
    rng(rngSeed, 'twister');
end
if nargin < 7 || isempty(stimMode),     stimMode = 'dense'; end
if nargin < 8 || isempty(nSparseSpots), nSparseSpots = 1;   end

fprintf('Generating noise movie: %d x %d checks, %d frames, mode=%s', ...
    nChecksY, nChecksX, nFrames, stimMode);

switch lower(stimMode)
    case 'dense'
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

    case 'sparse'
        if ~strcmpi(colorMode, 'luminance')
            error('generateNoiseMovie:sparseNeedsLum', ...
                'Sparse mode supports luminance only (got ''%s'').', colorMode);
        end
        nChecks = nChecksY * nChecksX;
        if nSparseSpots < 1 || nSparseSpots > nChecks
            error('generateNoiseMovie:badNSpots', ...
                'nSparseSpots (%d) must be in [1, %d].', nSparseSpots, nChecks);
        end

        noiseMovie = zeros(nChecksY, nChecksX, nFrames, 'int8');
        for f = 1:nFrames
            linIdx = randperm(nChecks, nSparseSpots);
            pol    = int8((rand(1, nSparseSpots) > 0.5) * 2 - 1);  % +/-1
            frame  = zeros(nChecksY, nChecksX, 'int8');
            frame(linIdx) = pol;
            noiseMovie(:, :, f) = frame;
        end

    otherwise
        error('generateNoiseMovie:badMode', ...
            'stimMode must be ''dense'' or ''sparse'' (got ''%s'').', stimMode);
end

fprintf(' done. (%.1f MB)\n', numel(noiseMovie) / 1e6);

end
