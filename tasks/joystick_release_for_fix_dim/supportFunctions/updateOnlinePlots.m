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

        % if this was a "release after fix off" trial, use one plotInd. If
        % this was a "release after reward" trial, use another:
        if p.trVars.isRelOnFixOffTrial
            plotInd = 4;
        else
            plotInd = 1;
        end

    case p.state.fixBreak
        
        % if he never started fixating, we don't code this the same way:
        if p.trData.timing.fixAq < 0
            newX = 0;
            plotInd = 3;
        else
            % what's the new "X" data value? Since the last trial was a miss,
            % we use the time that the joystick was released:
            try
                newX = p.trData.timing.fixBreak  - p.trData.timing.fixAq;
            catch me
                keyboard
            end
            plotInd = 2;
        end
        
    case p.state.joyBreak
        
        % if he never started fixating, we don't code this the same way:
        if p.trData.timing.fixAq < 0
            newX = 0;
            plotInd = 3;
        else
            % what's the new "X" data value? Since the last trial was a miss,
            % we use the time that the joystick was released:
            try
                newX = p.trData.timing.joyRelease - p.trData.timing.fixAq;
            catch me
                keyboard
            end
            plotInd = 2;
        end
    
    case p.state.miss

        % if this was a miss, set the x value to 0
        newX = 0;

        % plotInd determines which existing plot object we're going to add
        % the current trial's data to:
        plotInd = 5;
        
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

% get eye X & Y data both before and after fixation acquisition RELATIVE TO
% FIXATION LOCATION. If fixation wasn't acquired in this trial, assign 
% "NaN" to post-fixation-aquisition eye X & Y; if fixation was acquired in
% this trial, define a logicalindex for pre-fixation-acquisition time
% samples:
eyeX = 4 * p.trData.eyeX;
eyeY = 4 * p.trData.eyeY;
eyeT = p.trData.eyeT;
if p.trData.timing.fixAq < 0
    eyeX_preFixAq = eyeX - p.trVars.fixDegX;
    eyeY_preFixAq = eyeY - p.trVars.fixDegY;
    eyeX_postFixAq = NaN;
    eyeY_postFixAq = NaN;
else
    preFixAqLogical = eyeT < p.trData.timing.fixAq;
    eyeX_preFixAq = eyeX(preFixAqLogical) - p.trVars.fixDegX;
    eyeY_preFixAq = eyeY(preFixAqLogical) - p.trVars.fixDegY;
    eyeX_postFixAq = eyeX(~preFixAqLogical) - p.trVars.fixDegX;
    eyeY_postFixAq = eyeY(~preFixAqLogical) - p.trVars.fixDegY;
end
    
% update onlineEyePlots:
set(p.draw.onlineEyePlotObj(1), ...
    'XData', p.trVars.fixWinWidthDeg*[-1 1 1 -1 -1], ...
    'YData', p.trVars.fixWinHeightDeg*[-1 -1 1 1 -1]);
set(p.draw.onlineEyePlotObj(2), ...
    'XData', eyeX_preFixAq, ...
    'YData', eyeY_preFixAq);
set(p.draw.onlineEyePlotObj(3), ...
    'XData', eyeX_postFixAq, ...
    'YData', eyeY_postFixAq);

% set X & Y limits of onlineEyePlotAxes:
set(p.draw.onlineEyePlotAxes, ...
    'XLim', p.trVars.fixWinWidthDeg * [-1 1] + [-1 1], ...
    'YLim', p.trVars.fixWinHeightDeg * [-1 1] + [-1 1]);

% update figure window:
drawnow;

end