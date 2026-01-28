function postTrialTimeOut(p)
%   postTrialTimeOut(p)
%
% Applies a timeout period after error trials.
% For the Conflict Task, uses the timeoutAfterFa parameter (1.0 second).

% Define timeout duration based on trial end state
switch p.trData.trialEndState
    case {p.state.fixBreak, p.state.joyBreak, p.state.nonStart, ...
          p.state.noResponse, p.state.inaccurate}
        timeOutDur = p.trVars.timeoutAfterFa;
    otherwise
        timeOutDur = 0;
end

% timeNow is relative to trial Start
timeNow = GetSecs - p.trData.timing.trialStartPTB;

% Wait until the timeout interval has passed
while timeNow < (p.trData.timing.trialEnd + timeOutDur)
    WaitSecs(0.05);
    timeNow = GetSecs - p.trData.timing.trialStartPTB;
end

end
