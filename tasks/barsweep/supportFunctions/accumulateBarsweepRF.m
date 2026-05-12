function p = accumulateBarsweepRF(p)
% p = accumulateBarsweepRF(p)
%
% Update the online RF accumulator with this trial's spikes and bar
% trajectory. Pure update of p.init.barsweepRF.{spikeHist, dwellTime,
% spikeCount, trialsByDirection}; everything else is read-only.
%
% Identical machinery for cardinal4 and rfmap12 -- the only difference
% between the two regimes is the reconstruction step in
% reconstructBarsweepRF.m.
%
% Aborted-trial handling (plan §0 acceptance criterion #5):
%   nonStart       -> skipped at the call site (no bar visibility).
%   trialComplete  -> sweep ran to completion. Visibility window is
%                     [stimOn, stimOff]; spikes/dwell within
%                     [0, sweepDur - latency] are accumulated.
%   fixBreak       -> sweep aborted at fixBreak time. Visibility window
%                     is [stimOn, fixBreak]; spikes/dwell within
%                     [0, fixBreakRel - latency] are accumulated.
%
% latency is subtracted from spike times only (it offsets the cell's
% response relative to the stimulus); dwell-time accumulation honors
% the same upper-bound truncation (so the truncation point matches).

rf = p.init.barsweepRF;

if ~isstruct(rf) || ~isfield(rf, 'enabled') || ~rf.enabled
    return;
end

%% (1) Locate stimOn in Ripple clock.
stimOnCode = p.init.codes.stimOn;
onMask     = p.trData.eventValues == stimOnCode;
if ~any(onMask)
    % Strobe was missed by Ripple; can't anchor spikes to the sweep.
    fprintf('  barsweepRF: stimOn event not found in Ripple stream, skipping.\n');
    return;
end
stimOnRipple = p.trData.eventTimes(find(onMask, 1, 'last'));

%% (2) Sweep geometry, path-center-relative projection coordinate.
% sweepCenterDegByFrame is precomputed in nextParams.m (§7b) parallel to
% sweepCenterPix, in dva with the user-visible y-up sign convention.
relCenter   = p.trVars.sweepCenterDegByFrame - rf.pathCenterDeg;  % [2 x sweepFrames]
thetaMotion = deg2rad(p.trVars.pathAngleDeg);
thetaOri    = mod(thetaMotion, pi);
projAxis    = [cos(thetaOri); sin(thetaOri)];
s_perFrame  = projAxis' * relCenter;                              % [1 x sweepFrames]

% Map orientation to its row in spikeHist/dwellTime. The pooling is
% automatic because thetaOri = mod(thetaMotion, pi) collapses opposite
% directions to the same orientation row.
[diffOri, oriIdx] = min(abs(rf.orientationsRad - thetaOri));
if diffOri > 1e-3
    fprintf('  barsweepRF: trial orientation %.3f rad has no match in orientationsRad; skipping.\n', ...
        thetaOri);
    return;
end

%% (3) Slice flipTime starting at the stimOn flip index.
% flipTime is preallocated 1x3000 and indexed by p.trVars.flipIdx, which
% counts pre-stimulus flips too. flipIdxStimOn was captured by
% drawMachine immediately after the stimOn postFlip block. Slice through
% (fi0 + sweepFrames) inclusive: the +1th entry is the post-sweep blank
% flip that erases the bar (state holdFixAndSweep -> trialComplete or
% the stimOff flip from a fixBreak), so diff(flipT) is exactly
% sweepFrames real measured durations -- no synthetic fallback.
fi0 = p.trData.timing.flipIdxStimOn;
if fi0 < 0
    % stimOn never fired (e.g. trial aborted before any sweep flip).
    return;
end
sweepFrames = p.trVars.sweepFrames;

% Truncate slice to whatever flips actually happened: a fixBreak before
% the full sweep finished produces fewer than sweepFrames+1 flips.
% p.trVars.flipIdx points at the next-unwritten slot, so flips actually
% written to flipTime span 1..(p.trVars.flipIdx-1).
lastFlipIdx = p.trVars.flipIdx - 1;
endIdx      = min(fi0 + sweepFrames, lastFlipIdx);
if endIdx <= fi0
    % No bar flips were rendered -> nothing to accumulate.
    return;
end
flipT  = p.trData.timing.flipTime(fi0 : endIdx);
flipT  = flipT(:)' - flipT(1);                       % stim-onset relative
nFramesAccum = numel(flipT) - 1;                     % real sweep frames covered
if nFramesAccum < 1
    return;
end

%% (4) Visibility upper bound: truncate at fixBreak (relative seconds)
% if the trial broke fixation. Otherwise the natural sweep duration
% (flipT(end)) is the bound. latency is subtracted from spike times
% only (see §5 below).
sweepDur     = flipT(end);                           % seconds, stim-onset rel.
visibleEnd   = sweepDur;
if isfield(p.trData.timing, 'fixBreak') && p.trData.timing.fixBreak > 0 && ...
        p.trData.timing.stimOn > 0
    fixBreakRel = p.trData.timing.fixBreak - p.trData.timing.stimOn;
    if fixBreakRel > 0 && fixBreakRel < visibleEnd
        visibleEnd = fixBreakRel;
    end
end

%% (5) Dwell-time update (vectorized over frames).
% Truncate the per-frame s/duration arrays to those whose flip lands
% within the visibility window. The frame at index k spans
% [flipT(k), flipT(k+1)]; we treat a frame as in-window if its start
% (flipT(k)) is < visibleEnd, and clip its duration to visibleEnd.
posBins_perFrame = discretize(s_perFrame(1:nFramesAccum), rf.positionEdges);

frameStart = flipT(1:end-1);
frameEnd   = flipT(2:end);
visMask    = frameStart < visibleEnd;
% Clip the last partially-visible frame.
clippedDur = min(frameEnd, visibleEnd) - frameStart;
clippedDur(~visMask) = 0;
clippedDur(clippedDur < 0) = 0;

valid = ~isnan(posBins_perFrame) & visMask & clippedDur > 0;
if any(valid)
    rf.dwellTime(oriIdx, :) = rf.dwellTime(oriIdx, :) + ...
        accumarray(posBins_perFrame(valid)', clippedDur(valid)', ...
                   [numel(rf.positionCenters), 1])';
end

%% (6) Spike binning, vectorized across all channels.
% spikeClusters carries the channel index (asserted in barsweep_init.m
% via useOnlineSort=0). Latency is subtracted from spike times so a
% spike at time t_spike anchors to the bar position at time
% (t_spike - stimOn - latency).
spikeT = p.trData.spikeTimes(:);
spikeC = p.trData.spikeClusters(:);

if ~isempty(spikeT)
    tEff = spikeT - stimOnRipple - rf.latencyMs / 1000;
    keep = tEff >= 0 & tEff < visibleEnd;
    if any(keep)
        chs    = spikeC(keep);
        % Loud guard: a 64-channel user with rfNChannels left at 32 would
        % otherwise have channels 33+ silently dropped by the chs<=N
        % filter below, producing a half-population RF map that looks
        % like real data. Per plan §4 settings.m bullet, error rather
        % than warn so the misconfiguration is impossible to miss.
        maxChObserved = max(chs);
        if maxChObserved > rf.nChannels
            error('barsweepRF:channelOverflow', ...
                ['Observed spike on channel %d but rfNChannels = %d. ' ...
                 'Bump p.trVars.rfNChannels in the settings file (or in the GUI) ' ...
                 'before running again. The accumulator will not silently drop ' ...
                 'spikes from channels above the configured limit.'], ...
                maxChObserved, rf.nChannels);
        end
        % Map effective time to the frame the bar was at when the spike
        % was emitted. flipT itself is the frame-edges vector.
        frIdx  = discretize(tEff(keep), flipT);
        ok     = ~isnan(frIdx) & chs >= 1 & chs <= rf.nChannels;
        if any(ok)
            posBins = discretize(s_perFrame(frIdx(ok)), rf.positionEdges);
            ok2     = ~isnan(posBins);
            if any(ok2)
                chsK = chs(ok); chsK = chsK(ok2);
                posK = posBins(ok2);
                nPos = numel(rf.positionCenters);
                % 2D accumarray: rows = posBin, cols = channel.
                inc  = accumarray([posK(:), chsK(:)], 1, [nPos, rf.nChannels]);
                rf.spikeHist(oriIdx, :, :) = ...
                    squeeze(rf.spikeHist(oriIdx, :, :)) + inc;
                rf.spikeCount = rf.spikeCount + ...
                    accumarray(chsK(:), 1, [rf.nChannels, 1]);
            end
        end
    end
end

%% (7) Per-direction trial counter (balance diagnostic).
[diffDir, dirIdx] = min(abs(rf.directionsRad - thetaMotion));
if diffDir < 1e-3
    rf.trialsByDirection(dirIdx) = rf.trialsByDirection(dirIdx) + 1;
end

rf.lastUpdateTrial = p.status.iTrial;
p.init.barsweepRF  = rf;

end
