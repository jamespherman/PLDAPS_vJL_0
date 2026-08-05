function figureFiles = srs_make_simple_figures(T, stats, meta, figureFolder, options, summaryFile)
%SRS_MAKE_SIMPLE_FIGURES Display the requested analysis in one window.
%
% The single MATLAB figure contains one tab per requested plot plus a recap
% tab. Each plot tab contains a self-contained caption describing the axes,
% statistical test, interpretation, and expected result. Behavioral
% inference uses real eye-controlled two-target choices; single-target
% instruction trials are excluded by the core statistics pipeline.

if nargin < 5
    options = struct();
end
if nargin < 6
    summaryFile = '';
end
options = fillFigureDefaults(options);
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end

if meta.nRealEyeChoices > 0
    inferenceLabel = sprintf('%d real eye-controlled two-target choices', ...
        meta.nRealEyeChoices);
else
    inferenceLabel = 'DEBUG DESCRIPTION: no real eye-controlled choices';
end
blockLabel = sprintf('blocks %d-%d', round(min(meta.analyzedBlocks)), ...
    round(max(meta.analyzedBlocks)));
header = sprintf('%s | %s | %s', char(meta.sessionID), blockLabel, ...
    inferenceLabel);

fig = figure('Color', 'w', 'Units', 'normalized', ...
    'OuterPosition', [0 0 1 1], 'Name', 'SRS Simple Analysis', ...
    'NumberTitle', 'off', 'MenuBar', 'figure', 'ToolBar', 'figure');
tabGroup = uitabgroup('Parent', fig, 'Units', 'normalized', ...
    'Position', [0 0 1 1]);

tabInfo = repmat(struct('Handle', [], 'BaseName', ''), 0, 1);

%% 1. Candidate strategies
caption = [ ...
    "Axes: horizontal = fraction of real two-target choices predicted correctly; vertical = deterministic candidate policies. The dashed line at 0.5 is chance."; ...
    "Test: each strategy is tested against 0.5 with a two-sided exact binomial test, followed by Benjamini-Hochberg FDR correction across strategies; stars show q-values."; ...
    "What it shows: which simple policy best matches the observed choices. Strategies that generate identical predictions remain statistically indistinguishable."; ...
    "Expected: a learned reward rule should place Choose rich target/side above chance after reward reversals; a spatial habit should elevate Always right/left or repeat-side strategies." ...
    ];
[tab, ax] = createPlotTab(tabGroup, '1. Strategies', header, caption, ...
    [0.19 0.27 0.77 0.62]);
axes(ax); %#ok<LAXES>
plotStrategyAccuracy(stats.strategyTable);
tabInfo(end + 1) = makeTabInfo(tab, ...
    '01_candidate_strategies_real_choices'); %#ok<AGROW>

%% 2. Choice by task condition
caption = [ ...
    "Axes: horizontal = high-salience and high-reward choices in conflict and congruent trials; vertical = choice probability. Error bars are 95% Wilson confidence intervals; dashed line = 0.5."; ...
    "Tests: stars above bars are two-sided exact binomial tests against 0.5; brackets compare conflict with congruent using two-sided Fisher exact tests. Related tests use FDR-adjusted q-values."; ...
    "What it shows: whether salience or reward guides choices in each task condition."; ...
    "Expected: reward learning should produce P(high reward)>0.5, especially during conflict; salience capture should instead produce P(high salience)>0.5." ...
    ];
[tab, ax] = createPlotTab(tabGroup, '2. Task condition', header, caption, ...
    [0.13 0.29 0.83 0.60]);
axes(ax); %#ok<LAXES>
plotOnlineChoiceBars(stats);
tabInfo(end + 1) = makeTabInfo(tab, ...
    '02_choice_by_task_condition'); %#ok<AGROW>

%% 3. Conditional associations
caption = [ ...
    "Axes: each horizontal bar is P(response=1|predictor=1) minus P(response=1|predictor=0); positive values mean the predictor increases the named response. Vertical = predictor-response pairs."; ...
    "Test: each association uses a two-sided Fisher exact test on a 2x2 table, with FDR correction across associations."; ...
    "What it shows: associations of reward side, salience side, target identity, and previous choice with current spatial or identity choice."; ...
    "Expected: reward guidance gives positive rich-target effects; salience guidance gives positive high-salience effects; a large previous-choice effect indicates perseveration." ...
    ];
[tab, ax] = createPlotTab(tabGroup, '3. Associations', header, caption, ...
    [0.23 0.27 0.73 0.62]);
axes(ax); %#ok<LAXES>
plotAssociationEffects(stats.associationTable);
tabInfo(end + 1) = makeTabInfo(tab, ...
    '03_conditional_associations_real_choices'); %#ok<AGROW>

%% 4. Conditional spatial influences
caption = [ ...
    "Axes: horizontal pairs trials in which the rich target, high-salience target, T1, or previous choice was left versus right; vertical = P(choose right). Dashed line = 0.5."; ...
    "Test: each left-versus-right pair is compared with a two-sided Fisher exact test; brackets show FDR-adjusted significance."; ...
    "What it shows: whether each factor shifts spatial choice independently of target identity."; ...
    "Expected: an unbiased animal remains near 0.5 when T1 or rich side changes; a salience effect raises P(right) when salience is right; a large previous-side difference indicates spatial perseveration." ...
    ];
[tab, ax] = createPlotTab(tabGroup, '4. Spatial effects', header, caption, ...
    [0.12 0.29 0.84 0.60]);
axes(ax); %#ok<LAXES>
plotConditionalRightChoice(T, stats.associationTable);
tabInfo(end + 1) = makeTabInfo(tab, ...
    '04_conditional_spatial_influences'); %#ok<AGROW>

%% 5. Conflict versus congruent
caption = [ ...
    "Axes: each group is one outcome, with separate conflict and congruent bars; vertical = choice probability. Error bars are 95% Wilson intervals; dashed line = 0.5."; ...
    "Test: conflict and congruent proportions are compared with two-sided Fisher exact tests, with FDR correction across outcomes."; ...
    "What it shows: whether salience, reward, or spatial choice changes when the salient and rich targets agree versus compete."; ...
    "Expected: congruent trials support both reward and salience; conflict trials separate them. P(choose right) should remain similar across conditions in a balanced design." ...
    ];
[tab, ax] = createPlotTab(tabGroup, '5. Conflict/congruent', header, caption, ...
    [0.12 0.29 0.84 0.60]);
axes(ax); %#ok<LAXES>
plotConditionComparisons(stats.onlineConditionComparisonTable);
tabInfo(end + 1) = makeTabInfo(tab, ...
    '05_conflict_versus_congruent'); %#ok<AGROW>

%% 6. Previous reward versus switch
caption = [ ...
    "Axes: horizontal = reward obtained on the previous two-target choice; vertical = stay versus switch of target identity. Blue points are transitions; connected markers are binned switch probabilities."; ...
    "Test: the title reports Pearson r between previous reward and switching, with a two-sided permutation p-value."; ...
    "What it shows: whether larger previous rewards stabilize the selected target identity."; ...
    "Expected: reinforcement of the previous identity predicts a negative correlation because larger rewards should reduce switching; r near zero indicates no detectable reward-dependent stay/switch policy." ...
    ];
[tab, ax] = createPlotTab(tabGroup, '6. Reward/switch', header, caption, ...
    [0.12 0.29 0.84 0.60]);
axes(ax); %#ok<LAXES>
plotExploration(T, stats);
tabInfo(end + 1) = makeTabInfo(tab, ...
    '06_previous_reward_versus_switch'); %#ok<AGROW>

%% 7. Reaction time
caption = [ ...
    "Axes: horizontal = conflict versus congruent trials; vertical = saccadic reaction time in milliseconds. Circles are individual real choices; thick lines are medians."; ...
    "Test: the bracket and title report a two-sided permutation test of the conflict-minus-congruent median difference."; ...
    "What it shows: whether competition between reward and salience changes response latency."; ...
    "Expected: conflict may lengthen reaction time if competing values require additional processing; a non-significant result indicates no detectable latency cost in this session." ...
    ];
[tab, ax] = createPlotTab(tabGroup, '7. Reaction time', header, caption, ...
    [0.12 0.29 0.84 0.60]);
axes(ax); %#ok<LAXES>
plotReactionTimes(T, stats);
tabInfo(end + 1) = makeTabInfo(tab, ...
    '07_reaction_time_conflict_versus_congruent'); %#ok<AGROW>

%% 8. Recap
summaryTab = createSummaryTab(tabGroup, '8. Recap', header, summaryFile);
tabInfo(end + 1) = makeTabInfo(summaryTab, ...
    '08_simple_analysis_recap'); %#ok<AGROW>

%% Save exports while keeping a single visible MATLAB window
figureFiles = saveTabbedWindow(fig, tabGroup, tabInfo, figureFolder, options);
tabGroup.SelectedTab = tabInfo(1).Handle;
drawnow;
end

%% Plot helpers adapted from the validated SRS_behavior_analysis_2 pipeline

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
    currentLimits = ylim;
    yRange = max(1, maxY - currentLimits(1));
    yBracket = maxY + 0.08 * yRange;
    ylim([currentLimits(1), yBracket + 0.12 * yRange]);
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
        text(min(1.03, sortedAccuracy(i) + 0.02), i, ...
            significanceStars(q(rows(i))), 'FontWeight', 'bold', ...
            'VerticalAlignment', 'middle');
    end
end
set(gca, 'YTick', 1:numel(rows), ...
    'YTickLabel', cellstr(S.Strategy(rows)), 'YDir', 'reverse', ...
    'XLim', [0 1.10]);
xlabel('Proportion of choices correctly predicted');
title(['Candidate strategies - ' label]);
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
    'FontSize', 8, 'VerticalAlignment', 'top');
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
maxAbs = max(abs(values(rows)));
if ~isfinite(maxAbs) || maxAbs == 0
    maxAbs = 0.1;
end
for i = 1:numel(rows)
    x = values(rows(i));
    offset = 0.06 * maxAbs;
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
xlim(1.25 * [-maxAbs maxAbs]);
xlabel('P(response|predictor=1) - P(response|predictor=0)');
title(['Conditional associations - ' label]);
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

function values = getColumnOrNaN(T, variableName, rows)
if any(strcmp(T.Properties.VariableNames, variableName))
    values = T.(variableName)(rows);
else
    values = nan(numel(rows), 1);
end
values = values(:);
end

function showNoData(message)
axis off;
text(0.5, 0.5, message, 'HorizontalAlignment', 'center', ...
    'Units', 'normalized', 'FontWeight', 'bold', 'Interpreter', 'none');
end


function info = makeTabInfo(tabHandle, baseName)
info = struct('Handle', tabHandle, 'BaseName', baseName);
end

function [tab, ax] = createPlotTab(tabGroup, tabTitle, headerText, ...
        captionLines, axesPosition)
tab = uitab(tabGroup, 'Title', tabTitle);
uicontrol('Parent', tab, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.02 0.935 0.96 0.045], 'String', headerText, ...
    'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'BackgroundColor', [1 1 1]);
ax = axes('Parent', tab, 'Units', 'normalized', ...
    'Position', axesPosition, 'FontSize', 11); %#ok<LAXES>
captionText = strjoin(cellstr(captionLines), sprintf('\n'));
uicontrol('Parent', tab, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.025 0.015 0.95 0.205], 'String', captionText, ...
    'FontSize', 9, 'HorizontalAlignment', 'left', ...
    'BackgroundColor', [0.97 0.97 0.97], ...
    'ForegroundColor', [0.10 0.10 0.10]);
end

function tab = createSummaryTab(tabGroup, tabTitle, headerText, summaryFile)
tab = uitab(tabGroup, 'Title', tabTitle);
uicontrol('Parent', tab, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.02 0.935 0.96 0.045], 'String', headerText, ...
    'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'BackgroundColor', [1 1 1]);
if ~isempty(summaryFile) && isfile(summaryFile)
    summaryLines = regexp(fileread(summaryFile), '\r\n|\n|\r', 'split');
else
    summaryLines = {'The text recap could not be loaded.'};
end
uicontrol('Parent', tab, 'Style', 'edit', 'Units', 'normalized', ...
    'Position', [0.035 0.04 0.93 0.86], 'String', summaryLines, ...
    'Max', 2, 'Min', 0, 'Enable', 'inactive', ...
    'HorizontalAlignment', 'left', 'FontName', 'Courier', ...
    'FontSize', 10, 'BackgroundColor', [1 1 1]);
end

function figureFiles = saveTabbedWindow(fig, tabGroup, tabInfo, ...
        figureFolder, options)
figureFiles = strings(0, 1);
originalTab = tabGroup.SelectedTab;
set(fig, 'PaperPositionMode', 'auto', 'InvertHardcopy', 'off');

for iTab = 1:numel(tabInfo)
    tabGroup.SelectedTab = tabInfo(iTab).Handle;
    drawnow;
    baseName = tabInfo(iTab).BaseName;
    if options.saveFigures
        pngPath = fullfile(figureFolder, [baseName '.png']);
        try
            print(fig, pngPath, '-dpng', '-r180');
            figureFiles(end + 1) = string(pngPath); %#ok<AGROW>
        catch exportError
            warning('SRS:SimpleAnalysis:PNGExport', ...
                'Could not export %s: %s', pngPath, exportError.message);
        end
    end
    if options.savePdfFigures
        pdfPath = fullfile(figureFolder, [baseName '.pdf']);
        try
            print(fig, pdfPath, '-dpdf');
            figureFiles(end + 1) = string(pdfPath); %#ok<AGROW>
        catch exportError
            warning('SRS:SimpleAnalysis:PDFExport', ...
                'Could not export %s: %s', pdfPath, exportError.message);
        end
    end
end

if options.saveMatlabFigures
    figPath = fullfile(figureFolder, 'simple_analysis_all_tabs.fig');
    try
        if exist('savefig', 'file') == 2
            savefig(fig, figPath);
        else
            saveas(fig, figPath);
        end
        figureFiles(end + 1) = string(figPath); %#ok<AGROW>
    catch exportError
        warning('SRS:SimpleAnalysis:FIGExport', ...
            'Could not save %s: %s', figPath, exportError.message);
    end
end

tabGroup.SelectedTab = originalTab;
drawnow;
end

function options = fillFigureDefaults(options)
defaults = struct('saveFigures', true, 'savePdfFigures', true, ...
    'saveMatlabFigures', true);
fields = fieldnames(defaults);
for i = 1:numel(fields)
    if ~isfield(options, fields{i}) || isempty(options.(fields{i}))
        options.(fields{i}) = defaults.(fields{i});
    end
end
end
