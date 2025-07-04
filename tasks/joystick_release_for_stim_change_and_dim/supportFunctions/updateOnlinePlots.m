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

% % only try to update the plot if it's still open!
% if isgraphics(p.draw.onlinePlotWindow)
% for i = 1:length(p.draw.onlinePlotObj)
% 
%     % construct the PSTH:
%     [n, bins] = histcounts(p.draw.onlinePlotObj(i).UserData.spTimes, ...
%         'BinLimits', ...
%         psthLims(i,:), ...
%         'BinWidth', p.trVars.psthBinWidth);
% 
%     % make bin centers vector:
%     binCtrs = mean([bins(1:end-1); bins(2:end)]);
% 
%     % assign to plot object:
%     set(p.draw.onlinePlotObj(i), 'XData', binCtrs, 'YData', ...
%         (n/p.draw.onlinePlotObj(i).UserData.trialCount) / ...
%         p.trVars.psthBinWidth);
% end
% 
% % update legend entries for psth plots by looping over axes:
% for i = 1:length(p.draw.psthPlotAxes)
% 
%     % loop over plots in current axes to update legend entries, number of
%     % plots is stored in 'UserData':
%     for j = 1:p.draw.psthPlotAxes(i).UserData
% 
%         % make sure there are plot objects with trial data before we try to
%         % update anything - since we have single stimulus trials and
%         % multiple stimulus trials that happen in separate parts of the
%         % block, the multiple stimulus trial plots don't update until after
%         % the single stimulus trials have been completed:
%         if p.draw.psthPlotAxes(i).Children(j).UserData.trialCount > 0
% 
%             % there is a STUPID lack of correspondence between the ordering of
%             % an axes 'children' and the legend string entries. Children are
%             % stored last to first, so we have to make a "reversed" index for
%             % the legend strings to keep everything aligned:
%             legIdx = p.draw.psthPlotAxes(i).UserData - j + 1;
% 
%             % what is the trial count for the current plot object? Defining
%             % this as a temporary variable lets us keep the code a bit cleaner.
%             currCount = p.draw.psthPlotAxes(i).Children(j).UserData.trialCount;
% 
%             % use "regexprep" to replace the placeholder string 'XX' with the
%             % trial count:
%             p.draw.onlinePlotLegend(i).String{legIdx} = ...
%                 regexprep(p.draw.onlinePlotLegend(i).UserData{j}, 'XX', ...
%                 num2str(currCount));
%         end
%     end
% end

% % update plot:
% drawnow;
% end

% Cued vs. uncued stimulus change plot

% update accumulators

% if it's a no change trial (redundancy) or a one-stimulus trial, skip
if p.trVars.isStimChangeTrial && p.stim.nStim ~= 1

    if p.status.chgLoc(end) == 0 % No change trial, skip

        % if it's a cued change trial, add to the total number of cued change
        % trials
    elseif p.status.chgLoc(end) == p.stim.cueLoc
        p.status.cuedTotalCount.global = ...
            p.status.cuedTotalCount.global + 1;

        % if it's a correct response, add to the cued hit count
        if p.trData.trialEndState == p.state.hit
            p.status.cuedHitCount.global = ...
                p.status.cuedHitCount.global + 1;
        end


        % if it's an uncued change trial, add to the total number of uncued
        % change trials
    else
        p.status.uncuedTotalCount.global = ...
            p.status.uncuedTotalCount.global + 1;
        if p.trData.trialEndState == p.state.hit
            p.status.uncuedHitCount.global = ...
                p.status.uncuedHitCount.global + 1;
        end
    end
end

% Compute performance
[cuedPerf, cuedPCI] = binofit(p.status.cuedHitCount.global, ...
    p.status.cuedTotalCount.global);
[uncuedPerf, uncuedPCI] = binofit(p.status.uncuedHitCount.global, ...
    p.status.uncuedTotalCount.global);

barHalfWidth = 0.25;

% Bar colors
cueColor = [12 123 220] / 255; % blue
uncuedColor = [255 194 10] / 255; % gold

% Update the plot objects
fillXCued = 1 + barHalfWidth*[-1 1 1 -1 -1];
fillXUncued = 2 + barHalfWidth*[-1 1 1 -1 -1];

% Define y data for performance fill
perfFillYCuedGlobal = [cuedPCI(1) cuedPCI(1) cuedPCI(2) ...
    cuedPCI(2) cuedPCI(1)];
perfFillYUncuedGlobal = [uncuedPCI(1) uncuedPCI(1) uncuedPCI(2) ...
    uncuedPCI(2) uncuedPCI(1)];

% only update plot if window is still open:
if isgraphics(p.draw.onlineCuePerfPlotWindow)
set(p.draw.onlineCuePerfFillObj(1), 'XData', fillXCued, ...
    'YData', perfFillYCuedGlobal, 'FaceColor', cueColor);
set(p.draw.onlineCuePerfPlotObj(1), 'XData', fillXCued(1:2), ...
    'YData', [cuedPerf cuedPerf]);
set(p.draw.onlineCuePerfFillObj(2), 'XData', fillXUncued, ...
    'YData', perfFillYUncuedGlobal, 'FaceColor', uncuedColor);
set(p.draw.onlineCuePerfPlotObj(2), 'XData', fillXUncued(1:2), ...
    'YData', [uncuedPerf uncuedPerf]);

% update ticks:
set(p.draw.onlineCuePerfPlotAxes, 'XTick', ...
    [1 2], 'XTickLabel', ...
    {'Cued Change', 'Uncued Change'});

drawnow;
end

% Split cued vs. uncued stimulus change plot

% update accumulators

% if it's a no change trial (redundancy) or a one-stimulus trial, skip
if p.trVars.isStimChangeTrial && p.stim.nStim ~= 1
    chgLoc = p.status.chgLoc(end); % The location of the change
    isHit = (p.trData.trialEndState == p.state.hit); % if monkey is correct

    % if it's a no change trial (redundancy), skip
    if chgLoc == 0


        % if it's a cued change trial, add to the total number of cued change
        % trials
    elseif chgLoc == p.stim.cueLoc
        p.status.cuedTotalCount.global = p.status.cuedTotalCount.global + 1;
        % p.status.cuedTotalCount.(['loc' num2str(chgLoc)]) = p.status.cuedTotalCount.(['loc' num2str(chgLoc)]) + 1;

        % if it's a correct response, add to the cued hit count
        if isHit
            p.status.cuedHitCount.global = p.status.cuedHitCount.global + 1;
            % p.status.cuedHitCount.(['loc' num2str(chgLoc)]) = p.status.cuedHitCount.(['loc' num2str(chgLoc)]) + 1;
        end


        % if it's an uncued change trial, add to the total number of uncued
        % change trials
    else
        p.status.uncuedTotalCount.global = p.status.uncuedTotalCount.global + 1;
        % p.status.uncuedTotalCount.(['loc' num2str(chgLoc)]) = p.status.uncuedTotalCount.(['loc' num2str(chgLoc)]) + 1;

        % if it's a correct response, add to the uncued hit count
        if isHit
            p.status.uncuedHitCount.global = p.status.uncuedHitCount.global + 1;
            % p.status.uncuedHitCount.(['loc' num2str(chgLoc)]) = p.status.uncuedHitCount.(['loc' num2str(chgLoc)]) + 1;
        end
    end
end

% Update plot objects
xPosCued1 = 0.5 + 0.2;
xPosUncued1 = 0.62 + 0.2;
xPosCued3 = 1.38 - 0.2;
xPosUncued3 = 1.5 - 0.2;

xPositions = [xPosCued1, xPosUncued1, xPosCued3, xPosUncued3];

barHalfWidth = 0.05;

% only try to draw if window is open!
if isgraphics(p.draw.onlineCuePerfPlotWindow)
for i = 1:length(xPositions)
    loc = ceil(i / 2); % Determine actual location (1 and 3)

    % Check if cued or uncued and assign the correct color
    if loc == 1 && mod(i, 2) == 1 % Cued Location 1
        perfCount = p.status.cuedHitCount.loc1;
        totalCount = p.status.cuedTotalCount.loc1;
    elseif loc == 1 % Uncued Location 1
        perfCount = p.status.uncuedHitCount.loc1;
        totalCount = p.status.uncuedTotalCount.loc1;
    elseif loc == 3 && mod(i, 2) == 1 % Cued Location 3
        perfCount = p.status.cuedHitCount.loc3;
        totalCount = p.status.cuedTotalCount.loc3;
    else % Uncued Location 3
        perfCount = p.status.uncuedHitCount.loc3;
        totalCount = p.status.uncuedTotalCount.loc3;
    end

  
    [perf, pci] = binofit(perfCount, totalCount);

    fillX = xPositions(i) + barHalfWidth * [-1 1 1 -1 -1];
    perfFillY = [pci(1) pci(1) pci(2) pci(2) pci(1)];

    if mod(i, 2) == 1
        color = cueColor;
    else
        color = uncuedColor;
    end

    % Update plot objects
    set(p.draw.onlineSplitCuePerfFillObj(i), 'XData', fillX, ...
        'YData', perfFillY, 'FaceColor', color);
    set(p.draw.onlineSplitCuePerfPlotObj(i), 'XData', fillX(1:2), ...
        'YData', [perf perf]);
end

% Positions for the grouped tick labels
centerPos1 = mean([xPosCued1, xPosUncued1]);
centerPos3 = mean([xPosCued3, xPosUncued3]);
set(p.draw.onlineSplitCuePerfPlotAxes, 'XTick', ...
    [centerPos1, centerPos3], 'XTickLabel', {'Location 1', 'Location 3'});

% Dummy plot objects for the legend
hold(p.draw.onlineSplitCuePerfPlotAxes, 'on');
dummyCue = plot(p.draw.onlineSplitCuePerfPlotAxes, NaN, NaN, ...
    's', 'Color', cueColor, 'MarkerFaceColor', cueColor, 'MarkerSize', 10);
dummyUncued = plot(p.draw.onlineSplitCuePerfPlotAxes, NaN, NaN, ...
    's', 'Color', uncuedColor, 'MarkerFaceColor', uncuedColor, ...
    'MarkerSize', 10);

% Legend
lgd = legend(p.draw.onlineSplitCuePerfPlotAxes, ...
    [dummyCue, dummyUncued], {'Cued', 'Uncued'}, ...
    'Location', 'northoutside', 'Orientation', 'horizontal');
title(lgd, 'Change Type');

hold(p.draw.onlineSplitCuePerfPlotAxes, 'off');
drawnow;
end

% Confusion matrix plot

% end states - success:
% p.state.hit             = 21;
% p.state.cr              = 22;
% p.state.miss            = 23;
% p.state.foilFa          = 24;
% p.state.fa              = 25;

% we're going to plot 6 categories of behavioral response:
% 1 - single stimulus hits
% 2 - single stimulus FAs
% 3 - single stimulus OTHER (non starts / joybreaks / etc).
% 4 - multi stimulus hits
% 5 - multi stimulus FAs
% 6 - multi stimulus OTHER (non starts / joybreaks / etc).
% We count all of them up then we plot:
singleHits = nnz(p.status.trialEndStates == ...
    p.state.hit & p.status.nStim == 1);
singleFAs  = nnz(p.status.trialEndStates == ...
    p.state.fa & p.status.nStim == 1);
singleOther = nnz(p.status.trialEndStates < p.state.hit & ...
    p.status.nStim == 1);
singleHitsDenom = nnz(ismember(p.status.trialEndStates, ...
    [p.state.hit p.state.miss]) & p.status.nStim == 1);
singleFAsDenom = nnz(ismember(p.status.trialEndStates, ...
    [p.state.fa p.state.cr]) & p.status.nStim == 1);
singleOtherDenom = nnz(p.status.nStim == 1);
multiHits = nnz(p.status.trialEndStates == ...
    p.state.hit & p.status.nStim > 1);
multiFAs  = nnz(p.status.trialEndStates == ...
    p.state.fa & p.status.nStim > 1);
multiOther = nnz(p.status.trialEndStates < p.state.hit & ...
    p.status.nStim > 1);
multiHitsDenom = nnz(ismember(p.status.trialEndStates, ...
    [p.state.hit p.state.miss]) & p.status.nStim > 1);
multiFAsDenom = nnz(ismember(p.status.trialEndStates, ...
    [p.state.fa p.state.cr]) & p.status.nStim > 1);
multiOtherDenom = nnz(p.status.nStim > 1);
[confusionRates, confusionErrorBars] = binofit(...
    [singleHits, singleFAs, singleOther, multiHits, multiFAs, ...
    multiOther], [singleHitsDenom, singleFAsDenom, singleOtherDenom, ...
    multiHitsDenom, multiFAsDenom, multiOtherDenom]);

% Calculate hit rate, miss rate, change false alarm rate, no change false alarm rate, and correct reject rate
hitRate = p.status.totalHits / (p.status.totalHits + p.status.totalMisses);
missRate = p.status.totalMisses / (p.status.totalHits + p.status.totalMisses);
changeFalseAlarmRate = p.status.totalChangeFalseAlarms / (p.status.totalHits + p.status.totalMisses + p.status.totalChangeFalseAlarms);
noChangeFalseAlarmRate = p.status.totalNoChangeFalseAlarms / (p.status.totalCorrectRejects + p.status.totalNoChangeFalseAlarms);
correctRejectRate = p.status.totalCorrectRejects / (p.status.totalCorrectRejects + p.status.totalNoChangeFalseAlarms);

% Calculate error bars
z = 1.96; % 95%
hitErrorBar = z * sqrt((hitRate * (1 - hitRate)) / (p.status.totalHits + p.status.totalMisses));
missErrorBar = z * sqrt((missRate * (1 - missRate)) / (p.status.totalHits + p.status.totalMisses));
changeFalseAlarmErrorBar = z * sqrt((changeFalseAlarmRate * (1 - changeFalseAlarmRate)) / (p.status.totalHits + p.status.totalMisses + p.status.totalChangeFalseAlarms));
noChangeFalseAlarmErrorBar = z * sqrt((noChangeFalseAlarmRate * (1 - noChangeFalseAlarmRate)) / (p.status.totalCorrectRejects + p.status.totalNoChangeFalseAlarms));
correctRejectErrorBar = z * sqrt((correctRejectRate * (1 - correctRejectRate)) / (p.status.totalCorrectRejects + p.status.totalNoChangeFalseAlarms));

% Update confusion matrix plot data
% confusionRates = [hitRate, missRate, changeFalseAlarmRate, noChangeFalseAlarmRate, correctRejectRate];
% confusionErrorBars = [hitErrorBar, missErrorBar, changeFalseAlarmErrorBar, noChangeFalseAlarmErrorBar, correctRejectErrorBar];
nPlots = length(confusionRates);
for i = 1:nPlots
    % Update fill object for current box plot
    yFill = [confusionErrorBars(i, 1) confusionErrorBars(i, 1) ...
        confusionErrorBars(i, 2) confusionErrorBars(i, 2) ...
        confusionErrorBars(i, 1)];
    set(p.draw.onlineConfusionFillObj(i), 'YData', yFill);
    
    % Update plot object for current box plot
    centerY = confusionRates(i);
    xMin = 1 + (i-1) - 0.25;
    xMax = 1 + (i-1) + 0.25;
    xPlot = [xMin, xMax];
    yPlot = [centerY, centerY];
    set(p.draw.onlineConfusionPlotObj(i), 'XData', xPlot, 'YData', yPlot);
end
hold on;
ylim([0 1]);
hold off;
drawnow;


% % Psychometric function estimation plot
% if contains(p.init.exptType, 'psycho')
% 
%     % Update accumulators
% 
%     % if it's a no change trial, skip
%     if p.trVars.isStimChangeTrial
%         isHit = (p.trData.trialEndState == p.state.hit); % if monkey is correct
% 
%         % if it's a hit, add to the appropriate accumulator
%         if isHit
%             p.status.orientDelta{p.stim.deltasArrayIndex}.hitCount = ...
%                 p.status.orientDelta{p.stim.deltasArrayIndex}.hitCount + 1;
%         end
% 
%         % add to the total count after each trial
%         p.status.orientDelta{p.stim.deltasArrayIndex}.totalCount = ...
%             p.status.orientDelta{p.stim.deltasArrayIndex}.totalCount + 1;
%     end
% 
%     % Update plot objects
%     barHalfWidth = 0.05;
%     xPositions = [0.75, 1.25, 1.75, 2.25];
% 
%     for i = 1:length(p.status.orientDelta)
%         % Retrieve performance count and total count for this delta
%         perfCount = p.status.orientDelta{i}.hitCount;
%         totalCount = p.status.orientDelta{i}.totalCount;
% 
%         % Compute performance and confidence interval
%         [perf, pci] = binofit(perfCount, totalCount);
% 
%         % Set x positions for the fill objects
%         fillX = xPositions(i) + barHalfWidth * [-1 1 1 -1 -1];
% 
%         % Set Y positions for confidence interval and performance line
%         perfFillY = [pci(1) pci(1) pci(2) pci(2) pci(1)];
%         perfLineY = [perf perf];
% 
%         % Update the plot objects for this delta
%         set(p.draw.onlinePsychoPerfFillObj(i), 'XData', fillX, 'YData', perfFillY, 'FaceColor', 0.7*[1 1 1]); % Adjust color as needed
%         set(p.draw.onlinePsychoPerfPlotObj(i), 'XData', fillX(1:2), 'YData', perfLineY, 'Color', [0 0 0], 'LineWidth', 2); % Adjust color and line width as needed
%     end
%     try
%         set(p.draw.onlinePsychoPerfPlotAxes, 'XTick', xPositions, 'XTickLabel', {p.stim.deltasArray(1), p.stim.deltasArray(2), p.stim.deltasArray(3), p.stim.deltasArray(4)});
%     catch me
%     end
%     % Refresh the plot to show updates
%     drawnow;
% 
% end
% 
% % Learning curve plot
% 
% correctCodes = [21, 22];
% correctTrials = ismember(p.status.trialEndStates, correctCodes);
% 
% % Set the desired block size
% block_size = 60;
% 
% % Calculate the number of complete blocks
% num_blocks = floor(length(correctTrials) / block_size);
% 
% block_accuracy = zeros(num_blocks, 1);
% % Iterate over each block and calculate the accuracy
% for i = 1:num_blocks
%     start_idx = (i - 1) * block_size + 1;
%     end_idx = i * block_size;
%     block_data = correctTrials(start_idx:end_idx);
%     block_accuracy(i) = sum(block_data) / block_size;
% end
% 
% % Update the learning curve plot every 100 trials
% if mod(p.status.iTrial, block_size) == 0
%     plot(p.draw.onlineLearningCurveAxes, 1:num_blocks, block_accuracy, 'o-');
%     xlabel(p.draw.onlineLearningCurveAxes, 'Block Number');
%     ylabel(p.draw.onlineLearningCurveAxes, 'Accuracy');
%     title(p.draw.onlineLearningCurveAxes, 'Learning Curve');
%     drawnow;
% end
% 
% 
% % Here we will compute aggregate performance (percent correct) and reaction
% % time. We first define which trials we're interested in numerically based
% % on the variable "p.trVars.numTrialsForPerfCalc", then we only keep the
% % numerical indexes of hits or misses:
% firstTrial = max([1, p.status.iTrial - p.trVars.numTrialsForPerfCalc]);
% lastTrial  = p.status.iTrial;
% perfComputeTrialsIdx = firstTrial:lastTrial;
% perfComputeTrialsIdx = ...
%     perfComputeTrialsIdx(p.status.trialEndStates(perfComputeTrialsIdx) ...
%     > 20);
% 
% % make temporary variables to hold the data we're currently interested in:
% tempStates          = p.status.trialEndStates(perfComputeTrialsIdx);
% tempReactionTimes   = p.status.reactionTimes(perfComputeTrialsIdx);
% tempDimVals         = p.status.dimVals(perfComputeTrialsIdx);
% 
% % find unique values of "dimVals":
% uniqueDimVals       = unique(tempDimVals);
% nDimVals            = length(uniqueDimVals);
% 
% % make sure we actually have dimVals to work with and nothing hinky has
% % happened:
% if nDimVals > 0
% 
%     % compute bar width based on minimum difference between unique dim vals:
%     barHalfWidth = min(diff(uniqueDimVals))*0.4;
%     if isempty(barHalfWidth)
%         barHalfWidth = 0.4;
%     end
% 
%     % if the number of plot objects we have matches the number of unique dim
%     % values we'll just replace the X / Y data for each plot object, but if we
%     % have a mismatch, we'll delete extra plot objects or add new ones before
%     % we replace the X / Y data:
%     nPlotObj = length(p.draw.onlinePerfFillObj);
%     if  nPlotObj > nDimVals
% 
%         % index plot objects to be deleted:
%         deleteIdx = (nDimVals+1):nPlotObj;
% 
%         % delete plot objects:
%         delete([...
%             p.draw.onlinePerfFillObj(deleteIdx), ...
%             p.draw.onlineRtFillObj(deleteIdx), ...
%             p.draw.onlinePerfPlotObj(deleteIdx), ...
%             p.draw.onlineRtPlotObj(deleteIdx), ...
%             ]);
% 
%         % get rid of extra entries in vectors:
%         p.draw.onlinePerfFillObj(deleteIdx) = [];
%         p.draw.onlineRtFillObj(deleteIdx) = [];
%         p.draw.onlinePerfPlotObj(deleteIdx) = [];
%         p.draw.onlineRtPlotObj(deleteIdx) = [];
% 
%     elseif nPlotObj < nDimVals
% 
%         % add extra plot objects to the end of the plot object vectors:
%         p.draw.onlinePerfFillObj((nPlotObj+1):nDimVals) = ...
%             copyobj(p.draw.onlinePerfFillObj(1), ...
%             repmat(p.draw.onlinePerfPlotAxes, 1, nDimVals - nPlotObj));
%         p.draw.onlineRtFillObj((nPlotObj+1):nDimVals)   = ...
%             copyobj(p.draw.onlineRtFillObj(1), ...
%             repmat(p.draw.onlineRtPlotAxes, 1, nDimVals - nPlotObj));
%         p.draw.onlinePerfPlotObj((nPlotObj+1):nDimVals) = ...
%             copyobj(p.draw.onlinePerfPlotObj(1), ...
%             repmat(p.draw.onlinePerfPlotAxes, 1, nDimVals - nPlotObj));
%         p.draw.onlineRtPlotObj((nPlotObj+1):nDimVals)   = ...
%             copyobj(p.draw.onlineRtPlotObj(1), ...
%             repmat(p.draw.onlineRtPlotAxes, 1, nDimVals - nPlotObj));
%     end
% 
%     % loop over unique values of "dimVals" to compute average performance,
%     % median reaction time, and error bars:
%     for i = 1:length(uniqueDimVals)
% 
%         % if the dimVal is 0, we count "hits" differently since correct
%         % performance with a dimVal of 0 is a CR:
%         if uniqueDimVals(i) == 0
%             % count CRs and total trials for currently considered dimVal
%             hitCount    = nnz(tempStates == p.state.cr & ...
%                 tempDimVals == uniqueDimVals(i));
%             totalCount  = nnz(tempStates > 20 & ...
%                 tempDimVals == uniqueDimVals(i));
%         else
%             % count hits and total trials for currently considered dimVal
%             hitCount    = nnz(tempStates == p.state.hit & ...
%                 tempDimVals == uniqueDimVals(i));
%             totalCount  = nnz(tempStates > 20 & ...
%                 tempDimVals == uniqueDimVals(i));
%         end
% 
%         % compute performance and confidence interval:
%         [perf, pci] = binofit(hitCount, totalCount);
% 
%         % compute median reaction time and confidence interval:
%         [med, mci] = medci(tempReactionTimes(tempDimVals == ...
%             uniqueDimVals(i) & tempReactionTimes > 0));
% 
%         % define x / y vectors for fill objects; note that we only need a
%         % single X vector for both performance and RT:
%         fillX       = uniqueDimVals(i) + barHalfWidth*[-1 1 1 -1 -1];
%         perfFillY   = [pci(1) pci(1) pci(2) pci(2) pci(1)];
%         rtFillY     = [mci(1) mci(1) mci(2) mci(2) mci(1)];
% 
%         % update x/y data of plot objects:
%         p.draw.onlinePerfFillObj(i).XData   = fillX;
%         p.draw.onlineRtFillObj(i).XData     = fillX;
%         p.draw.onlinePerfFillObj(i).YData   = perfFillY;
%         p.draw.onlineRtFillObj(i).YData     = rtFillY;
%         p.draw.onlinePerfPlotObj(i).XData   = fillX(1:2);
%         p.draw.onlineRtPlotObj(i).XData     = fillX(1:2);
%         p.draw.onlinePerfPlotObj(i).YData   = perf*[1 1];
%         p.draw.onlineRtPlotObj(i).YData     = med*[1 1];
%     end
% 
%     % update axis x / y limits?
% end
% 
% % update ticks:
% set([p.draw.onlinePerfPlotAxes, p.draw.onlineRtPlotAxes], 'XTick', ...
%     [-1 0 1], 'XTickLabel', ...
%     {'hue change only', 'no change', 'dim + hue change'});
% 
% % update figure windows:
% drawnow;

end

function [med, mci] = medci(X)

p = prctile(X,[25 50 75]);

med = p(2);
mci = p(2) + [-1; 1]*1.57*(p(3)-p(1))/sqrt(length(X));
end