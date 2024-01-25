function p               = updateOnlinePlots(p)

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
    [p.trVars.stimOnPsthMinTime, p.trVars.stimOnPsthMaxTime]; ...   (13)
    [p.trVars.stimOnPsthMinTime, p.trVars.stimOnPsthMaxTime]; ...   (14)
    [p.trVars.stimOnPsthMinTime, p.trVars.stimOnPsthMaxTime]; ...   (15)
    [p.trVars.stimOnPsthMinTime, p.trVars.stimOnPsthMaxTime]; ...   (16)
    [p.trVars.stimChgPsthMinTime, p.trVars.stimChgPsthMaxTime]; ... (17)
    [p.trVars.stimChgPsthMinTime, p.trVars.stimChgPsthMaxTime]; ... (19)
    [p.trVars.stimChgPsthMinTime, p.trVars.stimChgPsthMaxTime]; ... (19)
    [p.trVars.stimChgPsthMinTime, p.trVars.stimChgPsthMaxTime]; ... (20)
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
% (13) Multiple stimulus onset (location 1)
% (14) Multiple stimulus onset (location 2)
% (15) Multiple stimulus onset (location 3)
% (16) Multiple stimulus onset (location 4)
% (17) Multiple stimulus change (location 1)
% (18) Multiple stimulus change (location 2)
% (19) Multiple stimulus change (location 3)
% (20) Multiple stimulus change (location 4)

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

        % make sure there are plot objects with trial data before we try to
        % update anything - since we have single stimulus trials and
        % multiple stimulus trials that happen in separate parts of the
        % block, the multiple stimulus trial plots don't update until after
        % the single stimulus trials have been completed:
        if p.draw.psthPlotAxes(i).Children(j).UserData.trialCount > 0

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
end

% update plot:
drawnow;

% Cued vs. uncued stimulus change plot

% update accumulators
if p.trVars.isStimChangeTrial
    if p.status.chgLoc(end) == 0 % No change trial, skip
    elseif p.status.chgLoc(end) == p.stim.cueLoc % Cued change trial
        p.status.cuedTotalCount.global = p.status.cuedTotalCount.global + 1;
        if p.trData.trialEndState == p.state.hit % if monkey is correct
            p.status.cuedHitCount.global = p.status.cuedHitCount.global + 1;
        end
    else
        % Foil change trial
        p.status.uncuedTotalCount.global = p.status.uncuedTotalCount.global + 1;
        if p.trData.trialEndState == p.state.hit
            p.status.uncuedHitCount.global = p.status.uncuedHitCount.global + 1;
        end
    end
end

% Compute performance
[cuedPerf, cuedPCI] = binofit(p.status.cuedHitCount.global, p.status.cuedTotalCount.global);
[uncuedPerf, uncuedPCI] = binofit(p.status.uncuedHitCount.global, p.status.uncuedTotalCount.global);

barHalfWidth = 0.25;

% Update the plot objects
fillXCued = 1 + barHalfWidth*[-1 1 1 -1 -1];
fillXUncued = 2 + barHalfWidth*[-1 1 1 -1 -1];
perfFillYCued = [cuedPCI(1) cuedPCI(1) cuedPCI(2) cuedPCI(2) cuedPCI(1)];
perfFillYUncued = [uncuedPCI(1) uncuedPCI(1) uncuedPCI(2) uncuedPCI(2) uncuedPCI(1)];

set(p.draw.onlineCuePerfFillObj(1), 'XData', fillXCued, 'YData', perfFillYCued);
set(p.draw.onlineCuePerfPlotObj(1), 'XData', fillXCued(1:2), 'YData', [cuedPerf cuedPerf]);
set(p.draw.onlineCuePerfFillObj(2), 'XData', fillXUncued, 'YData', perfFillYUncued);
set(p.draw.onlineCuePerfPlotObj(2), 'XData', fillXUncued(1:2), 'YData', [uncuedPerf uncuedPerf]);

% update ticks:
set(p.draw.onlineCuePerfPlotAxes, 'XTick', ...
    [1 2], 'XTickLabel', ...
    {'Cue Change', 'Foil Change'});

drawnow;

% Split cued vs. uncued stimulus change plot

% update accumulators
if p.trVars.isStimChangeTrial
    chgLoc = p.status.chgLoc(end); % The location of the change
    isHit = (p.trData.trialEndState == p.state.hit); % if monkey is correct

    if chgLoc == 0 % No change trial, skip
    elseif chgLoc == p.stim.cueLoc % Cued change trial
        p.status.cuedTotalCount.global = p.status.cuedTotalCount.global + 1;
        p.status.cuedTotalCount.(['loc' num2str(chgLoc)]) = p.status.cuedTotalCount.(['loc' num2str(chgLoc)]) + 1;

        if isHit
            p.status.cuedHitCount.global = p.status.cuedHitCount.global + 1;
            p.status.cuedHitCount.(['loc' num2str(chgLoc)]) = p.status.cuedHitCount.(['loc' num2str(chgLoc)]) + 1;
        end
    else
        % Foil change trial
        p.status.uncuedTotalCount.global = p.status.uncuedTotalCount.global + 1;
        p.status.uncuedTotalCount.(['loc' num2str(chgLoc)]) = p.status.uncuedTotalCount.(['loc' num2str(chgLoc)]) + 1;

        if isHit
            p.status.uncuedHitCount.global = p.status.uncuedHitCount.global + 1;
            p.status.uncuedHitCount.(['loc' num2str(chgLoc)]) = p.status.uncuedHitCount.(['loc' num2str(chgLoc)]) + 1;
        end
    end
end


% Define bar half width
barHalfWidth = 0.25;

% Adjusted X positions
xPosCued1 = 0.5;
xPosFoil1 = 0.7;
xPosFoil2 = 1.0; % Only Foil
xPosCued3 = 1.3;
xPosFoil3 = 1.5;
xPosFoil4 = 1.8; % Only Foil

% Colors for the plots
cueColors = {[0, 1, 0], [0, 0.8, 0]}; % Two shades of green
foilColors = {[1, 0, 0], [0.8, 0, 0]}; % Two shades of red

% Update plot objects
for i = 1:6
    loc = ceil(i / 2); % Determine the actual location (1, 2, 3, 4)
    
    % Check if cued or foil and if the location exists
    if ismember(i, [1, 4]) % Cued Locations (1 and 3)
        perfCount = p.status.cuedHitCount.(['loc' num2str(loc)]);
        totalCount = p.status.cuedTotalCount.(['loc' num2str(loc)]);
        color = cueColors{1};
    else
        perfCount = p.status.uncuedHitCount.(['loc' num2str(loc)]);
        totalCount = p.status.uncuedTotalCount.(['loc' num2str(loc)]);
        color = foilColors{1};
    end

    % Compute performance and confidence interval
    [perf, pci] = binofit(perfCount, totalCount);

    % Set x positions for the plots
    if i == 1
        fillX = xPosCued1 + barHalfWidth*[-1 1 1 -1 -1];
    elseif i == 2
        fillX = xPosFoil1 + barHalfWidth*[-1 1 1 -1 -1];
    elseif i == 3
        fillX = xPosFoil2 + barHalfWidth*[-1 1 1 -1 -1];
    elseif i == 4
        fillX = xPosCued3 + barHalfWidth*[-1 1 1 -1 -1];
    elseif i == 5
        fillX = xPosFoil3 + barHalfWidth*[-1 1 1 -1 -1];
    else % i == 6
        fillX = xPosFoil4 + barHalfWidth*[-1 1 1 -1 -1];
    end

    perfFillY = [pci(1) pci(1) pci(2) pci(2) pci(1)];

    % Update the plot objects
    set(p.draw.onlineSplitCuePerfFillObj(i), 'XData', fillX, 'YData', perfFillY, 'FaceColor', color);
    set(p.draw.onlineSplitCuePerfPlotObj(i), 'XData', fillX(1:2), 'YData', [perf perf], 'Color', color);

    % Update X-ticks for grouped labels
    set(p.draw.onlineSplitCuePerfPlotAxes, 'XTick', [0.6, 1.0, 1.4, 1.8], 'XTickLabel', {'1', '2', '3', '4'});

end



% Update ticks
set(p.draw.onlineSplitCuePerfPlotAxes, 'XTick', xPositions, 'XTickLabel', {'Cued 1', 'Foil 1', 'Foil 2', 'Cued 3', 'Foil 3', 'Foil 4'});

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