function updateSTAChannelBrowser(bd, staAccum, staSpikeCount, rfCentersDeg)
% updateSTAChannelBrowser  Refresh per-channel STA browser tiles.
%
%   updateSTAChannelBrowser(bd, staAccum, staSpikeCount)
%   updateSTAChannelBrowser(bd, staAccum, staSpikeCount, rfCentersDeg)
%
%   For each channel:
%     - mean STA = staAccum{ch} / staSpikeCount(ch)
%     - if chromatic (bd.isChromatic): collapse to color-blind magnitude
%       via per-pixel L2 norm across the 3rd dim (DKL axes), yielding
%       an [nY, nX, nLags] tensor before lag-energy / peak-lag selection
%     - lagEnergy(k) = sum(sum(slice(:, :, k).^2))
%     - peakLag = argmax(lagEnergy); display slice(:,:,peakLag)
%     - update top imagesc CData, bottom line YData, and the 'x' marker
%
%   rfCentersDeg (optional, nCh x 2) is the per-channel RF center
%   estimate in dva (output of computeRFCenters). When supplied, a 'k+'
%   marker on each tile's image axes is moved to that location. NaN rows
%   hide the marker. Omit or pass [] to leave markers at their previous
%   positions.
%
%   CLim policy:
%     - 'per-channel' (default): each visible tile uses symmetric
%       [-cMax, cMax] off its own slice
%     - 'global': one symmetric range is computed across all currently
%       visible tiles' slices and applied uniformly. Useful for
%       cross-channel amplitude comparison.
%
%   Channels with zero spikes get a blank slice and a flat curve; the
%   tile title still updates so the experimenter sees N=0.
%
%   This routine never adds or removes graphics objects -- only CData /
%   XData / YData / CLim / Text are mutated.

if nargin < 4, rfCentersDeg = []; end

if ~isstruct(bd) || ~isfield(bd, 'fig') || ~isvalid(bd.fig)
    return;
end

% Pull the live bd back off the figure -- the user may have changed the
% selection or the CLim toggle since this caller cached its handle.
bd = bd.fig.UserData;

nCh   = bd.nChannels;
nLags = bd.nLags;
sel   = bd.selectedChannels;

% Optional second pass: collect peak-lag slices for the visible tiles
% so we can apply a global CLim if requested. We compute all channels'
% slices unconditionally (cheap relative to the strobe / draw loop) so
% the per-channel update loop below never has to redo work.

% Stash per-channel results so we don't recompute in the second pass.
sliceByCh   = cell(1, nCh);
energyByCh  = cell(1, nCh);
peakLagByCh = nan(1, nCh);

for ch = 1:nCh
    if staSpikeCount(ch) < 1
        % No spikes: display a zero slice / flat curve.
        sliceByCh{ch}   = zeros(2);
        energyByCh{ch}  = zeros(1, nLags);
        peakLagByCh(ch) = 1;
        continue;
    end

    sta = staAccum{ch} / staSpikeCount(ch);
    if bd.isChromatic
        % Sanity: 4D expected.
        if ndims(sta) ~= 4 %#ok<ISMAT>
            error('updateSTAChannelBrowser:badShape', ...
                ['isChromatic=true but staAccum{%d} is %d-D, ' ...
                 'expected 4-D [nY x nX x 3 x nLags].'], ch, ndims(sta));
        end
        % Per-pixel L2 norm across DKL axes -> [nY, nX, nLags].
        sta = squeeze(sqrt(sum(sta.^2, 3)));
    end

    energy = squeeze(sum(sum(sta.^2, 1), 2));
    energy = energy(:)';   % [1 x nLags]
    [~, peakLag] = max(energy);
    sliceByCh{ch}   = sta(:, :, peakLag);
    energyByCh{ch}  = energy;
    peakLagByCh(ch) = peakLag;
end

% Compute global CLim if needed.
useGlobal = strcmp(bd.climMode, 'global');
globalCMax = 0;
if useGlobal && ~isempty(sel)
    for k = 1:numel(sel)
        ch = sel(k);
        s = sliceByCh{ch};
        if ~isempty(s)
            v = max(abs(s(:)));
            if v > globalCMax, globalCMax = v; end
        end
    end
    if globalCMax == 0, globalCMax = 1; end
end

% Apply updates. Iterate over ALL channels so the tiles a user might
% reveal next selection-toggle are also up to date when revealed.
for ch = 1:nCh
    if ~isgraphics(bd.imgObj(ch)), continue; end

    slice  = sliceByCh{ch};
    energy = energyByCh{ch};
    peakLag = peakLagByCh(ch);

    set(bd.imgObj(ch), 'CData', slice);
    if useGlobal
        set(bd.imgAx(ch), 'CLim', [-globalCMax, globalCMax]);
    else
        cMax = max(abs(slice(:)));
        if cMax == 0, cMax = 1; end
        set(bd.imgAx(ch), 'CLim', [-cMax, cMax]);
    end

    if isgraphics(bd.lineObj(ch))
        set(bd.lineObj(ch), 'XData', bd.lagAxisMs, 'YData', energy);
    end
    if isgraphics(bd.markerObj(ch))
        if all(energy == 0)
            set(bd.markerObj(ch), 'XData', NaN, 'YData', NaN);
        else
            set(bd.markerObj(ch), 'XData', bd.lagAxisMs(peakLag), ...
                'YData', energy(peakLag));
        end
    end
    if isgraphics(bd.lineAx(ch))
        % Pad the y-axis upper bound so the marker isn't flush with
        % the top edge.
        ymax = max(energy) * 1.1 + eps;
        if ymax <= 0, ymax = 1; end
        ylim(bd.lineAx(ch), [0, ymax]);
    end

    set(bd.titleObj(ch), 'Text', sprintf('ch %d  N=%d  peak %d ms', ...
        ch, staSpikeCount(ch), bd.lagAxisMs(peakLag)));

    if ~isempty(rfCentersDeg) && isfield(bd, 'rfCenterMarker') && ...
            isgraphics(bd.rfCenterMarker(ch))
        cx = rfCentersDeg(ch, 1);
        cy = rfCentersDeg(ch, 2);
        if isnan(cx) || isnan(cy)
            set(bd.rfCenterMarker(ch), 'XData', NaN, 'YData', NaN);
        else
            set(bd.rfCenterMarker(ch), 'XData', cx, 'YData', cy);
        end
    end
end

end
