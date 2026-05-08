function postTrialTimeOut(p)

%
% postTrialTimeOut(p)
%

% depending on the endState of the just-completed trial, define the
% duration of the timeOut
switch p.trData.trialEndState
    otherwise
        timeOutDur  = 0;
end

% timeNow is relative to trial Start (since "trialEnd" is also relative to
% trial start).
timeNow = GetSecs - p.trData.timing.trialStartPTB;

% hang out in while loop until the interval has passed
while timeNow < (p.trData.timing.trialEnd + timeOutDur)
    
    % let's try to wait 95% of the time (rounded to the nearest 10ms)
    % remaining.
    WaitSecs(0.05);
    
    % recalculate what time it is now
    timeNow = GetSecs - p.trData.timing.trialStartPTB;
    
end


end