function noiseMovie = generateStim_sparseBalanced(nChecksY, nChecksX, ...
    nFrames, nSparseSpots, rngSeed)
% generateStim_sparseBalanced  Pre-generate balanced sparse noise movie.
%
%   noiseMovie = generateStim_sparseBalanced(nChecksY, nChecksX, ...
%       nFrames, nSparseSpots, rngSeed)
%
%   Twin-Deck / Pad-Block-Shuffle algorithm: each frame contains
%   exactly N/2 white spots + N/2 black spots, with no overlap. Across
%   frames, every check position is visited equally often. Eliminates
%   the per-frame mean-luminance modulation that contaminates STA in
%   surround-suppressed cells (SC, etc.).
%
%   Ported from feng_LGN/create_sparsechecks.m (Twin-Deck v1.2 +
%   Pad-Block-Shuffle epoch logic). The intentional difference from
%   the legacy uniform-random sparse path: per-frame distribution is
%   balanced, so per-frame whole-field luminance is exactly mid-gray
%   regardless of nSparseSpots.
%
%   Inputs:
%     nChecksY      - grid height (number of checks)
%     nChecksX      - grid width  (number of checks)
%     nFrames       - total number of noise frames to generate
%     nSparseSpots  - total spots per frame (must be even; if odd, the
%                     function rounds DOWN with a warning so each color
%                     gets the same count)
%     rngSeed       - RNG seed (integer). REQUIRED.
%
%   Output:
%     noiseMovie    - [nY, nX, nFrames] int8 with values in {-1, 0, +1}.
%                       +1 = white spot,  -1 = black spot,  0 = background.
%                     Same data layout as the legacy sparse path so
%                     downstream code (texture builder, STA accumulator)
%                     needs no changes.
%
%   Validation: at the end of generation, every frame is checked for
%   (a) zero overlap between white and black spots, (b) exact count
%   per color. An assertion failure here indicates an algorithmic bug,
%   not a usage error.

if nargin < 5 || isempty(rngSeed)
    error('generateStim_sparseBalanced:missingSeed', ...
        'rngSeed is required.');
end

rng(rngSeed, 'twister');

%% sanity checks and per-color count
nPositions = nChecksY * nChecksX;
if nSparseSpots < 2
    error('generateStim_sparseBalanced:badNSpots', ...
        'nSparseSpots must be >= 2 for the balanced TwinDeck. Got %d.', ...
        nSparseSpots);
end
if nSparseSpots > nPositions
    error('generateStim_sparseBalanced:badNSpots', ...
        'nSparseSpots (%d) exceeds total positions (%d).', ...
        nSparseSpots, nPositions);
end

nColors  = 2;                                  % white, black
nPerColor = floor(nSparseSpots / nColors);
if mod(nSparseSpots, nColors) ~= 0
    warning('generateStim_sparseBalanced:roundedDown', ...
        ['nSparseSpots (%d) is not divisible by 2 colors. ' ...
         'Using %d per color (total = %d, not %d).'], ...
        nSparseSpots, nPerColor, nPerColor*nColors, nSparseSpots);
end

%% epoch sizing (Pad-Block-Shuffle)
remainder = mod(nPositions, nPerColor);
if remainder == 0
    nVirtual = 0;
else
    nVirtual = nPerColor - remainder;
end
nSlots          = nPositions + nVirtual;
framesPerEpoch  = nSlots / nPerColor;

%% pre-allocate output
noiseMovie = zeros(nChecksY, nChecksX, nFrames, 'int8');

%% generation loop
currentFrame = 0;
while currentFrame < nFrames
    universePerm = randperm(nSlots);
    blocks       = reshape(universePerm, nPerColor, framesPerEpoch);

    % Latin-shift schedule: row c uses block (i + (c-1)) mod
    % framesPerEpoch. With nColors=2 this means white uses block i and
    % black uses block i+1, ensuring disjointness within each frame.
    baseIdx       = 1:framesPerEpoch;
    blockSchedule = zeros(nColors, framesPerEpoch);
    for c = 1:nColors
        blockSchedule(c, :) = circshift(baseIdx, -(c-1));
    end

    % shuffle frame order to destroy temporal predictability
    frameOrder    = randperm(framesPerEpoch);
    blockSchedule = blockSchedule(:, frameOrder);

    for i = 1:framesPerEpoch
        if currentFrame >= nFrames
            break
        end
        currentFrame = currentFrame + 1;

        % gather raw block contents per color
        frameIdx = cell(1, nColors);
        allThis  = zeros(1, nColors * nPerColor);
        for c = 1:nColors
            raw                    = blocks(:, blockSchedule(c, i))';
            frameIdx{c}            = raw;
            allThis((c-1)*nPerColor + (1:nPerColor)) = raw;
        end

        % replace virtual padding with unused real positions
        usedReal      = allThis(allThis <= nPositions);
        availablePool = setdiff(1:nPositions, usedReal);
        availablePool = availablePool(randperm(length(availablePool)));
        poolPtr       = 1;
        for c = 1:nColors
            vals     = frameIdx{c};
            virtMask = vals > nPositions;
            nVirt    = sum(virtMask);
            if nVirt > 0
                if poolPtr + nVirt - 1 > length(availablePool)
                    error('generateStim_sparseBalanced:fillerLogic', ...
                        ['Filler logic error: not enough unique ' ...
                         'pixels left to fill frame %d.'], currentFrame);
                end
                fillers           = availablePool(poolPtr:poolPtr + nVirt - 1);
                vals(virtMask)    = fillers;
                poolPtr           = poolPtr + nVirt;
            end
            frameIdx{c} = vals;
        end

        % paint the frame
        frame                 = zeros(nChecksY, nChecksX, 'int8');
        frame(frameIdx{1})    = +1;   % white
        frame(frameIdx{2})    = -1;   % black
        noiseMovie(:, :, currentFrame) = frame;
    end
end

%% per-frame validation (lightweight)
% These assertions guard against a future algorithmic regression. They
% are O(nFrames) and add ~1% to generation time at typical sizes.
for f = 1:nFrames
    frame    = noiseMovie(:, :, f);
    nWhite   = sum(frame(:) == +1);
    nBlack   = sum(frame(:) == -1);
    if nWhite ~= nPerColor || nBlack ~= nPerColor
        error('generateStim_sparseBalanced:countMismatch', ...
            ['Frame %d count mismatch: white=%d, black=%d ' ...
             '(expected %d each).'], f, nWhite, nBlack, nPerColor);
    end
end

end
