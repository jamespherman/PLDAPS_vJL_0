function varargout = i1LivePhotometer(varargin)
% i1LivePhotometer
%
% PLDAPS user action for on-demand i1Pro/i1Pro3 luminance measurements
% while a task is running.
%
% IMPORTANT DESIGN CHOICE
% -----------------------
% The photometer runs in a SECOND MATLAB process. This prevents the
% blocking I1('TriggerMeasurement') call from pausing the PLDAPS task or
% producing missed video frames in the task process.
%
% GUI use:
%   1) Initialize the task in the PLDAPS GUI.
%   2) Click the "i1LivePhotometer" user-action button once to start it.
%   3) Calibrate the i1 on its white tile when the separate monitor window
%      asks you to do so.
%   4) Start the task normally.
%   5) Move the i1 sensor to the desired screen location and press the
%      physical button to take a measurement.
%   6) Click the action again, press Stop in the monitor window, or close
%      the monitor window to stop.
%
% Each measurement is appended to CSV and MAT files. The first value
% returned by this laboratory's I1 MEX is treated as luminance (cd/m^2),
% followed by CIE 1931 x and y, matching the existing PLDAPS i1 actions.
%
% This file has two entry modes:
%   p = i1LivePhotometer(p)                     % PLDAPS action/controller
%   i1LivePhotometer('worker', configMatFile)  % private worker process
%
% The action does not alter task stimuli, state transitions, timing, or
% trial data.

if nargin >= 1 && isstruct(varargin{1})
    p = varargin{1};
    p = controllerMode(p);
    varargout{1} = p;
    return
end

if nargin >= 2 && (ischar(varargin{1}) || isstring(varargin{1})) && ...
        strcmpi(string(varargin{1}), "worker")
    runWorker(char(varargin{2}));
    if nargout > 0
        varargout{1} = [];
    end
    return
end

error(['i1LivePhotometer must be called either as a PLDAPS action ', ...
       'with p, or internally with ''worker'' and a config file.']);
end


function p = controllerMode(p)
% Start or stop the independent worker process.

if ~isunix
    error('i1LivePhotometer currently supports the Linux PLDAPS rig only.');
end

stateDir = getStateDirectory();
if ~exist(stateDir, 'dir')
    [ok, msg] = mkdir(stateDir);
    if ~ok
        error('Could not create i1 live-monitor state directory: %s', msg);
    end
end

stateFile = fullfile(stateDir, 'controller_state.mat');
stopFile  = fullfile(stateDir, 'STOP_REQUESTED');
lockFile  = fullfile(stateDir, 'WORKER_RUNNING');

% If a live worker exists, a second click requests a clean stop.
[stateIsRunning, oldState] = readRunningState(stateFile, lockFile);
if stateIsRunning
    touchFile(stopFile);
    fprintf(['\nStop requested for the i1 live photometer.\n', ...
             'The worker will close after its current measurement, if any.\n']);

    if isfield(p, 'status')
        p.status.i1LivePhotometerRunning = false;
    end
    return
end

% Remove stale state left by an earlier crash.
safeDelete(stopFile);
safeDelete(lockFile);
if ~isempty(oldState) && isfield(oldState, 'stateFile')
    safeDelete(oldState.stateFile);
end
safeDelete(stateFile);

% Find the working, non-package I1 MEX used previously on this rig.
i1MexFolder = findI1MexFolder();

% Output is session-specific but the worker-control directory is fixed.
if isfield(p, 'init') && isfield(p.init, 'outputFolder') && ...
        ~isempty(p.init.outputFolder)
    outputRoot = p.init.outputFolder;
else
    outputRoot = pwd;
end

outputDir = fullfile(outputRoot, 'i1_live');
if ~exist(outputDir, 'dir')
    [ok, msg] = mkdir(outputDir);
    if ~ok
        error('Could not create i1 output directory: %s', msg);
    end
end

if isfield(p, 'init') && isfield(p.init, 'sessionId') && ...
        ~isempty(p.init.sessionId)
    sessionId = p.init.sessionId;
else
    sessionId = ['session_' datestr(now, 'yyyymmdd_HHMMSS')];
end

sessionId = sanitizeFilePart(sessionId);
launchStamp = datestr(now, 'yyyymmdd_HHMMSS');
baseName = [sessionId '_i1Live_' launchStamp];

config = struct();
config.version = 1;
config.i1MexFolder = i1MexFolder;
config.outputDir = outputDir;
config.baseName = baseName;
config.csvFile = fullfile(outputDir, [baseName '.csv']);
config.matFile = fullfile(outputDir, [baseName '.mat']);
config.latestFile = fullfile(outputDir, [baseName '_latest.txt']);
config.workerLogFile = fullfile(outputDir, [baseName '_worker.log']);
config.stopFile = stopFile;
config.lockFile = lockFile;
config.stateFile = stateFile;
config.pollIntervalSec = 0.02;
config.debounceSec = 0.20;
config.saveSpectrum = false;
config.figurePosition = [40 80 560 360];
config.actionsFolder = fileparts(mfilename('fullpath'));
config.matlabExecutable = fullfile(matlabroot, 'bin', 'matlab');

configFile = fullfile(stateDir, ['config_' launchStamp '.mat']);
launcherFile = fullfile(stateDir, ['launch_' launchStamp '.sh']);
config.configFile = configFile;
config.launcherFile = launcherFile;
save(configFile, 'config');

writeLauncherScript(launcherFile, config, configFile);

[status, chmodOutput] = system(sprintf('chmod u+x %s', shellQuote(launcherFile)));
if status ~= 0
    error('Could not make launcher executable: %s', strtrim(chmodOutput));
end

launchCommand = sprintf('nohup %s > %s 2>&1 & echo $!', ...
    shellQuote(launcherFile), shellQuote(config.workerLogFile));
[status, pidText] = system(launchCommand);
if status ~= 0
    error('Could not launch the independent i1 MATLAB worker: %s', strtrim(pidText));
end

workerPid = str2double(strtrim(pidText));
if ~isfinite(workerPid) || workerPid <= 0
    error('The worker launch returned an invalid PID: %s', strtrim(pidText));
end

controllerState = struct();
controllerState.workerPid = workerPid;
controllerState.configFile = configFile;
controllerState.launcherFile = launcherFile;
controllerState.workerLogFile = config.workerLogFile;
controllerState.stopFile = stopFile;
controllerState.lockFile = lockFile;
controllerState.stateFile = stateFile;
controllerState.startedAt = datestr(now, 31);
save(stateFile, 'controllerState');

% Give MATLAB a moment to launch. Do not require the lock immediately,
% because startup time depends on the workstation and license server.
pause(0.5);

fprintf(['\nIndependent i1 live photometer launched (PID %d).\n', ...
         'A separate monitor window should appear after MATLAB starts.\n', ...
         'Calibrate there, then start the PLDAPS task normally.\n', ...
         'Press the physical i1 button for each spot measurement.\n', ...
         'Measurements: %s\n', ...
         'Worker log:  %s\n', ...
         'Click this action again to request Stop.\n\n'], ...
         workerPid, config.csvFile, config.workerLogFile);

if ~isfield(p, 'status')
    p.status = struct();
end
p.status.i1LivePhotometerRunning = true;
p.status.i1LivePhotometerPid = workerPid;
p.status.i1LivePhotometerCsv = config.csvFile;
p.status.i1LivePhotometerMat = config.matFile;
end


function runWorker(configFile)
% Independent process: owns the USB device and performs blocking measures.

loaded = load(configFile, 'config');
if ~isfield(loaded, 'config')
    error('Config file does not contain a config structure: %s', configFile);
end
config = loaded.config;

cleanupObj = onCleanup(@() workerCleanup(config)); %#ok<NASGU>

touchFile(config.lockFile);
safeDelete(config.stopFile);

% Put the known working I1 MEX first on the worker path.
addpath(config.i1MexFolder, '-begin');
rehash;

if exist('I1', 'file') ~= 3 && exist('I1', 'file') ~= 2
    error('I1 MEX was not found in: %s', config.i1MexFolder);
end

fig = createMonitorFigure(config);
setappdata(fig, 'stopRequested', false);
setappdata(fig, 'manualMeasureRequested', false);

setStatus(fig, 'Connecting to i1Pro 3...', [0.15 0.15 0.15]);
drawnow;

if I1('IsConnected') == 0
    error(['No i1 device detected. Confirm USB connection and that no ', ...
           'other process currently owns the device.']);
end

physicalButtonSupported = true;
try
    I1('KeyPressed');
catch
    physicalButtonSupported = false;
end
setappdata(fig, 'physicalButtonSupported', physicalButtonSupported);

% Calibrate using the physical measurement button, as in the VPixx demo.
if physicalButtonSupported
    calibrationMessage = ['Put the i1Pro 3 on its matching white calibration tile. ' ...
        'Press the PHYSICAL button on the i1 when ready.'];
else
    calibrationMessage = ['Put the i1Pro 3 on its matching white calibration tile. ' ...
        'The MEX does not expose KeyPressed; click Calibrate now.'];
end
setStatus(fig, calibrationMessage, [0.65 0.35 0.00]);
setMeasureButtonLabel(fig, 'Calibrate now');

if ~waitForUserTrigger(fig, config)
    return
end

setStatus(fig, 'Calibrating i1Pro 3...', [0.15 0.35 0.75]);
drawnow;
I1('Calibrate');
waitForPhysicalButtonRelease(config);

if physicalButtonSupported
    readyMessage = ['READY. Put the sensor on any screen location. ' ...
        'Press the physical i1 button to measure.'];
else
    readyMessage = ['READY. Put the sensor on any screen location, then ' ...
        'click Measure now.'];
end
setStatus(fig, readyMessage, [0.00 0.45 0.10]);
setMeasureButtonLabel(fig, 'Measure now');
updateMeasurementDisplay(fig, NaN, NaN, NaN, 0, NaN);

records = emptyRecords();
writeCsvHeader(config.csvFile);
save(config.matFile, 'records', 'config');

fprintf('\nI1 LIVE PHOTOMETER READY\n');
fprintf('Move the sensor and press its physical button for each measure.\n');
fprintf('CSV: %s\n\n', config.csvFile);

while isgraphics(fig) && ~stopRequested(fig, config)
    physicalPressed = safeKeyPressed();
    manualRequested = getappdata(fig, 'manualMeasureRequested');

    if physicalPressed || manualRequested
        setappdata(fig, 'manualMeasureRequested', false);

        if physicalPressed
            triggerSource = 'deviceButton';
            buttonPressGetSecs = safeGetSecs();
            waitForPhysicalButtonRelease(config);
        else
            triggerSource = 'monitorButton';
            buttonPressGetSecs = safeGetSecs();
        end

        setStatus(fig, 'Measuring...', [0.15 0.35 0.75]);
        drawnow;

        try
            measurementStartGetSecs = safeGetSecs();
            I1('TriggerMeasurement');
            Lxy = I1('GetTriStimulus');
            measurementEndGetSecs = safeGetSecs();

            if ~isnumeric(Lxy) || numel(Lxy) < 3 || any(~isfinite(Lxy(1:3)))
                error('I1 returned an invalid tristimulus measurement.');
            end

            % This lab's existing MATLAB I1 code uses [L, x, y].
            luminanceCdM2 = double(Lxy(1));
            cieX = double(Lxy(2));
            cieY = double(Lxy(3));

            count = numel(records) + 1;
            record = struct();
            record.index = count;
            record.isoTime = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss.SSS'));
            record.matlabDatenum = now;
            record.posixTimeSec = posixtime(datetime('now', 'TimeZone', 'UTC'));
            record.triggerSource = triggerSource;
            record.buttonPressGetSecs = buttonPressGetSecs;
            record.measurementStartGetSecs = measurementStartGetSecs;
            record.measurementEndGetSecs = measurementEndGetSecs;
            record.measurementDurationSec = measurementEndGetSecs - measurementStartGetSecs;
            record.luminanceCdM2 = luminanceCdM2;
            record.cieX = cieX;
            record.cieY = cieY;

            if isfield(config, 'saveSpectrum') && config.saveSpectrum
                try
                    record.spectrum = I1('GetSpectrum');
                catch
                    record.spectrum = [];
                end
            else
                record.spectrum = [];
            end

            records(end + 1) = record; %#ok<AGROW>
            appendCsvRecord(config.csvFile, record);
            save(config.matFile, 'records', 'config');
            writeLatestFile(config.latestFile, record);

            updateMeasurementDisplay(fig, luminanceCdM2, cieX, cieY, ...
                count, record.measurementDurationSec);
            setStatus(fig, ['READY. Move sensor and press physical button ' ...
                'for another measurement.'], [0.00 0.45 0.10]);

            fprintf(['%03d | L = %.4f cd/m^2 | x = %.5f | y = %.5f | ', ...
                     'duration = %.3f s | %s\n'], ...
                count, luminanceCdM2, cieX, cieY, ...
                record.measurementDurationSec, record.isoTime);
        catch ME
            setStatus(fig, ['Measurement error: ' ME.message], [0.75 0.00 0.00]);
            fprintf(2, 'I1 measurement error: %s\n', getReport(ME, 'basic', ...
                'hyperlinks', 'off'));
        end

        pause(config.debounceSec);
    end

    drawnow limitrate;
    pause(config.pollIntervalSec);
end

if isgraphics(fig)
    setStatus(fig, 'Stopping...', [0.35 0.35 0.35]);
    drawnow;
    delete(fig);
end
end


function fig = createMonitorFigure(config)
fig = figure( ...
    'Name', 'i1Pro 3 - Live Luminance Monitor', ...
    'NumberTitle', 'off', ...
    'MenuBar', 'none', ...
    'ToolBar', 'none', ...
    'Renderer', 'painters', ...
    'Color', [0.96 0.96 0.96], ...
    'Position', config.figurePosition, ...
    'CloseRequestFcn', @requestStopFromFigure);

uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.80 0.90 0.15], ...
    'Tag', 'statusText', ...
    'String', 'Starting...', ...
    'BackgroundColor', [0.96 0.96 0.96], ...
    'HorizontalAlignment', 'left', ...
    'FontSize', 12, ...
    'FontWeight', 'bold');

uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.50 0.90 0.24], ...
    'Tag', 'luminanceText', ...
    'String', '-- cd/m^2', ...
    'BackgroundColor', [1 1 1], ...
    'ForegroundColor', [0.00 0.25 0.65], ...
    'FontSize', 28, ...
    'FontWeight', 'bold');

uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.34 0.90 0.12], ...
    'Tag', 'xyText', ...
    'String', 'CIE 1931: x = --    y = --', ...
    'BackgroundColor', [0.96 0.96 0.96], ...
    'FontSize', 12);

uicontrol(fig, ...
    'Style', 'text', ...
    'Units', 'normalized', ...
    'Position', [0.05 0.23 0.90 0.08], ...
    'Tag', 'countText', ...
    'String', 'Measurements: 0', ...
    'BackgroundColor', [0.96 0.96 0.96], ...
    'FontSize', 11);

uicontrol(fig, ...
    'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.10 0.07 0.48 0.11], ...
    'Tag', 'measureButton', ...
    'String', 'Measure now', ...
    'FontSize', 11, ...
    'Callback', @requestManualMeasurement);

uicontrol(fig, ...
    'Style', 'pushbutton', ...
    'Units', 'normalized', ...
    'Position', [0.65 0.07 0.25 0.11], ...
    'String', 'Stop', ...
    'FontSize', 11, ...
    'Callback', @requestStopFromFigure);
end


function triggered = waitForUserTrigger(fig, config)
triggered = false;
while isgraphics(fig) && ~stopRequested(fig, config)
    physicalPressed = safeKeyPressed();
    manualRequested = getappdata(fig, 'manualMeasureRequested');

    if physicalPressed || manualRequested
        setappdata(fig, 'manualMeasureRequested', false);
        if physicalPressed
            waitForPhysicalButtonRelease(config);
        end
        triggered = true;
        return
    end

    drawnow limitrate;
    pause(config.pollIntervalSec);
end
end


function waitForPhysicalButtonRelease(config)
% Debounce the i1 physical button so one long press yields one measure.
tStart = safeGetSecs();
while safeKeyPressed()
    drawnow limitrate;
    pause(config.pollIntervalSec);

    % Defensive timeout in case a driver reports a permanently pressed key.
    if safeGetSecs() - tStart > 5
        break
    end
end
pause(config.debounceSec);
end


function tf = safeKeyPressed()
try
    tf = logical(I1('KeyPressed'));
catch
    tf = false;
end
end


function tf = stopRequested(fig, config)
tf = false;
if isgraphics(fig) && isappdata(fig, 'stopRequested')
    tf = logical(getappdata(fig, 'stopRequested'));
end
if exist(config.stopFile, 'file')
    tf = true;
end
end


function requestManualMeasurement(src, ~)
fig = ancestor(src, 'figure');
if isgraphics(fig)
    setappdata(fig, 'manualMeasureRequested', true);
end
end


function requestStopFromFigure(src, ~)
if strcmp(get(src, 'Type'), 'figure')
    fig = src;
else
    fig = ancestor(src, 'figure');
end
if isgraphics(fig)
    setappdata(fig, 'stopRequested', true);
end
end


function updateMeasurementDisplay(fig, luminanceCdM2, cieX, cieY, count, durationSec)
if ~isgraphics(fig)
    return
end

lumHandle = findobj(fig, 'Tag', 'luminanceText');
xyHandle = findobj(fig, 'Tag', 'xyText');
countHandle = findobj(fig, 'Tag', 'countText');

if isfinite(luminanceCdM2)
    set(lumHandle, 'String', sprintf('%.4f cd/m^2', luminanceCdM2));
    set(xyHandle, 'String', sprintf('CIE 1931: x = %.5f    y = %.5f', cieX, cieY));
else
    set(lumHandle, 'String', '-- cd/m^2');
    set(xyHandle, 'String', 'CIE 1931: x = --    y = --');
end

if isfinite(durationSec)
    set(countHandle, 'String', sprintf('Measurements: %d    Last duration: %.3f s', ...
        count, durationSec));
else
    set(countHandle, 'String', sprintf('Measurements: %d', count));
end

drawnow;
end


function setStatus(fig, message, color)
if ~isgraphics(fig)
    return
end
statusHandle = findobj(fig, 'Tag', 'statusText');
if ~isempty(statusHandle)
    set(statusHandle, 'String', message, 'ForegroundColor', color);
end
drawnow limitrate;
end


function setMeasureButtonLabel(fig, label)
if ~isgraphics(fig)
    return
end
h = findobj(fig, 'Tag', 'measureButton');
if ~isempty(h)
    set(h, 'String', label);
end
end


function records = emptyRecords()
records = struct( ...
    'index', {}, ...
    'isoTime', {}, ...
    'matlabDatenum', {}, ...
    'posixTimeSec', {}, ...
    'triggerSource', {}, ...
    'buttonPressGetSecs', {}, ...
    'measurementStartGetSecs', {}, ...
    'measurementEndGetSecs', {}, ...
    'measurementDurationSec', {}, ...
    'luminanceCdM2', {}, ...
    'cieX', {}, ...
    'cieY', {}, ...
    'spectrum', {});
end


function writeCsvHeader(csvFile)
fid = fopen(csvFile, 'w');
if fid < 0
    error('Could not create CSV file: %s', csvFile);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, ['index,isoTime,matlabDatenum,posixTimeSec,triggerSource,buttonPressGetSecs,', ...
    'measurementStartGetSecs,measurementEndGetSecs,measurementDurationSec,', ...
    'luminanceCdM2,cieX,cieY\n']);
end


function appendCsvRecord(csvFile, record)
fid = fopen(csvFile, 'a');
if fid < 0
    error('Could not append to CSV file: %s', csvFile);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%d,%s,%.15f,%.6f,%s,%.9f,%.9f,%.9f,%.6f,%.9f,%.9f,%.9f\n', ...
    record.index, record.isoTime, record.matlabDatenum, record.posixTimeSec, ...
    record.triggerSource, record.buttonPressGetSecs, record.measurementStartGetSecs, ...
    record.measurementEndGetSecs, record.measurementDurationSec, ...
    record.luminanceCdM2, record.cieX, record.cieY);
end


function writeLatestFile(latestFile, record)
fid = fopen(latestFile, 'w');
if fid < 0
    return
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'Measurement %d\n', record.index);
fprintf(fid, 'Time: %s\n', record.isoTime);
fprintf(fid, 'Luminance: %.6f cd/m^2\n', record.luminanceCdM2);
fprintf(fid, 'CIE x: %.8f\n', record.cieX);
fprintf(fid, 'CIE y: %.8f\n', record.cieY);
fprintf(fid, 'POSIX UTC seconds: %.6f\n', record.posixTimeSec);
fprintf(fid, 'Trigger: %s\n', record.triggerSource);
fprintf(fid, 'Button GetSecs: %.9f\n', record.buttonPressGetSecs);
fprintf(fid, 'Measurement start GetSecs: %.9f\n', record.measurementStartGetSecs);
fprintf(fid, 'Measurement end GetSecs: %.9f\n', record.measurementEndGetSecs);
fprintf(fid, 'Duration: %.6f s\n', record.measurementDurationSec);
end


function [isRunning, state] = readRunningState(stateFile, lockFile)
isRunning = false;
state = [];

if exist(stateFile, 'file')
    try
        loaded = load(stateFile, 'controllerState');
        if isfield(loaded, 'controllerState')
            state = loaded.controllerState;
        end
    catch
        state = [];
    end
end

if isempty(state) || ~isfield(state, 'workerPid') || ...
        ~isfinite(state.workerPid)
    return
end

[status, ~] = system(sprintf('kill -0 %d 2>/dev/null', round(state.workerPid)));
isRunning = (status == 0);

% Lock is an additional positive signal, but PID liveness is authoritative.
if ~isRunning && exist(lockFile, 'file')
    safeDelete(lockFile);
end
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


function writeLauncherScript(launcherFile, config, configFile)
matlabExpr = sprintf([ ...
    'try, addpath(''%s'',''-begin''); ', ...
    'i1LivePhotometer(''worker'',''%s''); ', ...
    'catch ME, fprintf(2,''%%s\\n'',getReport(ME,''extended'',''hyperlinks'',''off'')); ', ...
    'end; exit;'], ...
    matlabString(config.actionsFolder), matlabString(configFile));

fid = fopen(launcherFile, 'w');
if fid < 0
    error('Could not create launcher script: %s', launcherFile);
end
cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '#!/usr/bin/env bash\n');
fprintf(fid, 'export DISPLAY="${DISPLAY:-:0}"\n');
fprintf(fid, 'exec %s -nodesktop -nosplash -r %s\n', ...
    shellQuote(config.matlabExecutable), shellQuote(matlabExpr));
end


function out = matlabString(in)
% Escape a path for inclusion inside a MATLAB single-quoted string.
out = strrep(char(in), '''', '''''');
end


function out = shellQuote(in)
% POSIX single-quote escaping.
in = char(in);
out = ['''' strrep(in, '''', '''"''"''') ''''];
end


function stateDir = getStateDirectory()
userName = getenv('USER');
if isempty(userName)
    userName = 'unknown_user';
end
userName = sanitizeFilePart(userName);
stateDir = fullfile(tempdir, ['pldaps_i1_live_' userName]);
end


function out = sanitizeFilePart(in)
out = regexprep(char(in), '[^A-Za-z0-9_.-]', '_');
if isempty(out)
    out = 'unnamed';
end
end


function touchFile(filePath)
fid = fopen(filePath, 'w');
if fid >= 0
    fprintf(fid, '%s\n', datestr(now, 31));
    fclose(fid);
end
end


function safeDelete(filePath)
if exist(filePath, 'file')
    try
        delete(filePath);
    catch
    end
end
end


function t = safeGetSecs()
try
    t = GetSecs;
catch
    t = now * 86400;
end
end


function workerCleanup(config)
safeDelete(config.lockFile);
safeDelete(config.stopFile);
safeDelete(config.stateFile);
if isfield(config, 'configFile')
    safeDelete(config.configFile);
end
if isfield(config, 'launcherFile')
    safeDelete(config.launcherFile);
end

try
    fprintf('\nI1 live photometer stopped.\n');
catch
end
end
