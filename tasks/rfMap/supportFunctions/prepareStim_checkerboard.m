function checkInfo = prepareStim_checkerboard( ...
    checkSizesDva, checkContrasts, screenWidthPx, screenHeightPx, ...
    checkSizesPix, refreshRate, checkReversalHz, ...
    lowSlots, highSlots, gpuMemCapBytes)
% prepareStim_checkerboard  Pre-render indexed checkerboard texture data.
%
%   checkInfo = prepareStim_checkerboard( ...
%       checkSizesDva, checkContrasts, screenWidthPx, screenHeightPx, ...
%       checkSizesPix, refreshRate, checkReversalHz, ...
%       lowSlots, highSlots, gpuMemCapBytes)
%
%   Pre-generates uint8 indexed-texture matrices for every
%   (checkSize, contrast) condition x 2 polarities. The matrices
%   contain only the per-contrast (low, high) CLUT slot values
%   installed by initClut.m, so polarity reversal at runtime is just
%   "draw texture A vs draw texture B" -- no CLUT churn, and reversals
%   land on PTB flips by construction.
%
%   This function returns DATA only (uint8 matrices). The caller is
%   responsible for uploading them to PTB via Screen('MakeTexture')
%   once the window exists; rfMap_init.m does this in its
%   uploadCheckerboardTextures helper.
%
%   Inputs:
%     checkSizesDva    - [1, nCheckSize] vector of check side lengths in dva
%     checkContrasts   - [1, nContrast] vector of Michelson contrasts (0..1]
%     screenWidthPx    - screen width in pixels (full-screen draw)
%     screenHeightPx   - screen height in pixels
%     checkSizesPix    - [1, nCheckSize] check side in pixels (caller
%                        converts via pds.deg2pix; the codebase has no
%                        p.rig.PixPerDeg field, deg2pix is the canonical
%                        unit conversion).
%     refreshRate      - display refresh rate in Hz (for validators)
%     checkReversalHz  - polarity reversal frequency in Hz
%     lowSlots         - [1, nContrast] 0-based CLUT slot for the low gray
%                        of each contrast (from p.init.checkerboardLowSlots)
%     highSlots        - [1, nContrast] 0-based CLUT slot for the high gray
%     gpuMemCapBytes   - hard cap on total texture memory (default 512 MB)
%
%   Output (struct):
%     checkInfo.textureData     - cell {nCheckSize x nContrast x 2} of
%                                 uint8 [nY, nX] matrices ready for
%                                 Screen('MakeTexture').
%     checkInfo.framesPerReversal - integer; how many display frames
%                                   between polarity flips.
%     checkInfo.conditionTable  - [nCond, 2] table mapping linear
%                                 condition index -> (checkSizeIdx,
%                                 contrastIdx).
%     checkInfo.nCheckSize / nContrast / nConditions - convenience.
%     checkInfo.totalBytes      - actual texture-memory estimate.
%     checkInfo.checkSizePix    - [1, nCheckSize] check side in pixels.
%
%   Validators (errors fast):
%     1. framesPerReversal must be a positive integer (else reversals
%        land between flips).
%     2. F2 = 2 * checkReversalHz < refreshRate / 2 (Nyquist).
%     3. Total texture bytes <= gpuMemCapBytes.

if nargin < 10 || isempty(gpuMemCapBytes)
    gpuMemCapBytes = 512 * 1024 * 1024;     % 512 MB
end

%% --- Validators ---------------------------------------------------------
% Round to nearest whole-frame reversal interval. PTB's MEASURED refresh
% rate is the right reference here, not the nominal rig-config value:
% measured rates have small non-integer offsets (e.g., 119.995 instead
% of 120), so requiring an exact-integer divisor would reject sane
% configurations. We round and then check that the effective reversal
% rate is within tolerance of the requested rate.
framesPerRevExact = refreshRate / checkReversalHz;
framesPerRev      = round(framesPerRevExact);
if framesPerRev < 1
    error('prepareStim_checkerboard:badReversalRate', ...
        ['checkReversalHz (%g) is too high for refresh rate %.3f Hz ' ...
         '(would need %.3f frames per reversal, < 1 frame).'], ...
         checkReversalHz, refreshRate, framesPerRevExact);
end

% Effective reversal rate at the actual refresh rate.
effRev = refreshRate / framesPerRev;
relErr = abs(effRev - checkReversalHz) / checkReversalHz;
% 0.5% tolerance: at 5 Hz request, that's 25 mHz; comfortably tighter
% than the LGN frequency-tuning bandwidth, but loose enough to absorb
% the typical PTB measurement offset.
if relErr > 0.005
    error('prepareStim_checkerboard:badReversalRate', ...
        ['checkReversalHz (%g) cannot be realized at refresh rate ' ...
         '%.3f Hz within tolerance: nearest integer-frame interval ' ...
         'is %d frames -> effective %g Hz (%.2f%% off). Use a value ' ...
         'with a near-integer divisor; legal set at %.3f Hz: %s.'], ...
         checkReversalHz, refreshRate, framesPerRev, effRev, ...
         100*relErr, refreshRate, ...
         legalSetForRefreshRate(refreshRate));
end

f2 = 2 * checkReversalHz;
nyquist = refreshRate / 2;
if f2 >= nyquist
    error('prepareStim_checkerboard:nyquist', ...
        ['F2 = 2 * checkReversalHz = %g Hz exceeds Nyquist (%.1f Hz) ' ...
         'at refresh rate %g Hz. Lower checkReversalHz to keep F2 ' ...
         'strictly below Nyquist.'], f2, nyquist, refreshRate);
end

%% --- Pre-compute conditions and texture-data layout --------------------
nCheckSize = numel(checkSizesDva);
nContrast  = numel(checkContrasts);
if nContrast ~= numel(lowSlots) || nContrast ~= numel(highSlots)
    error('prepareStim_checkerboard:slotMismatch', ...
        ['lowSlots/highSlots must have the same length as ' ...
         'checkContrasts (%d).'], nContrast);
end

% Check sizes in pixels (rounded; minimum 1 pixel). Caller pre-
% computed via pds.deg2pix; just enforce integer/positive here.
if numel(checkSizesPix) ~= numel(checkSizesDva)
    error('prepareStim_checkerboard:pixSizeMismatch', ...
        'checkSizesPix must have the same length as checkSizesDva.');
end
checkSizePix = max(1, round(checkSizesPix));

% Estimate total memory and bail before allocating if over cap.
totalBytes = 0;
for sz = 1:nCheckSize
    pxPerSide = checkSizePix(sz);
    nY = ceil(screenHeightPx / pxPerSide) * pxPerSide;
    nX = ceil(screenWidthPx  / pxPerSide) * pxPerSide;
    totalBytes = totalBytes + nCheckSize * 0 + nContrast * 2 * nY * nX;
    % NB: outer-loop variable sz is unused in cost; keep the formula
    % explicit per-size in case future revisions allow non-uniform
    % screen-fill per check size.
end
if totalBytes > gpuMemCapBytes
    error('prepareStim_checkerboard:memoryCap', ...
        ['Pre-rendered checkerboard textures would require %.1f MB, ' ...
         'over the cap of %.1f MB. Reduce checkSizesDva / ' ...
         'checkContrasts, or raise the cap explicitly.'], ...
        totalBytes / 1e6, gpuMemCapBytes / 1e6);
end

%% --- Build the indexed texture matrices --------------------------------
textureData    = cell(nCheckSize, nContrast, 2);
conditionTable = zeros(nCheckSize * nContrast, 2);
condIdx = 0;

for sz = 1:nCheckSize
    pxPerSide = checkSizePix(sz);
    nY = ceil(screenHeightPx / pxPerSide) * pxPerSide;
    nX = ceil(screenWidthPx  / pxPerSide) * pxPerSide;

    % Build a base [nY, nX] logical mask of the checkerboard pattern. Each
    % pxPerSide-by-pxPerSide block alternates between false / true such
    % that the (1,1) block is `false` (low slot) by convention.
    rowBlock = floor((0:nY-1) / pxPerSide);
    colBlock = floor((0:nX-1) / pxPerSide);
    [rowGrid, colGrid] = ndgrid(rowBlock, colBlock);
    baseMask = mod(rowGrid + colGrid, 2) == 1;     % logical [nY, nX]

    for ct = 1:nContrast
        condIdx = condIdx + 1;
        conditionTable(condIdx, :) = [sz, ct];

        loSlot = uint8(lowSlots(ct));
        hiSlot = uint8(highSlots(ct));

        % Polarity 1: false -> low, true -> high.
        tex1 = repmat(loSlot, nY, nX);
        tex1(baseMask) = hiSlot;

        % Polarity 2: swap (false -> high, true -> low). Equivalent to
        % bit-flipping the slot pair across baseMask.
        tex2 = repmat(hiSlot, nY, nX);
        tex2(baseMask) = loSlot;

        textureData{sz, ct, 1} = tex1;
        textureData{sz, ct, 2} = tex2;
    end
end

checkInfo.textureData       = textureData;
checkInfo.framesPerReversal = framesPerRev;
checkInfo.conditionTable    = conditionTable;
checkInfo.nCheckSize        = nCheckSize;
checkInfo.nContrast         = nContrast;
checkInfo.nConditions       = nCheckSize * nContrast;
checkInfo.totalBytes        = totalBytes;
checkInfo.checkSizePix      = checkSizePix;

fprintf(['prepareStim_checkerboard: %d sizes x %d contrasts ' ...
    '(%d conditions) x 2 polarities, ~%.1f MB texture data, ' ...
    '%d frames/reversal\n'], ...
    nCheckSize, nContrast, checkInfo.nConditions, totalBytes / 1e6, ...
    framesPerRev);

end


function s = legalSetForRefreshRate(rr)
% Build a printable list of in-spec reversal rates: those whose
% framesPerReversal = round(rr / candidate) gives an effective rate
% within 0.5% of the candidate, AND F2 = 2*candidate is below Nyquist.
% PTB-measured refresh rates aren't exact integers (e.g., 119.995),
% so we don't filter on integer divisibility -- just round-to-nearest
% and check the resulting error.
candidates = [50 25 20 15 12 10 8 6 5 4 3 2 1 0.5];
ok = false(size(candidates));
for ii = 1:numel(candidates)
    c = candidates(ii);
    fpr = round(rr / c);
    if fpr >= 1
        eff = rr / fpr;
        if abs(eff - c) / c < 0.005 && 2*c < rr/2
            ok(ii) = true;
        end
    end
end
parts = arrayfun(@(x) sprintf('%g', x), candidates(ok), ...
    'UniformOutput', false);
s = ['{', strjoin(parts, ', '), '}'];
end
