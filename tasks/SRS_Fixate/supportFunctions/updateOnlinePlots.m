function p               = updateOnlinePlots(p)

% the new Y value for updating the appropriate plot object is always the
% same, the trial index:
newY = p.status.iTrial;

% Was the last trial a hit, a miss, or a non-start? Depending on which
% state the last trial ended in, define the new "X" value and an index for
% updating the appropriate plot object:
switch p.trData.trialEndState
    case p.state.hit
        
        % what's the new "X" data value? Since the last trial was a hit, we
        % use the difference between the time when the joystick hold
        % duration requirement was met and the time that the joystick hold
        % began, note that this value is a little bit larger than the
        % actual hold duration requirement since the program can only log
        % that the requirement has been met at certain intervals dictated
        % by the "loop" (drawing, etc).
        newX = p.trData.timing.fixHoldReqMet - p.trData.timing.fixAq;
        plotInd = 1;
        
    case {p.state.miss, p.state.fixBreak}
        
        % what's the new "X" data value? Since the last trial was a miss,
        % we use the time that the joystick was released:
        newX = p.trData.timing.fixBreak  - p.trData.timing.fixAq;
        plotInd = 2;
        
    case p.state.nonStart
        
        % what's the new "X" data value? Since the last trial was a
        % non-start we set the x-value to 0;
        newX = 0;
        plotInd = 3;
end

% get existing X & Y values for plot object to be updated:
oldX = get(p.draw.onlinePlotObj(plotInd), 'XData');
oldY = get(p.draw.onlinePlotObj(plotInd), 'YData');

% update plot object by appending new X / Y data values and assigning to
% plot object:
set(p.draw.onlinePlotObj(plotInd), ...
    'XData', [oldX, newX], ...
    'YData', [oldY, newY]);

% update plot axes to make all data nicely visible; find the maximum X
% value across plot objects and multiply by 1.1 to set X-max.
xVals = cell2mat(get(p.draw.onlinePlotObj, 'XData')');
xMax = max(xVals(~isnan(xVals)));

% if xMax is either empty, NaN, or 0, set it to 1
if isnan(xMax) || isempty(xMax) || xMax == 0
    xMax = 1;
end

% assign new X / Y limits:
set(p.draw.onlinePlotAxes, 'XLim', xMax*[-0.1 1], 'YLim', [0 newY + 1]);

% 

% update figure window:
drawnow;

end