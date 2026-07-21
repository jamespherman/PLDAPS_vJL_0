function p = i1MeasureSrsRedLumRamp(p, varargin)
%I1MEASURESRSREDLUMRAMP Measure the task red CLUT ramp with the i1Pro.
%
% Measures the CLUT entries beginning at p.draw.clutIdx.redLumStart and
% stores a table containing CLUT index, DKL luminance, RGB and measured
% luminance in cd/m^2.
%
% Optional name/value inputs:
%   'nRepeats'   : measurements per color, default 3
%   'settleTime' : seconds after display flip, default 0.25
%   'saveTag'    : output filename tag
%   'i1Path'     : folder containing the directly callable I1.mexa64

opts = parseOptions(varargin{:});
assertTaskWindowAndRamp(p);
addI1Path(opts.i1Path);

redLumStart = p.draw.clutIdx.redLumStart;
redLumN = p.draw.clutIdx.redLumN;
clutIdxVec = redLumStart + (0:redLumN - 1);
nColors = numel(clutIdxVec);

dklLumValues = nan(nColors, 1);
if isfield(p.draw, 'clut') && isfield(p.draw.clut, 'dklRedLumValues')
    values = p.draw.clut.dklRedLumValues(:);
    if numel(values) == nColors
        dklLumValues = values;
    end
end

rgbNorm = nan(nColors, 3);
if isfield(p.draw, 'clut') && isfield(p.draw.clut, 'subCLUT')
    for iColor = 1:nColors
        rgbNorm(iColor, :) = p.draw.clut.subCLUT(clutIdxVec(iColor) + 1, :);
    end
end
rgb255 = round(255 * rgbNorm);

if ~I1('IsConnected')
    error('The i1Pro is not connected or not detected by I1.mexa64.');
end

disp('Place photometer in calibration cradle, then press any keyboard key.');
waitForUserKey;
I1('Calibrate');
disp('i1 calibration complete.');
disp('Place photometer on the screen, then press any keyboard key.');
waitForUserKey;

screenCleanup = onCleanup(@()restoreTaskBackground(p)); %#ok<NASGU>
measurements = nan(3, nColors, opts.nRepeats);
hWait = waitbar(0, 'Measuring SRS red luminance ramp...');
waitCleanup = onCleanup(@()safeCloseWaitbar(hWait)); %#ok<NASGU>

for iRepeat = 1:opts.nRepeats
    for iColor = 1:nColors
        abortIfEscape;
        Screen('FillRect', p.draw.window, clutIdxVec(iColor));
        Screen('Flip', p.draw.window);
        WaitSecs(opts.settleTime);
        I1('TriggerMeasurement');
        measurements(:, iColor, iRepeat) = I1('GetTriStimulus');
        waitbar(((iRepeat - 1) * nColors + iColor) / ...
            (opts.nRepeats * nColors), hWait);
    end
end

meanMeas = mean(measurements, 3, 'omitnan');
sdMeas = std(measurements, 0, 3, 'omitnan');
measuredCdM2 = meanMeas(1, :)';
measuredCdM2Sd = sdMeas(1, :)';

rampTable = table( ...
    clutIdxVec(:), clutIdxVec(:) + 1, dklLumValues, ...
    rgbNorm(:, 1), rgbNorm(:, 2), rgbNorm(:, 3), ...
    rgb255(:, 1), rgb255(:, 2), rgb255(:, 3), ...
    measuredCdM2, measuredCdM2Sd, meanMeas(2, :)', meanMeas(3, :)', ...
    'VariableNames', { ...
    'clutIdx', 'matlabRowIdx', 'dklLum', ...
    'rgbR_norm', 'rgbG_norm', 'rgbB_norm', ...
    'rgbR_255', 'rgbG_255', 'rgbB_255', ...
    'measuredCdM2', 'measuredCdM2_sd', 'cieX', 'cieY'});

p.rig.i1Connected = true;
p.rig.displayCal.srsRedLumRamp.table = rampTable;
p.rig.displayCal.srsRedLumRamp.rawMeasurements = measurements;
p.rig.displayCal.srsRedLumRamp.nRepeats = opts.nRepeats;
p.rig.displayCal.srsRedLumRamp.settleTime = opts.settleTime;

outDir = getOutputFolder(p);
stem = getOutputStem(p, opts.saveTag);
savePath = fullfile(outDir, [stem '_i1Data.mat']);
fprintf('Saving SRS red luminance ramp data to: %s\n', savePath);
save(savePath, 'rampTable', 'measurements', 'clutIdxVec', ...
    'dklLumValues', 'rgbNorm', 'rgb255', '-v7.3');
writetable(rampTable, fullfile(outDir, [stem '_i1Data.csv']));

figure('Name', 'SRS red luminance ramp - measured cd/m2');
plot(rampTable.clutIdx, rampTable.measuredCdM2, 'o-', 'LineWidth', 1.5);
xlabel('CLUT index'); ylabel('Measured luminance (cd/m^2)');
title('Measured luminance of SRS red CLUT ramp'); box off;

figure('Name', 'SRS red luminance ramp - DKL vs cd/m2');
plot(rampTable.dklLum, rampTable.measuredCdM2, 'o-', 'LineWidth', 1.5);
xlabel('DKL luminance value'); ylabel('Measured luminance (cd/m^2)');
title('Measured luminance vs DKL luminance'); box off;

disp('SRS red luminance ramp measurement complete.');
restoreTaskBackground(p);
end

function opts = parseOptions(varargin)
opts.nRepeats = 3;
opts.settleTime = 0.25;
opts.saveTag = 'srsRedLumRamp';
opts.i1Path = '/home/herman_lab/OneDrive/Code/i1';
if mod(numel(varargin), 2) ~= 0
    error('Optional inputs must be name/value pairs.');
end
for iArg = 1:2:numel(varargin)
    name = lower(char(varargin{iArg}));
    value = varargin{iArg + 1};
    switch name
        case 'nrepeats'
            opts.nRepeats = value;
        case 'settletime'
            opts.settleTime = value;
        case 'savetag'
            opts.saveTag = char(value);
        case 'i1path'
            opts.i1Path = char(value);
        otherwise
            error('Unknown option: %s', name);
    end
end
validateattributes(opts.nRepeats, {'numeric'}, ...
    {'scalar', 'integer', 'positive'});
validateattributes(opts.settleTime, {'numeric'}, ...
    {'scalar', 'nonnegative', 'finite'});
end

function assertTaskWindowAndRamp(p)
if ~isfield(p, 'draw') || ~isfield(p.draw, 'window') || isempty(p.draw.window)
    error('Initialize the task first so p.draw.window exists.');
end
if ~isfield(p.draw, 'clutIdx') || ...
        ~isfield(p.draw.clutIdx, 'redLumStart') || ...
        ~isfield(p.draw.clutIdx, 'redLumN')
    error('The red luminance CLUT ramp was not initialized.');
end
end

function addI1Path(i1Path)
if exist(i1Path, 'dir')
    addpath(i1Path, '-begin');
    rehash;
end
if exist('I1', 'file') ~= 2 && exist('I1', 'file') ~= 3
    error('I1.mexa64 was not found. Expected folder: %s', i1Path);
end
end

function waitForUserKey
if exist('KbStrokeWait', 'file')
    KbStrokeWait;
else
    pause;
end
end

function outDir = getOutputFolder(p)
if isfield(p, 'init') && isfield(p.init, 'outputFolder')
    outDir = p.init.outputFolder;
else
    outDir = pwd;
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
end

function stem = getOutputStem(p, saveTag)
if isfield(p, 'init') && isfield(p.init, 'sessionId')
    stem = [p.init.sessionId '_' saveTag];
else
    stem = [datestr(now, 'yyyymmdd_HHMMSS') '_' saveTag];
end
end

function restoreTaskBackground(p)
if isfield(p.draw, 'color') && isfield(p.draw.color, 'background')
    Screen('FillRect', p.draw.window, p.draw.color.background);
else
    Screen('FillRect', p.draw.window, 0);
end
Screen('Flip', p.draw.window);
end

function abortIfEscape
[isDown, ~, keyCode] = KbCheck;
if isDown && keyCode(KbName('ESCAPE'))
    error('i1 ramp measurement aborted by user.');
end
end

function safeCloseWaitbar(h)
if ~isempty(h) && ishandle(h)
    close(h);
end
end
