function p = reward_calibration_finish(p)
%   p = reward_calibration_finish(p)
%
% Part of the quintet of pldpas functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% finish function runs at the end of every trial and is usually used to 
% save data, update online plots, set stimulus for next trial, etc.


%% In this function:
% (1) Clear "Screen".
% (2) Strobe current trial's information (stimulus params, etc) to ephys
%     system.
% (3) Pause ephys.
% (4) Store data in PDS structure (eye position traces, spike times, etc.).
% (5) Auto save backup (if desired).
% (6) Update status variables.
% (7) Update trials list (shuffle back in trials to be repeated, take care
%     of transitions between blocks, etc.).
% (8) Update online plots.

% strobe and mark end of trial:
timeNow = GetSecs - p.trData.timing.trialStartPTB; % timeNow is relative to trial Start
p.trData.timing.trialEnd   = timeNow;
p.init.strb.strobeNow(p.init.codes.trialEnd);

% (3) mark end time in PTB & DP time:
[p.trData.timing.trialEndPTB, p.trData.timing.trialEndDP] = pds.getTimes;

% save strobed codes:
p.trData.strobed = p.init.strb.strobedList;

% flush strobe "veto" & "strobed" list
p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

% (5) auto save backup
pds.saveP(p);

% (7) update status variables
p           = updateStatusVariables(p);

pause(0.5);

% Maybe we can stop the task right away. Grab run button object handle and
% see if we can turn it off:
if p.status.iTrial >= p.trVars.numTrials
    runButtonObj = findall(groot, 'Tag', 'runButton');
    runButtonObj.Value = false;
end

end