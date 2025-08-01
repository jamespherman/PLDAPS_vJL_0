function p = deliverReward(p)
%
% p = deliverReward(p)
%
% Defines and loads a DAC waveform then starts a DAC schedule to deliver a 
% reward, marks timing, and strobes reward event code to indicate delivery.
% DAC schedule consists of a +4V square wave of duration defined by 
% "rewardDurationMs" padded with brief segments of 0V before and after to 
% ensure clean transitions.

% Build a square wave of the desired duration to output on the DAC for
% controlling the liquid reward solenoid open duration. +4V opens solenoid,
% 0V closes it. Wave is padded with brief 0V periods on either side to
% ensure clean transitions.
dacWaveOutDur = p.trVars.rewardDurationMs / 1e3 + p.rig.dp.dacPadDur;
dacWaveOut = [zeros(1, p.rig.dp.dacRate * p.rig.dp.dacPadDur / 2) ...
    4 * ones(1,p.rig.dp.dacRate * p.trVars.rewardDurationMs / 1e3) ...
    zeros(1,p.rig.dp.dacRate * p.rig.dp.dacPadDur / 2)];

% Write waveform to DAC buffer and configure reward delivery schedule
Datapixx('RegWrRd');
Datapixx('WriteDacBuffer', ...
    dacWaveOut, p.rig.dp.dacBuffAddr, p.rig.dp.dacChannelOut);
Datapixx('SetDacSchedule', 0, p.rig.dp.dacRate, ...
    fix(dacWaveOutDur * p.rig.dp.dacRate), ...
    0, p.rig.dp.dacBuffAddr, fix(dacWaveOutDur * p.rig.dp.dacRate));
Datapixx('RegWrRd');

% Start DAC schedule, strobe reward code, and mark reward delivery time
Datapixx('StartDacSchedule');
Datapixx('RegWrRd');
p.init.strb.strobeNow(p.init.codes.reward);
if p.trData.timing.reward < 0
p.trData.timing.reward = GetSecs - p.trData.timing.trialStartPTB;
end