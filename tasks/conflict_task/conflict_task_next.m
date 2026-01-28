function p = conflict_task_next(p)
%   p = conflict_task_next(p)
%
% Part of the quintet of PLDAPS functions:
%   settings function - defines default parameters
%   init function     - one-time setup
%   next function     - runs before each trial (this file)
%   run function      - executes each trial
%   finish function   - runs after each trial
%
% The "next" function runs for the first time after "init" and before
% "run". Thereafter, it runs after "finish" and before "run" until the
% experiment ends. It prepares all parameters needed for the upcoming trial.

%% Update p.trialVars
% Increment trial counter
p.status.iTrial = p.status.iTrial + 1;

% Copy GUI-communicable variables to current trial variables
p.trVars = p.trVarsGuiComm;

%% Define next trial parameters (trial type, delta-t, locations, timing)
p = nextParams(p);

%% Set DAC schedules for reward delivery and analog outputs
p = pds.setSchedules(p);

%% Initialize trial data structure (timing, gaze, strobes)
p = initTrData(p);

%% Start ephys recording and ADC schedules on DATAPixx
pds.startEphysAndSchedules;

end
