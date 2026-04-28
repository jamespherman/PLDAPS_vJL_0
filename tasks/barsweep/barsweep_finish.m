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
if isfield(p.rig, 'ripple') && isfield(p.rig.ripple, 'recChans') && ...
        p.rig.ripple.status && ~isempty(p.rig.ripple.recChans)
    p = pds.getRippleData(p);
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
        nA = numel(p.init.barsweepSchedule.angleList);
        p.status.barsweepPool = ...
            p.init.barsweepSchedule.angleList(randperm(nA));
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
% Note: pds.saveP(p) skips the per-trial trialNNNN.mat and the
% in-function status append on nonStart trials (returns at line 27).
% We close that gap with the unconditional status append in step (11).
pds.saveP(p);

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
