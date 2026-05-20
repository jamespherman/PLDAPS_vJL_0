function [rf, csvPath] = rebuildBarsweepRFFromTrials(sessionDir, varargin)
% [rf, csvPath] = rebuildBarsweepRFFromTrials(sessionDir, ...)
%
% Reaccumulate a barsweep session's RF estimator from trial####.mat
% files by feeding each trial through the current accumulateBarsweepRF.
% Use this to retroactively apply accumulator changes (e.g. the
% on-screen-frame filter added 2026-05-20) to recorded data without
% rerunning the experiment.
%
% Loads p.draw from the session-level p.mat (so the accumulator's
% on-screen mask can use draw.screenRect) and uses the trial file's
% own trVars/init for everything else. Writes a CSV alongside the
% existing one with a `_rebuilt.csv` suffix so the original CSV is
% preserved for comparison.
%
% Name-value options:
%   'csvSuffix' - filename suffix (default '_rebuilt')
%   'verbose'   - print per-trial progress (default false)

ip = inputParser;
ip.addRequired('sessionDir', @(x) ischar(x) || isstring(x));
ip.addParameter('csvSuffix', '_rebuilt', @(x) ischar(x) || isstring(x));
ip.addParameter('verbose',   false, @islogical);
ip.parse(sessionDir, varargin{:});
sessionDir = char(ip.Results.sessionDir);
csvSuffix  = char(ip.Results.csvSuffix);
verbose    = ip.Results.verbose;
assert(isfolder(sessionDir), 'rebuildBarsweepRFFromTrials: %s is not a folder.', sessionDir);

% Session-level p.mat carries p.draw (not saved per-trial). It's stored
% flattened (fields of p as top-level vars), not under a single 'p'
% struct. Required for the on-screen filter; if absent we warn and
% proceed without it.
pMatPath = fullfile(sessionDir, 'p.mat');
draw = [];
if exist(pMatPath, 'file')
    S = load(pMatPath, 'draw');
    if isfield(S, 'draw'), draw = S.draw; end
end
if isempty(draw) || ~isfield(draw, 'screenRect')
    warning('rebuildBarsweepRFFromTrials:noDraw', ...
        ['No draw.screenRect found in %s; rebuild will run without ' ...
         'the on-screen-frame filter.'], pMatPath);
end

% Locate trial files in numeric order. dir() globs * but not character
% classes; filter out anything else (e.g. trial_finish.mat) by regex.
all = dir(fullfile(sessionDir, 'trial*.mat'));
keep = ~cellfun('isempty', regexp({all.name}, '^trial\d+\.mat$', 'once'));
trialFiles = all(keep);
assert(~isempty(trialFiles), 'rebuildBarsweepRFFromTrials: no trial####.mat in %s.', sessionDir);
[~, ord] = sort({trialFiles.name});
trialFiles = trialFiles(ord);

% Initialize a fresh accumulator from the first trial's trVars/init.
% initBarsweepRF needs p.init.exptType and either p.trVars or p.trVarsInit
% with the spatial knobs (pathLengthDeg, barWidthDeg, rfPosBinDeg, ...).
first = load(fullfile(sessionDir, trialFiles(1).name));
pInit = struct();
pInit.init = first.init;
pInit.trVars = first.trVars;
pInit.init.barsweepRF = struct();  % force re-allocation
pInit = initBarsweepRF(pInit);
rf = pInit.init.barsweepRF;

% Replay every trial through the (updated) accumulator.
nUsed = 0;
for k = 1:numel(trialFiles)
    S = load(fullfile(sessionDir, trialFiles(k).name));
    trial = struct('trVars', S.trVars, 'trData', S.trData, ...
                   'status', S.status, 'init', S.init);
    rf = replayBarsweepRF(trial, rf, draw);
    nUsed = nUsed + 1;
    if verbose && mod(k, 20) == 0
        fprintf('  rebuilt through trial %d/%d\n', k, numel(trialFiles));
    end
end

% Per-channel centers using the current reconstruction + export rule:
% cardinal4 -> parabolic peaks; rfmap12 -> moment fit of iradon image.
nCh     = rf.nChannels;
centers = nan(nCh, 2);
snr     = nan(nCh, 1);
pathOff = rf.pathCenterDeg(:).';

for ch = 1:nCh
    if rf.spikeCount(ch) < 1, continue; end
    out     = reconstructBarsweepRF(rf, ch, rf.exptType);
    snr(ch) = out.peakStats.snr;
    if ~out.peakStats.detected, continue; end
    switch rf.exptType
        case 'barsweep_cardinal4'
            centers(ch, 1) = out.xCenter   + pathOff(1);
            centers(ch, 2) = out.yCenter   + pathOff(2);
        case 'barsweep_rfmap12'
            centers(ch, 1) = out.gaussFit.x0 + pathOff(1);
            centers(ch, 2) = out.gaussFit.y0 + pathOff(2);
        otherwise
            error('rebuildBarsweepRFFromTrials:exptType', ...
                'Unknown exptType "%s".', rf.exptType);
    end
end

[~, sessionId] = fileparts(sessionDir);
csvPath = fullfile(sessionDir, ...
    sprintf('rfCenters_%s_final%s.csv', sessionId, csvSuffix));
fid = fopen(csvPath, 'w');
assert(fid >= 0, 'rebuildBarsweepRFFromTrials: cannot open %s for writing.', csvPath);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'channel,x_deg,y_deg,snr\n');
for ch = 1:nCh
    fprintf(fid, '%d,%.4f,%.4f,%.4g\n', ch, centers(ch, 1), centers(ch, 2), snr(ch));
end

nDet = sum(~isnan(centers(:, 1)));
fprintf('rebuildBarsweepRFFromTrials: %s -- %d trials, %d/%d detected -> %s\n', ...
    sessionId, nUsed, nDet, nCh, csvPath);

end
