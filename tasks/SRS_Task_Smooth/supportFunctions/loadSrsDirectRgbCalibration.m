function p = loadSrsDirectRgbCalibration(p)
%LOADSRSDIRECTRGBCALIBRATION Load the measured direct-RGB red family.
%
% The table was measured with the i1Pro 3 while the DATAPixx was in C24
% passthrough mode. Every target color used in salienceType 3 is selected
% from an actually measured RGB row, rather than inferred from DKL or from
% a linear RGB-to-luminance approximation.

fileName = p.trVarsInit.directRgbCalibrationFile;
searchPaths = { ...
    fileName, ...
    fullfile(fileparts(mfilename('fullpath')), fileName), ...
    fullfile(p.init.pldapsFolder, 'tasks', 'SRS_Task_Smooth', ...
        'supportFunctions', fileName)};

filePath = '';
for iPath = 1:numel(searchPaths)
    if exist(searchPaths{iPath}, 'file') == 2
        filePath = searchPaths{iPath};
        break
    end
end
if isempty(filePath)
    error('Direct-RGB calibration file not found: %s', fileName);
end

calTable = readtable(filePath);
requiredColumns = { ...
    'familyID', 'gOverR', 'bOverR', 'redLevel', ...
    'rgbR_255', 'rgbG_255', 'rgbB_255', ...
    'measuredCdM2', 'measuredCdM2Sd', 'cieX', 'cieY'};
for iCol = 1:numel(requiredColumns)
    if ~ismember(requiredColumns{iCol}, calTable.Properties.VariableNames)
        error('Direct-RGB calibration is missing column %s.', requiredColumns{iCol});
    end
end

% Keep the measured family requested by the settings file.
familyID = p.trVarsInit.directRgbFamilyID;
calTable = calTable(calTable.familyID == familyID, :);
calTable = sortrows(calTable, 'redLevel');
if height(calTable) < 3
    error('Direct-RGB family %d has too few measured rows.', familyID);
end

numericColumns = {'redLevel', 'rgbR_255', 'rgbG_255', 'rgbB_255', ...
    'measuredCdM2'};
for iCol = 1:numel(numericColumns)
    values = calTable.(numericColumns{iCol});
    if any(~isfinite(values))
        error('Direct-RGB calibration contains non-finite %s values.', ...
            numericColumns{iCol});
    end
end

rgbValues = [calTable.rgbR_255 calTable.rgbG_255 calTable.rgbB_255];
if any(rgbValues(:) < 0 | rgbValues(:) > 255 | ...
        rgbValues(:) ~= round(rgbValues(:)))
    error('Direct-RGB calibration RGB values must be integers in [0,255].');
end
if any(diff(calTable.redLevel) <= 0)
    error('Direct-RGB redLevel values must be strictly increasing.');
end
if any(diff(calTable.measuredCdM2) <= 0)
    error('Direct-RGB measured luminance must be strictly increasing.');
end

% Verify that the table still describes the family measured by the user.
gRatio = p.trVarsInit.directRgbGOverR;
bRatio = p.trVarsInit.directRgbBOverR;
nonzero = calTable.redLevel > 0;
expectedG = round(gRatio * calTable.redLevel(nonzero));
expectedB = round(bRatio * calTable.redLevel(nonzero));
if any(calTable.rgbG_255(nonzero) ~= expectedG) || ...
        any(calTable.rgbB_255(nonzero) ~= expectedB) || ...
        any(calTable.rgbR_255(nonzero) ~= calTable.redLevel(nonzero))
    error(['Direct-RGB calibration does not match RGB = ', ...
        '[R, round(%.3fR), round(%.3fR)].'], gRatio, bRatio);
end

% The target subset excludes the physical black background and includes
% enough headroom for nearest-neighbour mapping of the desired 11.793778
% cd/m^2 upper endpoint to the measured 12.052165 cd/m^2 row.
targetMin = p.trVarsInit.directRgbLuminanceMinCdM2;
targetMax = p.trVarsInit.directRgbLuminanceMaxCdM2;
targetRows = calTable.measuredCdM2 >= targetMin - 1e-9;
if ~any(targetRows)
    error('No measured direct-RGB target is at or above %.6f cd/m^2.', targetMin);
end

% Retain the first row above the desired maximum so nearest-neighbour
% mapping can choose the genuinely closest measured color.
aboveMax = find(calTable.measuredCdM2 >= targetMax, 1, 'first');
if isempty(aboveMax)
    aboveMax = height(calTable);
end
targetRows((aboveMax + 1):end) = false;
targetTable = calTable(targetRows, :);
if height(targetTable) < 2
    error('Direct-RGB target calibration must contain at least two colors.');
end

backgroundRGB = p.trVarsInit.directRgbBackgroundRGB255;
backgroundMatch = all(rgbValues == reshape(backgroundRGB, 1, 3), 2);
if ~any(backgroundMatch)
    error('The configured direct-RGB background is absent from calibration.');
end
backgroundMeasured = calTable.measuredCdM2(find(backgroundMatch, 1, 'first'));
if abs(backgroundMeasured - ...
        p.trVarsInit.directRgbBackgroundMeasuredCdM2) > 0.01
    error(['Configured direct-RGB background measurement %.6f does not ', ...
        'match calibration %.6f cd/m^2.'], ...
        p.trVarsInit.directRgbBackgroundMeasuredCdM2, backgroundMeasured);
end

calibration = struct();
calibration.file = filePath;
calibration.label = p.trVarsInit.directRgbCalibrationLabel;
calibration.familyID = familyID;
calibration.gOverR = gRatio;
calibration.bOverR = bRatio;
calibration.table = calTable;
calibration.targetTable = targetTable;
calibration.minimumCdM2 = min(targetTable.measuredCdM2);
calibration.maximumCdM2 = max(targetTable.measuredCdM2);
calibration.desiredMinimumCdM2 = targetMin;
calibration.desiredMaximumCdM2 = targetMax;
calibration.backgroundRGB255 = double(backgroundRGB(:)');
calibration.backgroundMeasuredCdM2 = backgroundMeasured;

p.draw.directRgbCalibration = calibration;

fprintf(['Loaded SRS direct-RGB calibration: family %d, ', ...
    'target rows %.6f to %.6f cd/m^2, background %.6f cd/m^2.\n'], ...
    familyID, calibration.minimumCdM2, calibration.maximumCdM2, ...
    backgroundMeasured);

end
