function p = human_psychophysical_threshold_next(p)
%
%   function p = human_psychophysical_threshold_next(p)
%
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

%% In this fuction, you may expect:
% (1) Iterate trial counter
% (2) Initialize trial variables (fixation color, joystick release time,
%     etc.)
% (3) Define parameters for next trial (stimulus location, properties,
% etc).
% (4) Set "schedules" for VIEWPixx/DATAPixx.
% (5) Define visual elements (grid, fixation window, joystick bar).
% (6) Initialize trial data (holders for values recorded during trial)
% (7) Generate stimuli
% (8) record stimulus details
% (9) Start (or "unpause") electrophysiology system and start schedules.

%% update p.trialVars:
% p.trialVars inherits whatever was set in p.userVars which inherited its
% goodies from initVars. Thus, the variables on every trial (ie trialVars)
% stem from the initVars (in settings file) btu may be overriden by user
% via userVars

% (1) iterate trial counter
p.status.iTrial = p.status.iTrial + 1;

% (2) initialize trial variables.
p.trVars = p.trVarsGuiComm;

% (3) define next trial parameters
p  = nextParams(p);

% (4) define visual elements (experimenter display only)
p  = defineVisuals(p);

% (5) set schedules
p  = pds.setSchedules(p);

% (6) init trial data
p = initTrData(p);

% (7) generate stimuli
p   = generateStimuli(p);

% (8) record save the stim details (ie dot XYCW)
% p.trVars.stim = p.stim;

% (9) Send trial number information to Eyelink for EDF file:
% Write TRIALID message to EDF file: marking the start of a trial for
% DataViewer. See DataViewer manual section: Protocol for EyeLink Data to
% Viewer Integration > Defining the Start and End of a Trial:
Eyelink('Message', 'TRIALID %d', p.status.iTrial);

% Write !V CLEAR message to EDF file: creates blank backdrop for DataViewer
% See DataViewer manual section: Protocol for EyeLink Data to Viewer
% Integration > Simple Drawing
Eyelink('Message', '!V CLEAR %d %d %d', p.init.el.backgroundcolour(1), ...
    p.init.el.backgroundcolour(2), p.init.el.backgroundcolour(3));

% Supply the trial number as a line of text on Host PC screen
Eyelink('Command', 'record_status_message "TRIAL %d/%d"', ...
    p.status.iTrial, p.status.totalTrials);

% (10) % Perform a drift check / correction. Optionally provide x y target
% location, otherwise target is presented on screen centre
EyelinkDoDriftCorrection(p.init.el, p.draw.middleXY(1), ...
    p.draw.middleXY(2));

% Put tracker in idle/offline mode before recording.
Eyelink('SetOfflineMode');

% Start tracker recording
Eyelink('StartRecording');

% Check which eye is available online. Returns 0 (left), 1 (right)
% or 2 (binocular)
p.init.el.eyeUsed = Eyelink('EyeAvailable');

% Get events from right eye if binocular
if p.init.el.eyeUsed == 2
    p.init.el.eyeUsed = 1;
end


end