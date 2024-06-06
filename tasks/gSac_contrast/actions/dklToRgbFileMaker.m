% Script for making files used by DKL-to-RGB color space conversion
% function. This script assumes that the 3 X 256 X 3 "colorData" array
% generated by "i1CalibrateAndMeasure.m" is being used as input.

clear
close all

% define display name for saving files:
displayName = 'BENQ';

% load "colorData"
dataDir = '/home/jph/Documents/PLDAPS_vJL_0/output/';
dataFile = '20240313_t1546_human_psychophysical_threshold_x1Data.mat';
load([dataDir dataFile]);

% get maximum and minimum luminance values for each "gun":
maxLum = squeeze(max(colorData(1,:,:)));
minLum = squeeze(min(colorData(1,:,:)));

% make vectors of 256 linearly spaced luminance intensities between minimum
% and maximum:
nSteps = 256;
lumInts = [
    linspace(minLum(1), maxLum(1), nSteps)', ...
    linspace(minLum(2), maxLum(2), nSteps)', ...
    linspace(minLum(3), maxLum(3), nSteps)'];

% make data holder for "look up" curves:
luts = zeros(nSteps, 3);

% loop over intensities to construct "look up" curves:
for i = 1:nSteps
    
    % loop over guns:
    for j = 1:3

        % use two methods to find best luminance index and keep smallest:

        % find measurements nearby our target luminance intensity:
        g = (colorData(1, :, j) - lumInts(i, j)) < ...
            max(diff(colorData(1, :, j)))*1.1;

        % interpolate to find nearest value that would achieve target
        % luminance intensity:
        Vtemp = find(g);
        Xtemp = colorData(1, g, j);
        interpVal(i, j) = interp1(Xtemp, Vtemp, lumInts(i, j));

        % find smallest value that acheives desired luminance intensity
        luts(i, j) = find(colorData(1,:,j) >= lumInts(i, j), 1, 'first')-1;
    end
end

% make a set of temporary index values from 1:256. We're doing this
% because we want to keep the interpolated values from the loop above when
% they're larger than the values found by the more simple method, but only
% for intensity indexes greater than 50:
tempIdx = repmat(0:255, 3, 1)';
luts(tempIdx > 50 & interpVal > luts) = ...
    interpVal(tempIdx > 50 & interpVal > luts);

% set zero values to 1:
% luts(luts == 0) = 1;

% define xyY array (at max intensity):
xyYtemp = fliplr(squeeze(colorData(:,end,:))');
xyYtemp = xyYtemp(:, [2 1 3]);

% define folder for writing files:
outputDir = ['/home/jph/Documents/PLDAPS_vJL_0/tasks/' ...
    'human_psychophysical_threshold/supportFunctions/'];

% save xyY file:
writematrix(xyYtemp, [outputDir 'LUT' displayName '.xyY'], ...
    'FileType', 'text', 'Delimiter', 'tab');

% save r g b files:
writematrix(luts(:, 1), [outputDir 'LUT' displayName '.r'], ...
    'FileType', 'text', 'Delimiter', 'tab');
writematrix(luts(:, 2), [outputDir 'LUT' displayName '.g'], ...
    'FileType', 'text', 'Delimiter', 'tab');
writematrix(luts(:, 3), [outputDir 'LUT' displayName '.b'], ...
    'FileType', 'text', 'Delimiter', 'tab');



