function p = rfMap_next(p)
%   p = rfMap_next(p)
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% Runs before each trial. Sets up trial-specific parameters, creates
% noise textures, and starts hardware schedules.

% (0) Session-termination check (before any trial-specific work). Derived
% from PERSISTENT state (p.status/p.init) so it survives the
% `p.trVars = p.trVarsGuiComm` copy below; sets a transient flag consumed by
% _run and _finish, then returns immediately -- no iTrial increment, no
% nextParams, no schedules. _finish then drives the Run button off.
if rfMapSessionComplete(p)
    p.trVars.rfMapSessionDone = true;
    return;
end

% (1) iterate trial counter
p.status.iTrial = p.status.iTrial + 1;

% (2) initialize trial variables from GUI communication struct
p.trVars = p.trVarsGuiComm;

% (3) define next trial parameters (frame range, fixation, etc.)
p = nextParams(p);

% Check if movie is exhausted -- skip remaining setup
if isfield(p.trVars, 'movieExhausted') && p.trVars.movieExhausted
    return;
end

% (4) init trial data (timing, eye traces, spike data)
p = initTrData(p);

% (5) create PTB textures for this trial's noise frames
p = generateNoiseTextures(p);

% (6) set DataPixx schedules; first make sure no schedule is running:
Datapixx('RegWrRd');
dacStatus = Datapixx('GetDacStatus');
while dacStatus.scheduleRunning
    WaitSecs(0.05);
    Datapixx('RegWrRd');
    dacStatus = Datapixx('GetDacStatus');
end
p = pds.setSchedules(p);

% (7) start ephys recording and ADC schedules
pds.startEphysAndSchedules;

end
