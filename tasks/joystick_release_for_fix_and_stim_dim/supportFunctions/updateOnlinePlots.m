function p               = updateOnlinePlots(p)

% keep a running log of trial end states, reaction times, and dimVals. If
% only the peripheral stimulus dimmed on this trial, define this as a
% "negative" dimVal for the purposes of plotting:
p.status.trialEndStates(p.status.iTrial)    = p.trData.trialEndState;
p.status.reactionTimes(p.status.iTrial)     = p.trData.timing.reactionTime;
p.status.dimVals(p.status.iTrial)           = p.trData.dimVal * ...
    (-1)^p.trVars.isStimDimOnlyTrial;

% the new Y value for updating the appropriate plot object is always the
% same, the trial index:
newY = p.status.iTrial;

plotInd = 0;

% Was the last trial a hit, a miss, or a non-start? Depending on which
% state the last trial ended in, define the new "X" value and an index for
% updating the appropriate plot object. These new "X" values and "plotInd"s
% are for the trial-by-trial data plot. Since we also want to plot
% aggregate data across trials, we need to store across-trials data here
% since we save each trial's data at the end of the trial and discard it
% rather than keeping it in "p". We need to log trial end state and
% reaction time.
switch p.trData.trialEndState
    case p.state.hit
        
        % what's the new "X" data value? Since the last trial was a hit, we
        % use the difference between the time when the joystick hold
        % duration requirement was met and the time that the joystick hold
        % began, note that this value is a little bit larger than the
        % actual hold duration requirement since the program can only log
        % that the requirement has been met at certain intervals dictated
        % by the "loop" (drawing, etc).
        newX = p.trData.timing.joyRelease - p.trData.timing.fixAq;
        plotInd = 4;

    case p.state.cr

        % what's the new "X" data value? Since the last trial was a hit, we
        % use the difference between the time when the joystick hold
        % duration requirement was met and the time that the joystick hold
        % began, note that this value is a little bit larger than the
        % actual hold duration requirement since the program can only log
        % that the requirement has been met at certain intervals dictated
        % by the "loop" (drawing, etc).
        newX = p.trData.timing.fixHoldReqMet - p.trData.timing.fixAq;
        plotInd = 1;

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
        
    case {p.state.joyBreak, p.state.fa}
        
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

% Here we will compute aggregate performance (percent correct) and reaction
% time. We first define which trials we're interested in numerically based
% on the variable "p.trVars.numTrialsForPerfCalc", then we only keep the
% numerical indexes of hits or misses:
firstTrial = max([1, p.status.iTrial - p.trVars.numTrialsForPerfCalc]);
lastTrial  = p.status.iTrial;
perfComputeTrialsIdx = firstTrial:lastTrial;
perfComputeTrialsIdx = ...
    perfComputeTrialsIdx(p.status.trialEndStates(perfComputeTrialsIdx) ...
    > 20);

% make temporary variables to hold the data we're currently interested in:
tempStates          = p.status.trialEndStates(perfComputeTrialsIdx);
tempReactionTimes   = p.status.reactionTimes(perfComputeTrialsIdx);
tempDimVals         = p.status.dimVals(perfComputeTrialsIdx);

% find unique values of "dimVals":
uniqueDimVals       = unique(tempDimVals);
nDimVals            = length(uniqueDimVals);

% make sure we actually have dimVals to work with and nothing hinky has
% happened:
if nDimVals > 0

    % compute bar width based on minimum difference between unique dim vals:
    barHalfWidth = min(diff(uniqueDimVals))*0.4;
    if isempty(barHalfWidth)
        barHalfWidth = 0.4;
    end

    % if the number of plot objects we have matches the number of unique dim
    % values we'll just replace the X / Y data for each plot object, but if we
    % have a mismatch, we'll delete extra plot objects or add new ones before
    % we replace the X / Y data:
    nPlotObj = length(p.draw.onlinePerfFillObj);
    if  nPlotObj > nDimVals

        % index plot objects to be deleted:
        deleteIdx = (nDimVals+1):nPlotObj;

        % delete plot objects:
        delete([...
            p.draw.onlinePerfFillObj(deleteIdx), ...
            p.draw.onlineRtFillObj(deleteIdx), ...
            p.draw.onlinePerfPlotObj(deleteIdx), ...
            p.draw.onlineRtPlotObj(deleteIdx), ...
            ]);

        % get rid of extra entries in vectors:
        p.draw.onlinePerfFillObj(deleteIdx) = [];
        p.draw.onlineRtFillObj(deleteIdx) = [];
        p.draw.onlinePerfPlotObj(deleteIdx) = [];
        p.draw.onlineRtPlotObj(deleteIdx) = [];

    elseif nPlotObj < nDimVals

        % add extra plot objects to the end of the plot object vectors:
        p.draw.onlinePerfFillObj((nPlotObj+1):nDimVals) = ...
            copyobj(p.draw.onlinePerfFillObj(1), ...
            repmat(p.draw.onlinePerfPlotAxes, 1, nDimVals - nPlotObj));
        p.draw.onlineRtFillObj((nPlotObj+1):nDimVals)   = ...
            copyobj(p.draw.onlineRtFillObj(1), ...
            repmat(p.draw.onlineRtPlotAxes, 1, nDimVals - nPlotObj));
        p.draw.onlinePerfPlotObj((nPlotObj+1):nDimVals) = ...
            copyobj(p.draw.onlinePerfPlotObj(1), ...
            repmat(p.draw.onlinePerfPlotAxes, 1, nDimVals - nPlotObj));
        p.draw.onlineRtPlotObj((nPlotObj+1):nDimVals)   = ...
            copyobj(p.draw.onlineRtPlotObj(1), ...
            repmat(p.draw.onlineRtPlotAxes, 1, nDimVals - nPlotObj));
    end

    % loop over unique values of "dimVals" to compute average performance,
    % median reaction time, and error bars:
    for i = 1:length(uniqueDimVals)

        % if the dimVal is 0, we count "hits" differently since correct
        % performance with a dimVal of 0 is a CR:
        if uniqueDimVals(i) == 0
            % count CRs and total trials for currently considered dimVal
            hitCount    = nnz(tempStates == p.state.cr & ...
                tempDimVals == uniqueDimVals(i));
            totalCount  = nnz(tempStates > 20 & ...
                tempDimVals == uniqueDimVals(i));
        else
            % count hits and total trials for currently considered dimVal
            hitCount    = nnz(tempStates == p.state.hit & ...
                tempDimVals == uniqueDimVals(i));
            totalCount  = nnz(tempStates > 20 & ...
                tempDimVals == uniqueDimVals(i));
        end

        % compute performance and confidence interval:
        [perf, pci] = binofit(hitCount, totalCount);

        % compute median reaction time and confidence interval:
        [med, mci] = medci(tempReactionTimes(tempDimVals == ...
            uniqueDimVals(i) & tempReactionTimes > 0));

        % define x / y vectors for fill objects; note that we only need a
        % single X vector for both performance and RT:
        fillX       = uniqueDimVals(i) + barHalfWidth*[-1 1 1 -1 -1];
        perfFillY   = [pci(1) pci(1) pci(2) pci(2) pci(1)];
        rtFillY     = [mci(1) mci(1) mci(2) mci(2) mci(1)];

        % update x/y data of plot objects:
        p.draw.onlinePerfFillObj(i).XData   = fillX;
        p.draw.onlineRtFillObj(i).XData     = fillX;
        p.draw.onlinePerfFillObj(i).YData   = perfFillY;
        p.draw.onlineRtFillObj(i).YData     = rtFillY;
        p.draw.onlinePerfPlotObj(i).XData   = fillX(1:2);
        p.draw.onlineRtPlotObj(i).XData     = fillX(1:2);
        p.draw.onlinePerfPlotObj(i).YData   = perf*[1 1];
        p.draw.onlineRtPlotObj(i).YData     = med*[1 1];
    end

    % update axis x / y limits?
end

% update figure windows:
drawnow;

end

function [med, mci] = medci(X)

p = prctile(X,[25 50 75]);

med = p(2);
mci = p(2) + [-1; 1]*1.57*(p(3)-p(1))/sqrt(length(X));
end