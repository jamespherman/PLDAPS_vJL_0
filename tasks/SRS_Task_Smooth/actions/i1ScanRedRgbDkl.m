function p = i1ScanRedRgbDkl(p, varargin)
%I1SCANREDRGBDKL Measure candidate dark-red ramps generated through DKL.
%
% The action draws direct RGB triplets, not CLUT indices. Candidate colors
% are generated from fixed DKL hue/saturation families while DKL luminance
% varies. An i1Pro measurement is taken for every in-gamut red-like color.
% The action then ranks families by how closely one monotonic pair reaches
% TARGETLOW and TARGETHIGH cd/m^2 (defaults: 0.01 and 12.15).
%
% Run after task initialization from the PLDAPS GUI Actions menu. Do not run
% simultaneously with behavioral trials.
%
% Optional name/value inputs:
%   'profile'     : 'quick' (default) or 'full'
%   'nRepeats'    : measurements per color (default 1)
%   'settleTime'  : seconds after Screen flip (default 0.20)
%   'targetLow'   : desired low luminance cd/m^2 (default 0.01)
%   'targetHigh'  : desired high luminance cd/m^2 (default 12.15)
%   'i1Path'      : folder containing I1.mexa64
%
% The output is stored in p.rig.displayCal.dklRedRgbScan and saved as MAT
% and CSV files in p.init.outputFolder.

opts = parseOptions(p, varargin{:});
assertTaskWindow(p);
addI1Path(opts.i1Path);
calibrateI1;

% Generate candidates before changing display mode. The behavioral task
% uses L48, where the red channel is a CLUT index. The measurement window
% is therefore reopened in native C24 mode so [R G B] is truly direct RGB.
[candidateTable, familyTable] = makeDklCandidates(p, opts.profile);
if isempty(candidateTable)
    error('No in-gamut red-like DKL candidate was generated.');
end

fprintf('DKL RGB scan: %d colors in %d hue/saturation families.\n', ...
    height(candidateTable), height(familyTable));
fprintf('Approximate minimum acquisition time: %.1f minutes.\n', ...
    height(candidateTable) * opts.nRepeats * opts.settleTime / 60);

p = enterC24RgbMode(p);
try
    measurements = measureCandidateTable(p, candidateTable, opts);
catch measurementError
    p = restoreL48TaskMode(p);
    rethrow(measurementError);
end
p = restoreL48TaskMode(p);
[candidateTable, familySummary, bestLow, bestHigh] = ...
    summarizeMeasurements(candidateTable, measurements, ...
    opts.targetLow, opts.targetHigh);

result = struct();
result.candidates = candidateTable;
result.families = familyTable;
result.familySummary = familySummary;
result.bestLow = bestLow;
result.bestHigh = bestHigh;
result.rawMeasurements = measurements;
result.options = opts;
result.createdAt = datestr(now, 30);
p.rig.displayCal.dklRedRgbScan = result;

saveResult(p, result, 'i1_dkl_red_rgb_scan');
showResults(candidateTable, familySummary, bestLow, bestHigh, opts, ...
    'DKL-generated direct-RGB red scan');

fprintf('\nBest DKL red family found:\n');
disp(bestLow(:, {'familyID','dklHueDeg','dklSatRad','dklLum', ...
    'rgbR_255','rgbG_255','rgbB_255','measuredCdM2'}));
disp(bestHigh(:, {'familyID','dklHueDeg','dklSatRad','dklLum', ...
    'rgbR_255','rgbG_255','rgbB_255','measuredCdM2'}));
fprintf(['The displayed colors were direct RGB values. Confirm the chosen ', ...
    'endpoints with a dedicated dense ramp measurement before using them ', ...
    'in the behavioral task.\n']);
end

function opts = parseOptions(p, varargin)
opts.profile = 'quick';
opts.nRepeats = 1;
opts.settleTime = 0.20;
opts.targetLow = 0.01;
opts.targetHigh = 12.15;
opts.i1Path = '/home/herman_lab/OneDrive/Code/i1';
config = struct();
if isfield(p, 'trVars'), config = p.trVars; elseif isfield(p, 'trVarsInit'), config = p.trVarsInit; end
if isfield(config, 'redRgbScanProfile'), opts.profile = lower(char(config.redRgbScanProfile)); end
if isfield(config, 'redRgbScanNRepeats'), opts.nRepeats = config.redRgbScanNRepeats; end
if isfield(config, 'redRgbScanSettleTime'), opts.settleTime = config.redRgbScanSettleTime; end
if isfield(config, 'redRgbScanTargetLowCdM2'), opts.targetLow = config.redRgbScanTargetLowCdM2; end
if isfield(config, 'redRgbScanTargetHighCdM2'), opts.targetHigh = config.redRgbScanTargetHighCdM2; end
if mod(numel(varargin), 2) ~= 0
    error('Optional inputs must be name/value pairs.');
end
for iArg = 1:2:numel(varargin)
    name = lower(char(varargin{iArg}));
    value = varargin{iArg + 1};
    switch name
        case 'profile'
            opts.profile = lower(char(value));
        case 'nrepeats'
            opts.nRepeats = value;
        case 'settletime'
            opts.settleTime = value;
        case 'targetlow'
            opts.targetLow = value;
        case 'targethigh'
            opts.targetHigh = value;
        case 'i1path'
            opts.i1Path = char(value);
        otherwise
            error('Unknown option: %s', name);
    end
end
validateattributes(opts.nRepeats, {'numeric'}, ...
    {'scalar','integer','positive'});
validateattributes(opts.settleTime, {'numeric'}, ...
    {'scalar','nonnegative','finite'});
validateattributes(opts.targetLow, {'numeric'}, ...
    {'scalar','nonnegative','finite'});
validateattributes(opts.targetHigh, {'numeric'}, ...
    {'scalar','positive','finite','>',opts.targetLow});
if ~any(strcmp(opts.profile, {'quick','full'}))
    error('profile must be ''quick'' or ''full''.');
end
end

function assertTaskWindow(p)
if ~isfield(p, 'draw') || ~isfield(p.draw, 'window') || ...
        isempty(p.draw.window)
    error('Initialize the task first so p.draw.window exists.');
end
end

function addI1Path(i1Path)
if exist(i1Path, 'dir')
    addpath(i1Path);
    rehash;
end
if exist('I1', 'file') ~= 2 && exist('I1', 'file') ~= 3
    error('I1.mexa64 was not found. Expected folder: %s', i1Path);
end
end

function calibrateI1
connected = I1('IsConnected');
if ~connected
    error('The i1Pro is not connected or not detected by I1.mexa64.');
end
disp('Place photometer in calibration cradle, then press any keyboard key.');
pause;
I1('Calibrate');
disp('i1 calibration complete.');
disp('Place photometer on the screen, then press any keyboard key.');
pause;
end

function [candidateTable, familyTable] = makeDklCandidates(p, profile)
global M_dkl2rgb
if isempty(M_dkl2rgb)
    error('M_dkl2rgb is empty. initmon must run during task initialization.');
end

% Find DKL hue directions whose calibrated RGB is closest to the current
% task red, then scan several saturation radii along those directions.
targetRed = [225 0 76] / 255;
if isfield(p, 'trVarsInit') && ...
        isfield(p.trVarsInit, 'luminanceRedTargetRGB')
    targetRed = p.trVarsInit.luminanceRedTargetRGB;
end

hueProbe = 0:2:358;
probeSat = 0.30;
probeLum = -0.50;
err = inf(size(hueProbe));
for iHue = 1:numel(hueProbe)
    dkl = [probeLum; probeSat*cosd(hueProbe(iHue)); ...
        probeSat*sind(hueProbe(iHue))];
    raw = round((0.5 + M_dkl2rgb*dkl/2)*255);
    if any(raw < 0) || any(raw > 255)
        continue;
    end
    [r,g,b] = dkl2rgb(dkl);
    rgb = [r g b];
    if isRedLike(rgb)
        err(iHue) = sum((rgb-targetRed).^2);
    end
end

if strcmp(profile, 'quick')
    nHueKeep = 5;
    satGrid = [0.05 0.15 0.25 0.35 0.45];
    lumGrid = -1.00:0.04:0.20;
else
    nHueKeep = 12;
    satGrid = 0.04:0.04:0.48;
    lumGrid = -1.00:0.025:0.25;
end
chosenHues = chooseSeparatedHues(hueProbe, err, nHueKeep, 4);
if isempty(chosenHues)
    error('Could not identify an in-gamut red DKL hue direction.');
end

familyID = [];
hueCol = [];
satCol = [];
familyCounter = 0;
for hue = chosenHues
    for sat = satGrid
        familyCounter = familyCounter + 1;
        familyID(end+1,1) = familyCounter; %#ok<AGROW>
        hueCol(end+1,1) = hue; %#ok<AGROW>
        satCol(end+1,1) = sat; %#ok<AGROW>
    end
end
familyTable = table(familyID, hueCol, satCol, ...
    'VariableNames', {'familyID','dklHueDeg','dklSatRad'});

rows = zeros(0, 11);
for iFamily = 1:height(familyTable)
    hue = familyTable.dklHueDeg(iFamily);
    sat = familyTable.dklSatRad(iFamily);
    for lum = lumGrid
        dkl = [lum; sat*cosd(hue); sat*sind(hue)];
        raw = round((0.5 + M_dkl2rgb*dkl/2)*255);
        if any(raw < 0) || any(raw > 255)
            continue;
        end
        [r,g,b] = dkl2rgb(dkl);
        rgb = [r g b];
        if any(~isfinite(rgb)) || any(rgb < 0) || any(rgb > 1) || ...
                ~isRedLike(rgb)
            continue;
        end
        rgb255 = round(255*rgb);
        redness = rgb(1) - max(rgb(2:3));
        rows(end+1,:) = [familyTable.familyID(iFamily), hue, sat, lum, ...
            rgb, rgb255, redness]; %#ok<AGROW>
    end
end
candidateTable = array2table(rows, 'VariableNames', { ...
    'familyID','dklHueDeg','dklSatRad','dklLum', ...
    'rgbR_norm','rgbG_norm','rgbB_norm', ...
    'rgbR_255','rgbG_255','rgbB_255','redDominance'});

% Remove exact duplicate RGB triplets within each family.
if ~isempty(candidateTable)
    key = [candidateTable.familyID, candidateTable.rgbR_255, ...
        candidateTable.rgbG_255, candidateTable.rgbB_255];
    [~, keep] = unique(key, 'rows', 'stable');
    candidateTable = candidateTable(sort(keep), :);
end
end

function tf = isRedLike(rgb)
tf = rgb(1) >= rgb(2) && rgb(1) >= rgb(3) && ...
    rgb(1) - max(rgb(2:3)) >= 0.015;
end

function chosen = chooseSeparatedHues(hues, err, nKeep, minSeparation)
[~, order] = sort(err, 'ascend');
chosen = [];
for idx = order
    if ~isfinite(err(idx))
        continue;
    end
    hue = hues(idx);
    if isempty(chosen) || all(circularDistance(hue, chosen) >= minSeparation)
        chosen(end+1) = hue; %#ok<AGROW>
    end
    if numel(chosen) >= nKeep
        break;
    end
end
end

function d = circularDistance(a, b)
d = abs(mod(a-b+180,360)-180);
end

function measurements = measureCandidateTable(p, candidateTable, opts)
nColors = height(candidateTable);
measurements = nan(3, nColors, opts.nRepeats);
hWait = waitbar(0, 'Measuring DKL-generated direct RGB candidates...');
cleanup = onCleanup(@()safeCloseWaitbar(hWait)); %#ok<NASGU>
for iRepeat = 1:opts.nRepeats
    for iColor = 1:nColors
        abortIfEscape;
        rgb = [candidateTable.rgbR_255(iColor), ...
            candidateTable.rgbG_255(iColor), ...
            candidateTable.rgbB_255(iColor)];
        Screen('FillRect', p.draw.window, rgb);
        Screen('Flip', p.draw.window);
        WaitSecs(opts.settleTime);
        I1('TriggerMeasurement');
        measurements(:,iColor,iRepeat) = I1('GetTriStimulus');
        waitbar(((iRepeat-1)*nColors+iColor)/(opts.nRepeats*nColors), ...
            hWait);
        if mod(iColor,25)==0 || iColor==nColors
            fprintf('DKL scan repeat %d/%d: %d/%d colors measured.\n', ...
                iRepeat, opts.nRepeats, iColor, nColors);
        end
    end
end
end

function [candidateTable, summary, bestLow, bestHigh] = ...
        summarizeMeasurements(candidateTable, measurements, targetLow, targetHigh)
meanMeasurement = mean(measurements, 3, 'omitnan');
sdMeasurement = std(measurements, 0, 3, 'omitnan');
candidateTable.measuredCdM2 = meanMeasurement(1,:)';
candidateTable.measuredCdM2Sd = sdMeasurement(1,:)';
candidateTable.cieX = meanMeasurement(2,:)';
candidateTable.cieY = meanMeasurement(3,:)';

families = unique(candidateTable.familyID, 'stable');
summaryRows = nan(numel(families), 13);
for iFamily = 1:numel(families)
    id = families(iFamily);
    mask = candidateTable.familyID == id & ...
        isfinite(candidateTable.measuredCdM2);
    t = candidateTable(mask,:);
    if height(t) < 2
        continue;
    end
    [~,order] = sort(t.dklLum);
    t = t(order,:);
    monotonicFraction = mean(diff(t.measuredCdM2) >= -0.05);
    [iLow,iHigh,score] = bestEndpointPair(t.measuredCdM2, ...
        targetLow,targetHigh);
    summaryRows(iFamily,:) = [id,t.dklHueDeg(1),t.dklSatRad(1), ...
        height(t),monotonicFraction,iLow,iHigh, ...
        t.dklLum(iLow),t.dklLum(iHigh), ...
        t.measuredCdM2(iLow),t.measuredCdM2(iHigh), ...
        t.measuredCdM2(iHigh)-t.measuredCdM2(iLow),score];
end
summary = array2table(summaryRows, 'VariableNames', { ...
    'familyID','dklHueDeg','dklSatRad','nMeasured', ...
    'monotonicFraction','lowLocalIndex','highLocalIndex', ...
    'lowDklLum','highDklLum','lowCdM2','highCdM2','spanCdM2','score'});
summary = summary(isfinite(summary.score),:);
summary.score = summary.score + 25*max(0,0.95-summary.monotonicFraction);
summary = sortrows(summary,'score','ascend');
if isempty(summary)
    error('No DKL family had two valid measured colors.');
end
bestFamily = summary.familyID(1);
t = candidateTable(candidateTable.familyID==bestFamily,:);
[~,order] = sort(t.dklLum); t=t(order,:);
[lowIdx,highIdx] = bestEndpointPair(t.measuredCdM2,targetLow,targetHigh);
bestLow = t(lowIdx,:);
bestHigh = t(highIdx,:);
end

function [bestLow,bestHigh,bestScore] = bestEndpointPair(y,targetLow,targetHigh)
bestScore = inf; bestLow = 1; bestHigh = numel(y);
for i = 1:numel(y)-1
    for j = i+1:numel(y)
        if ~isfinite(y(i)) || ~isfinite(y(j)) || y(j) <= y(i)
            continue;
        end
        score = abs(y(i)-targetLow) + abs(y(j)-targetHigh);
        if score < bestScore
            bestScore = score; bestLow=i; bestHigh=j;
        end
    end
end
end

function saveResult(p,result,tag)
if isfield(p,'init') && isfield(p.init,'outputFolder')
    outDir=p.init.outputFolder;
else
    outDir=pwd;
end
if ~exist(outDir,'dir'), mkdir(outDir); end
if isfield(p,'init') && isfield(p.init,'sessionId')
    stem=[p.init.sessionId '_' tag];
else
    stem=[datestr(now,'yyyymmdd_HHMMSS') '_' tag];
end
save(fullfile(outDir,[stem '.mat']),'result','-v7.3');
writetable(result.candidates,fullfile(outDir,[stem '_candidates.csv']));
writetable(result.familySummary,fullfile(outDir,[stem '_families.csv']));
fprintf('Saved DKL red scan to %s\n',fullfile(outDir,[stem '.mat']));
end

function showResults(candidates,summary,bestLow,bestHigh,opts,titleText)
figure('Name',titleText);
hold on;
ids=unique(candidates.familyID);
for id=ids'
    t=candidates(candidates.familyID==id,:);
    [x,o]=sort(t.dklLum);
    y=t.measuredCdM2(o);
    plot(x,y,'Color',[0.82 0.82 0.82]);
end
bestID=summary.familyID(1);
t=candidates(candidates.familyID==bestID,:);
[x,o]=sort(t.dklLum); y=t.measuredCdM2(o);
plot(x,y,'k-o','LineWidth',2,'MarkerSize',4);
yline(opts.targetLow,'--'); yline(opts.targetHigh,'--');
plot(bestLow.dklLum,bestLow.measuredCdM2,'go','MarkerFaceColor','g');
plot(bestHigh.dklLum,bestHigh.measuredCdM2,'ro','MarkerFaceColor','r');
xlabel('DKL luminance coordinate'); ylabel('Measured luminance (cd/m^2)');
title(titleText); box off;
end

function p = enterC24RgbMode(p)
% Close the L48 task window and open a temporary native 8-bit RGB window.
try
    if isfield(p.draw, 'window') && ~isempty(p.draw.window) && ...
            Screen('WindowKind', p.draw.window) == 1
        Screen('Close', p.draw.window);
    end
catch
    Screen('CloseAll');
end
Datapixx('Open');
Datapixx('SetVideoMode', 0); % C24: straight 8-bit RGB passthrough
Datapixx('RegWrRd');
AssertOpenGL;
PsychImaging('PrepareConfiguration');
screenNumber = max(Screen('Screens'));
[p.draw.window, p.draw.screenRect] = PsychImaging('OpenWindow', ...
    screenNumber, [0 0 0]);
Screen('ColorRange', p.draw.window, 255);
LoadIdentityClut(p.draw.window);
p.draw.middleXY = [p.draw.screenRect(3) / 2, p.draw.screenRect(4) / 2];
Screen('FillRect', p.draw.window, [0 0 0]);
Screen('Flip', p.draw.window);
end

function p = restoreL48TaskMode(p)
% Recreate the normal SRS L48 dual-CLUT display after the RGB scan.
try
    if isfield(p.draw, 'window') && ~isempty(p.draw.window) && ...
            Screen('WindowKind', p.draw.window) == 1
        Screen('FillRect', p.draw.window, [0 0 0]);
        Screen('Flip', p.draw.window);
        Screen('Close', p.draw.window);
    end
catch
    Screen('CloseAll');
end
Datapixx('Open');
Datapixx('SetVideoMode', 0);
Datapixx('RegWrRd');
p = pds.initDataPixx(p);
p = pds.initAudio(p);
end

function abortIfEscape
[isDown,~,keyCode]=KbCheck;
if isDown && keyCode(KbName('ESCAPE'))
    error('Red RGB scan aborted by user.');
end
end

function safeCloseWaitbar(h)
if ~isempty(h) && ishandle(h), close(h); end
end
