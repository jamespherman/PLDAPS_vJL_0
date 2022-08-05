function [tPTB, tDP] = getTimes

Datapixx('RegWrRd');
tPTB    = GetSecs;
tDP     = Datapixx('GetTime');
end