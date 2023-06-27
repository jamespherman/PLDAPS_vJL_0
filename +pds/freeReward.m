function p = freeReward(p)

%
% p = freeReward(p)
%

% Define DAC schedule
dacWaveOutDur   = p.trVars.rewardDurationMs / 1e3 + p.rig.dp.dacPadDur;
dacWaveOut      = [zeros(1, p.rig.dp.dacRate * p.rig.dp.dacPadDur / 2) ...
    4 * ones(1,p.rig.dp.dacRate * p.trVars.rewardDurationMs / 1e3) ...
    zeros(1,p.rig.dp.dacRate * p.rig.dp.dacPadDur / 2)];

% Set DAC schedule (for reward system) for channel
Datapixx('RegWrRd');
Datapixx('WriteDacBuffer', ...
    dacWaveOut, p.rig.dp.dacBuffAddr, p.rig.dp.dacChannelOut);
Datapixx('SetDacSchedule', 0, p.rig.dp.dacRate, ...
    fix(dacWaveOutDur * p.rig.dp.dacRate), ...
    0, p.rig.dp.dacBuffAddr, fix(dacWaveOutDur * p.rig.dp.dacRate));
Datapixx('RegWrRd');

% deliver reward, strobe reward delivery, and record time of reward
% delivery
Datapixx('StartDacSchedule');
Datapixx('RegWrRd');
p.init.strb.strobeNow(p.init.codes.freeReward);
p.trData.timing.freeReward = GetSecs - ...
    p.trData.timing.trialStartPTB;

end