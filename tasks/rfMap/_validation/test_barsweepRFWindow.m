function test_barsweepRFWindow()
% test_barsweepRFWindow  Offline tests for the Phase-4 barsweep -> rfMap
% RF-restricted STA window (importBarsweepRFWindow, barsweepWindowToGridPix,
% occludedCheckMask under a displaced grid, two-word frame strobes).
%
% No hardware. Run from anywhere:  test_barsweepRFWindow
% Exits with an error on the first failed assertion.

here = fileparts(mfilename('fullpath'));
repo = fileparts(fileparts(fileparts(here)));
addpath(repo, fullfile(here, '..', 'supportFunctions'));
tmp = tempname; mkdir(tmp); cleanup = onCleanup(@() rmdir(tmp, 's'));

p = baseP();
nPass = 0;

%% 1. No CSV -> inactive, silent
w = importBarsweepRFWindow(p);
check(~w.active && strcmp(w.reason, 'no barsweepRFCsv set'), '1 no-CSV inactive');
nPass = nPass + 1;

%% 2. Real session (corrected CSV, 20260814_t1207)
realCsv = fullfile(repo, 'output', '20260814_t1207_barsweep', ...
    'rfCenters_20260814_t1207_barsweep_final_corrected.csv');
if exist(realCsv, 'file')
    p.trVarsInit.barsweepRFCsv = realCsv;
    w = importBarsweepRFWindow(p);
    T = readtable(realCsv);
    nAbove = sum(T.snr >= 4 & isfinite(T.x_corr_deg));
    check(w.active, '2 real CSV active');
    check(w.nChannelsAboveThresh == nAbove, '2 used corrected columns');
    fprintf(['  real 20260814: %d/%d ch kept -> center [%.2f %.2f], ' ...
             '%.2f x %.2f dva, containsFixation=%d, ch=%s\n'], ...
        w.nChannelsUsed, w.nChannelsAboveThresh, w.centerDeg, ...
        w.widthDeg, w.heightDeg, w.containsFixation, mat2str(w.channelsUsed));
    % These RFs are within ~3 dva of fixation, so the window must keep the
    % clearing patch + mask.
    check(w.containsFixation, '2 near-foveal cluster flags fixation');
    nPass = nPass + 1;

    %% 3. Directory resolution (output root -> one level down)
    p.trVarsInit.barsweepRFCsv = fullfile(repo, 'output');
    w3 = importBarsweepRFWindow(p);
    check(w3.active && ~isempty(w3.csvPath), '3 directory resolves a CSV');
    nPass = nPass + 1;
else
    fprintf('  (skipping 2-3: %s not present)\n', realCsv);
end

%% 4. 2026-06-08-like cluster + eccentric outliers
rng(1);
x = [-8.9 + 2*randn(12,1); -25; -24; 6];
y = [-0.4 + 0.6*randn(12,1); 9; -8; 7];
snr = [5 + rand(12,1); 6; 6; 6];
f4 = writeCsv(tmp, 'c4.csv', x, y, snr);
p.trVarsInit.barsweepRFCsv = f4;
w = importBarsweepRFWindow(p);
check(w.active, '4 active');
check(~any(ismember([13 14 15], w.channelsUsed)), '4 outliers trimmed');
check(w.widthDeg <= 12 && w.widthDeg >= 3 && w.heightDeg >= 3, '4 size clamped');
check(~w.containsFixation, '4 window clear of fixation');
check(abs(w.centerDeg(1) + 8.9) < 2, '4 center near cluster');
fprintf('  synthetic: %d kept, center [%.2f %.2f], %.2f x %.2f dva\n', ...
    w.nChannelsUsed, w.centerDeg, w.widthDeg, w.heightDeg);
nPass = nPass + 1;

%% 5. Low-SNR channels ignored
f5 = writeCsv(tmp, 'c5.csv', [x; 0; 0], [y; 0; 0], [snr; 3.9; 1]);
p.trVarsInit.barsweepRFCsv = f5;
w5 = importBarsweepRFWindow(p);
check(isequal(w5.channelsUsed, w.channelsUsed), '5 snr<thresh ignored');
nPass = nPass + 1;

%% 6. MAD == 0 (two identical centers) -> min-size window, never zero width
f6 = writeCsv(tmp, 'c6.csv', [-6; -6], [2; 2], [5; 5]);
p.trVarsInit.barsweepRFCsv = f6;
w = importBarsweepRFWindow(p);
check(w.active && w.widthDeg == 3 && w.heightDeg == 3, '6 MAD=0 -> min size');
nPass = nPass + 1;

%% 7. Too few channels / bad file / missing columns -> inactive with warning
f7 = writeCsv(tmp, 'c7.csv', -6, 2, 5);
p.trVarsInit.barsweepRFCsv = f7;
ws = warning('off', 'rfMap:barsweepWindow:fallback');
w = importBarsweepRFWindow(p);
check(~w.active, '7a single channel inactive');
p.trVarsInit.barsweepRFCsv = fullfile(tmp, 'nope.csv');
w = importBarsweepRFWindow(p);
check(~w.active, '7b missing file inactive');
fid = fopen(fullfile(tmp, 'c7c.csv'), 'w'); fprintf(fid, 'a,b\n1,2\n'); fclose(fid);
p.trVarsInit.barsweepRFCsv = fullfile(tmp, 'c7c.csv');
w = importBarsweepRFWindow(p);
check(~w.active, '7c wrong columns inactive');
warning(ws);
nPass = nPass + 1;

%% 8. Pixel placement is tangent-correct (edges land at the right dva)
win = struct('centerDeg', [-8.9 -0.4], 'widthDeg', 10, 'heightDeg', 4);
for fixX = [0 2]
    p.trVarsInit.fixDegX = fixX;
    g = barsweepWindowToGridPix(p, win, pds.deg2pix(1, p));
    check(g.ok, '8 placed');
    edgesDeg = pds.pix2deg(g.xEdgePix - p.draw.middleXY(1), p) - fixX;
    topBot   = pds.pix2deg(p.draw.middleXY(2) - g.yEdgePix, p);
    check(max(abs(edgesDeg - [-13.9 -3.9])) < 0.05, '8 x edges');
    check(max(abs(topBot - [1.6 -2.4])) < 0.05, '8 y edges');
    % The naive (buggy) width would be deg2pix(10); it must differ here.
    fprintf('  fix=%g: width %.0f px (naive deg2pix(10) = %d px)\n', ...
        fixX, g.widthPix, pds.deg2pix(10, p));
end
p.trVarsInit.fixDegX = 0;
winOff = struct('centerDeg', [60 0], 'widthDeg', 4, 'heightDeg', 4);
g = barsweepWindowToGridPix(p, winOff, 28);
check(~g.ok, '8 off-screen rejected');
nPass = nPass + 1;

%% 9. occludedCheckMask follows the grid center
p.trVars = p.trVarsInit;
p.trVars.checkSizeDeg = 1; p.trVars.clearPatchDeg = 1;
ck = pds.deg2pix(1, p);
% (a) left-hemifield grid: occluded checks must sit at fixation, i.e. at
% the grid's right edge -- the old code put them at the grid center.
p.init.noiseGridSize = [ceil(1200/ck), ceil(960/ck)];
p.init.noiseGridCenterPix = [480, 600];
m = occludedCheckMask(p);
[r, c] = find(m);
check(~isempty(c) && all(c >= p.init.noiseGridSize(2) - 1), '9a hemifield mask at fixation edge');
% (b) window clear of fixation, patch on: nothing to mask
p.init.noiseGridSize = [6 12];
p.init.noiseGridCenterPix = [p.draw.middleXY(1) + pds.deg2pix(-8.9, p), p.draw.middleXY(2)];
check(~any(occludedCheckMask(p), 'all'), '9b displaced window -> no mask');
% (c) clearPatchDeg = 0 -> all false
p.init.noiseGridSize = [10 10]; p.init.noiseGridCenterPix = p.draw.middleXY;
p.trVars.clearPatchDeg = 0;
check(~any(occludedCheckMask(p), 'all'), '9c no patch -> no mask');
% (d) centered full grid unchanged vs the old formula
p.trVars.clearPatchDeg = 1;
check(nnz(occludedCheckMask(p)) == nnz(oldMask(p)), '9d centered grid matches old mask');
nPass = nPass + 1;

%% 10. Two-word frame strobes reconstruct > 32767
for v = [1 32767 32768 60000 98303]
    lo = mod(v, 32768); hi = floor(v / 32768);
    check(lo <= 32767 && hi <= 32767 && lo + 32768*hi == v, '10 strobe split');
end
codes = pds.initCodes;
need = {'rfMapTrialFrameStartHigh','rfMapTrialFrameEndHigh','rfMapTotalFramesHigh', ...
    'rfMapGridSource','rfMapGridCenterTheta_x10','rfMapGridCenterRadius_x100'};
check(all(isfield(codes, need)), '10 codes exist');
vals = struct2array(codes);
check(numel(unique(vals)) == numel(vals), '10 codes unique');
nPass = nPass + 1;

fprintf('test_barsweepRFWindow: all %d blocks passed.\n', nPass);
end

%% ---- helpers ----
function p = baseP()
p.rig.viewdist = 410; p.rig.screenhpix = 1200; p.rig.screenh = 302.4;
p.draw.screenRect = [0 0 1920 1200];
p.draw.middleXY = [960 600];
p.trVarsInit = struct('barsweepRFCsv', '', 'fixDegX', 0, 'fixDegY', 0, ...
    'rfWindowSnrThresh', 4.0, 'rfWindowKmad', 2.0, 'rfWindowPadDeg', 1.5, ...
    'rfWindowMinDeg', 3, 'rfWindowMaxDeg', 12, 'rfWindowFixMarginDeg', 1.0, ...
    'rfWindowMinChannels', 2);
p.init = struct();
end

function f = writeCsv(d, name, x, y, snr)
f = fullfile(d, name);
writetable(table((1:numel(x)).', x(:), y(:), snr(:), nan(numel(x),1), ...
    'VariableNames', {'channel','x_deg','y_deg','snr','latency_ms'}), f);
end

function m = oldMask(p)
nY = p.init.noiseGridSize(1); nX = p.init.noiseGridSize(2); d = p.trVars.checkSizeDeg;
[CX, CY] = meshgrid(((1:nX) - 0.5 - nX/2) * d, -(((1:nY) - 0.5 - nY/2) * d));
m = hypot(CX, CY) <= p.trVars.clearPatchDeg/2 + d/2;
end

function check(c, msg)
if ~c, error('test_barsweepRFWindow:fail', 'FAILED: %s', msg); end
end
