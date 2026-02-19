function p = numerosity_spatial_finish(p)
%   p = numerosity_spatial_finish(p)
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

% fill screen with background color
Screen('FillRect', p.draw.window, p.draw.color.background);
Screen('Flip', p.draw.window);
Screen('Close'); % close any open textures
% read buffered ADC and DIN data from DATAPixx
p           = pds.readDatapixxBuffers(p);

% Was the previous trial aborted?
p.trData.trialRepeatFlag = ismember(p.trData.trialEndState, ...
    [p.state.fixBreak, p.state.joyBreak, p.state.nonStart, p.state.wrongTarget]);

% update status variables
p           = updateStatusVariables(p);

%% strobes:

% strobe trial data:
p           = pds.strobeTrialData(p);

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

% copy p.draw variables into p.trVars.draw so they get saved
p.trVars.draw = p.draw;

%%

% (3) pause ephys
pds.stopOmniPlex;

% wait for joystick release
p           = pds.waitForJoystickRelease(p);

% if a "time-out" is desired, make it happen here. Note: the way this works
% at present is: we only advance from here if the desired interval of time
% has elapsed since the end of the previous trial. This means that if the
% monkey has held the joystick down for a "long time" since the end of the
% last trial, the "time-out" window has passed and there won't be an
% ADDITIONAL time out.
postTrialTimeOut(p);

% retreive data from omniplex PC if desired.
if p.rig.connectToOmniplex
    p = pds.getOmniplexData(p);
end

% (5) auto save backup
pds.saveP(p);



% (7) update trials list IF we're using the trials array.
if p.trVars.setTargLocViaTrialArray
    p           = updateTrialsList(p); % Comment out this to remove drumming
end

% keyboard

end
