function p = i1ScanDklRedLumAxis(p, varargin)
% i1ScanDklRedLumAxis
%
% Robust i1 scan of the red DKL luminance axis.
%
% Goal:
%   Automatically measure which DKL luminance values, along the current
%   SRS red direction, correspond to physical luminances near the
%   Dubey/Pesaran range.
%
% This version is deliberately simple and robust:
%   1) it adds the known i1 mex folder to the MATLAB path
%   2) it asks for i1 cradle calibration before any long scan
%   3) it scans one DKL luminance value at a time
%   4) it displays direct RGB full-screen colors, like i1Validate.m
%   5) it saves a measured table and suggested low/high DKL values
%
% It does NOT modify the task CLUT permanently. Once good DKL values are
% found, put them in srs_settings.m as:
%   p.trVarsInit.luminanceRedDklLow  = <suggested low>;
%   p.trVarsInit.luminanceRedDklHigh = <suggested high>;
%
% Recommended call from srs_run measurement mode:
%   p = i1ScanDklRedLumAxis(p, 'nRepeats', 1, 'settleTime', 0.25);

%% ------------------------------------------------------------
% Options
% -------------------------------------------------------------

i1Path = '/home/herman_lab/OneDrive/Code/i1';

nRepeats = 1;
settleTime = 0.25;

targetLowCdM2  = 0.01;
targetHighCdM2 = 12.15;

% Conservative default grid. Increase resolution after first successful run.
lumGrid = linspace(-1.00, 0.25, 51);

% If empty, use p.draw.clut.dklRedLumSatRad when available.
forcedRedDklSatRad = [];

for iArg = 1:2:numel(varargin)
    switch lower(varargin{iArg})
        case 'nrepeats'
            nRepeats = varargin{iArg + 1};
        case 'settletime'
            settleTime = varargin{iArg + 1};
        case 'targetlow'
            targetLowCdM2 = varargin{iArg + 1};
        case 'targethigh'
            targetHighCdM2 = varargin{iArg + 1};
        case 'lumgrid'
            lumGrid = varargin{iArg + 1};
        case 'i1path'
            i1Path = varargin{iArg + 1};
        case 'reddklsatrad'
            forcedRedDklSatRad = varargin{iArg + 1};
        otherwise
            error('Unknown option: %s', varargin{iArg});
    end
end

lumGrid = lumGrid(:);

%% ------------------------------------------------------------
% Make sure I1 is available
% -------------------------------------------------------------

if exist(i1Path, 'dir')
    addpath(i1Path);
    rehash;
end

if exist('I1', 'file') ~= 3 && exist('I1', 'file') ~= 2
    error(['I1 was not found. Add the i1 mex folder to the MATLAB path. ', ...
           'Expected path: ' i1Path]);
end

%% ------------------------------------------------------------
% Basic checks
% -------------------------------------------------------------

if ~isfield(p, 'draw') || ~isfield(p.draw, 'window') || isempty(p.draw.window)
    error('p.draw.window is missing. Launch this through the PLDAPS GUI so the PTB window exists.');
end

if exist('dkl2rgb', 'file') ~= 2
    error('dkl2rgb.m was not found on the MATLAB path.');
end

global M_dkl2rgb
if isempty(M_dkl2rgb)
    if isfield(p, 'init') && isfield(p.init, 'initMonFile')
        initmon(p.init.initMonFile);
    elseif isfield(p, 'init') && isfield(p.init, 'pcName')
        initmon(['LUT_VPIXX_rig' p.init.pcName(end-1)]);
    else
        error('M_dkl2rgb is empty and no monitor init file could be inferred.');
    end
end

%% ------------------------------------------------------------
% Connect and calibrate i1 FIRST
% -------------------------------------------------------------

p.rig.i1Connected = I1('IsConnected');

if ~p.rig.i1Connected
    warning('i1 does not appear connected according to I1(''IsConnected'').');
end

disp('Place photometer in calibration cradle, then press any keyboard key.');
pause;

I1('Calibrate');

disp('i1 calibration complete.');
disp('Place photometer on the screen for measurement, then press any keyboard key.');
pause;

%% ------------------------------------------------------------
% Determine red DKL hue and saturation
% -------------------------------------------------------------

if isfield(p.draw, 'clut') && isfield(p.draw.clut, 'dklRedLumHueDeg')
    redDklHueDeg = p.draw.clut.dklRedLumHueDeg;
else
    redDklHueDeg = NaN;
end

if ~isempty(forcedRedDklSatRad)
    redDklSatRad = forcedRedDklSatRad;
elseif isfield(p.draw, 'clut') && isfield(p.draw.clut, 'dklRedLumSatRad')
    redDklSatRad = p.draw.clut.dklRedLumSatRad;
else
    redDklSatRad = 0.35;
end

% If initClut did not already compute redDklHueDeg, find the DKL direction
% closest to the SRS red. This is done after i1 calibration to avoid any
% pre-cradle crash.
targetRedRGB = [225 0 76] / 255;

if ~isfinite(redDklHueDeg)
    candidateHues = 0:359;
    candidateErr = nan(size(candidateHues));
    refLum = -0.80;

    for iHue = 1:numel(candidateHues)
        theta = candidateHues(iHue);

        dklColor = [refLum; ...
                    redDklSatRad * cosd(theta); ...
                    redDklSatRad * sind(theta)];

        if ~localInGamut(dklColor)
            continue
        end

        [r, g, b] = dkl2rgb(dklColor, targetRedRGB);
        thisRGB = [r g b];

        if any(~isfinite(thisRGB)) || any(thisRGB < 0) || any(thisRGB > 1)
            continue
        end

        candidateErr(iHue) = sum((thisRGB - targetRedRGB).^2);
    end

    if all(~isfinite(candidateErr))
        error('Could not find any in-gamut DKL red direction. Try lower redDklSatRad.');
    end

    [~, bestIdx] = min(candidateErr);
    redDklHueDeg = candidateHues(bestIdx);
end

fprintf('Using red DKL hue: %.1f deg\n', redDklHueDeg);
fprintf('Using red DKL saturation: %.3f\n', redDklSatRad);

%% ------------------------------------------------------------
% Scan one DKL luminance value at a time
% -------------------------------------------------------------

nLum = numel(lumGrid);

rgbNorm = nan(nLum, 3);
rgb255 = nan(nLum, 3);
inGamut = false(nLum, 1);
measurements = nan(3, nLum, nRepeats);

for iLum = 1:nLum

    thisLum = lumGrid(iLum);

    dklColor = [thisLum; ...
                redDklSatRad * cosd(redDklHueDeg); ...
                redDklSatRad * sind(redDklHueDeg)];

    if ~localInGamut(dklColor)
        fprintf('Skipping DKL %.3f: out of gamut before gamma correction.\n', thisLum);
        continue
    end

    try
        [r, g, b] = dkl2rgb(dklColor, targetRedRGB);
        thisRGB = [r g b];
    catch ME
        fprintf('Skipping DKL %.3f: dkl2rgb error: %s\n', thisLum, ME.message);
        continue
    end

    if any(~isfinite(thisRGB)) || any(thisRGB < 0) || any(thisRGB > 1)
        fprintf('Skipping DKL %.3f: invalid RGB after dkl2rgb.\n', thisLum);
        continue
    end

    inGamut(iLum) = true;
    rgbNorm(iLum, :) = thisRGB;
    rgb255(iLum, :) = round(255 * thisRGB);

    fprintf('Measuring %d/%d: DKL %.3f, RGB [%d %d %d]\n', ...
        iLum, nLum, thisLum, rgb255(iLum, 1), rgb255(iLum, 2), rgb255(iLum, 3));

    for iRep = 1:nRepeats
        Screen('FillRect', p.draw.window, rgb255(iLum, :));
        Screen('Flip', p.draw.window);
        WaitSecs(settleTime);

        I1('TriggerMeasurement');
        measurements(:, iLum, iRep) = I1('GetTriStimulus');
    end
end

%% ------------------------------------------------------------
% Restore background
% -------------------------------------------------------------

if isfield(p.draw, 'color') && isfield(p.draw.color, 'background')
    Screen('FillRect', p.draw.window, p.draw.color.background);
else
    Screen('FillRect', p.draw.window, 0);
end
Screen('Flip', p.draw.window);

%% ------------------------------------------------------------
% Average measurements
% -------------------------------------------------------------

measuredCdM2 = nan(nLum, 1);
measuredCdM2_sd = nan(nLum, 1);

for iLum = 1:nLum
    vals = squeeze(measurements(1, iLum, :));
    vals = vals(isfinite(vals));

    if ~isempty(vals)
        measuredCdM2(iLum) = mean(vals);
        measuredCdM2_sd(iLum) = std(vals);
    end
end

scanTable = table( ...
    lumGrid(:), ...
    inGamut(:), ...
    rgbNorm(:, 1), ...
    rgbNorm(:, 2), ...
    rgbNorm(:, 3), ...
    rgb255(:, 1), ...
    rgb255(:, 2), ...
    rgb255(:, 3), ...
    measuredCdM2, ...
    measuredCdM2_sd, ...
    'VariableNames', { ...
        'dklLum', ...
        'inGamut', ...
        'rgbR_norm', ...
        'rgbG_norm', ...
        'rgbB_norm', ...
        'rgbR_255', ...
        'rgbG_255', ...
        'rgbB_255', ...
        'measuredCdM2', ...
        'measuredCdM2_sd'});

%% ------------------------------------------------------------
% Pick suggested DKL values for Dubey/Pesaran target range
% -------------------------------------------------------------

validMeasured = scanTable.inGamut & isfinite(scanTable.measuredCdM2);

suggestedLow = table();
suggestedHigh = table();

if any(validMeasured)
    validTable = scanTable(validMeasured, :);

    [~, lowIdx] = min(abs(validTable.measuredCdM2 - targetLowCdM2));
    [~, highIdx] = min(abs(validTable.measuredCdM2 - targetHighCdM2));

    suggestedLow = validTable(lowIdx, :);
    suggestedHigh = validTable(highIdx, :);

    disp(' ');
    disp('Suggested DKL values based on measured cd/m2:');
    disp('LOW target:');
    disp(suggestedLow(:, {'dklLum', 'measuredCdM2', 'rgbR_255', 'rgbG_255', 'rgbB_255'}));

    disp('HIGH target:');
    disp(suggestedHigh(:, {'dklLum', 'measuredCdM2', 'rgbR_255', 'rgbG_255', 'rgbB_255'}));

    fprintf('\nCopy these into srs_settings.m after checking with James:\n');
    fprintf('p.trVarsInit.luminanceRedDklLow  = %.4f;\n', suggestedLow.dklLum);
    fprintf('p.trVarsInit.luminanceRedDklHigh = %.4f;\n', suggestedHigh.dklLum);
else
    warning('No valid measured DKL luminance values found.');
end

%% ------------------------------------------------------------
% Store and save
% -------------------------------------------------------------

p.rig.displayCal.srsRedDklLumScan.table = scanTable;
p.rig.displayCal.srsRedDklLumScan.measurements = measurements;
p.rig.displayCal.srsRedDklLumScan.redDklHueDeg = redDklHueDeg;
p.rig.displayCal.srsRedDklLumScan.redDklSatRad = redDklSatRad;
p.rig.displayCal.srsRedDklLumScan.targetLowCdM2 = targetLowCdM2;
p.rig.displayCal.srsRedDklLumScan.targetHighCdM2 = targetHighCdM2;
p.rig.displayCal.srsRedDklLumScan.suggestedLow = suggestedLow;
p.rig.displayCal.srsRedDklLumScan.suggestedHigh = suggestedHigh;

if isfield(p, 'init') && isfield(p.init, 'outputFolder') && ...
        isfield(p.init, 'sessionId')
    saveString = fullfile( ...
        p.init.outputFolder, ...
        [p.init.sessionId '_srsRedDklLumScan_i1Data.mat']);
else
    saveString = fullfile( ...
        pwd, ...
        [datestr(now, 'yyyymmdd_HHMMSS') '_srsRedDklLumScan_i1Data.mat']);
end

disp(['Saving DKL red luminance scan to: ' saveString]);

save(saveString, ...
    'scanTable', ...
    'measurements', ...
    'redDklHueDeg', ...
    'redDklSatRad', ...
    'targetLowCdM2', ...
    'targetHighCdM2', ...
    'suggestedLow', ...
    'suggestedHigh');

%% ------------------------------------------------------------
% Plots
% -------------------------------------------------------------

figure('Name', 'Red DKL luminance scan');
plot(scanTable.dklLum, scanTable.measuredCdM2, 'o-', 'LineWidth', 1.5);
hold on;
yline(targetLowCdM2, '--');
yline(targetHighCdM2, '--');
xlabel('DKL luminance value');
ylabel('Measured luminance, cd/m2');
title('Measured luminance along red DKL axis');
box off;

figure('Name', 'Red DKL luminance scan RGB');
plot(scanTable.dklLum, scanTable.rgbR_255, 'r-', 'LineWidth', 1.5);
hold on;
plot(scanTable.dklLum, scanTable.rgbG_255, 'g-', 'LineWidth', 1.5);
plot(scanTable.dklLum, scanTable.rgbB_255, 'b-', 'LineWidth', 1.5);
xlabel('DKL luminance value');
ylabel('RGB value');
title('RGB values for red DKL scan');
legend({'R', 'G', 'B'});
box off;

disp('Red DKL luminance scan complete.');

end

%% ========================================================================
% Local helper
% ========================================================================

function tf = localInGamut(dklColor)
% Check pre-gamma RGB gamut from DKL coordinates.

global M_dkl2rgb

if isempty(M_dkl2rgb)
    tf = false;
    return
end

rawRGB = round((0.5 + M_dkl2rgb * dklColor / 2) * 255);
tf = all(isfinite(rawRGB)) && all(rawRGB >= 0) && all(rawRGB <= 255);

end
