function noiseMovie = generateStim_denseAchromatic(nChecksY, nChecksX, ...
    nFrames, isBinary, rngSeed)
% generateStim_denseAchromatic  Pre-generate dense achromatic noise movie.
%
%   noiseMovie = generateStim_denseAchromatic(nChecksY, nChecksX, ...
%       nFrames, isBinary, rngSeed)
%
%   Spatiotemporally white binary luminance noise. Every check is
%   randomized independently each frame.
%
%   Inputs:
%     nChecksY   - grid height (number of checks)
%     nChecksX   - grid width (number of checks)
%     nFrames    - total number of noise frames to generate
%     isBinary   - true for binary (0/1), false for uniform continuous (0-255)
%     rngSeed    - RNG seed (integer). REQUIRED. Caller pins this; the
%                  function does not call rng('shuffle').
%
%   Output:
%     noiseMovie - [nY, nX, nFrames] uint8.
%                    isBinary=true  ->  values 0 or 1
%                    isBinary=false ->  values 0..255
%
%   Notes:
%   - This is the Phase-1 isolated dense-achromatic path, ported
%     verbatim (algorithmically) from the pre-merge generator (frozen
%     in tasks/rfMap/_validation/_legacy_snapshot/generateNoiseMovie_legacy.m,
%     'dense' / 'luminance' branch). Output is bit-exact identical when
%     called with the same seed and shape, modulo the seed-capture bug
%     fix (this function takes the seed as input rather than calling
%     the broken rng('shuffle')-and-grab-previous-state idiom).
%   - The RNG state is set immediately before the first random draw.
%     No upstream pre-allocation order changes between the rng() call
%     and the rand() call.

if nargin < 5 || isempty(rngSeed)
    error('generateStim_denseAchromatic:missingSeed', ...
        ['rngSeed is required. Pass an explicit integer; the ' ...
         'shuffle-and-capture idiom is forbidden because it does ' ...
         'not actually capture the seed used.']);
end

rng(rngSeed, 'twister');

if isBinary
    noiseMovie = uint8(round(rand(nChecksY, nChecksX, nFrames)));
else
    noiseMovie = uint8(255 * rand(nChecksY, nChecksX, nFrames));
end

end
