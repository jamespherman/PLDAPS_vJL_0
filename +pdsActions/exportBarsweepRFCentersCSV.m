function p = exportBarsweepRFCentersCSV(p)
% exportBarsweepRFCentersCSV  Per-channel barsweep RF centers -> CSV.
%
%   p = exportBarsweepRFCentersCSV(p)
%
%   Reconstructs per-channel 2-D Gaussian fits from a barsweep RF
%   accumulator (rfmap12 or cardinal4 regime) via reconstructBarsweepRF
%   and writes a minimal channel,x_deg,y_deg CSV. Centers are
%   fixation-relative dva (path-center offset added back).
%   Undetected channels (peakStats.detected == false) get NaN rows.
%
%   Two modes:
%
%   (1) In-session: when the current task is barsweep and
%       p.init.barsweepRF exists in memory, reconstructs from the live
%       accumulator and writes the CSV into p.init.sessionFolder. No
%       prompt.
%
%   (2) Post-session: otherwise, prompts the user (uigetdir) to select a
%       barsweep session folder, loads the <sessionId>_barsweepRF.mat
%       sidecar (written every trial by barsweep_finish.m), reconstructs,
%       and writes the CSV into that same folder. The per-trial trialNNNN
%       files have init.barsweepRF with spikeHist/dwellTime stripped, so
%       the sidecar is the only on-disk source of the full accumulator.
%
%   The CSV is consumed manually by sacc_to_phosph for online RF
%   targeting (same format as +pdsActions/exportRFCentersCSV).

% In-session detection: barsweep loaded AND its RF accumulator is live.
inSession = isfield(p, 'init') && isfield(p.init, 'taskName') && ...
    strcmp(p.init.taskName, 'barsweep') && ...
    isfield(p.init, 'barsweepRF') && ...
    isstruct(p.init.barsweepRF) && ...
    isfield(p.init.barsweepRF, 'spikeHist') && ...
    ~isempty(p.init.barsweepRF.spikeHist);

if inSession
    rf      = p.init.barsweepRF;
    outDir  = p.init.sessionFolder;
    if ~exist(outDir, 'dir'), mkdir(outDir); end
    csvName = sprintf('rfCenters_%s_trial%03d.csv', ...
        p.init.sessionId, p.status.iTrial);
else
    % Post-session: pick a barsweep session folder.
    startDir = '';
    if isfield(p, 'init') && isfield(p.init, 'outputFolder') && ...
            exist(p.init.outputFolder, 'dir')
        startDir = p.init.outputFolder;
    end
    sessionDir = uigetdir(startDir, ...
        'Select barsweep session folder (contains trial*.mat files)');
    if isequal(sessionDir, 0)
        fprintf('exportBarsweepRFCentersCSV: cancelled.\n');
        return;
    end

    % The full accumulator lives in the sidecar
    % <sessionId>_barsweepRF.mat (barsweep_finish.m strips spikeHist /
    % dwellTime from p.init.barsweepRF before writing trialNNNN.mat, so
    % the trial files cannot be used here).
    [~, sessionId] = fileparts(sessionDir);
    sidecarPath = fullfile(sessionDir, [sessionId '_barsweepRF.mat']);
    if ~exist(sidecarPath, 'file')
        error('exportBarsweepRFCentersCSV:noSidecar', ...
            ['No barsweepRF sidecar found at %s. Was this a barsweep ' ...
             'session with useOnlineRF=true?'], sidecarPath);
    end
    fprintf('exportBarsweepRFCentersCSV: loading %s\n', sidecarPath);
    tmp = load(sidecarPath, 'barsweepRF');
    if ~isfield(tmp, 'barsweepRF') || ~isstruct(tmp.barsweepRF) || ...
            ~isfield(tmp.barsweepRF, 'spikeHist') || ...
            isempty(tmp.barsweepRF.spikeHist)
        error('exportBarsweepRFCentersCSV:badSidecar', ...
            'Sidecar %s does not contain a populated barsweepRF struct.', ...
            sidecarPath);
    end
    rf = tmp.barsweepRF;
    outDir = sessionDir;
    csvName = sprintf('rfCenters_%s_final.csv', sessionId);
end

% Make sure reconstructBarsweepRF is on the path. supportFunctions lives
% next to the session folder's task directory.
if isempty(which('reconstructBarsweepRF'))
    thisFile = mfilename('fullpath');
    repoRoot = fileparts(fileparts(thisFile));   % +pdsActions/.. = repo
    supportDir = fullfile(repoRoot, 'tasks', 'barsweep', 'supportFunctions');
    if exist(supportDir, 'dir')
        addpath(supportDir);
    else
        error('exportBarsweepRFCentersCSV:noSupport', ...
            'Could not locate tasks/barsweep/supportFunctions on path.');
    end
end

% Reconstruct per-channel centers + SNR.
nCh     = rf.nChannels;
centers = nan(nCh, 2);
snr     = nan(nCh, 1);
pathOff = rf.pathCenterDeg(:).';   % [xOff, yOff] in dva

for ch = 1:nCh
    if rf.spikeCount(ch) < 1, continue; end
    out = reconstructBarsweepRF(rf, ch, rf.exptType);
    snr(ch) = out.peakStats.snr;
    if out.peakStats.detected
        centers(ch, 1) = out.gaussFit.x0 + pathOff(1);
        centers(ch, 2) = out.gaussFit.y0 + pathOff(2);
    end
end

csvPath = fullfile(outDir, csvName);
fid = fopen(csvPath, 'w');
if fid < 0
    error('exportBarsweepRFCentersCSV:fopen', ...
        'Could not open %s for writing.', csvPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'channel,x_deg,y_deg,snr\n');
for ch = 1:nCh
    fprintf(fid, '%d,%.4f,%.4f,%.4g\n', ch, centers(ch, 1), centers(ch, 2), snr(ch));
end

nDet = sum(~isnan(centers(:, 1)));
fprintf('exportBarsweepRFCentersCSV: %d/%d channels detected -> %s\n', ...
    nDet, nCh, csvPath);

end
