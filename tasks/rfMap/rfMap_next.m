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

% (1) iterate trial counter
p.status.iTrial = p.status.iTrial + 1;

% (2) initialize trial variables from GUI communication struct
p.trVars = p.trVarsGuiComm;

% (3) define next trial parameters (frame range, fixation, etc.)
p = nextParams(p);

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
