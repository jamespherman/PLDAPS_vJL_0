function p                      = initClut(p)
% initialize color lookup tables
% CLUTs may be customized as needed
% CLUTS also need to be defined before initializing DataPixx
% also define variables as pointers to certain colors (for ease of
% reference in other places).


% initialize DKL conversion variables`
p.init.initMonFile = ['LUT_VPIXX_rig' p.init.pcName(end-1)];
initmon(p.init.initMonFile);

% set Background color to black.
[bgRGB(1), bgRGB(2), bgRGB(3)] = dkl2rgb([-0.8 0 0]');

% define muted green (mutGreen):
% mutGreen    = [0.3953 0.7459 0.5244];
mutGreen    = [0.5 0.9 0.4];

redISH      = [225 0 76]/255;
orangeISH   = [255 146 0]/255;
blueISH     = [11 97 164]/255;
greenISH    = [112 229 0]/255;
oldGreen    = [0.45, 0.63, 0.45];

% colors for exp's display
% black                     0
% grey-1 (grid-lines)       1
% grey-2 (background)       2
% grey-3 (fix-window)       3
% white  (fix-point)        4
% red                       5
% orange                    6
% blue                      7
% cue ring                  8
% muted green (fixation)    9

p.draw.clut.expColors = ...
    [ 0, 0, 0;          % 0
    0.25, 0.25, 0.25;   % 1
    bgRGB;              % 2
    0.7, 0.7, 0.7;      % 3
    1, 1, 1;            % 4
    redISH;             % 5
    orangeISH;          % 6
    blueISH;            % 7
    0, 1, 1;            % 8
    0.9,0.9,0.9;        % 9
    mutGreen;           % 10
    greenISH;           % 11
    0, 0, 0;            % 12
    oldGreen];          % 13


% colors for subject's display
% black                     0
% grey-2 (grid-lines)       2
% grey-2 (background)       2
% grey-2 (fix-window)       3
% white  (fix-point)        4
% grey-2 (red)              2
% grey-2 (green)            2
% grey-2 (blue)             2
% cuering                   8
% muted green (fixation)    9

p.draw.clut.subColors = ...
    [0, 0, 0;     % 0
    bgRGB;        % 1
    bgRGB;        % 2
    bgRGB;        % 3
    1, 1, 1;      % 4
    bgRGB;        % 5
    bgRGB;        % 6
    bgRGB;        % 7
    0, 1, 1;      % 8
    bgRGB;        % 9
    mutGreen;     % 10
    bgRGB;        % 11
    bgRGB;        % 12
    oldGreen];    % 13

assert(size(p.draw.clut.subColors,1)==size(p.draw.clut.expColors,1), 'ERROR-- exp & sub Colors must have equal length')

%% append per-stim-type CLUT slots (chromatic tri-noise palette)
% denseChromatic mode needs 8 reserved CLUT slots holding the 8
% sign-combo colors of binary tri-noise on (L-M, S, Achro). The
% generator emits state-index textures (uint8 0..7); generateNoiseTextures
% adds p.init.chromaticClutBase to land in these slots. Done here (not
% as a separate post-initClut step) so pds.initDataPixx loads the
% chromatic palette to VPixx in the same Screen('LoadNormalizedGammaTable')
% call as the rest of the CLUT.
if isfield(p, 'init') && isfield(p.init, 'stimType') && ...
        strcmp(p.init.stimType, 'denseChromatic')
    [paletteRGB, stateBits] = buildChromaticPalette( ...
        p.trVarsInit.dklAxes, p.trVarsInit.dklContrasts);

    % Fail fast if any tri-noise corner is out-of-gamut. dkl2rgb maps
    % out-of-range RGB to bgRGB, which silently collapses two states
    % to the same color and biases the STA. Operator-actionable fix:
    % lower dklContrasts.
    nUnique = size(unique(paletteRGB', 'rows'), 1);
    nStatesExpected = 2 ^ 3;
    if nUnique < nStatesExpected
        sMax = gamutMaxContrasts(p.trVarsInit.dklAxes, [1 1 1]);
        error('initClut:chromaticGamutClip', ...
            ['Chromatic palette has %d unique colors but %d are needed ' ...
             '(one or more tri-noise corners is out-of-gamut and got ' ...
             'clipped to bgRGB). Lower p.trVarsInit.dklContrasts ' ...
             '(currently %s). For this rig calibration, the max ' ...
             'in-gamut uniform contrast is %.4f; recommend ' ...
             'p.trVarsInit.dklContrasts = %.4f (5%% safety margin).'], ...
             nUnique, nStatesExpected, ...
             mat2str(p.trVarsInit.dklContrasts), sMax, 0.95 * sMax);
    end

    chromaticClutBase = size(p.draw.clut.expColors, 1);   % first free
    paletteFloat      = double(paletteRGB) / 255;          % [3, 8]
    p.draw.clut.expColors(end+1:end+nStatesExpected, :) = paletteFloat';
    p.draw.clut.subColors(end+1:end+nStatesExpected, :) = paletteFloat';

    p.init.chromaticClutBase   = chromaticClutBase;
    p.init.chromaticPaletteRGB = paletteRGB;
    p.init.chromaticStateBits  = stateBits;

    % Per-axis drive variance, indexed by axis order [LM, S, Achro].
    % Inactive axes get 0. Saved so offline analysis can renormalize
    % cross-axis STA amplitudes when dklContrasts is a non-uniform
    % vector (the raw STA scales by c_axis, so |sta(:,:,axis,k)| is
    % NOT directly comparable across axes without dividing by
    % sqrt(dklDriveVariancePerAxis(axis))).
    contrastVec = zeros(1, 3);
    if isscalar(p.trVarsInit.dklContrasts)
        contrastVec(p.trVarsInit.dklAxes) = p.trVarsInit.dklContrasts;
    else
        contrastVec(p.trVarsInit.dklAxes) = p.trVarsInit.dklContrasts(:)';
    end
    p.init.dklDriveVariancePerAxis = contrastVec .^ 2;

    fprintf(['initClut: chromatic mode -- installed %d palette ' ...
        'slots at %d..%d (drive var = [%.3g %.3g %.3g])\n'], ...
        nStatesExpected, chromaticClutBase, ...
        chromaticClutBase + nStatesExpected - 1, ...
        p.init.dklDriveVariancePerAxis(1), ...
        p.init.dklDriveVariancePerAxis(2), ...
        p.init.dklDriveVariancePerAxis(3));
end

%%

% fill the remaining LUT slots with background RGB.
p.draw.nColors                                          = size(p.draw.clut.subColors,1);
nTotalColors                                            = 256;
p.draw.clut.expColors(p.draw.nColors+1:nTotalColors, :) = repmat(bgRGB, nTotalColors - p.draw.nColors, 1);
p.draw.clut.subColors(p.draw.nColors+1:nTotalColors, :) = repmat(bgRGB, nTotalColors - p.draw.nColors, 1);

% populate the rest with 0's
p.draw.clut.ffc      = p.draw.nColors + 1;
p.draw.clut.expCLUT  = p.draw.clut.expColors;
p.draw.clut.subCLUT  = p.draw.clut.subColors;


end



