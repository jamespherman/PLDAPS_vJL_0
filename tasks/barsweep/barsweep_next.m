function p = barsweep_next(p)
%   p = barsweep_next(p)
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% Runs before each trial. Sets up trial-specific parameters, peeks the
% next angle from the schedule pool, and pre-builds bar textures.
%
% Termination check is the first action: once the session is complete,
% _next.m sets the session-done flag and returns immediately, with no
% iTrial increment, no GUI copy, no pool peek, no texture build.

% (1) Session-end check (before any trial-specific work).
% Only valid once setRepeats has been frozen (i.e., after at least one
% _next.m call has run). On the very first _next.m call, the frozen
% schedule field is NaN and we skip this branch.
if p.status.iTrial >= 1 && ...
        ~isnan(p.init.barsweepSchedule.setRepeats) && ...
        p.status.barsweepSetsCompleted >= p.init.barsweepSchedule.setRepeats
    p.trVars.barsweepSessionDone = true;
    return;
end

% (2) Increment trial counter.
p.status.iTrial = p.status.iTrial + 1;

% (3) Copy GUI -> trVars.
p.trVars = p.trVarsGuiComm;

% (4) Lazy setRepeats freeze on the very first trial.
% At this point step (3) has already copied the operator's Run-time
% setRepeats from p.trVarsGuiComm into p.trVars.
if p.status.iTrial == 1
    p.init.barsweepSchedule.setRepeats = p.trVars.setRepeats;
end

% (5) Initialize per-trial trData fields.
p = initTrData(p);

% Reset state machine for this trial.
p.trVars.currentState  = p.state.trialBegun;
p.trVars.exitWhileLoop = false;
p.trVars.flipIdx       = 1;

% Reset postFlip plumbing for this trial (defensive: also flushed in finish).
p.trVars.postFlip.logical  = false;
p.trVars.postFlip.varNames = cell(0);

% (6) Resolve trial parameters (peek pool, validate, precompute, build textures).
p = nextParams(p);

% (7) Set DataPixx schedules; first make sure no schedule is running.
Datapixx('RegWrRd');
dacStatus = Datapixx('GetDacStatus');
while dacStatus.scheduleRunning
    WaitSecs(0.05);
    Datapixx('RegWrRd');
    dacStatus = Datapixx('GetDacStatus');
end
p = pds.setSchedules(p);

% (8) Start ephys recording and ADC schedules.
pds.startEphysAndSchedules;

end
