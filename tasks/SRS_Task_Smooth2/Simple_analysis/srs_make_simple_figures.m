function figureFiles = srs_make_simple_figures(T, stats, meta, figureFolder, options, summaryFile)
%SRS_MAKE_SIMPLE_FIGURES Display all requested analyses on one page.
%
% A single MATLAB figure contains seven plot panels and one recap panel.
% There are no tabs and no additional figure windows. Each plot has a
% caption directly underneath it describing the axes, statistical test,
% interpretation, and expected result. Behavioral inference uses real
% eye-controlled two-target choices; single-target instruction trials are
% excluded by the core statistics pipeline.

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
    'OuterPosition', [0 0 1 1], 'Name', 'SRS Simple Analysis - One Page', ...
    'NumberTitle', 'off', 'MenuBar', 'figure', 'ToolBar', 'figure', ...
    'Resize', 'on');

uicontrol('Parent', fig, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.01 0.962 0.98 0.030], 'String', header, ...
    'FontSize', 11, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center', 'BackgroundColor', [1 1 1]);

panelPositions = makePanelGrid(4, 2);

%% 1. Candidate strategies
caption = [ ...
    "Axes: x = fraction of real two-target choices correctly predicted; y = deterministic candidate strategies; dashed line = chance (0.5)."; ...
    "Test: two-sided exact binomial test versus 0.5 for each strategy, followed by Benjamini-Hochberg FDR correction; stars report q-values."; ...
    "Shows: which simple policy most closely matches the observed choices; identical prediction sequences remain indistinguishable."; ...
    "Expected: reward learning elevates rich-target/side strategies; a spatial habit elevates always-left/right or repeat-side strategies." ...
    ];
[~, ax] = createPlotPanel(fig, panelPositions(1,:), ...
    '1. Candidate strategies', caption, [0.28 0.36 0.69 0.56]);
axes(ax); %#ok<LAXES>
plotStrategyAccuracy(stats.strategyTable);
formatPanelAxes(ax);

%% 2. Choice by task condition
caption = [ ...
    "Axes: x = salience- and reward-based choices in conflict and congruent trials; y = probability; error bars = 95% Wilson CI; dashed line = 0.5."; ...
    "Tests: exact binomial tests versus 0.5 for bars; two-sided Fisher exact tests for conflict versus congruent; related tests are FDR-corrected."; ...
    "Shows: whether salience or reward guides choice separately in the two task conditions."; ...
    "Expected: reward learning gives P(high reward)>0.5, especially in conflict; salience capture gives P(high salience)>0.5." ...
    ];
[~, ax] = createPlotPanel(fig, panelPositions(2,:), ...
    '2. Choice by task condition', caption, [0.14 0.36 0.83 0.56]);
axes(ax); %#ok<LAXES>
plotOnlineChoiceBars(stats);
formatPanelAxes(ax);

%% 3. Conditional associations
caption = [ ...
    "Axes: x = P(response=1|predictor=1) - P(response=1|predictor=0); y = predictor-response pairs; positive values increase the named response."; ...
    "Test: two-sided Fisher exact test on each 2x2 table, followed by FDR correction across associations."; ...
    "Shows: associations of reward, salience, identity, side, and previous choice with current choice."; ...
    "Expected: positive rich or high-salience effects indicate value or salience guidance; a large previous-choice effect indicates perseveration." ...
    ];
[~, ax] = createPlotPanel(fig, panelPositions(3,:), ...
    '3. Conditional associations', caption, [0.30 0.36 0.67 0.56]);
axes(ax); %#ok<LAXES>
plotAssociationEffects(stats.associationTable);
formatPanelAxes(ax);

%% 4. Conditional spatial influences
caption = [ ...
    "Axes: x = rich, high-salience, T1, or previous choice located left versus right; y = P(choose right); dashed line = 0.5."; ...
    "Test: two-sided Fisher exact tests compare each left/right pair; bracket labels use FDR-adjusted significance."; ...
    "Shows: how each factor changes spatial choice independently of target identity."; ...
    "Expected: balanced identity/reward placement stays near 0.5; salience-right raises right choice; a large previous-side effect indicates spatial perseveration." ...
    ];
[~, ax] = createPlotPanel(fig, panelPositions(4,:), ...
    '4. Conditional spatial influences', caption, [0.14 0.36 0.83 0.56]);
axes(ax); %#ok<LAXES>
plotConditionalRightChoice(T, stats.associationTable);
formatPanelAxes(ax);

%% 5. Conflict versus congruent
caption = [ ...
    "Axes: x = high-salience choice, high-reward choice, and right choice; y = probability; paired bars = conflict and congruent; error bars = 95% Wilson CI."; ...
    "Test: two-sided Fisher exact tests compare conflict with congruent for each outcome, followed by FDR correction."; ...
    "Shows: whether salience, reward, or side choice changes when salient and rich targets agree versus compete."; ...
    "Expected: conflict separates reward from salience; right-choice probability should remain similar when the design is spatially balanced." ...
    ];
[~, ax] = createPlotPanel(fig, panelPositions(5,:), ...
    '5. Conflict versus congruent', caption, [0.14 0.36 0.83 0.56]);
axes(ax); %#ok<LAXES>
plotConditionComparisons(stats.onlineConditionComparisonTable);
formatPanelAxes(ax);

%% 6. Previous reward versus identity switch
caption = [ ...
    "Axes: x = reward obtained on the previous two-target choice; y = stay or switch target identity; points = transitions; line = binned switch probability."; ...
    "Test: Pearson correlation between previous reward and switching, with a two-sided permutation p-value in the title."; ...
    "Shows: whether the amount of previous reward stabilizes the previously selected identity."; ...
    "Expected: reinforcement predicts a negative correlation because larger reward should reduce switching; r near zero indicates no detectable effect." ...
    ];
[~, ax] = createPlotPanel(fig, panelPositions(6,:), ...
    '6. Previous reward versus identity switch', caption, ...
    [0.14 0.36 0.83 0.56]);
axes(ax); %#ok<LAXES>
plotExploration(T, stats);
formatPanelAxes(ax);

%% 7. Reaction time
caption = [ ...
    "Axes: x = conflict versus congruent; y = saccadic reaction time (ms); circles = individual real choices; thick horizontal lines = medians."; ...
    "Test: two-sided permutation test of the conflict-minus-congruent median difference, reported by the bracket and title."; ...
    "Shows: whether competition between reward and salience changes response latency."; ...
    "Expected: conflict may lengthen reaction time; a non-significant result indicates no detectable conflict cost in this session." ...
    ];
[~, ax] = createPlotPanel(fig, panelPositions(7,:), ...
    '7. Reaction time', caption, [0.14 0.36 0.83 0.56]);
axes(ax); %#ok<LAXES>
plotReactionTimes(T, stats);
formatPanelAxes(ax);

%% 8. Recap
createSummaryPanel(fig, panelPositions(8,:), '8. Recap', summaryFile);

%% Save the complete one-page figure
figureFiles = saveOnePageFigure(fig, figureFolder, options);
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

function positions = makePanelGrid(nRows, nCols)
%MAKEPANELGRID Return normalized panel positions ordered left-to-right,
%top-to-bottom.
leftMargin = 0.012;
rightMargin = 0.012;
bottomMargin = 0.012;
topMargin = 0.052;
horizontalGap = 0.012;
verticalGap = 0.012;

panelWidth = (1 - leftMargin - rightMargin - ...
    (nCols - 1) * horizontalGap) / nCols;
panelHeight = (1 - topMargin - bottomMargin - ...
    (nRows - 1) * verticalGap) / nRows;

positions = nan(nRows * nCols, 4);
index = 0;
for row = 1:nRows
    y = 1 - topMargin - row * panelHeight - ...
        (row - 1) * verticalGap;
    for column = 1:nCols
        index = index + 1;
        x = leftMargin + (column - 1) * (panelWidth + horizontalGap);
        positions(index,:) = [x y panelWidth panelHeight];
    end
end
end

function [panel, ax] = createPlotPanel(fig, panelPosition, panelTitle, ...
        captionLines, axesPosition)
panel = uipanel('Parent', fig, 'Units', 'normalized', ...
    'Position', panelPosition, 'Title', panelTitle, ...
    'FontSize', 9, 'FontWeight', 'bold', ...
    'BackgroundColor', [1 1 1], 'BorderType', 'etchedin');
ax = axes('Parent', panel, 'Units', 'normalized', ...
    'Position', axesPosition, 'FontSize', 7); %#ok<LAXES>
captionText = cellstr(captionLines);
uicontrol('Parent', panel, 'Style', 'text', 'Units', 'normalized', ...
    'Position', [0.02 0.015 0.96 0.285], 'String', captionText, ...
    'FontSize', 6.3, 'HorizontalAlignment', 'left', ...
    'BackgroundColor', [0.97 0.97 0.97], ...
    'ForegroundColor', [0.10 0.10 0.10]);
end

function createSummaryPanel(fig, panelPosition, panelTitle, summaryFile)
panel = uipanel('Parent', fig, 'Units', 'normalized', ...
    'Position', panelPosition, 'Title', panelTitle, ...
    'FontSize', 9, 'FontWeight', 'bold', ...
    'BackgroundColor', [1 1 1], 'BorderType', 'etchedin');
if ~isempty(summaryFile) && isfile(summaryFile)
    summaryLines = regexp(fileread(summaryFile), '\r\n|\n|\r', 'split');
else
    summaryLines = {'The text recap could not be loaded.'};
end
uicontrol('Parent', panel, 'Style', 'edit', 'Units', 'normalized', ...
    'Position', [0.025 0.035 0.95 0.91], 'String', summaryLines, ...
    'Max', 2, 'Min', 0, 'Enable', 'inactive', ...
    'HorizontalAlignment', 'left', 'FontName', 'Courier', ...
    'FontSize', 6.5, 'BackgroundColor', [1 1 1]);
end

function formatPanelAxes(ax)
%FORMATPANELAXES Keep labels readable in the compact one-page layout.
set(ax, 'FontSize', 7, 'Box', 'off');
ax.Title.FontSize = 9;
ax.Title.FontWeight = 'bold';
ax.XLabel.FontSize = 7;
ax.YLabel.FontSize = 7;
end

function figureFiles = saveOnePageFigure(fig, figureFolder, options)
figureFiles = strings(0, 1);
baseName = 'simple_analysis_one_page';
drawnow;
set(fig, 'PaperOrientation', 'landscape', 'PaperPositionMode', 'auto', ...
    'InvertHardcopy', 'off');

if options.saveFigures
    pngPath = fullfile(figureFolder, [baseName '.png']);
    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, pngPath, 'Resolution', 220);
        else
            print(fig, pngPath, '-dpng', '-r220');
        end
        figureFiles(end + 1) = string(pngPath); %#ok<AGROW>
    catch exportError
        warning('SRS:SimpleAnalysis:PNGExport', ...
            'Could not export %s: %s', pngPath, exportError.message);
    end
end

if options.savePdfFigures
    pdfPath = fullfile(figureFolder, [baseName '.pdf']);
    try
        if exist('exportgraphics', 'file') == 2
            exportgraphics(fig, pdfPath, 'ContentType', 'vector');
        else
            print(fig, pdfPath, '-dpdf', '-bestfit');
        end
        figureFiles(end + 1) = string(pdfPath); %#ok<AGROW>
    catch exportError
        warning('SRS:SimpleAnalysis:PDFExport', ...
            'Could not export %s: %s', pdfPath, exportError.message);
    end
end

if options.saveMatlabFigures
    figPath = fullfile(figureFolder, [baseName '.fig']);
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
