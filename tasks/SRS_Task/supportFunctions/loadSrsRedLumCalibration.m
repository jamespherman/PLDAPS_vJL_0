function p = loadSrsRedLumCalibration(p)
%LOADSRSREDLUMCALIBRATION Load and validate the i1Pro 3 red-ramp data.
%
% The task samples a nominal luminance coordinate inherited from the
% Dubey/Pesaran design, maps it to one of the 32 red DKL CLUT entries, and
% then uses this calibration table to recover the physical luminance that
% was measured on the rig in cd/m^2.
%
% This function deliberately fails when the calibration does not match the
% current CLUT ramp. A calibration measured for another DKL ramp must never
% be used silently.

calibrationFile = 'SRS_red_luminance_calibration_20260716.csv';
if isfield(p, 'trVarsInit') && ...
        isfield(p.trVarsInit, 'redLuminanceCalibrationFile') && ...
        ~isempty(p.trVarsInit.redLuminanceCalibrationFile)
    calibrationFile = char(p.trVarsInit.redLuminanceCalibrationFile);
end

requireCalibration = true;
if isfield(p, 'trVarsInit') && ...
        isfield(p.trVarsInit, 'requireRedLuminanceCalibration')
    requireCalibration = logical(p.trVarsInit.requireRedLuminanceCalibration);
end

if isfile(calibrationFile)
    calibrationPath = calibrationFile;
else
    calibrationPath = fullfile(fileparts(mfilename('fullpath')), calibrationFile);
end

if ~isfile(calibrationPath)
    if requireCalibration
        error(['SRS red-luminance calibration file not found: ' calibrationPath]);
    end
    warning('SRS red-luminance calibration file not found. Physical luminance values will be NaN.');
    p.draw.clut.redLumCalibration = struct();
    return
end

calibrationTable = readtable(calibrationPath, 'VariableNamingRule', 'preserve');
requiredColumns = {'clutIdx', 'dklLum', 'measuredCdM2'};
for iColumn = 1:numel(requiredColumns)
    if ~ismember(requiredColumns{iColumn}, calibrationTable.Properties.VariableNames)
        error('Calibration file is missing required column "%s".', requiredColumns{iColumn});
    end
end

calibrationTable = sortrows(calibrationTable, 'clutIdx');
clutIdx = double(calibrationTable.clutIdx(:));
dklLum = double(calibrationTable.dklLum(:));
measuredCdM2 = double(calibrationTable.measuredCdM2(:));

expectedClutIdx = (p.draw.clutIdx.redLumStart + ...
    (0:p.draw.clutIdx.redLumN - 1))';
expectedDklLum = double(p.draw.clut.dklRedLumValues(:));

if height(calibrationTable) ~= p.draw.clutIdx.redLumN
    error('Calibration has %d rows; the current red ramp requires %d.', ...
        height(calibrationTable), p.draw.clutIdx.redLumN);
end

if ~isequal(clutIdx, expectedClutIdx)
    error('Calibration CLUT indices do not match the current SRS red ramp.');
end

if numel(dklLum) ~= numel(expectedDklLum) || ...
        any(abs(dklLum - expectedDklLum) > 1e-6)
    error(['Calibration DKL values do not match the current red ramp. ', ...
        'Re-measure the ramp or restore luminanceRedDklLow/High.']);
end

if any(~isfinite(measuredCdM2)) || any(measuredCdM2 <= 0)
    error('Calibration contains invalid physical luminance values.');
end

if any(diff(measuredCdM2) <= 0)
    error('Measured red-ramp luminance must increase strictly with CLUT index.');
end

label = 'i1Pro3_20260716';
if isfield(p, 'trVarsInit') && ...
        isfield(p.trVarsInit, 'redLuminanceCalibrationLabel') && ...
        ~isempty(p.trVarsInit.redLuminanceCalibrationLabel)
    label = char(p.trVarsInit.redLuminanceCalibrationLabel);
end

backgroundMeasuredCdM2 = 47.4;
if isfield(p, 'trVarsInit') && ...
        isfield(p.trVarsInit, 'srsLuminanceBackgroundMeasuredCdM2') && ...
        isfinite(p.trVarsInit.srsLuminanceBackgroundMeasuredCdM2)
    backgroundMeasuredCdM2 = double( ...
        p.trVarsInit.srsLuminanceBackgroundMeasuredCdM2);
end

p.draw.clut.redLumCalibration = struct( ...
    'table', calibrationTable, ...
    'clutIdx', clutIdx, ...
    'dklLum', dklLum, ...
    'measuredCdM2', measuredCdM2, ...
    'minimumCdM2', min(measuredCdM2), ...
    'maximumCdM2', max(measuredCdM2), ...
    'maximumDifferenceCdM2', max(measuredCdM2) - min(measuredCdM2), ...
    'file', calibrationPath, ...
    'label', label);

p.draw.clut.srsBackgroundMeasuredCdM2 = backgroundMeasuredCdM2;

fprintf(['Loaded SRS red luminance calibration: %.3f to %.3f cd/m^2 ', ...
    '(CLUT %d:%d); background %.1f cd/m^2 at DKL %.3f.\n'], ...
    p.draw.clut.redLumCalibration.minimumCdM2, ...
    p.draw.clut.redLumCalibration.maximumCdM2, ...
    expectedClutIdx(1), expectedClutIdx(end), ...
    backgroundMeasuredCdM2, p.draw.clut.srsBackgroundDklLum);

end
