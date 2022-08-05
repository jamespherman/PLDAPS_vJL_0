function p = deliverReward(p)

%
% p = deliverReward(p)
%
% strobe reward, start dac schedule, note time of reward delivery

Datapixx('StartDacSchedule');
Datapixx('RegWrRd');
p.init.strb.strobeNow(p.init.codes.reward);
p.trData.timing.reward = GetSecs - p.trData.timing.trialStartPTB;