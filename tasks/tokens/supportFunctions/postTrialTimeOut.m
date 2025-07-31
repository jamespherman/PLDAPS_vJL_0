function postTrialTimeOut(p)

%
% postTrialTimeOut(p)
%

% depending on the endState of the just-completed trial, define the
% duration of the timeOut
switch p.trData.trialEndState
    case p.state.miss
        timeOutDur = p.trVars.timeoutAfterMiss;
    case p.state.foilFa
        timeOutDur = p.trVars.timeoutAfterFoilFa;
        case p.state.fa
        timeOutDur = p.trVars.timeoutAfterFa;
    case p.state.fixBreak
        timeOutDur = p.trVars.timeoutAfterFixBreak;
    otherwise
        timeOutDur  = 0;
end

% timeNow is relative to trial Start (since "trialEnd" is also relative to
% trial start).
timeNow = GetSecs - p.trData.timing.trialStartPTB;

% hang out in while loop until the interval has passed
while timeNow < (p.trData.timing.trialEnd + timeOutDur)
    
    % wait 50ms
    WaitSecs(0.05);
    
    % recalculate what time it is now
    timeNow = GetSecs - p.trData.timing.trialStartPTB;
    
end


end