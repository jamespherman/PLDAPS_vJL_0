function [p] = singleReward(p)
%   [p] = singleReward(p)

% Function delivers a single reward
% 20211208 jph

%% setup:


reward_time = p.trVars.rewardDurationMs/1000;  % reward solenoid opening time (sec)

%% init reward via datapixx:

Volt        = 4.0;
pad         = 0.01;
wave_time   = reward_time+pad;
Dacrate     = 1000;
reward_Volt = [zeros(1,round(Dacrate*pad/2)) Volt*ones(1,int16(Dacrate*reward_time)) zeros(1,round(Dacrate*pad/2))];
ndacsamples = floor(Dacrate*wave_time);
dacBuffAddr = 6e6;
chnl        = 0;

% init Datapixx:
Datapixx('Open');
Datapixx('RegWrRd');
Datapixx('WriteDacBuffer', reward_Volt,dacBuffAddr,chnl);

%% go reward go:
Datapixx('SetDacSchedule', 0, Dacrate, ndacsamples, chnl, dacBuffAddr, ndacsamples);
Datapixx('StartDacSchedule');
Datapixx('RegWrRd');
