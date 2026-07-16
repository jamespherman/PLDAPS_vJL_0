function p                      = initClut(p)
% initialize color lookup tables
% CLUTs may be customized as needed
% CLUTS also need to be defined before initializing DataPixx
% also define variables as pointers to certain colors (for ease of
% reference in other places).


% initialize DKL conversion variables`
p.init.initMonFile = ['LUT_VPIXX_rig' p.init.pcName(end-1)];
initmon(p.init.initMonFile);

% Achromatic gray background for luminance mode. The setting is a DKL
% luminance coordinate, not a physical cd/m2 value. Hue/contrast mode can
% still replace the background trial-by-trial later in applySalience().
srsBackgroundDklLum = 0.12;
if isfield(p, 'trVarsInit') && ...
        isfield(p.trVarsInit, 'srsLuminanceBackgroundDklLum')
    srsBackgroundDklLum = p.trVarsInit.srsLuminanceBackgroundDklLum;
end

[bgRGB(1), bgRGB(2), bgRGB(3)] = ...
    dkl2rgb([srsBackgroundDklLum 0 0]');

p.draw.clut.srsBackgroundDklLum = srsBackgroundDklLum;
p.draw.clut.srsBackgroundRGB = bgRGB;

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
    oldGreen;           % 13
    1, 0, 0]; %14 Test

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
    oldGreen;    % 13
    1, 0, 0]; %14 ? test

assert(size(p.draw.clut.subColors,1)==size(p.draw.clut.expColors,1), 'ERROR-- exp & sub Colors must have equal length')

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

%% ------------------------------------------------------------
% DKL red luminance range for SRS luminance targets
% ------------------------------------------------------------
% We do not update the CLUT during the task.
% Instead, we precompute several RED DKL luminance levels and choose among them.
%
% This changes ONLY the luminance salience mode.
% The hue/contrast mode below is left unchanged.

p.draw.clutIdx.redLumStart = 200;   % 0-based CLUT index
p.draw.clutIdx.redLumN     = 32;    % number of luminance levels

redLumStart = p.draw.clutIdx.redLumStart;
redLumN     = p.draw.clutIdx.redLumN;

%% ------------------------------------------------------------
% Settings for DKL red luminance ramp
% ------------------------------------------------------------
% New preferred format:
%   luminanceRedDklLow  = lowest DKL luminance value
%   luminanceRedDklHigh = highest DKL luminance value
%
% These are DKL coordinates, not cd/m².
%
% Older format, still supported:
%   luminanceRedDklMean ± luminanceRedDklHalfRange

% Default values from James discussion / current working hypothesis.
redDklLow  = -0.10;
redDklHigh =  0.14;

% Prefer explicit low/high values if present.
if isfield(p, 'trVarsInit') && isfield(p.trVarsInit, 'luminanceRedDklLow')
    redDklLow = p.trVarsInit.luminanceRedDklLow;
end

if isfield(p, 'trVarsInit') && isfield(p.trVarsInit, 'luminanceRedDklHigh')
    redDklHigh = p.trVarsInit.luminanceRedDklHigh;
end

% Backward compatibility:
% if low/high are not explicitly present, allow mean/halfRange.
if ~(isfield(p, 'trVarsInit') && ...
        isfield(p.trVarsInit, 'luminanceRedDklLow') && ...
        isfield(p.trVarsInit, 'luminanceRedDklHigh'))

    redDklMean = -0.495;
    if isfield(p, 'trVarsInit') && isfield(p.trVarsInit, 'luminanceRedDklMean')
        redDklMean = p.trVarsInit.luminanceRedDklMean;
    end

    redDklHalfRange = 0.10;
    if isfield(p, 'trVarsInit') && isfield(p.trVarsInit, 'luminanceRedDklHalfRange')
        redDklHalfRange = p.trVarsInit.luminanceRedDklHalfRange;
    end

    redDklLow  = redDklMean - redDklHalfRange;
    redDklHigh = redDklMean + redDklHalfRange;
end

% Safety check
if redDklHigh <= redDklLow
    error('luminanceRedDklHigh must be larger than luminanceRedDklLow.');
end

% Derived values for compatibility / reporting.
redDklMean      = mean([redDklLow, redDklHigh]);
redDklHalfRange = (redDklHigh - redDklLow) / 2;

% DKL red saturation.
redDklSatRad = 0.35;
if isfield(p, 'trVarsInit') && isfield(p.trVarsInit, 'luminanceRedDklSatRad')
    redDklSatRad = p.trVarsInit.luminanceRedDklSatRad;
end

% DKL red hue.
% NaN means: find the DKL hue direction closest to SRS red.
redDklHueDeg = NaN;
if isfield(p, 'trVarsInit') && isfield(p.trVarsInit, 'luminanceRedDklHueDeg')
    redDklHueDeg = p.trVarsInit.luminanceRedDklHueDeg;
end

% Target red used only to find the closest DKL chromatic direction.
targetRedRGB = redISH;
if isfield(p, 'trVarsInit') && isfield(p.trVarsInit, 'luminanceRedTargetRGB')
    targetRedRGB = p.trVarsInit.luminanceRedTargetRGB;
end

%% ------------------------------------------------------------
% Find DKL hue direction closest to SRS red, if needed
% ------------------------------------------------------------

if ~isfinite(redDklHueDeg)

    candidateHues = 0:359;
    candidateErr  = nan(size(candidateHues));

    for iHue = 1:numel(candidateHues)

        theta = candidateHues(iHue);

        dkl_color = [redDklMean; ...
                     redDklSatRad * cosd(theta); ...
                     redDklSatRad * sind(theta)];

        [r, g, b] = dkl2rgb(dkl_color);

        thisRGB = [r, g, b];

        candidateErr(iHue) = sum((thisRGB - targetRedRGB).^2);
    end

    [~, bestIdx] = min(candidateErr);
    redDklHueDeg = candidateHues(bestIdx);
end

%% ------------------------------------------------------------
% Create DKL luminance values
% ------------------------------------------------------------

% Higher DKL luminance values are mapped to brighter target entries.
redLumValues = linspace(redDklLow, redDklHigh, redLumN);

%% ------------------------------------------------------------
% Gamut safety
% ------------------------------------------------------------
% If the selected red direction/range is out of monitor gamut,
% shrink the saturation and the high endpoint until all entries fit.
%
% Important:
% We preserve the low endpoint as much as possible because low salience
% should remain close to the background. We shrink the high endpoint toward
% the low endpoint if needed.

global M_dkl2rgb

maxGamutIter = 25;
allInGamut = false;

for iTry = 1:maxGamutIter

    allInGamut = true;

    for iLum = 1:redLumN

        dkl_color = [redLumValues(iLum); ...
                     redDklSatRad * cosd(redDklHueDeg); ...
                     redDklSatRad * sind(redDklHueDeg)];

        rawRGB = round((0.5 + M_dkl2rgb * dkl_color / 2) * 255);

        if any(rawRGB < 0) || any(rawRGB > 255)
            allInGamut = false;
            break
        end
    end

    if allInGamut
        break
    end

    % Keep the same red DKL direction.
    % Reduce chromatic saturation and reduce the high-luminance excursion.
    redDklSatRad = redDklSatRad * 0.90;
    redDklHigh   = redDklLow + 0.90 * (redDklHigh - redDklLow);

    redLumValues = linspace(redDklLow, redDklHigh, redLumN);
end

if ~allInGamut
    warning('DKL red luminance ramp may still contain out-of-gamut values.');
end

%% ------------------------------------------------------------
% Store final values used by the task
% ------------------------------------------------------------

p.draw.clut.dklRedLumValues    = redLumValues;
p.draw.clut.dklRedLumHueDeg    = redDklHueDeg;
p.draw.clut.dklRedLumSatRad    = redDklSatRad;

p.draw.clut.dklRedLumLow       = redDklLow;
p.draw.clut.dklRedLumHigh      = redDklHigh;
p.draw.clut.dklRedLumMean      = mean([redDklLow, redDklHigh]);
p.draw.clut.dklRedLumHalfRange = (redDklHigh - redDklLow) / 2;



for iLum = 1:redLumN

    clutIdx = redLumStart + iLum - 1;   % 0-based
    rowIdx  = clutIdx + 1;              % MATLAB row index

    dkl_color = [redLumValues(iLum); ...
                 redDklSatRad * cosd(redDklHueDeg); ...
                 redDklSatRad * sind(redDklHueDeg)];

    [r, g, b] = dkl2rgb(dkl_color, targetRedRGB);
    thisRed = [r, g, b];

    % Real target color, visible the same way for experimenter and subject.
    p.draw.clut.expCLUT(rowIdx, :) = thisRed;
    p.draw.clut.subCLUT(rowIdx, :) = thisRed;
end

%% Hue Contrast ;

p.draw.clutIdx.expDkl0_subDkl0     = 20;
p.draw.clutIdx.expDkl20_subDkl20   = 21;
p.draw.clutIdx.expDkl180_subDkl180 = 22;
p.draw.clutIdx.expDkl200_subDkl200 = 23;

%% ------------------------------------------------------------
% DKL colors for hue / contrast salience
% Same method as conflict_task
% ------------------------------------------------------------

p.init.initMonFile = ['LUT_VPIXX_rig' p.init.pcName(end-1)];
initmon(p.init.initMonFile);

dkl_hues_to_calc = [0, 20, 180, 200];

p.draw.colors.dkl_hues = zeros(length(dkl_hues_to_calc), 3);

mean_lum = -0.495;
satRad = 0.4;

for i = 1:length(dkl_hues_to_calc)

    theta = dkl_hues_to_calc(i);

    dkl_color = [mean_lum; ...
                 satRad * cosd(theta); ...
                 satRad * sind(theta)];

    [r, g, b] = dkl2rgb(dkl_color);

    p.draw.colors.dkl_hues(i, :) = [r, g, b];
end

[r_gray, g_gray, b_gray] = dkl2rgb([mean_lum; 0; 0]);
p.draw.colors.isolumGray = [r_gray, g_gray, b_gray];

%% Insert DKL colors into CLUT

p.draw.clut.expCLUT(p.draw.clutIdx.expDkl0_subDkl0 + 1, :) = ...
    p.draw.colors.dkl_hues(1, :);

p.draw.clut.expCLUT(p.draw.clutIdx.expDkl20_subDkl20 + 1, :) = ...
    p.draw.colors.dkl_hues(2, :);

p.draw.clut.expCLUT(p.draw.clutIdx.expDkl180_subDkl180 + 1, :) = ...
    p.draw.colors.dkl_hues(3, :);

p.draw.clut.expCLUT(p.draw.clutIdx.expDkl200_subDkl200 + 1, :) = ...
    p.draw.colors.dkl_hues(4, :);

p.draw.clut.subCLUT(p.draw.clutIdx.expDkl0_subDkl0 + 1, :) = ...
    p.draw.colors.dkl_hues(1, :);

p.draw.clut.subCLUT(p.draw.clutIdx.expDkl20_subDkl20 + 1, :) = ...
    p.draw.colors.dkl_hues(2, :);

p.draw.clut.subCLUT(p.draw.clutIdx.expDkl180_subDkl180 + 1, :) = ...
    p.draw.colors.dkl_hues(3, :);

p.draw.clut.subCLUT(p.draw.clutIdx.expDkl200_subDkl200 + 1, :) = ...
    p.draw.colors.dkl_hues(4, :);

%% Exp-only overlay colors matched to the current DKL background for subject
% Keep experimenter overlays visible, but make them background-colored on
% the subject display in hue/contrast mode. This is required by srs_run.m
% function expOnlyColorForCurrentBg().

p.draw.clutIdx.expGrey25_subDkl0   = 30;
p.draw.clutIdx.expGrey25_subDkl180 = 31;
p.draw.clutIdx.expGrey70_subDkl0   = 32;
p.draw.clutIdx.expGrey70_subDkl180 = 33;
p.draw.clutIdx.expGrey90_subDkl0   = 34;
p.draw.clutIdx.expGrey90_subDkl180 = 35;
p.draw.clutIdx.expBlue_subDkl0     = 36;
p.draw.clutIdx.expBlue_subDkl180   = 37;
p.draw.clutIdx.expOrange_subDkl0   = 38;
p.draw.clutIdx.expOrange_subDkl180 = 39;
p.draw.clutIdx.expGreen_subDkl0    = 40;
p.draw.clutIdx.expGreen_subDkl180  = 41;
p.draw.clutIdx.expBlack_subDkl0    = 42;
p.draw.clutIdx.expBlack_subDkl180  = 43;

bg0RGB   = p.draw.colors.dkl_hues(1, :);  % DKL 0 background
bg180RGB = p.draw.colors.dkl_hues(3, :);  % DKL 180 background

overlayRows = { ...
    'expGrey25_subDkl0',   [0.25 0.25 0.25], bg0RGB; ...
    'expGrey25_subDkl180', [0.25 0.25 0.25], bg180RGB; ...
    'expGrey70_subDkl0',   [0.70 0.70 0.70], bg0RGB; ...
    'expGrey70_subDkl180', [0.70 0.70 0.70], bg180RGB; ...
    'expGrey90_subDkl0',   [0.90 0.90 0.90], bg0RGB; ...
    'expGrey90_subDkl180', [0.90 0.90 0.90], bg180RGB; ...
    'expBlue_subDkl0',     blueISH,          bg0RGB; ...
    'expBlue_subDkl180',   blueISH,          bg180RGB; ...
    'expOrange_subDkl0',   orangeISH,        bg0RGB; ...
    'expOrange_subDkl180', orangeISH,        bg180RGB; ...
    'expGreen_subDkl0',    greenISH,         bg0RGB; ...
    'expGreen_subDkl180',  greenISH,         bg180RGB; ...
    'expBlack_subDkl0',    [0 0 0],          bg0RGB; ...
    'expBlack_subDkl180',  [0 0 0],          bg180RGB};

for iOverlay = 1:size(overlayRows, 1)
    idxName = overlayRows{iOverlay, 1};
    expRGB  = overlayRows{iOverlay, 2};
    subRGB  = overlayRows{iOverlay, 3};

    rowIdx = p.draw.clutIdx.(idxName) + 1;

    p.draw.clut.expCLUT(rowIdx, :) = expRGB;
    p.draw.clut.subCLUT(rowIdx, :) = subRGB;

    % Also update these in case the display loader uses expColors/subColors.
    p.draw.clut.expColors(rowIdx, :) = expRGB;
    p.draw.clut.subColors(rowIdx, :) = subRGB;
end

end



