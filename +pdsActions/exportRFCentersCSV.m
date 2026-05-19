function p = exportRFCentersCSV(p)
% exportRFCentersCSV  Write per-channel RF centers to a minimal CSV.
%
%   p = exportRFCentersCSV(p)
%
%   Two modes:
%
%   (1) In-session: if p.trData.rfCentersDeg exists in memory and
%       contains at least one finite value, writes a CSV directly to
%       p.init.sessionFolder. No prompt.
%
%   (2) Post-session: otherwise, prompts the user (uigetdir) to select a
%       session folder, locates the latest 'trial*.mat' file inside,
%       extracts trData.rfCentersDeg from it, and writes the CSV into
%       that same folder.
%
%   CSV columns: channel, x_deg, y_deg.
%   Format: header + one row per channel; NaN written literally for
%   channels that lack an estimate (e.g., zero-spike or checkerboard).
%   Consumed manually by the sacc_to_phosph task.

inMem = isfield(p, 'trData') && isfield(p.trData, 'rfCentersDeg') ...
        && ~isempty(p.trData.rfCentersDeg) ...
        && any(isfinite(p.trData.rfCentersDeg(:)));

if inMem
    centers = p.trData.rfCentersDeg;

    outDir = p.init.sessionFolder;
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    csvName = sprintf('rfCenters_%s_trial%03d.csv', ...
        p.init.sessionId, p.status.iTrial);
else
    % Post-session: pick a session folder.
    startDir = '';
    if isfield(p, 'init') && isfield(p.init, 'outputFolder') && ...
            exist(p.init.outputFolder, 'dir')
        startDir = p.init.outputFolder;
    end
    sessionDir = uigetdir(startDir, ...
        'Select session folder containing trial .mat files');
    if isequal(sessionDir, 0)
        fprintf('exportRFCentersCSV: cancelled.\n');
        return;
    end

    % Find the latest trial*.mat in that folder.
    fileList = dir(fullfile(sessionDir, 'trial*.mat'));
    if isempty(fileList)
        error('exportRFCentersCSV:noTrialFiles', ...
            'No trial*.mat files found in %s', sessionDir);
    end
    [~, sortIdx] = sort([fileList.datenum], 'descend');
    latestFile = fullfile(sessionDir, fileList(sortIdx(1)).name);

    fprintf('exportRFCentersCSV: loading %s\n', latestFile);
    tmp = load(latestFile);
    if ~isfield(tmp, 'trData') || ...
            ~isfield(tmp.trData, 'rfCentersDeg') || ...
            isempty(tmp.trData.rfCentersDeg)
        error('exportRFCentersCSV:noField', ...
            ['Latest trial file %s has no trData.rfCentersDeg. ' ...
             'This session predates the RF-center save (or the ' ...
             'session was checkerboard).'], latestFile);
    end
    centers = tmp.trData.rfCentersDeg;
    outDir  = sessionDir;
    [~, sessionId] = fileparts(sessionDir);
    csvName = sprintf('rfCenters_%s_final.csv', sessionId);
end

csvPath = fullfile(outDir, csvName);
fid = fopen(csvPath, 'w');
if fid < 0
    error('exportRFCentersCSV:fopen', ...
        'Could not open %s for writing.', csvPath);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'channel,x_deg,y_deg\n');
nCh = size(centers, 1);
for ch = 1:nCh
    fprintf(fid, '%d,%.4f,%.4f\n', ch, centers(ch, 1), centers(ch, 2));
end

fprintf('exportRFCentersCSV: wrote %d channels -> %s\n', nCh, csvPath);

end
