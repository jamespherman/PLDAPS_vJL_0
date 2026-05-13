function bd = initCheckerboardChannelBrowser(nCh, nCheckSize, nContrast, ...
    checkSizesDva, checkContrasts)
% initCheckerboardChannelBrowser  Per-channel browser for checkerboard rfMap.
%
%   bd = initCheckerboardChannelBrowser(nCh, nCheckSize, nContrast, ...
%       checkSizesDva, checkContrasts)
%
%   Wraps pds.initChannelBrowser with an image-only tile per channel:
%     - x axis = contrast index 1..nContrast (labels = checkContrasts)
%     - y axis = checkSize index 1..nCheckSize (labels = checkSizesDva)
%     - color  = F1 amplitude at that (size, contrast) cell
%
%   F1 is non-negative, so the colormap defaults to 'parula' (sequential)
%   rather than the divergent blue-white-red used by the spatial-RF
%   browsers. Per-channel CLim spans [0, max(slice)]; global spans
%   [0, max across visible tiles]. The existing per-condition kernel /
%   F1F2-bar grid from initSTADisplay_checkerboard remains the place to
%   inspect temporal kernels and the F2 channel; this browser is for
%   cross-channel scanning of "which check size + contrast drives this
%   cell most strongly".
%
%   bd is the struct from pds.initChannelBrowser plus:
%     .nCheckSize, .nContrast - cached dimensions for the updater
%     .checkSizesDva          - row labels (visible on the leftmost tile)
%     .checkContrasts         - column labels (visible on the bottom tile)

if nargin < 4 || isempty(checkSizesDva),   checkSizesDva   = 1:nCheckSize; end
if nargin < 5 || isempty(checkContrasts),  checkContrasts  = 1:nContrast;  end

opts = struct( ...
    'figName',          'rfMap STA - Checkerboard channel browser', ...
    'imgXLabel',        'contrast', ...
    'imgYLabel',        'check size (dva)', ...
    'colormap',         parula(256), ...
    'initialSelection', 1:min(nCh, 16), ...
    'climMode',         'per-channel', ...
    'figPos',           [60 60 1500 850]);

bd = pds.initChannelBrowser(nCh, 'image', opts);
bd.nCheckSize     = nCheckSize;
bd.nContrast      = nContrast;
bd.checkSizesDva  = checkSizesDva(:)';
bd.checkContrasts = checkContrasts(:)';

% Pre-set XData/YData on every tile to the actual condition labels so
% pixel coords map to physically meaningful axes. The image is
% [nCheckSize x nContrast]; XData = contrasts, YData = sizes.
for ch = 1:nCh
    if isgraphics(bd.imgObj(ch))
        set(bd.imgObj(ch), ...
            'CData', zeros(nCheckSize, nContrast), ...
            'XData', bd.checkContrasts, ...
            'YData', bd.checkSizesDva);
    end
    if isgraphics(bd.imgAx(ch))
        % Pin the axes to the data ranges so the colormap doesn't
        % stretch over a single empty pixel before the first trial.
        xlim(bd.imgAx(ch), [bd.checkContrasts(1), bd.checkContrasts(end)] + ...
            [-1 1] * 0.5 * mean(diff([bd.checkContrasts, bd.checkContrasts(end) + 1])));
        ylim(bd.imgAx(ch), [bd.checkSizesDva(1), bd.checkSizesDva(end)] + ...
            [-1 1] * 0.5 * mean(diff([bd.checkSizesDva, bd.checkSizesDva(end) + 1])));
    end
end

bd.fig.UserData = bd;

end
