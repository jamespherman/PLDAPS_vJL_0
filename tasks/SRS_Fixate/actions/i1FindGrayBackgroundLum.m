function p = i1FindGrayBackgroundLum(p, varargin)
% i1FindGrayBackgroundLum
%
% Measure achromatic DKL gray backgrounds and find the DKL luminance value
% whose physical luminance is closest to a target cd/m2 value.
%
% This is intended for SRS_Fixate luminance mode.
%
% It measures colors of the form:
%   dkl_color = [dklLum; 0; 0]
%
% Output:
%   p.rig.displayCal.srsGrayBgScan.table
%   p.rig.displayCal.srsGrayBgScan.suggested
%
% Example:
%   p = i1FindGrayBackgroundLum(p, 'targetCdM2', 47.5);

%% Options

targetCdM2 = 47.5;
nRepeats = 3;
settleTime = 0.25;
dklGrid = linspace(-1.00, 0.40, 71);
saveTag = 'srsGrayBgScan';

for iArg = 1:2:numel(varargin)
    switch lower(varargin{iArg})
        case 'i1path'
            i1Path = varargin{iArg + 1};
        case 'targetcdm2'
            targetCdM2 = varargin{iArg + 1};
        case 'nrepeats'
            nRepeats = varargin{iArg + 1};
        case 'settletime'
            settleTime = varargin{iArg + 1};
        case 'dklgrid'
            dklGrid = varargin{iArg + 1};
        case 'savetag'
            saveTag = varargin{iArg + 1};
        otherwise
            error('Unknown option: %s', varargin{iArg});
    end
end

%% Basic checks

if ~isfield(p, 'draw') || ~isfield(p.draw, 'window') || isempty(p.draw.window)
    error('p.draw.window is missing. Launch through the PLDAPS GUI so the PTB window exists.');
end

%% Connect and calibrate i1 first

disp('Trying to connect to I1...')

p.rig.i1Connected = pds.I1('IsConnected');

if ~p.rig.i1Connected
    warning('i1 does not appear connected according to I1(''IsConnected'').');
end

disp('Place photometer in calibration cradle, then press any keyboard key.');
KbStrokeWait;   % PsychHID-based wait; MATLAB's pause() hangs while PTB holds the keyboard (ListenChar(-1)/fullscreen focus)

pds.I1('Calibrate');

disp('i1 calibration complete.');
disp('Place photometer on the screen for measurement, then press any keyboard key.');
KbStrokeWait;

%% Prepare and measure candidate gray backgrounds

nLum = numel(dklGrid);
rgbNorm = nan(nLum, 3);
rgb255 = nan(nLum, 3);
inGamut = false(nLum, 1);
measurements = nan(3, nLum, nRepeats);

hWait = waitbar(0, 'Measuring achromatic DKL gray backgrounds...');

validCount = 0;

for iLum = 1:nLum

    thisDklLum = dklGrid(iLum);
    dklColor = [thisDklLum; 0; 0];

    try
        [r, g, b] = dkl2rgb(dklColor);
        thisRGB = [r, g, b];
    catch ME
        warning('dkl2rgb failed for DKL %.4f: %s', thisDklLum, ME.message);
        continue
    end

    if any(~isfinite(thisRGB)) || any(thisRGB < 0) || any(thisRGB > 1)
        continue
    end

    inGamut(iLum) = true;
    rgbNorm(iLum, :) = thisRGB;
    rgb255(iLum, :) = round(255 * thisRGB);

    validCount = validCount + 1;

    for iRep = 1:nRepeats

        Screen('FillRect', p.draw.window, rgb255(iLum, :));
        Screen('Flip', p.draw.window);

        WaitSecs(settleTime);

        pds.I1('TriggerMeasurement');
        measurements(:, iLum, iRep) = pds.I1('GetTriStimulus');

        waitbar(((validCount - 1) * nRepeats + iRep) / ...
            max(1, nLum * nRepeats), hWait);
    end

    fprintf('Measured gray DKL %.4f, RGB [%d %d %d] LUM = %.2f\n', ...
        thisDklLum, rgb255(iLum, 1), rgb255(iLum, 2), rgb255(iLum, 3), ...
        measurements(1, iLum, iRep));
end

close(hWait);

%% Restore current task background

if isfield(p.draw, 'color') && isfield(p.draw.color, 'background')
    Screen('FillRect', p.draw.window, p.draw.color.background);
else
    Screen('FillRect', p.draw.window, 0);
end
Screen('Flip', p.draw.window);

%% Average measurements

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
    dklGrid(:), ...
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

validMeasured = scanTable.inGamut & isfinite(scanTable.measuredCdM2);

if ~any(validMeasured)
    error('No valid gray background measurements were obtained.');
end

validTable = scanTable(validMeasured, :);
[~, bestIdx] = min(abs(validTable.measuredCdM2 - targetCdM2));
suggested = validTable(bestIdx, :);

p.rig.displayCal.srsGrayBgScan.table = scanTable;
p.rig.displayCal.srsGrayBgScan.measurements = measurements;
p.rig.displayCal.srsGrayBgScan.targetCdM2 = targetCdM2;
p.rig.displayCal.srsGrayBgScan.suggested = suggested;

%% Save output

if isfield(p, 'init') && isfield(p.init, 'outputFolder') && ...
        isfield(p.init, 'sessionId')
    saveString = fullfile( ...
        p.init.outputFolder, ...
        [p.init.sessionId '_' saveTag '_i1Data.mat']);
else
    saveString = fullfile( ...
        pwd, ...
        [datestr(now, 'yyyymmdd_HHMMSS') '_' saveTag '_i1Data.mat']);
end

disp(['Saving gray background scan to: ' saveString]);

save(saveString, ...
    'scanTable', ...
    'measurements', ...
    'targetCdM2', ...
    'suggested');

%% Plots

figure('Name', 'SRS gray background DKL scan');
plot(scanTable.dklLum, scanTable.measuredCdM2, 'o-', 'LineWidth', 1.5);
hold on;
yline(targetCdM2, '--');
xline(suggested.dklLum, '--');
xlabel('Achromatic DKL luminance value');
ylabel('Measured luminance, cd/m2');
title('Measured luminance of achromatic DKL gray backgrounds');
box off;

figure('Name', 'SRS gray background RGB values');
plot(scanTable.dklLum, scanTable.rgbR_255, 'r-', 'LineWidth', 1.5);
hold on;
plot(scanTable.dklLum, scanTable.rgbG_255, 'g-', 'LineWidth', 1.5);
plot(scanTable.dklLum, scanTable.rgbB_255, 'b-', 'LineWidth', 1.5);
xlabel('Achromatic DKL luminance value');
ylabel('RGB value');
title('RGB values for achromatic DKL gray scan');
legend({'R', 'G', 'B'});
box off;

disp('Suggested gray background DKL value:');
disp(suggested(:, {'dklLum', 'measuredCdM2', 'rgbR_255', 'rgbG_255', 'rgbB_255'}));

fprintf('\nCopy this into srs_settings.m after checking the measured value:\n');
fprintf('p.trVarsInit.srsLuminanceBackgroundDklLum = %.4f; %% measured %.3f cd/m2\n', ...
    suggested.dklLum, suggested.measuredCdM2);

end
