function p = initTrData(p)

%% trialData
% finally, here we define some vars that we aim to collect on every trial.
% These inlcude behavioral responses, timing of responses, analog data via
% datapixx, and more and more..

p.trData.eyeX        = [];
p.trData.eyeY        = [];
p.trData.eyeP        = [];
p.trData.eyeT        = [];
p.trData.joyV        = [];
p.trData.dInValues   = [];
p.trData.dInTimes    = [];

% and so many more...

% timing variables are in time wrt trialStart
p.trData.timing.lastFrameTime   = 0;    % time at which last video frame was displayed
p.trData.timing.fixOn           = -1;   % time of fixation onset
p.trData.timing.fixAq           = -1;   % time of fixation acquisition
p.trData.timing.cueOn           = -1;   % time of cur ring onset
p.trData.timing.cueOff          = -1;   % time of cue ring offset
p.trData.timing.cueChg          = -1;   % time of cue change
p.trData.timing.foilChg         = -1;   % time of foil change
p.trData.timing.brokeFix        = -1;   % time of fixation break
p.trData.timing.brokeJoy        = -1;   % time of joystick release
p.trData.timing.reward          = -1;   % time of reward delivery
p.trData.timing.tone            = -1;   % time of audio feedback delivery
p.trData.timing.joyPress        = -1;   % time of initial joystick press


end