function c = joyBreakFun(c)

%
% c = joyBreakFun(c)
%
% strobe "joybreak", mark time of joystick hold break, set state "3.1"
% (joystick hold broken prematurely), turn off fixation and fixation
% window, strobe fixation offset after next flip.

% Joypress broken. Strobe joybreak.
strobe(c.codes.joybreak);

% mark the time of joystick break
c.timeBrokeJoy          = GetSecs - c.trialStartTime;

% set state "3.1" (joystick hold broken prematurely).
c.trialState               = 3.1;

% turn off fixation and fixation window.
c.fixColor              = backcolor;
c.fixWinColor           = backcolor;

% strobe fixation offset after the next flip.
strobeOnFlip.logic = true;
strobeOnFlip.value = c.codes.fixdotoff;

end