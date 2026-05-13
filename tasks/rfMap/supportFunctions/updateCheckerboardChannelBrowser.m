function updateCheckerboardChannelBrowser(bd, staAccum)
% updateCheckerboardChannelBrowser  Refresh checkerboard browser tiles.
%
%   updateCheckerboardChannelBrowser(bd, staAccum)
%
%   For each channel, pull the F1 amplitude per (checkSize, contrast)
%   cell from the running accumulator:
%       F1(sz, ct, ch) = f1f2AmpSum(1, sz, ct, ch) / f1f2TrialCount(sz, ct)
%   The slice is [nCheckSize x nContrast] (rows = size, cols = contrast)
%   and is non-negative by construction (mean of per-trial |z|). Cells
%   with zero trials display as 0.
%
%   CLim policy:
%     'per-channel' : [0, max(slice)] for each tile
%     'global'      : [0, max across visible tiles]
%
%   Tile title shows channel index, total spikes across all conditions
%   for that channel, and the (size, contrast) condition with the peak
%   F1 amplitude.

if ~isstruct(bd) || ~isfield(bd, 'fig') || ~isvalid(bd.fig)
    return;
end
if ~isstruct(staAccum) || ~isfield(staAccum, 'f1f2AmpSum') || ...
        ~isfield(staAccum, 'f1f2TrialCount')
    error('updateCheckerboardChannelBrowser:badAccum', ...
        'staAccum must be the checkerboard accumulator struct.');
end

% Re-fetch the live bd so we honor the user's most recent selection
% and CLim toggle state.
bd = bd.fig.UserData;

nCh        = bd.nChannels;
nCheckSize = bd.nCheckSize;
nContrast  = bd.nContrast;
sel        = bd.selectedChannels;

trialCount = staAccum.f1f2TrialCount;        % [nCheckSize x nContrast]
% Avoid divide-by-zero in cells with no trials yet.
safeCount  = trialCount;
safeCount(safeCount == 0) = 1;

% Pre-compute every channel's slice + summary stats so we can apply
% global CLim in a single sweep below.
sliceByCh    = cell(1, nCh);
peakSizeIdx  = nan(1, nCh);
peakCtrIdx   = nan(1, nCh);
totalSpikes  = zeros(1, nCh);

for ch = 1:nCh
    f1     = squeeze(staAccum.f1f2AmpSum(1, :, :, ch));   % [nCheckSize x nContrast]
    if size(f1, 1) ~= nCheckSize
        % squeeze can collapse a singleton dim; force the expected shape.
        f1 = reshape(f1, nCheckSize, nContrast);
    end
    f1(trialCount == 0) = 0;
    slice  = f1 ./ safeCount;
    sliceByCh{ch} = slice;
    [pk, idx] = max(slice(:));
    if pk > 0
        [r, c] = ind2sub([nCheckSize, nContrast], idx);
        peakSizeIdx(ch) = r;
        peakCtrIdx(ch)  = c;
    end
    totalSpikes(ch) = sum(reshape(staAccum.spikeCountPerCondCh(:, :, ch), 1, []));
end

useGlobal  = strcmp(bd.climMode, 'global');
globalCMax = 0;
if useGlobal && ~isempty(sel)
    for k = 1:numel(sel)
        ch = sel(k);
        v = max(sliceByCh{ch}(:));
        if v > globalCMax, globalCMax = v; end
    end
    if globalCMax == 0, globalCMax = 1; end
end

for ch = 1:nCh
    if ~isgraphics(bd.imgObj(ch)), continue; end
    slice = sliceByCh{ch};
    set(bd.imgObj(ch), 'CData', slice, ...
        'XData', bd.checkContrasts, 'YData', bd.checkSizesDva);

    if useGlobal
        cMax = globalCMax;
    else
        cMax = max(slice(:));
        if cMax == 0, cMax = 1; end
    end
    set(bd.imgAx(ch), 'CLim', [0, cMax]);

    if isnan(peakSizeIdx(ch))
        titleStr = sprintf('ch %d  N=%d  peak: --', ch, totalSpikes(ch));
    else
        titleStr = sprintf('ch %d  N=%d  peak: %.2fdeg @ c=%.2f', ...
            ch, totalSpikes(ch), ...
            bd.checkSizesDva(peakSizeIdx(ch)), ...
            bd.checkContrasts(peakCtrIdx(ch)));
    end
    set(bd.titleObj(ch), 'Text', titleStr);
end

end
