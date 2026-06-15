function p = barsweep_finish(p)
%   p = barsweep_finish(p)
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% Post-trial processing: pool mutation, parameter strobes, trialEnd
% strobe, save, texture cleanup, post-trial waits, status update.
%
% Per the plan's session-termination mechanism, the harness performs one
% extra _next.m -> _run.m -> _finish.m cycle after the session-done flag
% is raised; this function's first action is a strict no-op gate that
% only persists final status and toggles the run button off.

%% (0) Post-completion no-op gate.
if p.trVars.barsweepSessionDone
    % Final-status persistence (redundant with the per-trial append on
    % the last real trial, but cheap and self-contained: if the per-trial
    % append is ever removed or fails, this branch still produces a
    % valid final p.mat).
    status = p.status;
    save(fullfile(p.init.sessionFolder, 'p.mat'), 'status', '-append');
    runButtonObj = findall(groot, 'Tag', 'runButton');
    if ~isempty(runButtonObj)
        runButtonObj.Value = false;
    end
    return;
end

%% (1) Retrieve Ripple data if connected.
% Online RF mapping needs spikeTimes/spikeClusters/eventTimes/eventValues
% from Ripple. Pull whenever Ripple is alive; the accumulator step below
% gates on useOnlineRF separately.
if isfield(p.rig, 'ripple') && isfield(p.rig.ripple, 'recChans') && ...
        p.rig.ripple.status && ~isempty(p.rig.ripple.recChans)
    p = pds.getRippleData(p);
    if p.trVars.useOnlineRF
        ev = p.trData.eventValues;
        if isempty(ev)
            fprintf('  Ripple digin: 0 events received this trial.\n');
        else
            uniqEv = unique(ev(:)');
            fprintf('  Ripple digin: %d events, unique codes = [%s]\n', ...
                numel(ev), num2str(uniqEv, '%d '));
        end
    end
end

%% (1a) Trim spikes to stimulus presentation window.
% Same rationale as rfMap_finish.m §(0b): the first getRippleData call
% reads the entire Ripple buffer (pre-session crossings), and inter-trial
% crossings accumulate during ITIs. Discard everything outside a generous
% window around stimulus presentation; the accumulator applies its own
% precise latency-corrected filter internally.
if ~isempty(p.trData.spikeTimes) && ~isempty(p.trData.eventValues)
    stimOnCode_ = p.init.codes.stimOn;
    evMask_     = p.trData.eventValues == stimOnCode_;
    if any(evMask_)
        stimOnRipple_ = p.trData.eventTimes(find(evMask_, 1, 'last'));
        sweepDurS_    = p.trVars.sweepFrames * p.rig.frameDuration;
        inWindow_     = p.trData.spikeTimes >= stimOnRipple_ & ...
                        p.trData.spikeTimes <  stimOnRipple_ + sweepDurS_ + 1.0;
        nDiscarded_   = numel(p.trData.spikeTimes) - nnz(inWindow_);
        if nDiscarded_ > 0
            fprintf('  Spike filter: kept %d of %d (discarded %d out-of-window).\n', ...
                nnz(inWindow_), numel(p.trData.spikeTimes), nDiscarded_);
            p.trData.spikeTimes    = p.trData.spikeTimes(inWindow_);
            p.trData.spikeClusters = p.trData.spikeClusters(inWindow_);
        end
    end
end

%% (1b) Online RF: detect spatial-knob changes and reset if needed.
% Compares live trVars (which already reflects mid-session GUI edits via
% trVarsGuiComm) against the snapshot in p.init.barsweepRF. Sub-bin
% pathCenterDeg moves are treated as label-only (continuity preserved);
% larger spatial moves and any pathLengthDeg/barWidthDeg/rfPosBinDeg/
% rfLatencyMs change snapshot-then-reset the accumulator.
[p, didReset] = barsweepRF_detectAndReset(p);

%% (1c) Online RF: accumulate this trial.
% Per plan §0 acceptance criterion #5:
%   nonStart      -> excluded outright (no bar visibility).
%   trialComplete -> full sweep contributes.
%   fixBreak      -> partial sweep up to fixBreak time; accumulator
%                    truncates internally based on p.trData.timing.fixBreak.
% Dwell time accumulates regardless of whether any spikes were emitted,
% so we don't gate on isempty(spikeTimes) here -- bar position coverage
% is stimulus-only.
if p.trVars.useOnlineRF && isfield(p.init, 'barsweepRF') && ...
        isfield(p.init.barsweepRF, 'enabled') && p.init.barsweepRF.enabled && ...
        p.rig.ripple.status && ...
        (p.trData.trialEndState == p.state.trialComplete || ...
         p.trData.trialEndState == p.state.fixBreak)
    p = accumulateBarsweepRF(p);
end

%% (1d) Online RF: refresh the figure (reads live trVars knobs).
if p.trVars.useOnlineRF && isfield(p.init, 'barsweepRF') && ...
        isfield(p.init.barsweepRF, 'enabled') && p.init.barsweepRF.enabled && ...
        isfield(p.init.barsweepRF, 'figData') && ...
        ~isempty(p.init.barsweepRF.figData) && ...
        isvalid(p.init.barsweepRF.figData.fig)
    if didReset
        p.init.barsweepRF.bannerNextTrial = ...
            sprintf('RF accumulator reset (N=%d)', p.init.barsweepRF.resetCount);
    end
    p = plotBarsweepRF(p);
end

%% (2) Fill background and flip once to clear the bar.
bgClut = p.stim.luminanceLevels(p.trVars.backgroundLumIdx);
Screen('FillRect', p.draw.window, bgClut);
Screen('Flip', p.draw.window);

%% (3) Read DataPixx ADC/DIN buffers.
p = pds.readDatapixxBuffers(p);

%% (4) trialRepeatFlag: aborted trials repeat (leave pool unchanged).
p.trData.trialRepeatFlag = (p.trData.trialEndState > 10) & ...
    (p.trData.trialEndState < 20);

%% (5) Schedule pool mutation (the ONLY place the pool is mutated).
% Per the plan's schedule state-machine table:
%   trialComplete (rewarded): remove front element. If empty, increment
%       barsweepSetsCompleted and re-shuffle a fresh pool.
%   fixBreak / nonStart: leave pool unchanged (retry on next trial).
if p.trData.trialEndState == p.state.trialComplete
    % Remove the angle that was peeked in _next.m.
    p.status.barsweepPool(1) = [];
    if isempty(p.status.barsweepPool)
        p.status.barsweepSetsCompleted = ...
            p.status.barsweepSetsCompleted + 1;
        % Live pair-shuffle flag (mid-session GUI-tunable). Default true
        % so the §2 forward/reverse balance window is one trial wide.
        p.status.barsweepPool = shuffleAngleList( ...
            p.init.barsweepSchedule.angleList, ...
            p.trVars.barsweepPairShuffle);
    end
end

%% (6) Strobe end-of-trial parameter values.
p = pds.strobeTrialData(p);
p.trData.strobed = p.init.strb.strobedList;
p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

%% (7) Strobe trialEnd (exactly once, after parameter strobes,
% before any post-trial WaitSecs).
p.trData.timing.trialEnd = GetSecs - p.trData.timing.trialStartPTB;
p.init.strb.strobeNow(p.init.codes.trialEnd);

%% (8) Save trial data.
% Strip the large RF accumulators from p.init before saveP (pds.saveP
% writes p.init on every trial; the accumulators are ~hundreds of KB
% and are also saved separately to a sidecar below). Mirrors the
% rfMap_finish.m:68-82 strip-restore pattern.
%
% Note: pds.saveP(p) skips the per-trial trialNNNN.mat and the
% in-function status append on nonStart trials (returns at line 27).
% We close that gap with the unconditional status append in step (11).
tempBsRF = [];
if isfield(p.init, 'barsweepRF') && isstruct(p.init.barsweepRF) && ...
        isfield(p.init.barsweepRF, 'enabled') && p.init.barsweepRF.enabled
    tempBsRF = p.init.barsweepRF;
    pruned   = rmfield(tempBsRF, intersect(fieldnames(tempBsRF), ...
        {'spikeHist', 'dwellTime', 'figData', 'browser'}));
    p.init.barsweepRF = pruned;
end
pds.saveP(p);
if ~isempty(tempBsRF)
    p.init.barsweepRF = tempBsRF;
end

%% (8b) Per-trial sidecar with full RF accumulator state.
% Overwritten each trial; the latest snapshot on disk is the post-session
% state. Cost is ~hundreds of KB to a local SSD; if the output folder is
% on a network share this can grow into the tens of ms and chew into the
% ITI -- gate on a future flag if/when that bites.
%
% figData carries live graphics handles (figure, axes, image/plot objects)
% that MATLAB warns about when serialized into a .mat file and which are
% useless on disk anyway. Strip before saving.
if ~isempty(tempBsRF)
    barsweepRF = rmfield(tempBsRF, ...
        intersect(fieldnames(tempBsRF), {'figData', 'browser'}));
    sidecarPath = fullfile(p.init.sessionFolder, ...
        [p.init.sessionId '_barsweepRF.mat']);
    save(sidecarPath, 'barsweepRF');
end

%% (9) Release pre-built textures.
% Both modes pre-build per trial in _next.m and release per trial here.
% Solid mode uses one handle replicated across all slots; dedupe before
% Screen('Close') to avoid double-close errors.
if isfield(p.trVars, 'barTextures') && ~isempty(p.trVars.barTextures)
    valid = unique(p.trVars.barTextures(p.trVars.barTextures > 0));
    if ~isempty(valid)
        Screen('Close', valid);
    end
    p.trVars.barTextures = [];
end

%% (10) Apply post-trial waits.
%   reward branch: WaitSecs(postRewardDuration), then iti
%   abort branch:  WaitSecs(timeoutAfterFixBreak), then iti
% iti applies on every outcome (matches source Stm.ITI).
p = postTrialTimeOut(p);

%% (11) Update status counters.
p = updateStatusVariables(p);

% Missed-frame count for this trial.
flipDiffs = diff(p.trData.timing.flipTime(p.trData.timing.flipTime > 0));
if ~isempty(flipDiffs)
    p.trData.missedFrameCount = nnz(flipDiffs > p.rig.frameDuration * 1.5);
else
    p.trData.missedFrameCount = 0;
end
p.status.missedFrames = p.status.missedFrames + p.trData.missedFrameCount;

%% (12) Per-trial unconditional status append.
% Closes the nonStart gap left by pds.saveP (which returns before its
% own status append on nonStart trials). Runs on every outcome so the
% on-disk status reflects every attempt regardless of stop path.
% On the very first trial, pds.saveP wrote the full p struct (the
% initial p.mat write fires before its nonStart return), so we can
% always -append here without risking an empty file.
status = p.status;
save(fullfile(p.init.sessionFolder, 'p.mat'), 'status', '-append');

%% (13) Print one-line trial summary.
switch p.trData.trialEndState
    case p.state.trialComplete
        outcomeStr = 'GOOD';
    case p.state.fixBreak
        outcomeStr = 'FBRK';
    case p.state.nonStart
        outcomeStr = 'NONS';
    otherwise
        outcomeStr = 'UNK ';
end
fprintf(['Trial %d: %s | angle=%d | sets=%d/%d | pool=[%s] | ' ...
    'good=%d fb=%d ns=%d | missed=%d\n'], ...
    p.status.iTrial, outcomeStr, round(p.trVars.pathAngleDeg), ...
    p.status.barsweepSetsCompleted, ...
    p.init.barsweepSchedule.setRepeats, ...
    num2str(p.status.barsweepPool, '%d '), ...
    p.status.iGoodTrial, p.status.fixBreakCount, ...
    p.status.nonStartCount, p.trData.missedFrameCount);

end

%% -------------------- LOCAL: RF accumulator change detection --------------------
function [p, didReset] = barsweepRF_detectAndReset(p)
% Compare live trVars spatial knobs against the snapshot in
% p.init.barsweepRF. Sub-bin pathCenterDeg moves are absorbed as
% label-only (continuity preserved). Larger spatial moves and any
% pathLengthDeg/barWidthDeg/rfPosBinDeg/rfLatencyMs change snapshot the
% accumulator to a versioned sidecar, then re-init. Reconstruction-only
% knobs (rfMapExtentDeg, rfRampFilter, rfRampCutoff, rfSelectedChannel)
% are read live by plotBarsweepRF and never trigger a reset.

didReset = false;

if ~p.trVars.useOnlineRF
    return;
end
if ~isfield(p.init, 'barsweepRF') || ~isstruct(p.init.barsweepRF) || ...
        ~isfield(p.init.barsweepRF, 'enabled') || ~p.init.barsweepRF.enabled
    return;
end

rf = p.init.barsweepRF;
needReset = false;

% Spatial knobs that DO trigger a reset.
if abs(rf.pathLengthDeg - p.trVars.pathLengthDeg) > 1e-6, needReset = true; end
if abs(rf.barWidthDeg   - p.trVars.barWidthDeg)   > 1e-6, needReset = true; end
if abs(rf.rfPosBinDeg   - p.trVars.rfPosBinDeg)   > 1e-6, needReset = true; end
if abs(rf.latencyMs     - p.trVars.rfLatencyMs)   > 1e-6, needReset = true; end

% pathCenterDeg: sub-bin nudge -> absorbed (label-only); super-bin -> reset.
deltaPath = abs([p.trVars.pathCenterXDeg; p.trVars.pathCenterYDeg] - rf.pathCenterDeg);
if any(deltaPath >= rf.rfPosBinDeg)
    needReset = true;
elseif any(deltaPath > 0)
    % Sub-bin move: just update the snapshot so future deltas are computed
    % from the new origin. The accumulator stays bit-identical.
    rf.pathCenterDeg = [p.trVars.pathCenterXDeg; p.trVars.pathCenterYDeg];
    p.init.barsweepRF = rf;
end

if ~needReset
    return;
end

% Snapshot the pre-reset accumulator. The §1 plan emphasis: this save
% must happen BEFORE re-init zeroes the arrays, otherwise the auto-reset
% destroys exactly the data the experimenter wants to review post hoc.
nextN = rf.resetCount + 1;
sidecarPath = fullfile(p.init.sessionFolder, ...
    sprintf('%s_barsweepRF_reset%d.mat', p.init.sessionId, nextN));
try
    barsweepRF = rmfield(rf, intersect(fieldnames(rf), {'figData', 'browser'}));
    save(sidecarPath, 'barsweepRF');
catch me
    warning('barsweepRF:snapshotSaveFailed', ...
        'Failed to save reset snapshot %s: %s', sidecarPath, me.message);
end

% Increment the reset counter, then re-init (which preserves figData).
p.init.barsweepRF.resetCount = nextN;
p = initBarsweepRF(p);
didReset = true;

end
