function p = i1MeasureSrsRedLumRamp(p, varargin)
% i1MeasureSrsRedLumRamp
%
% Measure the SRS red DKL luminance ramp with the i1 photometer.
%
% This function measures the CLUT entries:
%   p.draw.clutIdx.redLumStart : p.draw.clutIdx.redLumStart + p.draw.clutIdx.redLumN - 1
%
% It assumes:
%   - the PLDAPS window is already open
%   - initClut has already created the red DKL luminance ramp
%   - the i1 / I1 toolbox is available
%
% Output is stored in:
%   p.rig.displayCal.srsRedLumRamp
%
% and saved to:
%   <outputFolder>/<sessionId>_srsRedLumRamp_i1Data.mat

%% ------------------------------------------------------------
% Parse optional inputs
% ------------------------------------------------------------

nRepeats = 3;
settleTime = 0.25;
saveTag = 'srsRedLumRamp';

for iArg = 1:2:numel(varargin)
    switch lower(varargin{iArg})
        case 'nrepeats'
            nRepeats = varargin{iArg + 1};

        case 'settletime'
            settleTime = varargin{iArg + 1};

        case 'savetag'
            saveTag = varargin{iArg + 1};

        otherwise
            error('Unknown option: %s', varargin{iArg});
    end
end

%% ------------------------------------------------------------
% Basic checks
% ------------------------------------------------------------

if ~isfield(p, 'draw') || ~isfield(p.draw, 'window') || isempty(p.draw.window)
    error('p.draw.window is missing. Open the PLDAPS/PTB window before measuring.');
end

if ~isfield(p.draw, 'clutIdx') || ...
        ~isfield(p.draw.clutIdx, 'redLumStart') || ...
        ~isfield(p.draw.clutIdx, 'redLumN')
    error('Red luminance CLUT indices are missing. Check initClut.m.');
end

redLumStart = p.draw.clutIdx.redLumStart;
redLumN     = p.draw.clutIdx.redLumN;

clutIdxVec = redLumStart + (0:redLumN-1);
nColors = numel(clutIdxVec);

if isfield(p.draw, 'clut') && isfield(p.draw.clut, 'dklRedLumValues')
    dklLumValues = p.draw.clut.dklRedLumValues(:);
else
    dklLumValues = nan(nColors, 1);
end

if numel(dklLumValues) ~= nColors
    dklLumValues = nan(nColors, 1);
end

%% ------------------------------------------------------------
% Get RGB values from CLUT for logging
% ------------------------------------------------------------

rgbNorm = nan(nColors, 3);

if isfield(p.draw, 'clut') && isfield(p.draw.clut, 'subCLUT')
    for iColor = 1:nColors
        rowIdx = clutIdxVec(iColor) + 1; % CLUT is 0-based, MATLAB rows are 1-based
        rgbNorm(iColor, :) = p.draw.clut.subCLUT(rowIdx, :);
    end
end

rgb255 = round(255 * rgbNorm);

%% Added
% Find the working, non-package I1 MEX used previously on this rig.
i1MexFolder = findI1MexFolder();

config.i1MexFolder = i1MexFolder;

% Put the known working I1 MEX first on the worker path.
addpath(config.i1MexFolder, '-begin');
rehash;

if exist('I1', 'file') ~= 3 && exist('I1', 'file') ~= 2
    error('I1 MEX was not found in: %s', config.i1MexFolder);
end

if I1('IsConnected') == 0
    error(['No i1 device detected. Confirm USB connection and that no ', ...
           'other process currently owns the device.']);
end


function i1MexFolder = findI1MexFolder()
% Prefer a directly callable I1 MEX, not +pds/I1.
resolved = which('I1');
if ~isempty(resolved)
    i1MexFolder = fileparts(resolved);
else
    candidates = { ...
        '/home/herman_lab/OneDrive/Code/i1', ...
        fullfile(getenv('HOME'), 'OneDrive', 'Code', 'i1')};

    i1MexFolder = '';
    for iCandidate = 1:numel(candidates)
        mexFile = fullfile(candidates{iCandidate}, ['I1.' mexext]);
        if exist(mexFile, 'file')
            i1MexFolder = candidates{iCandidate};
            break
        end
    end
end

if isempty(i1MexFolder)
    error(['Could not find a directly callable I1 MEX. Expected the working ', ...
        'file under /home/herman_lab/OneDrive/Code/i1.']);
end

mexFile = fullfile(i1MexFolder, ['I1.' mexext]);
if ~exist(mexFile, 'file')
    error('I1 MEX does not exist at: %s', mexFile);
end
end


%%


%% ------------------------------------------------------------
% Connect and calibrate i1
% ------------------------------------------------------------

p.rig.i1Connected = pds.I1('IsConnected');

if ~p.rig.i1Connected
    warning('i1 photometer does not appear connected according to I1(''IsConnected'').');
end

disp('Place photometer in calibration cradle, then press any keyboard key.');
pause;

pds.I1('Calibrate');

disp('i1 calibration complete.');
disp('Place photometer on the screen for measurement, then press any keyboard key.');
pause;

%% ------------------------------------------------------------
% Measure the ramp
% ------------------------------------------------------------

% measurements:
%   dimension 1 = i1 returned values
%   dimension 2 = color index
%   dimension 3 = repeat
measurements = nan(3, nColors, nRepeats);

hWait = waitbar(0, 'Measuring SRS red luminance ramp...');

for iRep = 1:nRepeats

    for iColor = 1:nColors

        thisIdx = clutIdxVec(iColor);

        % Fill the whole screen with the CLUT color index.
        % This is intentional: it makes the photometer measurement stable.
        Screen('FillRect', p.draw.window, thisIdx);
        Screen('Flip', p.draw.window);

        WaitSecs(settleTime);

        pds.I1('TriggerMeasurement');

        measurements(:, iColor, iRep) = pds.I1('GetTriStimulus');

        waitbar(((iRep - 1) * nColors + iColor) / (nRepeats * nColors), hWait);
    end
end

close(hWait);

%% ------------------------------------------------------------
% Restore background after measurement
% ------------------------------------------------------------

if isfield(p.draw, 'color') && isfield(p.draw.color, 'background')
    Screen('FillRect', p.draw.window, p.draw.color.background);
else
    Screen('FillRect', p.draw.window, 0);
end
Screen('Flip', p.draw.window);

%% ------------------------------------------------------------
% Average repeated measurements
% ------------------------------------------------------------

meanMeas = nan(3, nColors);
stdMeas  = nan(3, nColors);

for iVal = 1:3
    for iColor = 1:nColors
        vals = squeeze(measurements(iVal, iColor, :));
        vals = vals(isfinite(vals));

        if ~isempty(vals)
            meanMeas(iVal, iColor) = mean(vals);
            stdMeas(iVal, iColor)  = std(vals);
        end
    end
end

% Following the existing James code convention:
% i1CalibrateAndMeasure and dklToRgbFileMaker treat the first returned
% coordinate as luminance.
measuredCdM2 = meanMeas(1, :)';
measuredCdM2_sd = stdMeas(1, :)';

%% ------------------------------------------------------------
% Build table
% ------------------------------------------------------------

rampTable = table( ...
    clutIdxVec(:), ...
    (clutIdxVec(:) + 1), ...
    dklLumValues(:), ...
    rgbNorm(:, 1), ...
    rgbNorm(:, 2), ...
    rgbNorm(:, 3), ...
    rgb255(:, 1), ...
    rgb255(:, 2), ...
    rgb255(:, 3), ...
    measuredCdM2, ...
    measuredCdM2_sd, ...
    meanMeas(2, :)', ...
    meanMeas(3, :)', ...
    'VariableNames', { ...
        'clutIdx', ...
        'matlabRowIdx', ...
        'dklLum', ...
        'rgbR_norm', ...
        'rgbG_norm', ...
        'rgbB_norm', ...
        'rgbR_255', ...
        'rgbG_255', ...
        'rgbB_255', ...
        'measuredCdM2', ...
        'measuredCdM2_sd', ...
        'i1_value2', ...
        'i1_value3'});

p.rig.displayCal.srsRedLumRamp.table = rampTable;
p.rig.displayCal.srsRedLumRamp.rawMeasurements = measurements;
p.rig.displayCal.srsRedLumRamp.nRepeats = nRepeats;
p.rig.displayCal.srsRedLumRamp.settleTime = settleTime;

%% ------------------------------------------------------------
% Save output
% ------------------------------------------------------------

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

disp(['Saving SRS red luminance ramp data to: ' saveString]);

save(saveString, ...
    'rampTable', ...
    'measurements', ...
    'clutIdxVec', ...
    'dklLumValues', ...
    'rgbNorm', ...
    'rgb255', ...
    'nRepeats', ...
    'settleTime');

%% ------------------------------------------------------------
% Quick diagnostic plots
% ------------------------------------------------------------

figure('Name', 'SRS red luminance ramp - measured cd/m2');
plot(rampTable.clutIdx, rampTable.measuredCdM2, 'o-', 'LineWidth', 1.5);
xlabel('CLUT index');
ylabel('Measured luminance, cd/m2');
title('Measured luminance of SRS red CLUT ramp');
box off;

figure('Name', 'SRS red luminance ramp - DKL vs cd/m2');
plot(rampTable.dklLum, rampTable.measuredCdM2, 'o-', 'LineWidth', 1.5);
xlabel('DKL luminance value');
ylabel('Measured luminance, cd/m2');
title('Measured luminance vs DKL luminance');
box off;

disp('SRS red luminance ramp measurement complete.');

end