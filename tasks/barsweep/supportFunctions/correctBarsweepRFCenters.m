function [T, csvPath] = correctBarsweepRFCenters(sessionDir, varargin)
% [T, csvPath] = correctBarsweepRFCenters(sessionDir, ...)
%
% Post-hoc geometry correction for barsweep sessions collected BEFORE the
% nextParams.m sweep-geometry fix.
%
% Reads the session's RF accumulator sidecar and rig geometry, reconstructs
% each channel's RF, and relabels the resulting centres from the (incorrect)
% sweep-axis units into true visual angle. Writes a CSV carrying raw and
% corrected values side by side. Nothing on disk is overwritten.
%
% Background, derivation, and error magnitudes:
%   analysisPlanningDocs/barsweep_geometry_discrepancy_report.md
%
% ---------------------------------------------------------------------
% What is and is not corrected
%
%   corrected : per-channel RF centre (x, y), and RF sigma via the local
%               derivative of the mapping.
%   unchanged : latency estimates. The pre-fix sweep axis is exactly linear
%               in TIME, so the opposite-direction peak separation (and the
%               midpoint cancellation it relies on) is already correct.
%   unfixable : coverage lost to off-screen frames. accumulateBarsweepRF
%               correctly excluded frames whose bar centre fell outside
%               screenRect; those positions were never sampled. This
%               function reports the affected range so you can flag
%               channels whose centre sits near or beyond it.
%
% ---------------------------------------------------------------------
% Inputs
%   sessionDir   path to an output session folder, i.e. the one containing
%                p.mat and <sessionId>_barsweepRF.mat.
%
% Name-value options
%   'csvSuffix'  output filename suffix (default '_corrected')
%   'force'      correct even if the session looks post-fix (default false)
%   'fitMode'    passed to reconstructBarsweepRF (default 'full', matching
%                +pdsActions/exportBarsweepRFCentersCSV)
%   'rebuild'    'auto' (default) | 'always' | 'never'. Sessions predating
%                the v2 per-direction accumulator carry a sidecar whose
%                spikeHist is keyed by ORIENTATION (2 rows for cardinal4),
%                but reconstructBarsweepRF's cardinal4 branch requires the
%                v2 per-DIRECTION layout (4 rows) for its midpoint method.
%                'auto' detects that mismatch and re-accumulates from the
%                session's trial####.mat files through the current
%                accumulator. 'never' errors instead of rebuilding.
%
% Outputs
%   T            table, one row per channel:
%                  channel, x_raw_deg, y_raw_deg, x_corr_deg, y_corr_deg,
%                  dx_deg, dy_deg, sigmaX_raw, sigmaY_raw,
%                  sigmaX_corr, sigmaY_corr, snr, latency_ms, detected,
%                  outsideCoverage
%   csvPath      path of the CSV written
%
% See also barsweepSweepAxisToDeg, rebuildBarsweepRFFromTrials,
%          exportBarsweepRFCentersCSV

%% ---------------- parse inputs ----------------
ip = inputParser;
ip.addRequired('sessionDir', @(x) ischar(x) || isstring(x));
ip.addParameter('csvSuffix', '_corrected', @(x) ischar(x) || isstring(x));
ip.addParameter('force',     false, @(x) islogical(x) && isscalar(x));
ip.addParameter('fitMode',   'full', @(x) ischar(x) || isstring(x));
ip.addParameter('rebuild',   'auto', @(x) any(strcmpi(char(x), ...
    {'auto', 'always', 'never'})));
ip.parse(sessionDir, varargin{:});
sessionDir = char(ip.Results.sessionDir);
csvSuffix  = char(ip.Results.csvSuffix);
force      = ip.Results.force;
fitMode    = char(ip.Results.fitMode);
rebuildOpt = lower(char(ip.Results.rebuild));

assert(isfolder(sessionDir), ...
    'correctBarsweepRFCenters: %s is not a folder.', sessionDir);

% supportFunctions must be on the path for reconstructBarsweepRF.
if isempty(which('reconstructBarsweepRF'))
    addpath(fileparts(mfilename('fullpath')));
end

%% ---------------- load rig geometry ----------------
% p.mat is written by pds.saveP with '-struct', so p's substructs are
% top-level variables in the file.
pMatPath = fullfile(sessionDir, 'p.mat');
assert(exist(pMatPath, 'file') == 2, ...
    ['correctBarsweepRFCenters: no p.mat in %s. Rig geometry ' ...
     '(viewdist/screenh/screenhpix) is NOT strobed and exists only here; ' ...
     'the correction cannot proceed without it.'], sessionDir);
S = load(pMatPath, 'rig', 'draw', 'trVars', 'init');
assert(isfield(S, 'rig') && all(isfield(S.rig, ...
    {'viewdist', 'screenhpix', 'screenh'})), ...
    'correctBarsweepRFCenters: p.mat lacks p.rig geometry fields.');
rigK = S.rig.viewdist * S.rig.screenhpix / S.rig.screenh;

%% ---------------- provenance guard ----------------
% The fixed nextParams.m stamps p.trVars.sweepGeometryVersion. Sessions
% predating the fix have no such field. Refuse post-fix sessions unless
% forced, so this can't be applied twice or to clean data.
geomVersion = 1;
if isfield(S, 'trVars') && isfield(S.trVars, 'sweepGeometryVersion') && ...
        ~isempty(S.trVars.sweepGeometryVersion)
    geomVersion = S.trVars.sweepGeometryVersion;
end
if geomVersion >= 2 && ~force
    error('correctBarsweepRFCenters:notAffected', ...
        ['Session %s reports sweepGeometryVersion = %d, i.e. it was ' ...
         'collected AFTER the nextParams.m geometry fix and needs no ' ...
         'correction. Pass ''force'', true to override.'], ...
        sessionDir, geomVersion);
end

%% ---------------- load the RF accumulator sidecar ----------------
sc = dir(fullfile(sessionDir, '*_barsweepRF.mat'));
assert(~isempty(sc), ...
    ['correctBarsweepRFCenters: no *_barsweepRF.mat sidecar in %s. ' ...
     'Use rebuildBarsweepRFFromTrials to regenerate one from trial####.mat ' ...
     'first.'], sessionDir);
if numel(sc) > 1
    [~, newest] = max([sc.datenum]);
    warning('correctBarsweepRFCenters:multipleSidecars', ...
        '%d sidecars found in %s; using the newest (%s).', ...
        numel(sc), sessionDir, sc(newest).name);
    sc = sc(newest);
end
L  = load(fullfile(sessionDir, sc.name), 'barsweepRF');
assert(isfield(L, 'barsweepRF'), ...
    'correctBarsweepRFCenters: %s has no barsweepRF variable.', sc.name);
rf = L.barsweepRF;
assert(isfield(rf, 'enabled') && rf.enabled, ...
    'correctBarsweepRFCenters: accumulator in %s is not enabled.', sc.name);

%% ---------------- accumulator-format compatibility ----------------
% reconstructBarsweepRF's cardinal4 branch implements the v2 midpoint
% method and indexes spikeHist by DIRECTION (4 rows). Sessions collected
% before that change stored 2 orientation rows and carry no accumBy /
% formatVersion field, so reconstruction would fail with an opaque
% out-of-bounds index. Detect and re-accumulate from the trial files,
% which retain everything the current accumulator needs.
[compatible, whyNot] = accumulatorIsCompatible(rf);
doRebuild = strcmp(rebuildOpt, 'always') || ...
    (strcmp(rebuildOpt, 'auto') && ~compatible);

if ~compatible && strcmp(rebuildOpt, 'never')
    error('correctBarsweepRFCenters:legacyAccumulator', ...
        ['Sidecar %s is not readable by the current reconstructBarsweepRF: %s\n' ...
         'Re-accumulate from trial####.mat by passing ''rebuild'', ''auto''.'], ...
        sc.name, whyNot);
end

if doRebuild
    if ~compatible
        fprintf('  legacy accumulator detected (%s)\n', whyNot);
        fprintf(['  NOTE: rebuilding also switches this session from the v1 ' ...
                 'assumed-latency method to the\n        v2 opposite-direction ' ...
                 'midpoint method. Centres and spike totals will differ\n' ...
                 '        slightly from the online sidecar for that reason ' ...
                 'alone, independent of the\n        geometry correction.\n']);
    end
    fprintf('  re-accumulating from trial####.mat ...\n');
    drawIn = [];
    if isfield(S, 'draw'), drawIn = S.draw; end
    rf = rebuildAccumulatorFromTrials(sessionDir, drawIn, rf);
    [compatible, whyNot] = accumulatorIsCompatible(rf);
    assert(compatible, ...
        ['correctBarsweepRFCenters: rebuilt accumulator is still ' ...
         'incompatible (%s). This is a bug.'], whyNot);
end

pathCenter    = rf.pathCenterDeg(:).';        % [xOff, yOff], dva
pathLengthDeg = rf.pathLengthDeg;

%% ---------------- report the true sweep geometry ----------------
% Endpoint of the sweep axis is +/- pathLengthDeg/2 in the pre-fix units.
halfEnds  = barsweepSweepAxisToDeg([-1 1] * pathLengthDeg / 2, ...
    pathCenter(1), pathLengthDeg, rigK);
halfEndsY = barsweepSweepAxisToDeg([-1 1] * pathLengthDeg / 2, ...
    pathCenter(2), pathLengthDeg, rigK);

fprintf('correctBarsweepRFCenters: %s\n', sessionDir);
fprintf('  rig k = %.2f px/unit-tangent | pathCenter = [%.2f %.2f] | pathLength = %.2f deg\n', ...
    rigK, pathCenter(1), pathCenter(2), pathLengthDeg);
fprintf('  azimuth   sweep actually spanned %.2f to %.2f deg (nominal %.2f to %.2f)\n', ...
    halfEnds(1), halfEnds(2), pathCenter(1) - pathLengthDeg/2, ...
    pathCenter(1) + pathLengthDeg/2);
fprintf('  elevation sweep actually spanned %.2f to %.2f deg (nominal %.2f to %.2f)\n', ...
    halfEndsY(1), halfEndsY(2), pathCenter(2) - pathLengthDeg/2, ...
    pathCenter(2) + pathLengthDeg/2);

% On-screen coverage limits. accumulateBarsweepRF dropped frames whose bar
% centre left screenRect, so positions beyond these were never sampled.
covX = [-Inf Inf];
covY = [-Inf Inf];
if isfield(S, 'draw') && isfield(S.draw, 'screenRect') && ...
        ~isempty(S.draw.screenRect) && isfield(S.draw, 'middleXY')
    sR  = S.draw.screenRect;
    mid = S.draw.middleXY;
    covX = sort(atand(([sR(1) sR(3)] - mid(1)) / rigK));
    % pixel y is down, dva y is up.
    covY = sort(atand((mid(2) - [sR(2) sR(4)]) / rigK));
    fprintf('  on-screen coverage: azimuth [%.2f %.2f] deg, elevation [%.2f %.2f] deg\n', ...
        covX(1), covX(2), covY(1), covY(2));
    if halfEnds(1) < covX(1) || halfEnds(2) > covX(2) || ...
            halfEndsY(1) < covY(1) || halfEndsY(2) > covY(2)
        fprintf(['  NOTE: part of the sweep ran off-screen and was excluded ' ...
                 'from accumulation. Channels near the coverage edge are ' ...
                 'flagged outsideCoverage in the output.\n']);
    end
end

%% ---------------- per-channel reconstruction + correction ----------------
nCh       = rf.nChannels;
reconOpts = struct('fitMode', fitMode);

channel     = (1:nCh)';
xRaw        = nan(nCh, 1);   yRaw        = nan(nCh, 1);
xCorr       = nan(nCh, 1);   yCorr       = nan(nCh, 1);
sigXRaw     = nan(nCh, 1);   sigYRaw     = nan(nCh, 1);
sigXCorr    = nan(nCh, 1);   sigYCorr    = nan(nCh, 1);
snr         = nan(nCh, 1);   latMs       = nan(nCh, 1);
detected    = false(nCh, 1); outsideCov  = false(nCh, 1);

for ch = 1:nCh
    if rf.spikeCount(ch) < 1
        continue;
    end
    out     = reconstructBarsweepRF(rf, ch, rf.exptType, reconOpts);
    snr(ch) = out.peakStats.snr;
    if isfield(out, 'latencyMs')
        latMs(ch) = out.latencyMs;   % latency needs NO correction
    end
    detected(ch) = out.peakStats.detected;
    if ~detected(ch)
        continue;
    end

    % Path-center-relative centre on the pre-fix sweep axis. cardinal4 uses
    % the opposite-direction midpoint (already averaged in the time-linear
    % coordinate -- see barsweepSweepAxisToDeg for why that ordering
    % matters); rfmap12 uses the moment fit of the iradon image.
    switch rf.exptType
        case 'barsweep_cardinal4'
            sX = out.xCenter;
            sY = out.yCenter;
        case 'barsweep_rfmap12'
            sX = out.gaussFit.x0;
            sY = out.gaussFit.y0;
        otherwise
            error('correctBarsweepRFCenters:exptType', ...
                'Unknown exptType "%s".', rf.exptType);
    end

    % Raw = what the online export reported (path centre simply added back).
    xRaw(ch) = sX + pathCenter(1);
    yRaw(ch) = sY + pathCenter(2);

    % Corrected = the same sweep-axis position relabelled to true dva.
    [xCorr(ch), jx] = barsweepSweepAxisToDeg(sX, pathCenter(1), pathLengthDeg, rigK);
    [yCorr(ch), jy] = barsweepSweepAxisToDeg(sY, pathCenter(2), pathLengthDeg, rigK);

    % RF size: sweep-axis sigma scaled by the local derivative.
    if isfield(out, 'gaussFit') && isstruct(out.gaussFit)
        if isfield(out.gaussFit, 'sigmaX'), sigXRaw(ch) = out.gaussFit.sigmaX; end
        if isfield(out.gaussFit, 'sigmaY'), sigYRaw(ch) = out.gaussFit.sigmaY; end
    end
    sigXCorr(ch) = sigXRaw(ch) * jx;
    sigYCorr(ch) = sigYRaw(ch) * jy;

    outsideCov(ch) = xCorr(ch) < covX(1) || xCorr(ch) > covX(2) || ...
                     yCorr(ch) < covY(1) || yCorr(ch) > covY(2);
end

T = table(channel, xRaw, yRaw, xCorr, yCorr, ...
    xCorr - xRaw, yCorr - yRaw, ...
    sigXRaw, sigYRaw, sigXCorr, sigYCorr, ...
    snr, latMs, detected, outsideCov, ...
    'VariableNames', {'channel', 'x_raw_deg', 'y_raw_deg', ...
    'x_corr_deg', 'y_corr_deg', 'dx_deg', 'dy_deg', ...
    'sigmaX_raw_deg', 'sigmaY_raw_deg', 'sigmaX_corr_deg', 'sigmaY_corr_deg', ...
    'snr', 'latency_ms', 'detected', 'outsideCoverage'});

%% ---------------- write CSV ----------------
[~, sessionId] = fileparts(sessionDir);
csvPath = fullfile(sessionDir, ...
    sprintf('rfCenters_%s_final%s.csv', sessionId, csvSuffix));
writetable(T, csvPath);

nDet = nnz(detected);
if nDet > 0
    fprintf(['  %d/%d channels detected | median |shift| = [%.3f %.3f] deg, ' ...
             'max |shift| = [%.3f %.3f] deg\n'], ...
        nDet, nCh, ...
        median(abs(T.dx_deg(detected)), 'omitnan'), ...
        median(abs(T.dy_deg(detected)), 'omitnan'), ...
        max(abs(T.dx_deg(detected))), max(abs(T.dy_deg(detected))));
    if any(outsideCov)
        fprintf('  WARNING: %d detected channel(s) sit outside the sampled coverage.\n', ...
            nnz(outsideCov & detected));
    end
else
    fprintf('  no channels detected.\n');
end
fprintf('  -> %s\n', csvPath);

end

%% ===================== helpers =====================

function [ok, why] = accumulatorIsCompatible(rf)
% Can the current reconstructBarsweepRF read this accumulator?
%
% cardinal4 (v2) requires per-DIRECTION rows because the midpoint method
% needs the 0/180 and 90/270 profiles separately. rfmap12 pools opposite
% directions and has always been keyed by orientation.
ok  = true;
why = '';
switch rf.exptType
    case 'barsweep_cardinal4'
        nWant = numel(rf.directionsRad);
        if ~isfield(rf, 'accumBy') || ~strcmp(rf.accumBy, 'direction')
            ok  = false;
            why = sprintf(['accumBy is "%s" but cardinal4 reconstruction ' ...
                'requires per-direction accumulation'], ...
                getfielddef(rf, 'accumBy', '<absent>'));
        elseif size(rf.spikeHist, 1) ~= nWant
            ok  = false;
            why = sprintf('spikeHist has %d rows, expected %d (one per direction)', ...
                size(rf.spikeHist, 1), nWant);
        end
    case 'barsweep_rfmap12'
        nWant = numel(rf.orientationsRad);
        if size(rf.spikeHist, 1) ~= nWant
            ok  = false;
            why = sprintf('spikeHist has %d rows, expected %d (one per orientation)', ...
                size(rf.spikeHist, 1), nWant);
        end
    otherwise
        ok  = false;
        why = sprintf('unknown exptType "%s"', rf.exptType);
end
end

function v = getfielddef(s, f, d)
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end

function rf = rebuildAccumulatorFromTrials(sessionDir, draw, rfRef)
% Re-accumulate a session from its trial####.mat files through the CURRENT
% accumulator, yielding an rf in today's format.
%
% Trials whose spatial knobs differ from the reference sidecar are SKIPPED.
% p.init.barsweepRF is reset mid-session whenever a spatial knob changes
% (barsweep_finish.m step 1b), so a session can contain trials from more
% than one geometry; blindly replaying all of them would silently mix
% coordinate systems. The sidecar snapshot describes the last regime, so
% that is the one we reproduce.
%
% Note this replays the trials' SAVED sweepCenterDegByFrame, i.e. the
% pre-fix sweep axis -- which is exactly what the caller then corrects.

all_ = dir(fullfile(sessionDir, 'trial*.mat'));
keep = ~cellfun('isempty', regexp({all_.name}, '^trial\d+\.mat$', 'once'));
trialFiles = all_(keep);
assert(~isempty(trialFiles), ...
    'correctBarsweepRFCenters: no trial####.mat in %s to rebuild from.', ...
    sessionDir);
[~, ord] = sort({trialFiles.name});
trialFiles = trialFiles(ord);

refGeom = [rfRef.pathCenterDeg(:).', rfRef.pathLengthDeg, ...
    rfRef.barWidthDeg, rfRef.rfPosBinDeg, rfRef.nChannels];

rf      = [];
nUsed   = 0;
nSkip   = 0;
for kk = 1:numel(trialFiles)
    T = load(fullfile(sessionDir, trialFiles(kk).name));
    if ~all(isfield(T, {'trVars', 'trData', 'status', 'init'}))
        nSkip = nSkip + 1;
        continue;
    end
    g = [T.trVars.pathCenterXDeg, T.trVars.pathCenterYDeg, ...
         T.trVars.pathLengthDeg,  T.trVars.barWidthDeg, ...
         T.trVars.rfPosBinDeg,    T.trVars.rfNChannels];
    if numel(g) ~= numel(refGeom) || ~all(abs(g - refGeom) < 1e-9)
        nSkip = nSkip + 1;
        continue;
    end

    if isempty(rf)
        % Allocate from the first matching trial, in the current format.
        pInit = struct('init', T.init, 'trVars', T.trVars);
        pInit.init.barsweepRF = struct();     % force re-allocation
        pInit = initBarsweepRF(pInit);
        rf = pInit.init.barsweepRF;
    end
    rf = replayBarsweepRF(struct('trVars', T.trVars, 'trData', T.trData, ...
        'status', T.status, 'init', T.init), rf, draw);
    nUsed = nUsed + 1;
end

assert(~isempty(rf), ...
    ['correctBarsweepRFCenters: no trial file matched the sidecar geometry ' ...
     '[cx cy L barW posBin nCh] = %s; cannot rebuild.'], mat2str(refGeom));

fprintf('  rebuilt from %d trial(s)', nUsed);
if nSkip > 0
    fprintf(', skipped %d with mismatched geometry', nSkip);
end
fprintf(' | %d spikes across %d channel(s)\n', ...
    sum(rf.spikeCount), nnz(rf.spikeCount));
end
