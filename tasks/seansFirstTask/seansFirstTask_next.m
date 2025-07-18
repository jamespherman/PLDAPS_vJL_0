function p = seansFirstTask_next(p)
%   function p = seansFirstTask_next(p)
% Part of the quintet of pldpas functions:
%
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
% "next" file runs for the first time after "init" and before "run".
% Thereafter, runs after "finish" and before "run" until experiment is
% done.

%% update p.trialVars:
% p.trialVars inherits whatever was set in p.userVars which inherited its
% goodies from initVars. Thus, the variables on every trial (ie trialVars)
% stem from the initVars (in settings file) btu may be overriden by user
% via userVars

% iterate trial counter
p.status.iTrial = p.status.iTrial + 1;

% initialize trial variables
p.trVars = p.trVarsGuiComm;

%% (4) define next trial parameters
p  = nextParams(p);

%% (5) set schedules
p  = pds.setSchedules(p);

%% (6) init trial data
p = initTrData(p);

%% record save the stim details (ie dot XYCW)
p.trVars.stim = p.stim;

%% (9) Start ephys recording and ADC schedules
pds.startEphysAndSchedules;

end
