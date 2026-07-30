function p = initBarsweepRF(p)
% p = initBarsweepRF(p)
%
% Allocate / re-allocate the online RF-mapping accumulators used by the
% barsweep task. Called once from barsweep_init.m on the initial setup,
% and again from barsweep_finish.m whenever a spatial knob change forces
% a coordinate-system reset (see plan §1 "Mid-session parameter changes").
%
% Reads from p.trVarsInit on first call and from p.trVars on subsequent
% calls so mid-session GUI edits to spatial knobs are honored. Both flow
% through trVarsGuiComm; on the very first call (before any _next.m has
% run), p.trVars may be absent OR partially seeded by upstream +pds
% helpers (pds.initRigConfigFile sets p.trVars.rewardDurationMs from the
% rig's baseReward), so we sentinel on a task-specific field that's only
% present once p.trVars has been wholesale-populated from trVarsGuiComm.
%
% Allocates:
%   p.init.barsweepRF.spikeHist        [nOri x nPosBins x nCh]
%   p.init.barsweepRF.dwellTime        [nOri x nPosBins]   (seconds)
%   p.init.barsweepRF.spikeCount       [nCh x 1]
%   p.init.barsweepRF.trialsByDirection [nDir x 1]
%   p.init.barsweepRF.positionEdges    1 x (nPosBins+1)
%   p.init.barsweepRF.positionCenters  1 x nPosBins
% plus snapshots of the spatial knobs that drive the accumulator extent.
%
% Preserves figData, browser, and resetCount across resets so the
% figure handles stay alive and the on-disk versioned sidecar names
% monotonically increment.

% Read live params if p.trVars has been wholesale-populated (sentinel on
% pathLengthDeg, a task-specific spatial knob). Otherwise fall back to
% p.trVarsInit — covers both the "p.trVars absent" and the "p.trVars
% partial seed from pds.initRigConfigFile" cases at first call.
if isfield(p, 'trVars') && isfield(p.trVars, 'pathLengthDeg')
    src = p.trVars;
else
    src = p.trVarsInit;
end

% Preserve handles and resetCount across resets.
priorFig     = [];
priorBrowser = [];
priorReset   = 0;
if isfield(p.init, 'barsweepRF') && isstruct(p.init.barsweepRF)
    if isfield(p.init.barsweepRF, 'figData')
        priorFig = p.init.barsweepRF.figData;
    end
    if isfield(p.init.barsweepRF, 'browser')
        priorBrowser = p.init.barsweepRF.browser;
    end
    if isfield(p.init.barsweepRF, 'resetCount') && ...
            ~isempty(p.init.barsweepRF.resetCount)
        priorReset = p.init.barsweepRF.resetCount;
    end
end

%% Regime-driven orientation/direction lists.
switch p.init.exptType
    case 'barsweep_cardinal4'
        directionsDeg    = [0 90 180 270];
        orientationsDeg  = [0 90];
        % v2 midpoint method: accumulate BY DIRECTION (0/90/180/270 each
        % get their own histogram row) so opposite sweeps are NOT pooled.
        % The RF center is then the midpoint of opposite-direction peaks,
        % which cancels response latency without assuming it. Contrast
        % rfmap12 below, which still pools opposite directions by
        % orientation for filtered back-projection.
        accumBy          = 'direction';
    case 'barsweep_rfmap12'
        directionsDeg    = 0:30:330;
        orientationsDeg  = 0:30:150;
        % Unchanged: iradon reconstruction pools opposite directions into
        % one orientation row (each row is a sinogram projection).
        accumBy          = 'orientation';
    otherwise
        error('initBarsweepRF: unknown exptType "%s".', p.init.exptType);
end

% Number of histogram rows = directions (cardinal4) or orientations
% (rfmap12). This is the ONLY structural difference between the regimes'
% accumulators.
if strcmp(accumBy, 'direction')
    nAccum = numel(directionsDeg);
else
    nAccum = numel(orientationsDeg);
end

%% Position edges: span the sweep with a small accum margin, in
% path-center-relative dva. Spans pathLengthDeg/2 + barWidthDeg/2 so the
% bar's center never falls outside the histogram even at the very ends.
accumMarginDeg = 1.0;
halfL = src.pathLengthDeg / 2 + src.barWidthDeg / 2 + accumMarginDeg;
positionEdges = -halfL : src.rfPosBinDeg : halfL;
% discretize() requires monotonically increasing edges; the above is fine
% but guard against pathological cases (rfPosBinDeg too large).
assert(numel(positionEdges) >= 3, ...
    'initBarsweepRF: derived positionEdges has too few bins (rfPosBinDeg=%g, halfL=%g).', ...
    src.rfPosBinDeg, halfL);
positionCenters = 0.5 * (positionEdges(1:end-1) + positionEdges(2:end));

nPosBins = numel(positionCenters);
nOri     = numel(orientationsDeg);
nDir     = numel(directionsDeg);
nCh      = src.rfNChannels;

%% Pack the struct (preserve fig + resetCount if present).
rf.enabled            = true;
rf.exptType           = p.init.exptType;
rf.accumBy            = accumBy;      % 'direction' (cardinal4) | 'orientation' (rfmap12)
rf.formatVersion      = 2;           % v2 = per-direction midpoint method (cardinal4)
rf.nChannels          = nCh;
rf.orientationsRad    = deg2rad(orientationsDeg);
rf.directionsRad      = deg2rad(directionsDeg);
rf.pathLengthDeg      = src.pathLengthDeg;
rf.barWidthDeg        = src.barWidthDeg;
rf.accumMarginDeg     = accumMarginDeg;
rf.rfPosBinDeg        = src.rfPosBinDeg;
rf.positionEdges      = positionEdges;
rf.positionCenters    = positionCenters;
rf.pathCenterDeg      = [src.pathCenterXDeg; src.pathCenterYDeg];
rf.mapExtentDeg       = src.rfMapExtentDeg;
rf.mapPixelDeg        = src.rfPosBinDeg;
rf.latencyMs          = src.rfLatencyMs;   % rfmap12 only in v2 (cardinal4 needs no assumed latency)
% Sweep speed snapshot: cardinal4 reads it back to convert the
% opposite-direction peak separation into a latency estimate (dva / (dva/s)
% = s). Guarded for the synthetic test harness, which may not set it.
if isfield(src, 'speedDegPerSec') && ~isempty(src.speedDegPerSec)
    rf.speedDegPerSec = src.speedDegPerSec;
else
    rf.speedDegPerSec = NaN;
end
rf.rampFilter         = src.rfRampFilter;
rf.rampCutoff         = src.rfRampCutoff;
rf.spikeHist          = zeros(nAccum, nPosBins, nCh);
rf.dwellTime          = zeros(nAccum, nPosBins);
rf.spikeCount         = zeros(nCh, 1);
rf.trialsByDirection  = zeros(nDir, 1);
rf.resetCount         = priorReset;
rf.figData            = priorFig;
rf.browser            = priorBrowser;
rf.lastUpdateTrial    = 0;
rf.bannerNextTrial    = '';

p.init.barsweepRF = rf;

end
