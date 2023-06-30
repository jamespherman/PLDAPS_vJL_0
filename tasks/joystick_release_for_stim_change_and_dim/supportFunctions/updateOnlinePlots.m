function p               = updateOnlinePlots(p)

% keep a running log of trial end states, reaction times, and dimVals. If
% only the peripheral stimulus dimmed on this trial, define this as a
% "negative" dimVal for the purposes of plotting, if this was a no-change
% trial, instead define the dimVal as 0.
p.status.trialEndStates(p.status.iTrial)    = p.trData.trialEndState;
p.status.reactionTimes(p.status.iTrial)     = p.trData.timing.reactionTime;
p.status.dimVals(p.status.iTrial)           = p.trData.dimVal * ...
    ((-1)^p.trVars.isStimChgNoDim) * p.trVars.isStimChangeTrial;

% make a big list of PSTH min / max times so we can make our code the most
% efficient it can be:
psthLims = [...
    [p.trVars.fixOnPsthMinTime, p.trVars.fixOnPsthMaxTime]; ...     (1)
    [p.trVars.stimOnPsthMinTime, p.trVars.stimOnPsthMaxTime]; ...   (2)
    [p.trVars.stimOnPsthMinTime, p.trVars.stimOnPsthMaxTime]; ...   (3)
    [p.trVars.stimOnPsthMinTime, p.trVars.stimOnPsthMaxTime]; ...   (4)
    [p.trVars.stimOnPsthMinTime, p.trVars.stimOnPsthMaxTime]; ...   (5)
    [p.trVars.stimChgPsthMinTime, p.trVars.stimChgPsthMaxTime]; ... (6)
    [p.trVars.stimChgPsthMinTime, p.trVars.stimChgPsthMaxTime]; ... (7)
    [p.trVars.stimChgPsthMinTime, p.trVars.stimChgPsthMaxTime]; ... (8)
    [p.trVars.stimChgPsthMinTime, p.trVars.stimChgPsthMaxTime]; ... (9)
    [p.trVars.rwdPsthMinTime, p.trVars.rwdPsthMaxTime]; ...         (10)
    [p.trVars.freeRwdPsthMinTime, p.trVars.freeRwdPsthMaxTime]; ... (11)
    [p.trVars.freeRwdPsthMinTime, p.trVars.freeRwdPsthMaxTime]; ... (12)
    ];

% for each of our 11 online-plotted PSTHs we recompute the binned counts
% and assign the x / y data to the plot object here.

% (1) Fixation onset
% (2) Stimulus onset (location 1)
% (3) Stimulus onset (location 2)
% (4) stimulus onset (location 3)
% (5) Stimulus onset (location 4)
% (6) Stimulus change (location 1)
% (7) Stimulus change (location 2)
% (8) Stimulus change (location 3)
% (9) Stimulus change (location 4)
% (10) Reward
% (11) Free reward
% (12) no free reward

for i = 1:length(p.draw.onlinePlotObj)

    % construct the PSTH:
    [n, bins] = histcounts(p.draw.onlinePlotObj(i).UserData.spTimes, ...
        'BinLimits', ...
        psthLims(i,:), ...
        'BinWidth', p.trVars.psthBinWidth);

    % make bin centers vector:
    binCtrs = mean([bins(1:end-1); bins(2:end)]);

    % assign to plot object:
    set(p.draw.onlinePlotObj(i), 'XData', binCtrs, 'YData', ...
        (n/p.draw.onlinePlotObj(i).UserData.trialCount) / ...
        p.trVars.psthBinWidth);
end

% update legend entries for psth plots by looping over axes:
for i = 1:length(p.draw.psthPlotAxes)

    % loop over plots in current axes to update legend entries, number of
    % plots is stored in 'UserData':
    for j = 1:p.draw.psthPlotAxes(i).UserData

        % there is a STUPID lack of correspondence between the ordering of
        % an axes 'children' and the legend string entries. Children are
        % stored last to first, so we have to make a "reversed" index for
        % the legend strings to keep everything aligned:
        legIdx = p.draw.psthPlotAxes(i).UserData - j + 1;

        % what is the trial count for the current plot object? Defining
        % this as a temporary variable lets us keep the code a bit cleaner.
        currCount = p.draw.psthPlotAxes(i).Children(j).UserData.trialCount;

        % use "regexprep" to replace the placeholder string 'XX' with the
        % trial count:
        p.draw.onlinePlotLegend(i).String{legIdx} = ...
            regexprep(p.draw.onlinePlotLegend(i).UserData{j}, 'XX', ...
            num2str(currCount));
    end
end

% update plot:
drawnow;

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

% update ticks:
set([p.draw.onlinePerfPlotAxes, p.draw.onlineRtPlotAxes], 'XTick', ...
    [-1 0 1], 'XTickLabel', ...
    {'hue change only', 'no change', 'dim + hue change'});

% update figure windows:
drawnow;

end

function [med, mci] = medci(X)

p = prctile(X,[25 50 75]);

med = p(2);
mci = p(2) + [-1; 1]*1.57*(p(3)-p(1))/sqrt(length(X));
end