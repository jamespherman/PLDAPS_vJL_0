function p = nextParams(p)
% p = nextParams(p)
%
% Set per-trial parameters for barsweep:
%   - peek the front of p.status.barsweepPool (no mutation here)
%   - validate trVars geometry / luminance / projected texture memory
%   - precompute sweep trajectory (start/end pix, sweepCenterPix,
%     visible vs motion duration, realized speed)
%   - pre-build all bar textures for this trial's sweep
%
% The pool is mutated only in barsweep_finish.m per the plan's schedule
% state-machine table.

%% (1) Peek the next angle from the pool. Snapshot the pool for audit.
assert(~isempty(p.status.barsweepPool), ...
    ['nextParams: barsweepPool is empty entering _next.m. ' ...
     '_finish.m should have re-shuffled it after the prior set ' ...
     'was completed.']);

p.trVars.pathAngleDeg = p.status.barsweepPool(1);
p.trData.pathAngleDeg = p.trVars.pathAngleDeg;

p.status.barsweepPoolAtTrialStart = p.status.barsweepPool;
p.trData.barsweepPoolAtTrialStart = p.status.barsweepPool;

%% (2) Fixation point and window in pixels.
p.draw.fixPointPix = [ ...
    p.draw.middleXY(1) + pds.deg2pix(p.trVars.fixDegX, p), ...
    p.draw.middleXY(2) - pds.deg2pix(p.trVars.fixDegY, p)];
p.draw.fixWinWidthPix  = pds.deg2pix(p.trVars.fixWinWidthDeg,  p);
p.draw.fixWinHeightPix = pds.deg2pix(p.trVars.fixWinHeightDeg, p);

%% (3) Validation guards.
% Luminance contrast.
if p.trVars.stimulusMode == 2
    assert(p.trVars.backgroundLumIdx ~= p.trVars.barLumIdx, ...
        'nextParams: backgroundLumIdx == barLumIdx in solid mode.');
end
assert(p.trVars.noiseLumLowIdx ~= p.trVars.noiseLumHighIdx, ...
    'nextParams: noiseLumLowIdx == noiseLumHighIdx (zero noise contrast).');

% Geometry positivity.
assert(p.trVars.speedDegPerSec > 0, ...
    'nextParams: speedDegPerSec must be > 0.');
assert(p.trVars.pathLengthDeg > 0, ...
    'nextParams: pathLengthDeg must be > 0.');
assert(p.trVars.barWidthDeg > 0, ...
    'nextParams: barWidthDeg must be > 0.');
assert(p.trVars.barLengthDeg > 0, ...
    'nextParams: barLengthDeg must be > 0.');
if p.trVars.stimulusMode == 1
    assert(p.trVars.noiseCheckSizeDeg > 0, ...
        'nextParams: noiseCheckSizeDeg must be > 0 in noise mode.');
end

% setRepeats >= 1 (validates against the live trVars; the frozen value
% in p.init.barsweepSchedule.setRepeats is what the termination rule
% reads, but a non-positive frozen value would be a programmer error).
assert(p.trVars.setRepeats >= 1, ...
    'nextParams: setRepeats must be >= 1.');

%% (4) Sweep trajectory: endpoints in dva, THEN dva -> pix.
% CRITICAL: pds.deg2pix is a tangent (perspective) mapping, not a scale
% factor. deg2pix(a + b) ~= deg2pix(a) + deg2pix(b), and in particular
% 0.5*deg2pix(L) ~= deg2pix(L/2). It is valid ONLY on an absolute
% eccentricity measured from screen centre.
%
% Passing a LENGTH (pathLengthDeg) through it and then doing linear
% arithmetic in pixel space -- as this function did prior to 2026-08-17 --
% stretches the path and displaces its endpoints asymmetrically. For
% pathCenterXDeg = -17, pathLengthDeg = 40 that put the start of a
% leftward sweep at +6.50 deg instead of +3.00 deg and made the path span
% 42.44 deg rather than 40. See
% analysisPlanningDocs/barsweep_geometry_discrepancy_report.md.
%
% So: resolve both endpoints as absolute dva positions first, and only
% then convert each one to pixels.
theta = deg2rad(p.trVars.pathAngleDeg);

dxDeg = 0.5 * p.trVars.pathLengthDeg * cos(theta);
dyDeg = 0.5 * p.trVars.pathLengthDeg * sin(theta);
startDeg = [p.trVars.pathCenterXDeg - dxDeg; p.trVars.pathCenterYDeg - dyDeg];
endDeg   = [p.trVars.pathCenterXDeg + dxDeg; p.trVars.pathCenterYDeg + dyDeg];

% Y-sign convention follows existing PLDAPS tasks (rfMap, fixate, etc.):
% positive Y in dva is up; pixel Y is down.
p.trVars.sweepStartPix = [ ...
    p.draw.middleXY(1) + pds.deg2pix(startDeg(1), p); ...
    p.draw.middleXY(2) - pds.deg2pix(startDeg(2), p)];
p.trVars.sweepEndPix   = [ ...
    p.draw.middleXY(1) + pds.deg2pix(endDeg(1), p); ...
    p.draw.middleXY(2) - pds.deg2pix(endDeg(2), p)];

% Geometry-version stamp, saved per trial via p.trVars. Sessions recorded
% before this fix carry no such field; correctBarsweepRFCenters keys off
% its absence to identify data needing the post-hoc coordinate correction.
p.trVars.sweepGeometryVersion = 2;

%% (5) Quantization contract (visibility vs motion duration).
frameInterval = p.rig.frameDuration;

p.trVars.sweepDurationS_nominal = p.trVars.pathLengthDeg / p.trVars.speedDegPerSec;
sweepFrames = round(p.trVars.sweepDurationS_nominal / frameInterval);
assert(sweepFrames >= 1, ...
    'nextParams: derived sweepFrames < 1 (pathLength / speed / frameInterval = %g). Check speedDegPerSec.', ...
    p.trVars.sweepDurationS_nominal / frameInterval);
assert(sweepFrames <= p.trVars.sweepFramesMax, ...
    sprintf(['nextParams: derived sweepFrames (%d) exceeds sweepFramesMax (%d). ' ...
        'Reduce pathLengthDeg or increase speedDegPerSec.'], ...
        sweepFrames, p.trVars.sweepFramesMax));
p.trVars.sweepFrames           = sweepFrames;
p.trData.sweepFrames           = sweepFrames;

% Visible window (sweepFrames flips on screen).
p.trVars.sweepDurationS_visible = sweepFrames * frameInterval;
% Motion: bar moves between sweepFrames - 1 inter-frame intervals.
% Guard against degenerate sweepFrames=1 (would give zero motion, infinite speed).
if sweepFrames >= 2
    p.trVars.sweepDurationS_motion = (sweepFrames - 1) * frameInterval;
    p.trVars.speedDegPerSec_realized = p.trVars.pathLengthDeg / p.trVars.sweepDurationS_motion;
else
    % single-frame sweep: bar shown statically at start. Realized speed undefined.
    p.trVars.sweepDurationS_motion   = 0;
    p.trVars.speedDegPerSec_realized = NaN;
end

p.trData.sweepDurationS_nominal  = p.trVars.sweepDurationS_nominal;
p.trData.sweepDurationS_visible  = p.trVars.sweepDurationS_visible;
p.trData.sweepDurationS_motion   = p.trVars.sweepDurationS_motion;
p.trData.speedDegPerSec_realized = p.trVars.speedDegPerSec_realized;
p.trData.sweepStartPix           = p.trVars.sweepStartPix;
p.trData.sweepEndPix             = p.trVars.sweepEndPix;
p.trData.sweepCenterDeg          = [p.trVars.pathCenterXDeg, p.trVars.pathCenterYDeg];

%% (6) Spatial-undersampling warning (not a hard fail).
refreshRate = 1 / frameInterval;
if p.trVars.speedDegPerSec / refreshRate > p.trVars.barWidthDeg
    fprintf(['barsweep:nextParams: WARNING -- bar moves %.3f dva/frame ' ...
        'but bar width is %.3f dva. Spatial undersampling along motion axis.\n'], ...
        p.trVars.speedDegPerSec / refreshRate, p.trVars.barWidthDeg);
end

%% (7) Precomputed bar-center arrays (2 x sweepFrames): dva, then pixels.
% Interpolate in DEGREES so the bar advances by a constant ANGULAR step
% per frame -- i.e. so speedDegPerSec means what it says. Interpolating in
% pixel space instead (as this function did prior to 2026-08-17) would
% reintroduce the tangent distortion fixed in §4: constant pixel velocity
% is not constant angular velocity on a flat screen.
%
% sweepCenterDegByFrame is the y-up dva array consumed by
% accumulateBarsweepRF as the RF position axis. Because it is now the true
% on-screen position of the bar, that axis needs no correction downstream.
% Distinct from the existing static [1x2] p.trData.sweepCenterDeg.
%
% Endpoint contract: sweepCenterPix(:,1) == sweepStartPix and
% sweepCenterPix(:,sweepFrames) == sweepEndPix exactly, since both are the
% same pds.deg2pix call applied to the same startDeg / endDeg values.
% Intermediate frames are deliberately NOT linear in pixels.
if sweepFrames >= 2
    p.trVars.sweepCenterDegByFrame = [ ...
        linspace(startDeg(1), endDeg(1), sweepFrames); ...
        linspace(startDeg(2), endDeg(2), sweepFrames) ];
else
    p.trVars.sweepCenterDegByFrame = startDeg;
end

p.trVars.sweepCenterPix = [ ...
    p.draw.middleXY(1) + pds.deg2pix(p.trVars.sweepCenterDegByFrame(1, :), p); ...
    p.draw.middleXY(2) - pds.deg2pix(p.trVars.sweepCenterDegByFrame(2, :), p)];

%% (8) Bar geometry in pixels for textures and dest rect.
barWidthPix  = max(1, round(pds.deg2pix(p.trVars.barWidthDeg,  p)));
barLengthPix = max(1, round(pds.deg2pix(p.trVars.barLengthDeg, p)));
p.trVars.barWidthPix  = barWidthPix;
p.trVars.barLengthPix = barLengthPix;
% Destination rect (length x width) centered on origin; we'll
% CenterRectOnPoint at draw time using sweepCenterPix(:,frameIdx).
p.draw.barDestRectAtOrigin = [0 0 barLengthPix barWidthPix];
% Rotation passed to Screen('DrawTexture'): bar long axis is
% perpendicular to motion -> rotate the texture (whose long axis is X)
% by pathAngleDeg so that the long axis of the rendered bar lies along
% the direction of motion. Wait -- the bar's *long axis* must be
% perpendicular to motion. Texture's long axis is along X (length-pix);
% to make the rendered long axis lie at pathAngleDeg + 90, we rotate
% by pathAngleDeg + 90.
p.trVars.barRotationDeg = p.trVars.pathAngleDeg + 90;

%% (9) Projected noise-texture memory (admission test).
if p.trVars.stimulusMode == 1
    nChecksX = max(1, ceil(p.trVars.barLengthDeg / p.trVars.noiseCheckSizeDeg));
    nChecksY = max(1, ceil(p.trVars.barWidthDeg  / p.trVars.noiseCheckSizeDeg));
    bytesPerTexel = 4;  % conservative RGBA estimate per the plan
    projectedBytes = nChecksX * nChecksY * sweepFrames * bytesPerTexel;
    assert(projectedBytes <= p.trVars.noiseTextureBudgetBytes, ...
        sprintf(['nextParams: projected noise-texture data %.1f MB exceeds ' ...
            'budget %.1f MB. Reduce barLengthDeg/barWidthDeg/sweepFrames or ' ...
            'increase noiseCheckSizeDeg / noiseTextureBudgetBytes.'], ...
            projectedBytes / 1024 / 1024, ...
            p.trVars.noiseTextureBudgetBytes / 1024 / 1024));
    p.trVars.noiseGridSize = [nChecksY, nChecksX];
end

%% (10) First-trial dry-run validation of strobeList expressions.
% pds.strobeTrialData wraps each eval in a silent try/catch (see
% +pds/strobeTrialData.m:14). Run every expression here, outside that
% catch, on trial 1 only -- after p.trVars / p.trData have been
% populated above so all references resolve. Run BEFORE texture build
% so a dry-run failure can't leak GPU handles.
if p.status.iTrial == 1
    nS = size(p.init.strobeList, 1);
    for ii = 1:nS
        nm   = p.init.strobeList{ii, 1};
        expr = p.init.strobeList{ii, 2};
        try
            v = eval(expr);
        catch me
            error(['nextParams: strobeList row ' num2str(ii) ' (code "' ...
                nm '"): expression "' expr '" raised: ' me.message]);
        end
        assert(isscalar(v) || numel(v) >= 1, ...
            ['nextParams: strobeList row ' num2str(ii) ...
             ' produced non-numeric value.']);
        assert(all(isfinite(v)) && all(v >= 0) && all(v == round(v)), ...
            ['nextParams: strobeList row ' num2str(ii) ' (code "' nm ...
             '") produced non-finite, negative, or non-integer value: ' ...
             mat2str(v)]);
    end
end

%% (11) Pre-build all bar textures for this trial's sweep.
% Wrap in try/catch so a partial allocation doesn't orphan GPU handles.
p.trVars.barTextures = zeros(1, sweepFrames);
try
    if p.trVars.stimulusMode == 1
        % Noise mode: per-frame fresh binary noise textures.
        for f = 1:sweepFrames
            p.trVars.barTextures(f) = buildNoiseBarFrame(p, ...
                p.trVars.noiseGridSize(1), p.trVars.noiseGridSize(2));
        end
    else
        % Solid mode: one bar texture, drawn every frame (run loop indexes f=1).
        % Plan §"Texture Pre-Build": "the remainder of the array (2:sweepFrames)
        % holds copies of the same handle". We fill all slots so _run.m can
        % index by frameIdx without branching on stimulusMode.
        solidTex = buildBarTexture(p, p.trVars.barWidthPix, p.trVars.barLengthPix);
        p.trVars.barTextures(:) = solidTex;
    end
catch me
    valid = p.trVars.barTextures(p.trVars.barTextures > 0);
    valid = unique(valid);
    if ~isempty(valid)
        Screen('Close', valid);
    end
    p.trVars.barTextures = [];
    rethrow(me);
end

%% (12) Trial-summary print.
fprintf('Trial %d: angle %d deg, %d frames, sweep %.3f s (visible)\n', ...
    p.status.iTrial, round(p.trVars.pathAngleDeg), sweepFrames, ...
    p.trVars.sweepDurationS_visible);

end
