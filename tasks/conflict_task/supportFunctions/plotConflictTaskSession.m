function plotConflictTaskSession(dataFile)
%   plotConflictTaskSession(dataFile)
%
% Standalone script to plot conflict task session data from a concatenated
% .mat file. Generates the same 6-panel visualization used online:
%   Panel 1: Phase 1 P(High Salience) by Hemifield
%   Panel 2: Phases 2-3 P(High Salience) Conflict vs Congruent
%   Panel 3: Phase 1 Median RT by Hemifield
%   Panel 4: Phases 2-3 Median RT Conflict vs Congruent
%   Panel 5: Choice Evolution Over Session
%   Panel 6: Session Information
%
% SRT is recomputed from online timing variables (saccadeOnset - fixOff)
% rather than using stored p.trData.SRT, which may have been computed with
% a timing reference bug in some sessions.
%
% Usage:
%   plotConflictTaskSession('output/20260213_t1018_conflict_task.mat')

if nargin < 1
    dataFile = 'output/20260213_t1018_conflict_task.mat';
end

%% Load data
% define location of PLDAPS home directory:
pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
fprintf('Loading %s ...\n', dataFile);
data = load([pldapsHome filesep dataFile]);

% Handle nested structure (load may wrap in a struct)
if isfield(data, 'p')
    p = data.p;
else
    p = data;
end

nTrials = length(p.trData);
fprintf('Loaded %d trials.\n', nTrials);

%% Extract state definitions
sacCompleteState = p.state.sacComplete;
fixBreakState    = p.state.fixBreak;
noResponseState  = p.state.noResponse;
inaccurateState  = p.state.inaccurate;

%% Determine deltaT values
if isfield(p.status, 'deltaTValues')
    deltaTValues = p.status.deltaTValues;
else
    % Fall back: derive from trial array
    allDeltaT = arrayfun(@(x) x.deltaT, p.trVars);
    deltaTValues = unique(allDeltaT(allDeltaT ~= 0))';
    if isempty(deltaTValues)
        deltaTValues = [-150, 150];
    end
end
nDeltaT = length(deltaTValues);

%% Extract per-trial variables
phaseNumber    = arrayfun(@(x) x.phaseNumber, p.trVars);
deltaTIdx      = arrayfun(@(x) x.deltaTIdx, p.trVars);
highSalSide    = arrayfun(@(x) x.highSalienceSide, p.trVars);
rewardBigSide  = arrayfun(@(x) x.rewardBigSide, p.trVars);
singleStimSide = arrayfun(@(x) x.singleStimSide, p.trVars);
choseHighSal   = arrayfun(@(x) x.choseHighSalience, p.trData);
trialEndState  = arrayfun(@(x) x.trialEndState, p.trData);

% Compute isConflict per trial
if isfield(p.trVars, 'isConflict')
    isConflict = arrayfun(@(x) x.isConflict, p.trVars);
else
    % Recompute: conflict when rewardBigSide != highSalienceSide
    isConflict = (rewardBigSide ~= highSalSide) & (singleStimSide == 0);
end

% Compute SRT from online timing (both trial-relative, in seconds)
srt_ms = NaN(1, nTrials);
for i = 1:nTrials
    if trialEndState(i) == sacCompleteState
        fixOff    = p.trData(i).timing.fixOff;
        sacOnset  = p.trData(i).timing.saccadeOnset;
        if fixOff > 0 && sacOnset > 0
            srt_ms(i) = (sacOnset - fixOff) * 1000;  % convert to ms
        end
    end
end

%% Identify trial subsets
isSacComplete  = (trialEndState == sacCompleteState);
isDualStim     = (singleStimSide == 0);
isSingleStim   = ~isDualStim;

%% Accumulate metrics by condition
% Initialize metric structures: {deltaTIdx} -> struct with counts and RTs
emptyMetric = struct('nChoseHighSal', 0, 'nChoseLowSal', 0, ...
    'rtHighSal', [], 'rtLowSal', []);

% Phase 1 by hemifield
p1_highSalLeft  = repmat({emptyMetric}, nDeltaT, 1);
p1_highSalRight = repmat({emptyMetric}, nDeltaT, 1);

% Phases 2-3 by conflict/congruent
p2_conflict  = repmat({emptyMetric}, nDeltaT, 1);
p2_congruent = repmat({emptyMetric}, nDeltaT, 1);
p3_conflict  = repmat({emptyMetric}, nDeltaT, 1);
p3_congruent = repmat({emptyMetric}, nDeltaT, 1);

% Counters
nChoseHighSalience = 0;
nChoseLowSalience  = 0;
nFixBreak    = 0;
nNoResponse  = 0;
nInaccurate  = 0;
nSingleStimCorrect = 0;
nSingleStimTotal   = 0;

% Cumulative tracking (for evolution plot)
cum_trialNum     = [];
cum_choseHighSal = [];
cum_phase        = [];
cum_highSalSide  = [];
cum_isConflict   = [];
cum_isSingleStim = [];

goodTrialCount = 0;

for i = 1:nTrials
    % Count errors (all trials)
    switch trialEndState(i)
        case fixBreakState
            nFixBreak = nFixBreak + 1;
        case noResponseState
            nNoResponse = nNoResponse + 1;
        case inaccurateState
            nInaccurate = nInaccurate + 1;
    end

    % Only process completed saccade trials for metrics
    if ~isSacComplete(i)
        continue
    end

    goodTrialCount = goodTrialCount + 1;
    iDT = deltaTIdx(i);
    rt  = srt_ms(i);

    % Cumulative tracking
    cum_trialNum(end+1)     = goodTrialCount;          %#ok<AGROW>
    cum_choseHighSal(end+1) = choseHighSal(i);         %#ok<AGROW>
    cum_phase(end+1)        = phaseNumber(i);           %#ok<AGROW>
    cum_highSalSide(end+1)  = highSalSide(i);          %#ok<AGROW>
    cum_isConflict(end+1)   = isConflict(i);            %#ok<AGROW>
    cum_isSingleStim(end+1) = isSingleStim(i);         %#ok<AGROW>

    % Route metrics by phase
    if phaseNumber(i) == 1
        if isSingleStim(i)
            nSingleStimTotal = nSingleStimTotal + 1;
            if choseHighSal(i)
                nSingleStimCorrect = nSingleStimCorrect + 1;
            end
        else
            % Dual-stim Phase 1: by hemifield
            if highSalSide(i) == 1
                metricsCell = p1_highSalLeft;
            else
                metricsCell = p1_highSalRight;
            end

            if choseHighSal(i)
                metricsCell{iDT}.nChoseHighSal = metricsCell{iDT}.nChoseHighSal + 1;
                if ~isnan(rt)
                    metricsCell{iDT}.rtHighSal(end+1) = rt;
                end
            else
                metricsCell{iDT}.nChoseLowSal = metricsCell{iDT}.nChoseLowSal + 1;
                if ~isnan(rt)
                    metricsCell{iDT}.rtLowSal(end+1) = rt;
                end
            end

            if highSalSide(i) == 1
                p1_highSalLeft = metricsCell;
            else
                p1_highSalRight = metricsCell;
            end
        end

    elseif phaseNumber(i) == 2
        if isConflict(i)
            metricsCell = p2_conflict;
        else
            metricsCell = p2_congruent;
        end

        if choseHighSal(i)
            metricsCell{iDT}.nChoseHighSal = metricsCell{iDT}.nChoseHighSal + 1;
            if ~isnan(rt), metricsCell{iDT}.rtHighSal(end+1) = rt; end
        else
            metricsCell{iDT}.nChoseLowSal = metricsCell{iDT}.nChoseLowSal + 1;
            if ~isnan(rt), metricsCell{iDT}.rtLowSal(end+1) = rt; end
        end

        if isConflict(i), p2_conflict = metricsCell; else, p2_congruent = metricsCell; end

    elseif phaseNumber(i) == 3
        if isConflict(i)
            metricsCell = p3_conflict;
        else
            metricsCell = p3_congruent;
        end

        if choseHighSal(i)
            metricsCell{iDT}.nChoseHighSal = metricsCell{iDT}.nChoseHighSal + 1;
            if ~isnan(rt), metricsCell{iDT}.rtHighSal(end+1) = rt; end
        else
            metricsCell{iDT}.nChoseLowSal = metricsCell{iDT}.nChoseLowSal + 1;
            if ~isnan(rt), metricsCell{iDT}.rtLowSal(end+1) = rt; end
        end

        if isConflict(i), p3_conflict = metricsCell; else, p3_congruent = metricsCell; end
    end

    % Global outcome counters (dual-stim only)
    if isDualStim(i)
        if choseHighSal(i)
            nChoseHighSalience = nChoseHighSalience + 1;
        else
            nChoseLowSalience = nChoseLowSalience + 1;
        end
    end
end

%% Compute summary statistics for plotting

% Panel 1: Phase 1 P(HighSal) by Hemifield
pHS_left  = NaN(1, nDeltaT);
pHS_right = NaN(1, nDeltaT);
for iDT = 1:nDeltaT
    nHS = p1_highSalLeft{iDT}.nChoseHighSal;
    nLS = p1_highSalLeft{iDT}.nChoseLowSal;
    if (nHS + nLS) > 0, pHS_left(iDT) = nHS / (nHS + nLS); end

    nHS = p1_highSalRight{iDT}.nChoseHighSal;
    nLS = p1_highSalRight{iDT}.nChoseLowSal;
    if (nHS + nLS) > 0, pHS_right(iDT) = nHS / (nHS + nLS); end
end

% Panel 2: Phases 2-3 P(HighSal) Conflict vs Congruent
pHS_conflict  = NaN(1, nDeltaT);
pHS_congruent = NaN(1, nDeltaT);
for iDT = 1:nDeltaT
    nHS = p2_conflict{iDT}.nChoseHighSal  + p3_conflict{iDT}.nChoseHighSal;
    nLS = p2_conflict{iDT}.nChoseLowSal   + p3_conflict{iDT}.nChoseLowSal;
    if (nHS + nLS) > 0, pHS_conflict(iDT) = nHS / (nHS + nLS); end

    nHS = p2_congruent{iDT}.nChoseHighSal + p3_congruent{iDT}.nChoseHighSal;
    nLS = p2_congruent{iDT}.nChoseLowSal  + p3_congruent{iDT}.nChoseLowSal;
    if (nHS + nLS) > 0, pHS_congruent(iDT) = nHS / (nHS + nLS); end
end

% Panel 3: Phase 1 Median RT by Hemifield
medRT_left  = NaN(1, nDeltaT);
medRT_right = NaN(1, nDeltaT);
for iDT = 1:nDeltaT
    allRT = [p1_highSalLeft{iDT}.rtHighSal, p1_highSalLeft{iDT}.rtLowSal];
    if ~isempty(allRT), medRT_left(iDT) = median(allRT); end

    allRT = [p1_highSalRight{iDT}.rtHighSal, p1_highSalRight{iDT}.rtLowSal];
    if ~isempty(allRT), medRT_right(iDT) = median(allRT); end
end

% Panel 4: Phases 2-3 Median RT Conflict vs Congruent
medRT_conflict  = NaN(1, nDeltaT);
medRT_congruent = NaN(1, nDeltaT);
for iDT = 1:nDeltaT
    allRT = [p2_conflict{iDT}.rtHighSal,  p2_conflict{iDT}.rtLowSal, ...
             p3_conflict{iDT}.rtHighSal,  p3_conflict{iDT}.rtLowSal];
    if ~isempty(allRT), medRT_conflict(iDT) = median(allRT); end

    allRT = [p2_congruent{iDT}.rtHighSal, p2_congruent{iDT}.rtLowSal, ...
             p3_congruent{iDT}.rtHighSal, p3_congruent{iDT}.rtLowSal];
    if ~isempty(allRT), medRT_congruent(iDT) = median(allRT); end
end

%% ======================== CREATE FIGURE ========================

fig = figure('Position', [100 50 1200 950], ...
    'Name', 'Conflict Task - Session Summary', ...
    'NumberTitle', 'off', 'Color', [1 1 1]);

% Colors (match online visualization)
orangeC = [0.850 0.325 0.098];   % High Sal Left / Conflict
blueC   = [0.000 0.447 0.741];   % High Sal Right / Congruent

%% Panel 1: Phase 1 P(High Sal) by Hemifield
ax1 = axes('Parent', fig, 'Position', [0.06 0.72 0.28 0.22], ...
    'TickDir', 'out', 'LineWidth', 1.5, 'NextPlot', 'add', ...
    'XLim', [-200 200], 'YLim', [0 1], ...
    'XTick', deltaTValues, 'YTick', [0 0.25 0.5 0.75 1], 'FontSize', 10);
xlabel(ax1, '\Deltat (ms)', 'FontSize', 11);
ylabel(ax1, 'P(High Salience)', 'FontSize', 11);
title(ax1, 'Phase 1 - By Hemifield', 'FontSize', 12, 'FontWeight', 'bold');
plot(ax1, [-200 200], [0.5 0.5], '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1);

h1L = plot(ax1, deltaTValues(~isnan(pHS_left)),  pHS_left(~isnan(pHS_left)),  '-o', ...
    'Color', orangeC, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', orangeC);
h1R = plot(ax1, deltaTValues(~isnan(pHS_right)), pHS_right(~isnan(pHS_right)), '-o', ...
    'Color', blueC, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', blueC);
legend(ax1, [h1L, h1R], {'High Sal LEFT', 'High Sal RIGHT'}, ...
    'Location', 'southeast', 'FontSize', 9, 'Box', 'off');

%% Panel 2: Phases 2-3 P(High Sal) Conflict vs Congruent
ax2 = axes('Parent', fig, 'Position', [0.40 0.72 0.28 0.22], ...
    'TickDir', 'out', 'LineWidth', 1.5, 'NextPlot', 'add', ...
    'XLim', [-200 200], 'YLim', [0 1], ...
    'XTick', deltaTValues, 'YTick', [0 0.25 0.5 0.75 1], 'FontSize', 10);
xlabel(ax2, '\Deltat (ms)', 'FontSize', 11);
ylabel(ax2, 'P(High Salience)', 'FontSize', 11);
title(ax2, 'Phases 2-3 - Conflict vs Congruent', 'FontSize', 12, 'FontWeight', 'bold');
plot(ax2, [-200 200], [0.5 0.5], '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1);

h2C = plot(ax2, deltaTValues(~isnan(pHS_conflict)),  pHS_conflict(~isnan(pHS_conflict)),  '-o', ...
    'Color', orangeC, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', orangeC);
h2G = plot(ax2, deltaTValues(~isnan(pHS_congruent)), pHS_congruent(~isnan(pHS_congruent)), '-o', ...
    'Color', blueC, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', blueC);
legend(ax2, [h2C, h2G], {'Conflict', 'Congruent'}, ...
    'Location', 'southeast', 'FontSize', 9, 'Box', 'off');

%% Panel 3: Phase 1 Median RT by Hemifield
ax3 = axes('Parent', fig, 'Position', [0.06 0.42 0.28 0.22], ...
    'TickDir', 'out', 'LineWidth', 1.5, 'NextPlot', 'add', ...
    'XLim', [-200 200], 'YLim', [100 500], ...
    'XTick', deltaTValues, 'FontSize', 10);
xlabel(ax3, '\Deltat (ms)', 'FontSize', 11);
ylabel(ax3, 'Median RT (ms)', 'FontSize', 11);
title(ax3, 'Phase 1 - Median RT', 'FontSize', 12, 'FontWeight', 'bold');

h3L = plot(ax3, deltaTValues(~isnan(medRT_left)),  medRT_left(~isnan(medRT_left)),  '-s', ...
    'Color', orangeC, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', orangeC);
h3R = plot(ax3, deltaTValues(~isnan(medRT_right)), medRT_right(~isnan(medRT_right)), '-s', ...
    'Color', blueC, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', blueC);
legend(ax3, [h3L, h3R], {'High Sal LEFT', 'High Sal RIGHT'}, ...
    'Location', 'northeast', 'FontSize', 9, 'Box', 'off');

%% Panel 4: Phases 2-3 Median RT Conflict vs Congruent
ax4 = axes('Parent', fig, 'Position', [0.40 0.42 0.28 0.22], ...
    'TickDir', 'out', 'LineWidth', 1.5, 'NextPlot', 'add', ...
    'XLim', [-200 200], 'YLim', [100 500], ...
    'XTick', deltaTValues, 'FontSize', 10);
xlabel(ax4, '\Deltat (ms)', 'FontSize', 11);
ylabel(ax4, 'Median RT (ms)', 'FontSize', 11);
title(ax4, 'Phases 2-3 - Median RT', 'FontSize', 12, 'FontWeight', 'bold');

h4C = plot(ax4, deltaTValues(~isnan(medRT_conflict)),  medRT_conflict(~isnan(medRT_conflict)),  '-s', ...
    'Color', orangeC, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', orangeC);
h4G = plot(ax4, deltaTValues(~isnan(medRT_congruent)), medRT_congruent(~isnan(medRT_congruent)), '-s', ...
    'Color', blueC, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', blueC);
legend(ax4, [h4C, h4G], {'Conflict', 'Congruent'}, ...
    'Location', 'northeast', 'FontSize', 9, 'Box', 'off');

%% Panel 5: Choice Evolution Over Session
totalTrials = length(cum_trialNum);
ax5 = axes('Parent', fig, 'Position', [0.06 0.06 0.62 0.28], ...
    'TickDir', 'out', 'LineWidth', 1.5, 'NextPlot', 'add', ...
    'XLim', [0 max(totalTrials + 10, 460)], 'YLim', [0 1], ...
    'YTick', [0 0.25 0.5 0.75 1], 'FontSize', 10);
xlabel(ax5, 'Trial Number', 'FontSize', 11);
ylabel(ax5, 'Cumulative P(High Salience)', 'FontSize', 11);
title(ax5, 'Choice Evolution Over Session', 'FontSize', 12, 'FontWeight', 'bold');

% Reference line
plot(ax5, [0 500], [0.5 0.5], '--', 'Color', [0.7 0.7 0.7], 'LineWidth', 1);

% Phase transition lines (based on actual trial counts)
if isfield(p.init, 'trialsPerPhaseList')
    phaseBoundary1 = p.init.trialsPerPhaseList(1);
    phaseBoundary2 = phaseBoundary1 + p.init.trialsPerPhaseList(2);
else
    phaseBoundary1 = 192;
    phaseBoundary2 = 320;
end
plot(ax5, [phaseBoundary1 phaseBoundary1], [0 1], ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
plot(ax5, [phaseBoundary2 phaseBoundary2], [0 1], ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);

% Phase labels
text(ax5, phaseBoundary1/2, 0.97, 'Phase 1', 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);
text(ax5, (phaseBoundary1 + phaseBoundary2)/2, 0.97, 'Phase 2', 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);
text(ax5, (phaseBoundary2 + totalTrials)/2, 0.97, 'Phase 3', 'FontSize', 9, ...
    'HorizontalAlignment', 'center', 'Color', [0.5 0.5 0.5]);

% Phase 1: cumulative by hemifield (dual-stim only)
p1L_mask = (cum_phase == 1) & (cum_highSalSide == 1) & ~cum_isSingleStim;
p1R_mask = (cum_phase == 1) & (cum_highSalSide == 2) & ~cum_isSingleStim;

if any(p1L_mask)
    trials = cum_trialNum(p1L_mask);
    choices = cum_choseHighSal(p1L_mask);
    cumP = cumsum(choices) ./ (1:length(choices));
    plot(ax5, trials, cumP, '-', 'Color', orangeC, 'LineWidth', 1.5);
end
if any(p1R_mask)
    trials = cum_trialNum(p1R_mask);
    choices = cum_choseHighSal(p1R_mask);
    cumP = cumsum(choices) ./ (1:length(choices));
    plot(ax5, trials, cumP, '-', 'Color', blueC, 'LineWidth', 1.5);
end

% Phases 2-3: cumulative by conflict/congruent
p23_con_mask = ((cum_phase == 2) | (cum_phase == 3)) & (cum_isConflict == 1);
p23_cog_mask = ((cum_phase == 2) | (cum_phase == 3)) & (cum_isConflict == 0);

h5a = []; h5b = []; h5c = []; h5d = [];
if any(p23_con_mask)
    trials = cum_trialNum(p23_con_mask);
    choices = cum_choseHighSal(p23_con_mask);
    cumP = cumsum(choices) ./ (1:length(choices));
    h5c = plot(ax5, trials, cumP, '--', 'Color', orangeC, 'LineWidth', 1.5);
end
if any(p23_cog_mask)
    trials = cum_trialNum(p23_cog_mask);
    choices = cum_choseHighSal(p23_cog_mask);
    cumP = cumsum(choices) ./ (1:length(choices));
    h5d = plot(ax5, trials, cumP, '--', 'Color', blueC, 'LineWidth', 1.5);
end

% Build legend entries for visible traces
legHandles = []; legLabels = {};
if any(p1L_mask)
    % Use a dummy handle for legend since the solid lines were plotted directly
    h5a = plot(ax5, NaN, NaN, '-', 'Color', orangeC, 'LineWidth', 1.5);
    legHandles(end+1) = h5a; legLabels{end+1} = 'P1: Sal Left';
end
if any(p1R_mask)
    h5b = plot(ax5, NaN, NaN, '-', 'Color', blueC, 'LineWidth', 1.5);
    legHandles(end+1) = h5b; legLabels{end+1} = 'P1: Sal Right';
end
if ~isempty(h5c)
    legHandles(end+1) = h5c; legLabels{end+1} = 'P2-3: Conflict';
end
if ~isempty(h5d)
    legHandles(end+1) = h5d; legLabels{end+1} = 'P2-3: Congruent';
end
if ~isempty(legHandles)
    legend(ax5, legHandles, legLabels, 'Location', 'southwest', 'FontSize', 8, 'Box', 'off');
end

%% Panel 6: Information Panel
ax6 = axes('Parent', fig, 'Position', [0.74 0.06 0.24 0.88], 'Visible', 'off');

% Session ID
if isfield(p.init, 'sessionId')
    sessionId = p.init.sessionId;
else
    [~, sessionId] = fileparts(dataFile);
end

% Reward parameters
if isfield(p, 'trVarsInit')
    C = p.trVarsInit.rewardDurationMs;
    R = p.trVarsInit.rewardRatioBig;
    probHigh = p.trVarsInit.rewardProbHigh;
    eccDeg = p.trVarsInit.targetEccentricityDeg;
else
    C = p.trVars(1).rewardDurationMs;
    R = p.trVars(1).rewardRatioBig;
    probHigh = p.trVars(1).rewardProbHigh;
    eccDeg = p.trVars(1).targetEccentricityDeg;
end
equalR = round(C / 2);
smallR = round(C * 1 / (1 + R));
bigR   = round(C * R / (1 + R));

% Phase progress
finalPhase = max(phaseNumber);
text(ax6, 0.5, 0.95, sprintf('Phase %d/3', finalPhase), ...
    'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

text(ax6, 0.5, 0.88, sprintf('Total: %d trials completed', goodTrialCount), ...
    'FontSize', 12, 'HorizontalAlignment', 'center');

% Reward parameters
rewardParamStr = {...
    '--- Reward Parameters ---', ...
    sprintf('Budget: %d ms', C), ...
    sprintf('Ratio big:small = %.1f:1', R), ...
    sprintf('Big: %d ms | Small: %d ms', bigR, smallR), ...
    sprintf('Equal: %d ms each', equalR), ...
    sprintf('P(canonical) P2/3: %.0f%%', probHigh * 100)};
text(ax6, 0.5, 0.72, rewardParamStr, ...
    'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.3 0.3 0.3]);

% Outcome counts
outcomeStr = {...
    '--- Outcomes ---', ...
    sprintf('High Sal: %d | Low Sal: %d', nChoseHighSalience, nChoseLowSalience), ...
    sprintf('Fix Breaks: %d', nFixBreak), ...
    sprintf('No Response: %d', nNoResponse), ...
    sprintf('Inaccurate: %d', nInaccurate)};
text(ax6, 0.5, 0.50, outcomeStr, ...
    'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.4 0.4 0.4]);

% Single-stim counter
text(ax6, 0.5, 0.35, sprintf('Single-Stim: %d/%d correct', ...
    nSingleStimCorrect, nSingleStimTotal), ...
    'FontSize', 10, 'HorizontalAlignment', 'center', 'Color', [0.2 0.6 0.2]);

% Session info
sessionInfoStr = {sprintf('Session: %s', sessionId), ...
    sprintf('Eccentricity: %.1f deg', eccDeg)};
text(ax6, 0.5, 0.25, sessionInfoStr, ...
    'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.4 0.4 0.4]);

% P(HighSal) summary
nTotal = nChoseHighSalience + nChoseLowSalience;
if nTotal > 0
    pHS_overall = nChoseHighSalience / nTotal;
    summaryStr = {'--- P(HighSal) ---', sprintf('Overall: %.2f (n=%d)', pHS_overall, nTotal)};
else
    summaryStr = {'--- P(HighSal) ---', 'Overall: - (n=0)'};
end
text(ax6, 0.5, 0.12, summaryStr, ...
    'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.3 0.3 0.6]);

% RT summary
validRTs = srt_ms(~isnan(srt_ms));
if ~isempty(validRTs)
    rtSummaryStr = {'--- Median RT ---', ...
        sprintf('Overall: %.0f ms (n=%d)', median(validRTs), length(validRTs))};
else
    rtSummaryStr = {'--- Median RT ---', 'No valid RTs'};
end
text(ax6, 0.5, 0.04, rtSummaryStr, ...
    'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.3 0.5 0.3]);

%% Print summary to console
fprintf('\n=== Session Summary: %s ===\n', sessionId);
fprintf('Trials: %d total (%d completed)\n', nTrials, goodTrialCount);
fprintf('Outcomes: %d high-sal, %d low-sal, %d fix-break, %d no-resp, %d inaccurate\n', ...
    nChoseHighSalience, nChoseLowSalience, nFixBreak, nNoResponse, nInaccurate);
fprintf('Single-stim: %d/%d correct\n', nSingleStimCorrect, nSingleStimTotal);
if nTotal > 0
    fprintf('P(HighSal) overall: %.3f (n=%d)\n', nChoseHighSalience/nTotal, nTotal);
end
if ~isempty(validRTs)
    fprintf('Median RT overall: %.0f ms (n=%d)\n', median(validRTs), length(validRTs));
end

% Print per-condition RT summary
fprintf('\n--- Median RT by condition ---\n');
for iDT = 1:nDeltaT
    fprintf('deltaT = %d ms:\n', deltaTValues(iDT));
    if ~isnan(medRT_left(iDT)),      fprintf('  P1 HighSal Left:  %.0f ms\n', medRT_left(iDT)); end
    if ~isnan(medRT_right(iDT)),     fprintf('  P1 HighSal Right: %.0f ms\n', medRT_right(iDT)); end
    if ~isnan(medRT_conflict(iDT)),  fprintf('  P2-3 Conflict:    %.0f ms\n', medRT_conflict(iDT)); end
    if ~isnan(medRT_congruent(iDT)), fprintf('  P2-3 Congruent:   %.0f ms\n', medRT_congruent(iDT)); end
end

fprintf('\nFigure generated.\n');

% reformat figure for saving:
set(gcf, 'Position', [1135 2 1050 1200], 'MenuBar', 'None', ...
    'ToolBar', 'None');

% get dataFile 'stem' for PDF filename:
[~,dataFileStem] = fileparts(dataFile);

pdfWrite([pldapsHome filesep 'output' filesep dataFileStem '.pdf'], ...
    fig.Position(3:4)/72, fig)

end

function pdfWrite(fileName, paperSize, varargin)
%
% pdfSave(fileName, paperSize, [fig handle])
%
% Assuming you have a figure handle "fh" the "WYSIWYG" way to generate a
% PDF is:
%
% pdfSave(fileName, fh.Position(3:4)/72, fh)
%
% Uses exportgraphics with rasterization for smaller file sizes.
% Resolution is set to 150 DPI for good quality at reasonable size.

if nargin > 2
    fh = varargin{1};
else
    fh = gcf;
end

set(fh, 'PaperUnits', 'Inches', 'PaperSize', paperSize);
set(fh, 'PaperUnits', 'Normalized', 'PaperPosition', [0 0 1 1]);

% Use exportgraphics with rasterization for smaller file sizes
% 'ContentType', 'image' rasterizes the figure at specified resolution
exportgraphics(fh, fileName, 'Resolution', 150, 'ContentType', 'image');

end