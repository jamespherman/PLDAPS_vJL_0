function p = setSchedules(p)

% c = setSchedules(p)
%
% Define ("set") scheduls for analog to digital converter (ADC) and digital
% to analog converter (DAC) on VIEWPixx / DATAPixx.

% Set ADC schedule with a buffer of "maxDur" seconds sampling "adcRate"
% samples / second.
Datapixx('SetAdcSchedule', ...
    0, ...                          % start delay (s)
    p.rig.dp.adcRate, ...                  % samping rate
    p.rig.dp.adcRate * p.rig.dp.maxDurADC, ...      % memory buffer size in samples
    [0 1 2 3], ...                  % list of channels to sample from
    p.rig.dp.adcBuffAddr, ...              % memory buffer base address
    p.rig.dp.adcRate * p.rig.dp.maxDurADC ...      % number of buffer frames (redundant)
    );
Datapixx('RegWrRd');

% Build a square wave of the desired duration to output on the DAC for
% controlling the liquid reward solenoid open duration. Pad the +4v square
% wave with 10ms of zeros on either side to avoid unwanted weirdness with
% the DAC.
dacWaveOutDur   = p.trVars.rewardDurationMs / 1e3 + p.rig.dp.dacPadDur; % duration in seconds
dacWaveOut      = [zeros(1, p.rig.dp.dacRate * p.rig.dp.dacPadDur / 2) ...
    4 * ones(1,p.rig.dp.dacRate * p.trVars.rewardDurationMs / 1e3) ...
    zeros(1,p.rig.dp.dacRate * p.rig.dp.dacPadDur / 2)];

% Set DAC schedule (for reward system) for channel
Datapixx('RegWrRd');
Datapixx('WriteDacBuffer', ...
    dacWaveOut, p.rig.dp.dacBuffAddr, p.rig.dp.dacChannelOut);
Datapixx('SetDacSchedule', 0, p.rig.dp.dacRate, fix(dacWaveOutDur * p.rig.dp.dacRate), ...
    0, p.rig.dp.dacBuffAddr, fix(dacWaveOutDur * p.rig.dp.dacRate));
Datapixx('RegWrRd');

end