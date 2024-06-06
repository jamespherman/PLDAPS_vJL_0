function c = fixBreakFun(c)

%
% c = fixBreakFun(c)
%
% Strobe "fixbreak", set c.trialState to "3" (fixation break), note the
% time of the fixation break, play the low-freq tone, and strobe "lowtone". 

% Fixation broken. Strobe fixbreak.
strobe(c.codes.fixbreak)

% set state "3" (fixation break).
c.trialState       = 3;

% note time of fixation break
c.timeBrokeFix     = GetSecs - c.trialStartTime;

% play low-freq tone and strobe "lowtone"
c = playTone(c, 'low');

en