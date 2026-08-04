function figureFiles = srs_make_figures(T, stats, meta, figureFolder, options)
%SRS_MAKE_FIGURES Create annotated offline behavioral figures.
%
% All user-facing text is in English. Inferential panels display statistical
% significance directly on the plots. Unless stated otherwise, stars are
% based on Benjamini-Hochberg FDR-adjusted q-values within each family:
%   ns: q >= 0.05, *: q < 0.05, **: q < 0.01, ***: q < 0.001.
%
% Figures are saved in:
%   SRS_behavior_analysis/figures/<session ID>/

figureFiles = strings(0, 1);
if nargin < 5 || ~isfield(options, 'makeFigures') || ~options.makeFigures
    return;
end
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end

if meta.nRealEyeChoices > 0
    inferenceLabel = sprintf('%d real eye-controlled choices', ...
        meta.nRealEyeChoices);
else
    inferenceLabel = 'DEBUG DESCRIPTION: no real eye-controlled choices';
end

%% Figure 1: offline reconstruction of online plots plus inferential tests
fig = newFigure('SRS online plots and statistics', [80 50 1550 1030]);

subplot(3, 2, 1);
plotRewardDifference(T);

subplot(3, 2, 2);
plotSalienceDifference(T);

subplot(3, 2, 3);
plotOnlineChoiceBars(stats);

subplot(3, 2, 4);
plotCumulativeHighSalienceChoice(T);

subplot(3, 2, 5);
plotReactionTimes(T, stats);

subplot(3, 2, 6);
plotExploration(T, stats);

addFigureTitle(sprintf('%s | Online plots reconstructed offline | %s', ...
    meta.sessionID, inferenceLabel));
caption = [ ...
    "A: signed reward difference; positive values mean T1 offered more reward. " + ...
    "B: signed visual-salience evidence; positive values mean T1 was more salient. " + ...
    "C: choice proportions with 95% Wilson confidence intervals. Stars above individual bars test P=0.5; brackets compare conflict and congruent trials with Fisher's exact test. " + ...
    "D: cumulative probability of choosing the high-salience target, shown overall and by condition. " + ...
    "E: individual saccadic reaction times and medians; the bracket is a two-sided permutation test of the conflict-congruent median difference. " + ...
    "F: identity stay/switch as a function of previous reward; the title reports the permutation correlation. Stars use FDR-adjusted q-values where a family correction is available."];
addFigureCaption(fig, caption);
figureFiles(end + 1) = saveFigure(fig, figureFolder, ...
    '01_online_plots_with_statistics', options); %#ok<AGROW>

%% Figure 2: candidate strategies and spatial versus identity control
fig = newFigure('SRS strategy diagnostics', [100 45 1550 1030]);

subplot(3, 2, 1);
plotStrategyAccuracy(stats.strategyTable);

subplot(3, 2, 2);
plotSpatialSequence(T);

subplot(3, 2, 3);
plotIdentitySequence(T);

subplot(3, 2, 4);
plotConditionalRightChoice(T, stats.associationTable);

subplot(3, 2, 5);
plotBlockChoiceSummary(T);

subplot(3, 2, 6);
plot(T.Attempt, stats.engagement.rollingRightChoiceEntropy, ...
    'LineWidth', 1.5);
hold on;
plotHorizontalReference(1);
ylim([0 1.05]);
xlabel('Attempt');
ylabel('Binary entropy (bits)');
title(sprintf('Right/left diversity, trailing window = %d', ...
    stats.engagement.window));
box off;

addFigureTitle(sprintf('%s | Strategy diagnostics | %s', ...
    meta.sessionID, inferenceLabel));
caption = [ ...
    "A: accuracy of deterministic candidate strategies. A value of 0.5 is chance; stars are exact binomial tests corrected across strategies. Strategies that make identical predictions in the current design remain statistically indistinguishable and are listed in strategy_comparison.csv. " + ...
    "B: selected side on each two-target choice, overlaid with the side containing the rich and high-salience targets. " + ...
    "C: the same sequence expressed as target identity T1/T2. Comparing B and C distinguishes spatial from identity-based behavior. " + ...
    "D: P(right) conditional on whether reward, salience, T1, or the previous choice was on the right. Brackets are two-sided Fisher exact tests. " + ...
    "E: descriptive choice proportions within each block; reversals of rich-target identity are essential for separating identity from reward strategies. " + ...
    "F: rolling spatial entropy. One bit indicates balanced right/left choices; values near zero indicate a nearly fixed side."];
addFigureCaption(fig, caption);
figureFiles(end + 1) = saveFigure(fig, figureFolder, ...
    '02_strategy_diagnostics_with_statistics', options); %#ok<AGROW>

%% Figure 3: operational engagement and data quality
fig = newFigure('SRS engagement and quality', [120 25 1550 1190]);

subplot(4, 2, 1);
plot(T.Attempt, double(T.GoodTrial), 'ko', 'MarkerSize', 4);
hold on;
set(gca, 'YLim', [-0.15 1.15], 'YTick', [0 1], ...
    'YTickLabel', {'Failure', 'Success'});
xlabel('Attempt');
ylabel('Outcome');
title('Trial-by-trial outcome');
markDisengagement(stats.engagement);
box off;

subplot(4, 2, 2);
plot(T.Attempt, stats.engagement.rollingCompletionRate, 'LineWidth', 1.7);
hold on;
plot([min(T.Attempt) max(T.Attempt)], [0.8 0.8], 'k:');
ylim([0 1.05]);
xlabel('Attempt');
ylabel('Completion rate');
title(sprintf('Rolling completion, window %d | change-point p=%s', ...
    stats.engagement.window, formatP(stats.engagement.failureChangeP)));
markDisengagement(stats.engagement);
box off;

subplot(4, 2, 3);
plot(T.Attempt, T.PreTrialIntervalSec, '.', 'MarkerSize', 8);
hold on;
plot(T.Attempt, stats.engagement.rollingPreTrialIntervalSec, ...
    'LineWidth', 1.7);
xlabel('Attempt');
ylabel('Pre-trial interval (s)');
title(sprintf('Delay before starting | change-point p=%s', ...
    formatP(stats.engagement.intervalChangeP)));
markDisengagement(stats.engagement);
box off;

subplot(4, 2, 4);
validFix = isfinite(T.FixAcquisitionLatencyMs);
if any(validFix)
    plot(T.Attempt(validFix), T.FixAcquisitionLatencyMs(validFix), '.', ...
        'MarkerSize', 8);
    hold on;
    plot(T.Attempt, stats.engagement.rollingFixAcquisitionLatencyMs, ...
        'LineWidth', 1.7);
    xlabel('Attempt');
    ylabel('Fixation acquisition latency (ms)');
    title(sprintf('Fixation acquisition | change-point p=%s', ...
        formatP(stats.engagement.fixChangeP)));
    markDisengagement(stats.engagement);
    box off;
else
    showNoData('No valid fixation-acquisition latency');
end

subplot(4, 2, 5);
validRT = isfinite(T.ReactionTimeMs);
if any(validRT)
    plot(T.Attempt(validRT), T.ReactionTimeMs(validRT), '.', ...
        'MarkerSize', 8);
    hold on;
    plot(T.Attempt, stats.engagement.rollingReactionTimeMs, ...
        'LineWidth', 1.7);
    xlabel('Attempt');
    ylabel('Reaction time (ms)');
    title(sprintf('Saccadic reaction time | change-point p=%s', ...
        formatP(stats.engagement.rtChangeP)));
    markDisengagement(stats.engagement);
    box off;
else
    showNoData('No valid reaction time');
end

subplot(4, 2, 6);
stem(T.Attempt, T.MissedFrames, 'Marker', 'none');
xlabel('Attempt');
ylabel('Missed frames');
title(sprintf('Display quality | total missed frames = %.0f', ...
    sum(T.MissedFrames, 'omitnan')));
markDisengagement(stats.engagement);
box off;

subplot(4, 2, 7);
plotBlockCompletion(stats.blockTable);

subplot(4, 2, 8);
validDuration = isfinite(T.TrialDurationSec);
if any(validDuration)
    plot(T.Attempt(validDuration), T.TrialDurationSec(validDuration), '.', ...
        'MarkerSize', 8);
    hold on;
    plot(T.Attempt, stats.engagement.rollingTrialDurationSec, ...
        'LineWidth', 1.7);
    xlabel('Attempt');
    ylabel('Attempt duration (s)');
    title('Attempt duration');
    markDisengagement(stats.engagement);
    box off;
else
    showNoData('No valid attempt duration');
end

addFigureTitle(sprintf('%s | Operational engagement and quality | %s', ...
    meta.sessionID, inferenceLabel));
caption = [ ...
    "A: success and failure for every saved attempt. B: trailing completion rate; the dotted line at 0.8 is a visual reference, not a statistical threshold. " + ...
    "C: time between attempts. D: latency to acquire fixation after fixation onset. E: saccadic reaction time. F: missed display frames. G: completed fraction of each planned block. H: total attempt duration. " + ...
    "Raw points are overlaid with trailing medians or means. Change-point p-values are permutation tests that already account for scanning candidate split points. A red vertical line is displayed only when the operational rule identifies convergent evidence. This analysis cannot measure subjective boredom."];
addFigureCaption(fig, caption);
figureFiles(end + 1) = saveFigure(fig, figureFolder, ...
    '03_engagement_and_quality_with_statistics', options); %#ok<AGROW>

%% Figure 4: psychometric, temporal, and conditional inferential analyses
fig = newFigure('SRS additional inferential analyses', [140 50 1550 1030]);

subplot(2, 2, 1);
plotPsychometric(stats.psychometricTable, stats.psychometricFit);

subplot(2, 2, 2);
plotChoiceEvolution(stats.choiceEvolutionTable);

subplot(2, 2, 3);
plotAssociationEffects(stats.associationTable);

subplot(2, 2, 4);
plotTimeSeriesTrends(stats.timeSeriesTable);

addFigureTitle(sprintf('%s | Additional inferential analyses | %s', ...
    meta.sessionID, inferenceLabel));
caption = [ ...
    "A: binned P(T1) with 95% Wilson confidence intervals. The smooth curve is a logistic regression fitted to unbinned real choices; its slope tests whether signed salience predicts T1 selection. " + ...
    "B: last-third minus first-third changes in major choice policies; stars are two-sided permutation tests with FDR correction. " + ...
    "C: conditional probability differences from 2x2 tables; positive values mean the predictor increases the response. Stars are Fisher exact tests with FDR correction. " + ...
    "D: Pearson correlation with attempt number; stars are permutation tests with FDR correction. Statistical significance does not by itself establish a meaningful effect size."];
addFigureCaption(fig, caption);
figureFiles(end + 1) = saveFigure(fig, figureFolder, ...
    '04_additional_inferential_analyses', options); %#ok<AGROW>

%% Figure 5: compact statistical summary
fig = newFigure('SRS statistical summary', [160 80 1550 980]);

subplot(2, 2, 1);
plotBiasSummary(stats.biasTable);

subplot(2, 2, 2);
plotConditionComparisons(stats.onlineConditionComparisonTable);

subplot(2, 2, 3);
plotLogisticModelSummary(stats.modelTable);

subplot(2, 2, 4);
plotEngagementSummaryText(stats);

addFigureTitle(sprintf('%s | Statistical summary | %s', ...
    meta.sessionID, inferenceLabel));
caption = [ ...
    "A: core choice probabilities with 95% Wilson confidence intervals; stars test each probability against 0.5. " + ...
    "B: direct conflict-versus-congruent comparisons; brackets use Fisher exact tests. " + ...
    "C: multivariable logistic-regression odds ratios when fitglm is available; values above one increase the modeled response after controlling for the other predictors. " + ...
    "D: exact numerical summary of engagement tests. Stars throughout this figure use FDR-adjusted q-values, except single pre-specified tests such as the RT and psychometric slope tests, which use raw p-values. Exact values are exported to CSV and analysis_report.txt."];
addFigureCaption(fig, caption);
figureFiles(end + 1) = saveFigure(fig, figureFolder, ...
    '05_statistical_summary', options); %#ok<AGROW>

end

%% Plotting helpers

function fig = newFigure(nameText, position)
fig = figure('Color', 'w', 'Position', position, 'Name', nameText, ...
    'NumberTitle', 'off');
end

function plotRewardDifference(T)
mask = T.GoodTrial & isfinite(T.RewardDifferenceT1MinusT2Ms);
if ~any(mask)
    showNoData('No finite reward difference');
    return;
end
plot(T.GoodTrialOrdinal(mask), T.RewardDifferenceT1MinusT2Ms(mask), ...
    '.-', 'LineWidth', 1.0, 'MarkerSize', 9);
hold on;
plotHorizontalReference(0);
xlabel('Successful trial');
ylabel('T1 - T2 reward (ms)');
title('Signed reward difference');
box off;
end

function plotSalienceDifference(T)
hueMask = T.GoodTrial & isfinite(T.HueContrastDifferenceT1MinusT2Deg);
lumMask = T.GoodTrial & ...
    isfinite(T.MeasuredLuminanceDifferenceT1MinusT2CdM2);
if sum(hueMask) >= sum(lumMask) && any(hueMask)
    plot(T.GoodTrialOrdinal(hueMask), ...
        T.HueContrastDifferenceT1MinusT2Deg(hueMask), ...
        '.-', 'LineWidth', 1.0, 'MarkerSize', 9);
    ylabel('T1 - T2 hue contrast (deg)');
    title('Signed hue-salience evidence');
elseif any(lumMask)
    plot(T.GoodTrialOrdinal(lumMask), ...
        T.MeasuredLuminanceDifferenceT1MinusT2CdM2(lumMask), ...
        '.-', 'LineWidth', 1.0, 'MarkerSize', 9);
    ylabel('T1 - T2 luminance (cd/m^2)');
    title('Signed luminance evidence');
else
    showNoData('No finite salience measurement');
    return;
end
hold on;
plotHorizontalReference(0);
xlabel('Successful trial');
box off;
end

function plotOnlineChoiceBars(stats)
S = stats.onlineChoiceTable;
if isempty(S) || height(S) < 4
    showNoData('No online-choice statistics');
    return;
end
rows = 1:4;
useReal = any(S.NReal(rows) > 0);
if useReal
    values = S.ProportionReal(rows);
    low = S.CI95LowReal(rows);
    high = S.CI95HighReal(rows);
    q = getColumnOrNaN(S, 'QFDR', rows);
else
    values = S.ProportionAll(rows);
    low = nan(size(values));
    high = nan(size(values));
    q = nan(size(values));
end
bar(1:4, values);
hold on;
if useReal
    errorbar(1:4, values, values - low, high - values, ...
        'k.', 'LineWidth', 1.2);
    annotatePointStars(1:4, high, q);
end
plot([0.5 4.5], [0.5 0.5], 'k--');
labels = {'High salience: conflict', 'High salience: congruent', ...
          'High reward: conflict', 'High reward: congruent'};
set(gca, 'XTick', 1:4, 'XTickLabel', labels, ...
    'XTickLabelRotation', 20, 'YLim', [0 1.30]);
ylabel('Choice probability');
title('Choice by task condition');
if useReal && isfield(stats, 'onlineConditionComparisonTable') && ...
        ~isempty(stats.onlineConditionComparisonTable)
    C = stats.onlineConditionComparisonTable;
    if height(C) >= 2
        qPair = getColumnOrNaN(C, 'QFDR', 1:2);
        addSignificanceBracket(1, 2, 1.06, qPair(1));
        addSignificanceBracket(3, 4, 1.20, qPair(2));
    end
end
box off;
end

function plotCumulativeHighSalienceChoice(T)
C = selectChoiceRows(T);
if isempty(C)
    showNoData('No two-target choices');
    return;
end
x = (1:height(C))';
overall = cumsum(C.ChoseHighSalience) ./ x;
plot(x, overall, 'k--', 'LineWidth', 1.5);
hold on;
legendLabels = {'All'};
conflict = C.IsConflict;
if any(conflict)
    ordinal = cumsum(double(conflict));
    cumulative = cumsum(C.ChoseHighSalience .* double(conflict));
    y = nan(height(C), 1);
    y(conflict) = cumulative(conflict) ./ ordinal(conflict);
    plot(x(conflict), y(conflict), '-', 'LineWidth', 1.7);
    legendLabels{end + 1} = 'Conflict'; %#ok<AGROW>
end
congruent = C.IsCongruent;
if any(congruent)
    ordinal = cumsum(double(congruent));
    cumulative = cumsum(C.ChoseHighSalience .* double(congruent));
    y = nan(height(C), 1);
    y(congruent) = cumulative(congruent) ./ ordinal(congruent);
    plot(x(congruent), y(congruent), '-', 'LineWidth', 1.7);
    legendLabels{end + 1} = 'Congruent'; %#ok<AGROW>
end
plot([1 max(2, height(C))], [0.5 0.5], 'k:');
ylim([0 1]);
xlabel('Two-target choice number');
ylabel('Cumulative P(high-salience choice)');
legend(legendLabels, 'Location', 'best');
title('Evolution of salience-guided choices');
box off;
end

function plotReactionTimes(T, stats)
maskBase = T.RealEyeChoice;
if ~any(maskBase & isfinite(T.ReactionTimeMs))
    maskBase = T.GoodChoice;
end
conflict = maskBase & T.IsConflict & isfinite(T.ReactionTimeMs);
congruent = maskBase & T.IsCongruent & isfinite(T.ReactionTimeMs);
if ~any(conflict | congruent)
    showNoData('No valid reaction time');
    return;
end
hold on;
maxY = -Inf;
if any(conflict)
    values = T.ReactionTimeMs(conflict);
    x = deterministicJitter(1, numel(values), 0.12);
    plot(x, values, 'o', 'MarkerSize', 4);
    med = median(values);
    plot([0.75 1.25], [med med], 'k-', 'LineWidth', 2);
    maxY = max(maxY, max(values));
end
if any(congruent)
    values = T.ReactionTimeMs(congruent);
    x = deterministicJitter(2, numel(values), 0.12);
    plot(x, values, 'o', 'MarkerSize', 4);
    med = median(values);
    plot([1.75 2.25], [med med], 'k-', 'LineWidth', 2);
    maxY = max(maxY, max(values));
end
set(gca, 'XLim', [0.5 2.5], 'XTick', [1 2], ...
    'XTickLabel', {'Conflict', 'Congruent'});
ylabel('Reaction time (ms)');
title(sprintf('Reaction time | median difference p=%s', ...
    formatP(stats.rtConflictVsCongruentP)));
if isfinite(maxY)
    yRange = max(1, maxY - min(ylim));
    yBracket = maxY + 0.08 * yRange;
    ylim([min(ylim), yBracket + 0.12 * yRange]);
    addSignificanceBracket(1, 2, yBracket, ...
        stats.rtConflictVsCongruentP);
end
box off;
end

function plotExploration(T, stats)
mask = T.RealEyeChoice & isfinite(T.PreviousRewardMs) & ...
    isfinite(T.SwitchedTarget);
if ~any(mask)
    mask = T.GoodChoice & isfinite(T.PreviousRewardMs) & ...
        isfinite(T.SwitchedTarget);
end
if ~any(mask)
    showNoData('No valid choice transition');
    return;
end
scatter(T.PreviousRewardMs(mask), T.SwitchedTarget(mask), 22, 'filled');
hold on;
if any(isfinite(stats.exploration.binCenters))
    plot(stats.exploration.binCenters, stats.exploration.binPSwitch, ...
        '-o', 'LineWidth', 2);
end
ylim([-0.12 1.12]);
set(gca, 'YTick', [0 1], 'YTickLabel', {'Stay', 'Switch'});
xlabel('Reward obtained on previous choice (ms)');
ylabel('Identity transition');
title(sprintf('Previous reward vs switch: r=%.3f, p=%s %s', ...
    stats.exploration.rewardSwitchCorrelation, ...
    formatP(stats.exploration.rewardSwitchPermutationP), ...
    significanceStars(stats.exploration.rewardSwitchPermutationP)));
box off;
end

function plotStrategyAccuracy(S)
if isempty(S)
    showNoData('No candidate strategy can be evaluated');
    return;
end
useReal = any(S.NReal > 0);
if useReal
    accuracy = S.AccuracyReal;
    valid = S.NReal > 0 & isfinite(accuracy);
    q = getColumnOrNaN(S, 'QFDR', (1:height(S))');
    label = 'real choices';
else
    accuracy = S.AccuracyAll;
    valid = S.NAll > 0 & isfinite(accuracy);
    q = nan(height(S), 1);
    label = 'debug description';
end
rows = find(valid);
[sortedAccuracy, order] = sort(accuracy(rows), 'descend');
rows = rows(order);
barh(1:numel(rows), sortedAccuracy);
hold on;
plot([0.5 0.5], [0.5 numel(rows) + 0.5], 'k--');
for i = 1:numel(rows)
    if useReal
        text(min(0.98, sortedAccuracy(i) + 0.02), i, ...
            significanceStars(q(rows(i))), 'FontWeight', 'bold', ...
            'VerticalAlignment', 'middle');
    end
end
set(gca, 'YTick', 1:numel(rows), ...
    'YTickLabel', cellstr(S.Strategy(rows)), 'YDir', 'reverse', ...
    'XLim', [0 1.08]);
xlabel('Proportion of choices correctly predicted');
title(['Candidate strategies - ' label]);
box off;
end

function plotSpatialSequence(T)
C = selectChoiceRows(T);
if isempty(C)
    showNoData('No two-target choices');
    return;
end
x = (1:height(C))';
plot(x, C.ChosenSide, 'ko', 'MarkerSize', 4);
hold on;
plot(x, C.RichSide, '-', 'LineWidth', 1.0);
plot(x, C.HighSalienceSide, ':', 'LineWidth', 1.2);
set(gca, 'YLim', [0.7 2.3], 'YTick', [1 2], ...
    'YTickLabel', {'Right', 'Left'});
xlabel('Two-target choice number');
ylabel('Side');
legend({'Chosen', 'Rich', 'High salience'}, 'Location', 'best');
title('Spatial choice sequence');
box off;
end

function plotIdentitySequence(T)
C = selectChoiceRows(T);
if isempty(C)
    showNoData('No two-target choices');
    return;
end
x = (1:height(C))';
plot(x, C.ChosenTarget, 'ko', 'MarkerSize', 4);
hold on;
plot(x, C.RichTarget, '-', 'LineWidth', 1.0);
plot(x, C.HighSalienceTarget, ':', 'LineWidth', 1.2);
set(gca, 'YLim', [0.7 2.3], 'YTick', [1 2], ...
    'YTickLabel', {'T1', 'T2'});
xlabel('Two-target choice number');
ylabel('Target identity');
legend({'Chosen', 'Rich', 'High salience'}, 'Location', 'best');
title('Identity choice sequence');
box off;
end

function plotConditionalRightChoice(T, A)
C = selectChoiceRows(T);
if isempty(C)
    showNoData('No two-target choices');
    return;
end
previousRight = nan(height(C), 1);
validPrevious = ismember(C.PreviousChosenSide, [1 2]);
previousRight(validPrevious) = double(C.PreviousChosenSide(validPrevious) == 1);
predictors = {C.RichOnRight, C.HighSalienceOnRight, C.T1OnRight, previousRight};
pairLabels = {'Rich target', 'High-salience target', 'T1', 'Previous choice'};
values = nan(8, 1);
for i = 1:4
    predictor = predictors{i};
    values(2*i-1) = mean(C.ChoseRight(predictor == 0), 'omitnan');
    values(2*i) = mean(C.ChoseRight(predictor == 1), 'omitnan');
end
bar(1:8, values);
hold on;
plot([0.5 8.5], [0.5 0.5], 'k--');
labels = {'Rich left', 'Rich right', 'Salience left', 'Salience right', ...
    'T1 left', 'T1 right', 'Previous left', 'Previous right'};
set(gca, 'XTick', 1:8, 'XTickLabel', labels, ...
    'XTickLabelRotation', 25, 'YLim', [0 1.33]);
ylabel('P(choose right)');
title('Conditional spatial influences');
if ~isempty(A) && height(A) >= 4
    q = getColumnOrNaN(A, 'QFDR', 1:4);
    yLevels = [1.04 1.12 1.20 1.28];
    for i = 1:4
        addSignificanceBracket(2*i-1, 2*i, yLevels(i), q(i));
    end
end
text(0.02, 0.96, strjoin(pairLabels, ', '), 'Units', 'normalized', ...
    'FontSize', 7, 'VerticalAlignment', 'top');
box off;
end

function plotBlockChoiceSummary(T)
blocks = unique(T.BlockUID, 'stable');
if isempty(blocks)
    showNoData('No blocks');
    return;
end
pRich = nan(numel(blocks), 1);
pRight = nan(numel(blocks), 1);
pT1 = nan(numel(blocks), 1);
pHighSal = nan(numel(blocks), 1);
for iBlock = 1:numel(blocks)
    mask = T.BlockUID == blocks(iBlock) & T.RealEyeChoice;
    if ~any(mask)
        mask = T.BlockUID == blocks(iBlock) & T.GoodChoice;
    end
    pRich(iBlock) = mean(T.ChoseRich(mask), 'omitnan');
    pRight(iBlock) = mean(T.ChoseRight(mask), 'omitnan');
    pT1(iBlock) = mean(T.ChoseT1(mask), 'omitnan');
    pHighSal(iBlock) = mean(T.ChoseHighSalience(mask), 'omitnan');
end
plot(1:numel(blocks), pRich, '-o', 'LineWidth', 1.5);
hold on;
plot(1:numel(blocks), pRight, '-o', 'LineWidth', 1.5);
plot(1:numel(blocks), pT1, '-o', 'LineWidth', 1.5);
plot(1:numel(blocks), pHighSal, '-o', 'LineWidth', 1.5);
plot([0.5 numel(blocks) + 0.5], [0.5 0.5], 'k:');
set(gca, 'XTick', 1:numel(blocks), 'XTickLabel', cellstr(blocks), ...
    'XTickLabelRotation', 25, 'YLim', [0 1]);
ylabel('Choice probability');
title('Choice policy by block');
legend({'Rich', 'Right', 'T1', 'High salience'}, 'Location', 'best');
box off;
end

function plotBlockCompletion(B)
if isempty(B)
    showNoData('No blocks');
    return;
end
bar(1:height(B), B.CompletionFraction);
hold on;
plot([0.5 height(B) + 0.5], [1 1], 'k--');
set(gca, 'XTick', 1:height(B), 'XTickLabel', cellstr(B.BlockUID), ...
    'XTickLabelRotation', 25, 'YLim', [0 1.1]);
ylabel('Completed fraction of planned block');
title('Stopping point of each block');
box off;
end

function plotPsychometric(P, fit)
if isempty(P)
    showNoData('No continuous salience evidence');
    return;
end
useReal = any(P.NReal > 0);
if useReal
    y = P.PChooseT1Real;
    low = P.CI95LowReal;
    high = P.CI95HighReal;
    valid = P.NReal > 0 & isfinite(y);
    label = 'real choices';
else
    y = P.PChooseT1All;
    low = P.CI95LowAll;
    high = P.CI95HighAll;
    valid = P.NAll > 0 & isfinite(y);
    label = 'debug description';
end
if ~any(valid)
    showNoData('No usable psychometric bin');
    return;
end
x = P.EvidenceMean(valid);
y = y(valid);
low = low(valid);
high = high(valid);
errorbar(x, y, y - low, high - y, 'o', 'LineWidth', 1.5);
hold on;
if isfield(fit, 'Converged') && fit.Converged && ...
        ~isempty(fit.XGrid)
    plot(fit.XGrid, fit.PGrid, '-', 'LineWidth', 2);
end
limits = [min(x) max(x)];
if limits(1) == limits(2)
    limits = limits + [-0.5 0.5];
end
plot(limits, [0.5 0.5], 'k--');
plot([0 0], [0 1], 'k:');
xlim(limits);
ylim([0 1]);
xlabel(char(P.EvidenceType(1)));
ylabel('P(choose T1)');
if fit.Converged
    title(sprintf('Salience psychometric | slope p=%s %s | OR/SD=%.2f', ...
        formatP(fit.LikelihoodRatioP), ...
        significanceStars(fit.LikelihoodRatioP), fit.OddsRatioPerSD));
else
    title(['Salience psychometric - ' label]);
end
box off;
end

function plotChoiceEvolution(E)
if isempty(E)
    showNoData('No early-late choice comparison');
    return;
end
useReal = any(E.NEarlyReal > 0 & E.NLateReal > 0);
if useReal
    values = E.LateMinusEarlyReal;
    valid = E.NEarlyReal > 0 & E.NLateReal > 0 & isfinite(values);
    q = getColumnOrNaN(E, 'QFDR', (1:height(E))');
    label = 'real choices';
else
    values = E.LateMinusEarlyAll;
    valid = E.NEarlyAll > 0 & E.NLateAll > 0 & isfinite(values);
    q = nan(height(E), 1);
    label = 'debug description';
end
rows = find(valid);
if isempty(rows)
    showNoData('No early-late choice comparison');
    return;
end
barh(1:numel(rows), values(rows));
hold on;
plot([0 0], [0.5 numel(rows) + 0.5], 'k--');
for i = 1:numel(rows)
    x = values(rows(i));
    offset = 0.015 * max(1, max(abs(values(rows))));
    if x >= 0
        xText = x + offset;
        align = 'left';
    else
        xText = x - offset;
        align = 'right';
    end
    text(xText, i, significanceStars(q(rows(i))), ...
        'HorizontalAlignment', align, 'FontWeight', 'bold');
end
set(gca, 'YTick', 1:numel(rows), ...
    'YTickLabel', cellstr(E.Metric(rows)), 'YDir', 'reverse');
xlabel('Last third minus first third');
title(['Policy evolution - ' label]);
box off;
end

function plotAssociationEffects(A)
if isempty(A)
    showNoData('No conditional association');
    return;
end
useReal = any(A.NReal > 0);
if useReal
    values = A.DifferenceReal;
    valid = A.NReal > 0 & isfinite(values);
    q = getColumnOrNaN(A, 'QFDR', (1:height(A))');
    label = 'real choices';
else
    values = A.DifferenceAll;
    valid = A.NAll > 0 & isfinite(values);
    q = nan(height(A), 1);
    label = 'debug description';
end
rows = find(valid);
if isempty(rows)
    showNoData('Associations cannot be estimated');
    return;
end
labels = A.Predictor(rows) + " -> " + A.Response(rows);
barh(1:numel(rows), values(rows));
hold on;
plot([0 0], [0.5 numel(rows) + 0.5], 'k--');
for i = 1:numel(rows)
    x = values(rows(i));
    offset = 0.015 * max(1, max(abs(values(rows))));
    if x >= 0
        xText = x + offset;
        align = 'left';
    else
        xText = x - offset;
        align = 'right';
    end
    text(xText, i, significanceStars(q(rows(i))), ...
        'HorizontalAlignment', align, 'FontWeight', 'bold');
end
set(gca, 'YTick', 1:numel(rows), 'YTickLabel', cellstr(labels), ...
    'YDir', 'reverse');
xlabel('P(response|predictor=1) - P(response|predictor=0)');
title(['Conditional associations - ' label]);
box off;
end

function plotTimeSeriesTrends(S)
if isempty(S)
    showNoData('No time series');
    return;
end
valid = S.N >= 5 & isfinite(S.CorrelationWithAttempt);
rows = find(valid);
if isempty(rows)
    showNoData('No estimable temporal trend');
    return;
end
values = S.CorrelationWithAttempt(rows);
q = getColumnOrNaN(S, 'QFDR', rows);
barh(1:numel(rows), values);
hold on;
plot([0 0], [0.5 numel(rows) + 0.5], 'k--');
for i = 1:numel(rows)
    x = values(i);
    if x >= 0
        xText = x + 0.02;
        align = 'left';
    else
        xText = x - 0.02;
        align = 'right';
    end
    text(xText, i, significanceStars(q(i)), ...
        'HorizontalAlignment', align, 'FontWeight', 'bold');
end
set(gca, 'YTick', 1:numel(rows), ...
    'YTickLabel', cellstr(S.Metric(rows)), 'YDir', 'reverse', ...
    'XLim', [-1 1]);
xlabel('Pearson correlation with attempt number');
title('Temporal trends');
box off;
end

function plotBiasSummary(B)
if isempty(B)
    showNoData('No bias statistics');
    return;
end
useReal = any(B.NReal > 0);
if useReal
    values = B.ProportionReal;
    low = B.CI95LowReal;
    high = B.CI95HighReal;
    valid = B.NReal > 0 & isfinite(values);
    q = getColumnOrNaN(B, 'QFDR', (1:height(B))');
else
    values = B.ProportionAll;
    low = nan(size(values));
    high = nan(size(values));
    valid = B.NAll > 0 & isfinite(values);
    q = nan(height(B), 1);
end
rows = find(valid);
bar(1:numel(rows), values(rows));
hold on;
if useReal
    errorbar(1:numel(rows), values(rows), ...
        values(rows) - low(rows), high(rows) - values(rows), ...
        'k.', 'LineWidth', 1.2);
    annotatePointStars(1:numel(rows), high(rows), q(rows));
end
plot([0.5 numel(rows)+0.5], [0.5 0.5], 'k--');
set(gca, 'XTick', 1:numel(rows), 'XTickLabel', cellstr(B.Metric(rows)), ...
    'XTickLabelRotation', 25, 'YLim', [0 1.22]);
ylabel('Probability');
title('Core choice biases and perseveration');
box off;
end

function plotConditionComparisons(C)
if isempty(C)
    showNoData('No conflict-congruent comparison');
    return;
end
n = height(C);
values = nan(n, 2);
low = nan(n, 2);
high = nan(n, 2);
values(:, 1) = C.PConflict;
values(:, 2) = C.PCongruent;
low(:, 1) = C.CI95LowConflict;
low(:, 2) = C.CI95LowCongruent;
high(:, 1) = C.CI95HighConflict;
high(:, 2) = C.CI95HighCongruent;
bar(values);
hold on;
groupWidth = min(0.8, 2 / (2 + 1.5));
xPositions = nan(n, 2);
for j = 1:2
    xPositions(:, j) = (1:n)' - groupWidth/2 + ...
        (2*j - 1) * groupWidth / 4;
    errorbar(xPositions(:, j), values(:, j), ...
        values(:, j)-low(:, j), high(:, j)-values(:, j), ...
        'k.', 'LineWidth', 1.1);
end
plot([0.5 n+0.5], [0.5 0.5], 'k--');
q = getColumnOrNaN(C, 'QFDR', (1:n)');
for i = 1:n
    addSignificanceBracket(xPositions(i,1), xPositions(i,2), ...
        min(1.18, max(high(i,:)) + 0.10), q(i));
end
set(gca, 'XTick', 1:n, 'XTickLabel', cellstr(C.Outcome), ...
    'XTickLabelRotation', 20, 'YLim', [0 1.28]);
ylabel('Choice probability');
title('Conflict versus congruent');
legend({'Conflict', 'Congruent'}, 'Location', 'best');
box off;
end

function plotLogisticModelSummary(M)
if isempty(M) || ~any(strcmp(M.Properties.VariableNames, 'PValue'))
    showNoData('No logistic model output');
    return;
end
valid = isfinite(M.OddsRatio) & M.Term ~= "(Intercept)" & ...
    M.Term ~= "Not run" & M.Term ~= "Model failure";
rows = find(valid);
if isempty(rows)
    showNoData('fitglm unavailable or model not estimable');
    return;
end
or = M.OddsRatio(rows);
logOR = log(or);
q = getColumnOrNaN(M, 'QFDR', rows);
labels = M.Model(rows) + ": " + M.Term(rows);
barh(1:numel(rows), logOR);
hold on;
plot([0 0], [0.5 numel(rows)+0.5], 'k--');
for i = 1:numel(rows)
    if logOR(i) >= 0
        xText = logOR(i) + 0.05;
        align = 'left';
    else
        xText = logOR(i) - 0.05;
        align = 'right';
    end
    text(xText, i, significanceStars(q(i)), ...
        'HorizontalAlignment', align, 'FontWeight', 'bold');
end
set(gca, 'YTick', 1:numel(rows), 'YTickLabel', cellstr(labels), ...
    'YDir', 'reverse');
xlabel('Log odds ratio');
title('Multivariable logistic models');
box off;
end

function plotEngagementSummaryText(stats)
axis off;
lines = strings(0,1);
lines(end+1) = "Operational engagement tests";
lines(end+1) = "";
E = stats.engagementTable;
if ~isempty(E)
    for i = 1:height(E)
        q = NaN;
        if any(strcmp(E.Properties.VariableNames, 'QFDR'))
            q = E.QFDR(i);
        end
        lines(end+1) = sprintf('%s: early=%s, late=%s, delta=%s, p=%s, q=%s %s', ...
            char(E.Metric(i)), formatNumber(E.EarlyValue(i)), ...
            formatNumber(E.LateValue(i)), formatNumber(E.LateMinusEarly(i)), ...
            formatP(E.PermutationP(i)), formatP(q), significanceStars(q));
    end
end
lines(end+1) = "";
lines(end+1) = "Change-point tests (permutation-corrected for split search):";
lines(end+1) = sprintf('Failures: attempt %s, p=%s', ...
    formatNumber(stats.engagement.failureChangeAttempt), ...
    formatP(stats.engagement.failureChangeP));
lines(end+1) = sprintf('Pre-trial interval: attempt %s, p=%s', ...
    formatNumber(stats.engagement.intervalChangeAttempt), ...
    formatP(stats.engagement.intervalChangeP));
lines(end+1) = sprintf('Reaction time: attempt %s, p=%s', ...
    formatNumber(stats.engagement.rtChangeAttempt), ...
    formatP(stats.engagement.rtChangeP));
lines(end+1) = sprintf('Fixation latency: attempt %s, p=%s', ...
    formatNumber(stats.engagement.fixChangeAttempt), ...
    formatP(stats.engagement.fixChangeP));
lines(end+1) = "";
lines(end+1) = "Final operational interpretation:";
lines(end+1) = string(stats.engagement.evidence);
text(0, 1, cellstr(lines), 'Units', 'normalized', ...
    'VerticalAlignment', 'top', 'Interpreter', 'none', 'FontSize', 9);
title('Engagement statistics and interpretation');
end

function C = selectChoiceRows(T)
if any(T.RealEyeChoice)
    C = T(T.RealEyeChoice, :);
else
    C = T(T.GoodChoice, :);
end
end

function x = deterministicJitter(center, n, width)
if n <= 1
    x = center * ones(n, 1);
else
    x = center + linspace(-width/2, width/2, n)';
end
end

function annotatePointStars(x, y, pValues)
for i = 1:numel(x)
    if isfinite(y(i))
        text(x(i), min(1.18, y(i) + 0.04), significanceStars(pValues(i)), ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    end
end
end

function addSignificanceBracket(x1, x2, y, pValue)
if ~isfinite(y)
    return;
end
h = 0.025;
plot([x1 x1 x2 x2], [y-h y y y-h], 'k-', 'LineWidth', 1.0);
text(mean([x1 x2]), y + 0.008, significanceStars(pValue), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
    'FontWeight', 'bold');
end

function label = significanceStars(pValue)
if ~isfinite(pValue)
    label = 'n/a';
elseif pValue < 0.001
    label = '***';
elseif pValue < 0.01
    label = '**';
elseif pValue < 0.05
    label = '*';
else
    label = 'ns';
end
end

function textValue = formatP(pValue)
if ~isfinite(pValue)
    textValue = 'n/a';
elseif pValue < 0.001
    textValue = '<0.001';
else
    textValue = sprintf('%.3f', pValue);
end
end

function textValue = formatNumber(value)
if ~isfinite(value)
    textValue = 'n/a';
elseif abs(value) >= 100
    textValue = sprintf('%.1f', value);
else
    textValue = sprintf('%.3f', value);
end
end

function values = getColumnOrNaN(T, variableName, rows)
if any(strcmp(T.Properties.VariableNames, variableName))
    values = T.(variableName)(rows);
else
    values = nan(numel(rows), 1);
end
values = values(:);
end

function plotHorizontalReference(value)
limits = xlim;
if all(isfinite(limits))
    plot(limits, [value value], 'k:');
end
end

function showNoData(message)
axis off;
text(0.5, 0.5, message, 'HorizontalAlignment', 'center', ...
    'Units', 'normalized', 'FontWeight', 'bold', 'Interpreter', 'none');
end

function addFigureTitle(titleText)
if exist('sgtitle', 'file') == 2
    sgtitle(titleText, 'FontWeight', 'bold', 'Interpreter', 'none');
else
    annotation('textbox', [0 0.965 1 0.03], ...
        'String', titleText, 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
        'Interpreter', 'none');
end
end

function addFigureCaption(fig, captionText)
% Reserve space below all axes so the explanatory caption is visible in the
% MATLAB figure window and in saved PNG/PDF files.
axesHandles = findall(fig, 'Type', 'axes');
for i = 1:numel(axesHandles)
    pos = get(axesHandles(i), 'Position');
    pos(2) = 0.115 + 0.86 * pos(2);
    pos(4) = 0.86 * pos(4);
    set(axesHandles(i), 'Position', pos);
end
annotation(fig, 'textbox', [0.025 0.008 0.95 0.095], ...
    'String', char(captionText), 'EdgeColor', [0.65 0.65 0.65], ...
    'BackgroundColor', [0.97 0.97 0.97], 'Interpreter', 'none', ...
    'FontSize', 8.5, 'VerticalAlignment', 'middle', ...
    'HorizontalAlignment', 'left', 'FitBoxToText', 'off');
end

function markDisengagement(engagement)
if ~isfinite(engagement.estimatedDisengagementAttempt)
    return;
end
limits = ylim;
x = engagement.estimatedDisengagementAttempt;
plot([x x], limits, 'r--', 'LineWidth', 1.4);
ylim(limits);
end

function filePath = saveFigure(fig, figureFolder, baseName, options)
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
filePath = fullfile(figureFolder, [baseName '.png']);
set(fig, 'PaperPositionMode', 'auto');
if isfield(options, 'saveFigures') && options.saveFigures
    print(fig, filePath, '-dpng', '-r180');
end
if isfield(options, 'savePdfFigures') && options.savePdfFigures
    pdfPath = fullfile(figureFolder, [baseName '.pdf']);
    print(fig, pdfPath, '-dpdf', '-painters');
end
if isfield(options, 'saveMatlabFigures') && options.saveMatlabFigures
    figPath = fullfile(figureFolder, [baseName '.fig']);
    if exist('savefig', 'file') == 2
        savefig(fig, figPath);
    else
        saveas(fig, figPath);
    end
end
end
