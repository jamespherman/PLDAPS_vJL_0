function win = importBarsweepRFWindow(p)
% importBarsweepRFWindow  Build the RF-restricted STA noise window from a
% barsweep RF-centers CSV (LGN battery redesign, Phase 4).
%
%   win = importBarsweepRFWindow(p)
%
%   Reads p.trVarsInit.barsweepRFCsv, which may be:
%     - ''                  -> inactive (no window; current full/hemifield path)
%     - a .csv file path    -> that file
%     - a directory         -> newest rfCenters_*_final*.csv in it or in any
%                              immediate subdirectory (a session folder or the
%                              output root both work). Within one session
%                              folder a *_final_corrected.csv beats *_final.csv.
%
%   Accepted CSV schemas:
%     exportBarsweepRFCentersCSV:  channel,x_deg,y_deg,snr[,latency_ms]
%     correctBarsweepRFCenters:    channel,x_corr_deg,y_corr_deg,...,snr,...
%   The corrected columns are preferred when present (true visual angle for
%   sessions recorded before the sweep-geometry fix, cb4170fd). Centers are
%   fixation-relative dva.
%
%   Window construction (robust trimmed union):
%     1. keep channels with snr >= rfWindowSnrThresh and finite centers
%     2. per axis keep |v - median| <= rfWindowKmad * 1.4826*MAD
%        (MAD == 0 -> keep all on that axis)
%     3. padded bounding box (+rfWindowPadDeg each side), each side length
%        clamped to [rfWindowMinDeg, rfWindowMaxDeg] about the box center
%     4. containsFixation = fixation lies within the box grown by
%        rfWindowFixMarginDeg (then the clearing patch + mask are kept)
%   Fewer than rfWindowMinChannels surviving channels -> inactive (warn).
%
%   Output struct (always has .active):
%     active, reason, csvPath, centerDeg [x y], widthDeg, heightDeg,
%     containsFixation, nChannelsUsed, channelsUsed, nChannelsAboveThresh
%   centerDeg/width/height are fixation-relative dva. Pixel placement is
%   done by the caller (rfMap_init) with tangent-correct edge conversion.

win = struct('active', false, 'reason', '', 'csvPath', '', ...
    'centerDeg', [NaN NaN], 'widthDeg', NaN, 'heightDeg', NaN, ...
    'containsFixation', false, 'nChannelsUsed', 0, 'channelsUsed', [], ...
    'nChannelsAboveThresh', 0);

src = getdef(p.trVarsInit, 'barsweepRFCsv', '');
if isstring(src), src = char(src); end
if isempty(src)
    win.reason = 'no barsweepRFCsv set';
    return;
end

csvPath = resolveCsv(src);
if isempty(csvPath)
    win.reason = sprintf('no rfCenters_*_final*.csv found at "%s"', src);
    warnFallback(win.reason);
    return;
end
win.csvPath = csvPath;

try
    T = readtable(csvPath);
catch err
    win.reason = sprintf('could not read "%s": %s', csvPath, err.message);
    warnFallback(win.reason);
    return;
end

vn = T.Properties.VariableNames;
if all(ismember({'x_corr_deg', 'y_corr_deg'}, vn))
    x = T.x_corr_deg;  y = T.y_corr_deg;
elseif all(ismember({'x_deg', 'y_deg'}, vn))
    x = T.x_deg;       y = T.y_deg;
else
    win.reason = sprintf('"%s" has no x_deg/y_deg (or x_corr_deg/y_corr_deg) columns', csvPath);
    warnFallback(win.reason);
    return;
end
if ~ismember('snr', vn)
    win.reason = sprintf('"%s" has no snr column', csvPath);
    warnFallback(win.reason);
    return;
end
snr = T.snr;
if ismember('channel', vn), ch = T.channel; else, ch = (1:height(T)).'; end

thr   = getdef(p.trVarsInit, 'rfWindowSnrThresh', 4.0);
kmad  = getdef(p.trVarsInit, 'rfWindowKmad', 2.0);
pad   = getdef(p.trVarsInit, 'rfWindowPadDeg', 1.5);
minD  = getdef(p.trVarsInit, 'rfWindowMinDeg', 3);
maxD  = getdef(p.trVarsInit, 'rfWindowMaxDeg', 12);
marg  = getdef(p.trVarsInit, 'rfWindowFixMarginDeg', 1.0);
minCh = getdef(p.trVarsInit, 'rfWindowMinChannels', 2);

keep = snr >= thr & isfinite(x) & isfinite(y);
win.nChannelsAboveThresh = sum(keep);
keep = keep & robustKeep(x, keep, kmad) & robustKeep(y, keep, kmad);

if sum(keep) < minCh
    win.reason = sprintf(['only %d channel(s) survive snr>=%.2f + robust trim ' ...
        '(need %d)'], sum(keep), thr, minCh);
    warnFallback(win.reason);
    return;
end

xk = x(keep);  yk = y(keep);
[cx, w] = clampSpan(min(xk) - pad, max(xk) + pad, minD, maxD);
[cy, h] = clampSpan(min(yk) - pad, max(yk) + pad, minD, maxD);

% Fixation sits at the origin of these fixation-relative coordinates.
win.containsFixation = abs(cx) < w/2 + marg && abs(cy) < h/2 + marg;

win.active        = true;
win.reason        = 'ok';
win.centerDeg     = [cx, cy];
win.widthDeg      = w;
win.heightDeg     = h;
win.nChannelsUsed = sum(keep);
win.channelsUsed  = ch(keep).';
end

%% ---- local functions ----

function k = robustKeep(v, base, kmad)
% True where v lies within median +/- kmad * 1.4826*MAD of the base set.
% MAD == 0 (<=2 points, or identical values) keeps the whole base set;
% the min-size clamp then gives the window a sane extent.
k = base;
vb = v(base);
if isempty(vb), return; end
med = median(vb);
s   = 1.4826 * median(abs(vb - med));
if s > 0
    k = base & abs(v - med) <= kmad * s;
end
end

function [c, len] = clampSpan(lo, hi, minLen, maxLen)
c   = (lo + hi) / 2;
len = min(max(hi - lo, minLen), maxLen);
end

function csvPath = resolveCsv(src)
csvPath = '';
if exist(src, 'file') == 2
    csvPath = src;
    return;
end
if exist(src, 'dir') ~= 7, return; end

dirs = {src};
sub  = dir(src);
sub  = sub([sub.isdir] & ~ismember({sub.name}, {'.', '..'}));
dirs = [dirs, fullfile(src, {sub.name})];

best = '';  bestT = -Inf;
for i = 1:numel(dirs)
    f = dir(fullfile(dirs{i}, 'rfCenters_*_final*.csv'));
    if isempty(f), continue; end
    % Within one session folder, the corrected file wins over the raw one.
    isCorr = contains({f.name}, '_final_corrected');
    if any(isCorr), f = f(isCorr); end
    [t, j] = max([f.datenum]);
    if t > bestT
        bestT = t;
        best  = fullfile(dirs{i}, f(j).name);
    end
end
csvPath = best;
end

function warnFallback(msg)
warning('rfMap:barsweepWindow:fallback', ...
    'barsweep RF window inactive (%s); using the default full/hemifield grid.', msg);
end

function v = getdef(s, f, d)
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
