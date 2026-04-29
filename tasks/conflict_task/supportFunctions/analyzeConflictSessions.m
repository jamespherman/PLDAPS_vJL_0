function analyzeConflictSessions()
%   analyzeConflictSessions()
%
% Comprehensive multi-session analysis of the conflict task.
% Loads 5 sessions (Feb 9, 11, 13, 16, 18, 2026), computes behavioral
% metrics, generates publication-quality figures, and prints a report.
%
% Output: PDF figures saved to output/analysis/
%
% Usage:
%   analyzeConflictSessions

%% ====================== SETUP ======================
pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
outputDir  = fullfile(pldapsHome, 'output', 'analysis');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

% Session files
sessionFiles = {
    'output/20260209_t1010_conflict_task.mat'
    'output/20260211_t0929_conflict_task.mat'
    'output/20260213_t1018_conflict_task.mat'
    'output/20260216_t0837_conflict_task.mat'
    'output/20260218_t0934_conflict_task.mat'
    };
sessionLabels = {'Feb 9', 'Feb 11', 'Feb 13', 'Feb 16', 'Feb 18'};
sessionDates  = {'2026-02-09', '2026-02-11', '2026-02-13', '2026-02-16', '2026-02-18'};
nSessions = length(sessionFiles);

% Color scheme
colSession = lines(nSessions);
colOrange  = [0.850 0.325 0.098];
colBlue    = [0.000 0.447 0.741];
colGreen   = [0.466 0.674 0.188];
colPurple  = [0.494 0.184 0.556];
colGray    = [0.5 0.5 0.5];

%% ====================== LOAD DATA ======================
fprintf('\n====== LOADING SESSIONS ======\n');
S = struct(); % master struct array

for iSess = 1:nSessions
    fpath = fullfile(pldapsHome, sessionFiles{iSess});
    fprintf('Loading %s ... ', sessionLabels{iSess});
    data = load(fpath);
    if isfield(data, 'p')
        p = data.p;
    else
        p = data;
    end
    nTrials = length(p.trData);
    fprintf('%d trials\n', nTrials);

    % --- Extract session parameters ---
    if isfield(p, 'trVarsInit')
        tv0 = p.trVarsInit;
    else
        tv0 = p.trVars(1);
    end

    S(iSess).label    = sessionLabels{iSess};
    S(iSess).date     = sessionDates{iSess};
    S(iSess).nTrials  = nTrials;
    S(iSess).p        = p;

    % Parameters (with safe defaults for pre-refactor sessions)
    S(iSess).rewardRatioBig  = safeField(tv0, 'rewardRatioBig', 2.0);
    S(iSess).rewardProbHigh  = safeField(tv0, 'rewardProbHigh', 0.9);
    S(iSess).rewardDurationMs = safeField(tv0, 'rewardDurationMs', 400);
    S(iSess).responseWindow   = safeField(tv0, 'responseWindow', 0.6);

    % deltaT values
    if isfield(p.status, 'deltaTValues')
        S(iSess).deltaTValues = p.status.deltaTValues;
    else
        allDT = arrayfun(@(x) x.deltaT, p.trVars(:)');
        S(iSess).deltaTValues = unique(allDT(~isnan(allDT)))';
    end

    % Trial array info
    if isfield(p.init, 'trialArrayColumnNames')
        S(iSess).colNames = p.init.trialArrayColumnNames;
        S(iSess).nCols    = length(S(iSess).colNames);
    else
        S(iSess).colNames = {};
        S(iSess).nCols    = 0;
    end
    if isfield(p.init, 'trialsPerPhaseList')
        S(iSess).trialsPerPhase = p.init.trialsPerPhaseList;
    else
        S(iSess).trialsPerPhase = [128 128 128];
    end

    % Has single-stim trials?
    hasSingleStimField = isfield(p.trVars, 'singleStimSide');
    if hasSingleStimField
        sss = arrayfun(@(x) x.singleStimSide, p.trVars(:)');
        S(iSess).hasSingleStim = any(sss > 0);
    else
        S(iSess).hasSingleStim = false;
    end

    % Has per-trial rewardBigSide?
    S(iSess).hasPerTrialReward = isfield(p.trVars, 'rewardBigSide');

    % --- Extract per-trial behavioral data ---
    % Force all vectors to row orientation for consistency
    sacCompleteState = p.state.sacComplete;

    phase     = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
    dtIdx     = arrayfun(@(x) x.deltaTIdx, p.trVars(:)');
    dt        = arrayfun(@(x) x.deltaT, p.trVars(:)');
    hsSide    = arrayfun(@(x) x.highSalienceSide, p.trVars(:)');
    endState  = arrayfun(@(x) x.trialEndState, p.trData(:)');

    if isfield(p.trVars, 'rewardBigSide')
        rwdSide = arrayfun(@(x) x.rewardBigSide, p.trVars(:)');
    else
        % Pre-refactor: infer from phase
        rwdSide = ones(1, nTrials);
        rwdSide(phase == 2) = 2; % Phase 2: big right
        rwdSide(phase == 3) = 1; % Phase 3: big left
        % Phase 1: equal (set to 0 = no asymmetry)
        rwdSide(phase == 1) = 0;
    end

    if hasSingleStimField
        singleStim = arrayfun(@(x) x.singleStimSide, p.trVars(:)');
    else
        singleStim = zeros(1, nTrials);
    end

    % Chosen side (1=left, 2=right)
    chosenSide = NaN(1, nTrials);
    for iTr = 1:nTrials
        if isfield(p.trData(iTr), 'chosenSide') && ~isempty(p.trData(iTr).chosenSide)
            chosenSide(iTr) = p.trData(iTr).chosenSide;
        end
    end

    if isfield(p.trData, 'choseHighSalience')
        choseHighSal = zeros(1, nTrials);
        for iTr = 1:nTrials
            val = p.trData(iTr).choseHighSalience;
            if ~isempty(val)
                choseHighSal(iTr) = double(val);
            end
        end
    else
        choseHighSal = zeros(1, nTrials);
    end

    % SRT (recompute from timing for consistency)
    srt = NaN(1, nTrials);
    for iTr = 1:nTrials
        if endState(iTr) == sacCompleteState
            fOff = p.trData(iTr).timing.fixOff;
            sOn  = p.trData(iTr).timing.saccadeOnset;
            if fOff > 0 && sOn > 0
                srt(iTr) = (sOn - fOff) * 1000;
            end
        end
    end

    % isConflict (handle logical/numeric and missing fields)
    if isfield(p.trVars, 'isConflict')
        isConf = zeros(1, nTrials);
        for iTr = 1:nTrials
            val = p.trVars(iTr).isConflict;
            if ~isempty(val)
                isConf(iTr) = double(val);
            end
        end
    else
        isConf = double((rwdSide ~= hsSide) & (rwdSide > 0) & (singleStim == 0));
    end

    % Store extracted vectors (all guaranteed row)
    isSC        = (endState == sacCompleteState);
    isDual      = (singleStim == 0);
    isSingle    = (singleStim > 0);

    S(iSess).phase      = phase;
    S(iSess).dtIdx      = dtIdx;
    S(iSess).dt         = dt;
    S(iSess).hsSide     = hsSide;
    S(iSess).rwdSide    = rwdSide;
    S(iSess).singleStim = singleStim;
    S(iSess).chosenSide = chosenSide;
    S(iSess).choseHS    = choseHighSal;
    S(iSess).srt        = srt;
    S(iSess).isConf     = isConf;
    S(iSess).isSC       = isSC;
    S(iSess).isDual     = isDual;
    S(iSess).isSingle   = isSingle;
    S(iSess).endState   = endState;

    % Error states
    S(iSess).nFixBreak   = sum(endState == p.state.fixBreak);
    S(iSess).nNoResp     = sum(endState == p.state.noResponse);
    S(iSess).nInaccurate = sum(endState == p.state.inaccurate);
    if isfield(p.state, 'joyBreak')
        S(iSess).nJoyBreak = sum(endState == p.state.joyBreak);
    else
        S(iSess).nJoyBreak = 0;
    end
    if isfield(p.state, 'nonStart')
        S(iSess).nNonStart = sum(endState == p.state.nonStart);
    else
        S(iSess).nNonStart = 0;
    end
end

%% ====================== FIGURE 1: PARAMETER TABLE ======================
fprintf('\n====== FIGURE 1: SESSION PARAMETERS ======\n');
fig1 = figure('Position', [100 100 900 400], 'Color', 'w', ...
    'Name', 'Fig1: Session Parameters', 'NumberTitle', 'off');

% Create text-based table
ax = axes('Position', [0.05 0.05 0.9 0.9], 'Visible', 'off');
xlim([0 1]); ylim([0 1]);

% Header
headers = {'Parameter', sessionLabels{:}};
nCols = length(headers);
colX = linspace(0.02, 0.98, nCols + 1);
colX = colX(1:end-1) + diff(colX(1:2))/2;

rowParams = {
    'rewardRatioBig',  'Reward Ratio (big:small)'
    'rewardProbHigh',  'P(canonical) in P2/3'
    'rewardDurationMs','Reward Budget (ms)'
    'trialsPerPhase',  'Trials Per Phase'
    'hasSingleStim',   'Has Single-Stim Trials'
    'hasPerTrialReward','Per-Trial Reward Assign'
    'nTrials',         'Total Trial Files'
    };
nRows = size(rowParams, 1);
rowY = linspace(0.85, 0.15, nRows + 1);

% Draw header row
for c = 1:nCols
    text(colX(c), 0.93, headers{c}, 'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'Parent', ax);
end
plot(ax, [0.01 0.99], [0.90 0.90], 'k-', 'LineWidth', 1.5);

for r = 1:nRows
    y = rowY(r);
    fieldName = rowParams{r, 1};
    displayName = rowParams{r, 2};

    text(colX(1), y, displayName, 'FontSize', 9, 'FontWeight', 'normal', ...
        'HorizontalAlignment', 'center', 'Parent', ax);

    for s = 1:nSessions
        val = S(s).(fieldName);
        if islogical(val)
            valStr = ternary(val, 'Yes', 'No');
        elseif isnumeric(val) && isscalar(val)
            if val == round(val)
                valStr = sprintf('%d', val);
            else
                valStr = sprintf('%.2f', val);
            end
        elseif isnumeric(val) && isvector(val)
            valStr = sprintf('[%s]', strjoin(arrayfun(@(x) sprintf('%d', x), val, 'UniformOutput', false), ','));
        else
            valStr = '?';
        end

        % Highlight changes from previous session
        fontWeight = 'normal';
        fontColor = [0 0 0];
        if s > 1
            prevVal = S(s-1).(fieldName);
            if ~isequal(val, prevVal)
                fontWeight = 'bold';
                fontColor = [0.8 0 0];
            end
        end

        text(colX(s+1), y, valStr, 'FontSize', 9, 'FontWeight', fontWeight, ...
            'Color', fontColor, 'HorizontalAlignment', 'center', 'Parent', ax);
    end
end

title(ax, 'Session Parameter Comparison', 'FontSize', 14, 'FontWeight', 'bold', ...
    'Visible', 'on');

pdfSave(fullfile(outputDir, 'fig01_session_parameters.pdf'), fig1);
printParamSummary(S);

%% ====================== FIGURE 2: RIGHTWARD BIAS (Phase 1) ======================
fprintf('\n====== FIGURE 2: RIGHTWARD SACCADE BIAS ======\n');
fig2 = figure('Position', [100 100 1400 500], 'Color', 'w', ...
    'Name', 'Fig2: Rightward Bias', 'NumberTitle', 'off');

% Panel A: P(right) overall in Phase 1, per session
ax2a = subplot(1,3,1); hold on;
title('Phase 1: P(Choose Right)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(Right)');

pRight = NaN(1, nSessions);
pRight_ci = NaN(nSessions, 2);
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    nR = sum(S(s).chosenSide(mask) == 2);
    nT = sum(mask);
    if nT > 0
        pRight(s) = nR / nT;
        [pRight_ci(s,:)] = binomCI(nR, nT, 0.95);
    end
    fprintf('  %s: P(right)=%.3f, n=%d\n', S(s).label, pRight(s), nT);
end

bar(1:nSessions, pRight, 0.6, 'FaceColor', colBlue, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
for s = 1:nSessions
    plot([s s], pRight_ci(s,:), 'k-', 'LineWidth', 1.5);
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);
% Annotate parameter changes
annotateParamChanges(gca, S, 'rewardRatioBig');

% Panel B: P(right) by deltaT in Phase 1
ax2b = subplot(1,3,2); hold on;
title('Phase 1: P(Right) by \Deltat', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('\Deltat (ms)'); ylabel('P(Right)');

for s = 1:nSessions
    dtVals = S(s).deltaTValues;
    pR_dt = NaN(1, length(dtVals));
    for d = 1:length(dtVals)
        mask = S(s).isSC & S(s).isDual & (S(s).phase == 1) & (S(s).dt == dtVals(d));
        nR = sum(S(s).chosenSide(mask) == 2);
        nT = sum(mask);
        if nT > 0, pR_dt(d) = nR / nT; end
    end
    plot(dtVals, pR_dt, '-o', 'Color', colSession(s,:), 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', colSession(s,:), 'DisplayName', S(s).label);
end
plot([-200 200], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1, 'HandleVisibility', 'off');
legend('Location', 'best', 'Box', 'off', 'FontSize', 9);
set(gca, 'XLim', [-200 200], 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 10);

% Panel C: P(high-sal) conditioned on high-sal side (Phase 1)
ax2c = subplot(1,3,3); hold on;
title('Phase 1: P(HighSal) by Salience Side', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(High Salience)');

barWidth = 0.35;
for s = 1:nSessions
    maskL = S(s).isSC & S(s).isDual & (S(s).phase == 1) & (S(s).hsSide == 1);
    maskR = S(s).isSC & S(s).isDual & (S(s).phase == 1) & (S(s).hsSide == 2);

    nL = sum(maskL); nR = sum(maskR);
    pHSL = sum(S(s).choseHS(maskL)) / max(nL, 1);
    pHSR = sum(S(s).choseHS(maskR)) / max(nR, 1);

    bar(s - barWidth/2, pHSL, barWidth, 'FaceColor', colOrange, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    bar(s + barWidth/2, pHSR, barWidth, 'FaceColor', colBlue, 'EdgeColor', 'none', 'FaceAlpha', 0.7);

    if nL > 0
        ci = binomCI(sum(S(s).choseHS(maskL)), nL, 0.95);
        plot([s-barWidth/2 s-barWidth/2], ci, 'k-', 'LineWidth', 1.5);
    end
    if nR > 0
        ci = binomCI(sum(S(s).choseHS(maskR)), nR, 0.95);
        plot([s+barWidth/2 s+barWidth/2], ci, 'k-', 'LineWidth', 1.5);
    end
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);
% Manual legend
hL = bar(NaN, NaN, 'FaceColor', colOrange, 'EdgeColor', 'none');
hR = bar(NaN, NaN, 'FaceColor', colBlue, 'EdgeColor', 'none');
legend([hL hR], {'HighSal LEFT', 'HighSal RIGHT'}, 'Location', 'best', 'Box', 'off');

pdfSave(fullfile(outputDir, 'fig02_rightward_bias.pdf'), fig2);

%% ====================== FIGURE 3: UNCERTAINTY & EXPLORATION ======================
fprintf('\n====== FIGURE 3: UNCERTAINTY & EXPLORATION ======\n');
fig3 = figure('Position', [100 100 1200 500], 'Color', 'w', ...
    'Name', 'Fig3: Exploration', 'NumberTitle', 'off');

% Panel A: Running P(right) within Phase 1
ax3a = subplot(1,2,1); hold on;
title('Phase 1: Running P(Right) Over Trials', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Trial within Phase 1 (dual-stim)'); ylabel('P(Right) [20-trial window]');

winSize = 20;
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    chosen = S(s).chosenSide(mask);
    nT = sum(mask);
    if nT < winSize, continue; end

    isRight = (chosen == 2);
    runP = movmean(double(isRight), [winSize-1 0]); % trailing window
    plot(1:nT, runP, '-', 'Color', colSession(s,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (R=%.2f)', S(s).label, S(s).rewardRatioBig));
end
plot([0 200], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1, 'HandleVisibility', 'off');
legend('Location', 'best', 'Box', 'off', 'FontSize', 9);
set(gca, 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 10);

% Panel B: P(right) comparison grouped by parameter regime
ax3b = subplot(1,2,2); hold on;
title('Phase 1: P(Right) by Parameter Regime', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Regime'); ylabel('P(Right)');

% Group sessions by parameter regime
% Pre-refactor (Feb 9, 11): ratio=2, phase-level reward
% Post-refactor (Feb 13, 16): ratio=2, per-trial 50/50
% Low-ratio (Feb 18): ratio=1.25, per-trial 50/50
regimeLabels = {'R=2, Phase-lvl', 'R=2, Per-trial', 'R=1.25, Per-trial'};
regimeIdx    = {[1 2], [3 4], [5]};
nRegimes = length(regimeLabels);

for r = 1:nRegimes
    sessIdx = regimeIdx{r};
    allRight = []; allTotal = [];
    for s = sessIdx
        mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
        allRight = [allRight, sum(S(s).chosenSide(mask) == 2)];
        allTotal = [allTotal, sum(mask)];
    end
    nR = sum(allRight);
    nT = sum(allTotal);
    if nT > 0
        pR = nR / nT;
        ci = binomCI(nR, nT, 0.95);
        bar(r, pR, 0.5, 'FaceColor', colSession(sessIdx(1),:), 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        plot([r r], ci, 'k-', 'LineWidth', 2);
        text(r, ci(2) + 0.03, sprintf('n=%d', nT), 'HorizontalAlignment', 'center', 'FontSize', 9);
    end
end
plot([0.3 nRegimes+0.7], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nRegimes, 'XTickLabel', regimeLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nRegimes+0.7], 'YLim', [0 1], 'FontSize', 10);

pdfSave(fullfile(outputDir, 'fig03_exploration.pdf'), fig3);

%% ====================== FIGURE 4: REWARD vs SALIENCY (Phases 2-3) ======================
fprintf('\n====== FIGURE 4: REWARD vs SALIENCY ======\n');
fig4 = figure('Position', [100 100 1400 800], 'Color', 'w', ...
    'Name', 'Fig4: Reward vs Saliency', 'NumberTitle', 'off');

% Panel A: P(high-sal) in conflict trials by deltaT, per session
ax4a = subplot(2,3,1); hold on;
title({'P(HighSal) in CONFLICT Trials', '(Phases 2-3)'}, 'FontSize', 11, 'FontWeight', 'bold');
xlabel('\Deltat (ms)'); ylabel('P(High Salience)');

for s = 1:nSessions
    dtVals = S(s).deltaTValues;
    pHS = NaN(1, length(dtVals));
    for d = 1:length(dtVals)
        mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & ...
               S(s).isConf & (S(s).dt == dtVals(d));
        nHS = sum(S(s).choseHS(mask));
        nT  = sum(mask);
        if nT > 0, pHS(d) = nHS / nT; end
    end
    plot(dtVals, pHS, '-o', 'Color', colSession(s,:), 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', colSession(s,:), 'DisplayName', S(s).label);
end
plot([-200 200], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1, 'HandleVisibility', 'off');
legend('Location', 'best', 'Box', 'off', 'FontSize', 8);
set(gca, 'XLim', [-200 200], 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 10);

% Panel B: P(high-sal) in congruent trials by deltaT
ax4b = subplot(2,3,2); hold on;
title({'P(HighSal) in CONGRUENT Trials', '(Phases 2-3)'}, 'FontSize', 11, 'FontWeight', 'bold');
xlabel('\Deltat (ms)'); ylabel('P(High Salience)');

for s = 1:nSessions
    dtVals = S(s).deltaTValues;
    pHS = NaN(1, length(dtVals));
    for d = 1:length(dtVals)
        mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & ...
               ~S(s).isConf & (S(s).dt == dtVals(d));
        nHS = sum(S(s).choseHS(mask));
        nT  = sum(mask);
        if nT > 0, pHS(d) = nHS / nT; end
    end
    plot(dtVals, pHS, '-o', 'Color', colSession(s,:), 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', colSession(s,:), 'DisplayName', S(s).label);
end
plot([-200 200], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1, 'HandleVisibility', 'off');
set(gca, 'XLim', [-200 200], 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 10);

% Panel C: P(high-reward) by deltaT (Phases 2-3)
ax4c = subplot(2,3,3); hold on;
title({'P(Choose High Reward)', '(Phases 2-3)'}, 'FontSize', 11, 'FontWeight', 'bold');
xlabel('\Deltat (ms)'); ylabel('P(High Reward)');

for s = 1:nSessions
    dtVals = S(s).deltaTValues;
    pHR = NaN(1, length(dtVals));
    for d = 1:length(dtVals)
        mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & (S(s).dt == dtVals(d));
        if S(s).hasPerTrialReward
            choseHR = (S(s).chosenSide(mask) == S(s).rwdSide(mask));
        else
            % Pre-refactor: Phase 2 = big right, Phase 3 = big left
            ph = S(s).phase(mask);
            cs = S(s).chosenSide(mask);
            choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
        end
        nT = sum(mask);
        if nT > 0, pHR(d) = sum(choseHR) / nT; end
    end
    plot(dtVals, pHR, '-o', 'Color', colSession(s,:), 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', colSession(s,:), 'DisplayName', S(s).label);
end
plot([-200 200], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1, 'HandleVisibility', 'off');
legend('Location', 'best', 'Box', 'off', 'FontSize', 8);
set(gca, 'XLim', [-200 200], 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 10);

% Panel D: Delta-T effect size for conflict trials
ax4d = subplot(2,3,4); hold on;
title({'\Deltat Effect on P(HighSal)', 'Conflict: Gap minus Overlap'}, 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Session'); ylabel('\DeltaP(HighSal) [Gap - Overlap]');

effectSize = NaN(1, nSessions);
for s = 1:nSessions
    dtVals = S(s).deltaTValues;
    if length(dtVals) < 2, continue; end
    overlapDT = min(dtVals); % -150
    gapDT     = max(dtVals); % +150

    maskO = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf & (S(s).dt == overlapDT);
    maskG = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf & (S(s).dt == gapDT);

    nO = sum(maskO); nG = sum(maskG);
    if nO > 0 && nG > 0
        pO = sum(S(s).choseHS(maskO)) / nO;
        pG = sum(S(s).choseHS(maskG)) / nG;
        effectSize(s) = pG - pO;
    end
end

bar(1:nSessions, effectSize, 0.6, 'FaceColor', colPurple, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
plot([0.5 nSessions+0.5], [0 0], '-', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'FontSize', 10);
ylabel('\DeltaP(HighSal)');

% Print effect sizes
fprintf('  Delta-T effect on P(HighSal) in conflict trials:\n');
for s = 1:nSessions
    fprintf('    %s: %.3f\n', S(s).label, effectSize(s));
end

% Panel E: P(high-sal) Phase 2 vs Phase 3 separately
ax4e = subplot(2,3,5); hold on;
title({'P(HighSal) Phase 2 vs Phase 3', 'Conflict Trials Only'}, 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(High Salience)');

barW = 0.35;
for s = 1:nSessions
    maskP2 = S(s).isSC & S(s).isDual & (S(s).phase == 2) & S(s).isConf;
    maskP3 = S(s).isSC & S(s).isDual & (S(s).phase == 3) & S(s).isConf;

    nP2 = sum(maskP2); nP3 = sum(maskP3);
    pP2 = sum(S(s).choseHS(maskP2)) / max(nP2, 1);
    pP3 = sum(S(s).choseHS(maskP3)) / max(nP3, 1);

    if nP2 > 0
        bar(s - barW/2, pP2, barW, 'FaceColor', colOrange, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        ci = binomCI(sum(S(s).choseHS(maskP2)), nP2, 0.95);
        plot([s-barW/2 s-barW/2], ci, 'k-', 'LineWidth', 1.5);
    end
    if nP3 > 0
        bar(s + barW/2, pP3, barW, 'FaceColor', colGreen, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        ci = binomCI(sum(S(s).choseHS(maskP3)), nP3, 0.95);
        plot([s+barW/2 s+barW/2], ci, 'k-', 'LineWidth', 1.5);
    end
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);
hP2 = bar(NaN, NaN, 'FaceColor', colOrange, 'EdgeColor', 'none');
hP3 = bar(NaN, NaN, 'FaceColor', colGreen, 'EdgeColor', 'none');
legend([hP2 hP3], {'Phase 2 (big R)', 'Phase 3 (big L)'}, 'Location', 'best', 'Box', 'off');

% Panel F: Congruent vs Conflict P(HighSal) overall (pooled deltaT)
ax4f = subplot(2,3,6); hold on;
title({'Conflict vs Congruent', 'P(HighSal) Phases 2-3'}, 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(High Salience)');

for s = 1:nSessions
    maskConf = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf;
    maskCong = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & ~S(s).isConf;

    nConf = sum(maskConf); nCong = sum(maskCong);
    pConf = sum(S(s).choseHS(maskConf)) / max(nConf, 1);
    pCong = sum(S(s).choseHS(maskCong)) / max(nCong, 1);

    if nConf > 0
        bar(s - barW/2, pConf, barW, 'FaceColor', colOrange, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        ci = binomCI(sum(S(s).choseHS(maskConf)), nConf, 0.95);
        plot([s-barW/2 s-barW/2], ci, 'k-', 'LineWidth', 1.5);
    end
    if nCong > 0
        bar(s + barW/2, pCong, barW, 'FaceColor', colBlue, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        ci = binomCI(sum(S(s).choseHS(maskCong)), nCong, 0.95);
        plot([s+barW/2 s+barW/2], ci, 'k-', 'LineWidth', 1.5);
    end
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);
hConf = bar(NaN, NaN, 'FaceColor', colOrange, 'EdgeColor', 'none');
hCong = bar(NaN, NaN, 'FaceColor', colBlue, 'EdgeColor', 'none');
legend([hConf hCong], {'Conflict', 'Congruent'}, 'Location', 'best', 'Box', 'off');

pdfSave(fullfile(outputDir, 'fig04_reward_vs_saliency.pdf'), fig4);

%% ====================== FIGURE 5: LOW REWARD RATIO ======================
fprintf('\n====== FIGURE 5: REWARD RATIO COMPARISON ======\n');
fig5 = figure('Position', [100 100 1200 500], 'Color', 'w', ...
    'Name', 'Fig5: Reward Ratio', 'NumberTitle', 'off');

% Panel A: P(right) in Phase 1 comparison (ratio 2.0 vs 1.25)
ax5a = subplot(1,2,1); hold on;
title({'Phase 1: P(Right)', 'Ratio 2.0 vs 1.25'}, 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(Right)');

for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    nR = sum(S(s).chosenSide(mask) == 2);
    nT = sum(mask);
    if nT > 0
        pR = nR / nT;
        ci = binomCI(nR, nT, 0.95);
        if S(s).rewardRatioBig < 1.5
            fc = colPurple;
        else
            fc = colBlue;
        end
        bar(s, pR, 0.6, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        plot([s s], ci, 'k-', 'LineWidth', 1.5);
        text(s, 0.05, sprintf('R=%.2f', S(s).rewardRatioBig), ...
            'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
    end
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);

% Panel B: P(high-reward) in Phases 2-3 comparison
ax5b = subplot(1,2,2); hold on;
title({'Phases 2-3: P(High Reward)', 'Ratio 2.0 vs 1.25'}, 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(High Reward)');

for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2);
    nT = sum(mask);
    if nT == 0, continue; end

    if S(s).hasPerTrialReward
        choseHR = (S(s).chosenSide(mask) == S(s).rwdSide(mask));
    else
        ph = S(s).phase(mask);
        cs = S(s).chosenSide(mask);
        choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
    end
    nHR = sum(choseHR);
    pHR = nHR / nT;
    ci = binomCI(nHR, nT, 0.95);

    if S(s).rewardRatioBig < 1.5
        fc = colPurple;
    else
        fc = colBlue;
    end
    bar(s, pHR, 0.6, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    plot([s s], ci, 'k-', 'LineWidth', 1.5);
    text(s, 0.05, sprintf('R=%.2f', S(s).rewardRatioBig), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);

pdfSave(fullfile(outputDir, 'fig05_reward_ratio.pdf'), fig5);

%% ====================== FIGURE 6: RT DISTRIBUTIONS ======================
fprintf('\n====== FIGURE 6: RT DISTRIBUTIONS ======\n');
fig6 = figure('Position', [100 100 1400 800], 'Color', 'w', ...
    'Name', 'Fig6: RT Distributions', 'NumberTitle', 'off');

rtBins = 50:10:600;

for s = 1:nSessions
    % Phase 1 RT distribution
    ax = subplot(2, nSessions, s); hold on;
    title(sprintf('%s - Phase 1', S(s).label), 'FontSize', 10);

    dtVals = S(s).deltaTValues;
    for d = 1:length(dtVals)
        mask = S(s).isSC & S(s).isDual & (S(s).phase == 1) & (S(s).dt == dtVals(d));
        rts = S(s).srt(mask);
        rts = rts(~isnan(rts));
        if ~isempty(rts)
            if dtVals(d) < 0
                histogram(rts, rtBins, 'FaceColor', colOrange, 'FaceAlpha', 0.5, 'EdgeColor', 'none', ...
                    'DisplayName', sprintf('\\Deltat=%d', dtVals(d)));
            else
                histogram(rts, rtBins, 'FaceColor', colBlue, 'FaceAlpha', 0.5, 'EdgeColor', 'none', ...
                    'DisplayName', sprintf('\\Deltat=%d', dtVals(d)));
            end
        end
    end
    xlim([50 600]); xlabel('SRT (ms)'); ylabel('Count');
    if s == 1, legend('Location', 'northeast', 'Box', 'off', 'FontSize', 7); end

    % Phases 2-3 RT distribution
    ax = subplot(2, nSessions, nSessions + s); hold on;
    title(sprintf('%s - Phases 2-3', S(s).label), 'FontSize', 10);

    for d = 1:length(dtVals)
        mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & (S(s).dt == dtVals(d));
        rts = S(s).srt(mask);
        rts = rts(~isnan(rts));
        if ~isempty(rts)
            if dtVals(d) < 0
                histogram(rts, rtBins, 'FaceColor', colOrange, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
            else
                histogram(rts, rtBins, 'FaceColor', colBlue, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
            end
        end
    end
    xlim([50 600]); xlabel('SRT (ms)'); ylabel('Count');
end

pdfSave(fullfile(outputDir, 'fig06_rt_distributions.pdf'), fig6);

%% ====================== FIGURE 7: TACHOMETRIC / CONDITIONAL ACCURACY ======================
fprintf('\n====== FIGURE 7: TACHOMETRIC FUNCTIONS ======\n');
fig7 = figure('Position', [100 100 1400 800], 'Color', 'w', ...
    'Name', 'Fig7: Tachometric Functions', 'NumberTitle', 'off');

rtEdges = [0 100 150 200 250 300 400 600];
rtCenters = (rtEdges(1:end-1) + rtEdges(2:end)) / 2;
nBins = length(rtCenters);

% Panel per session: P(high-sal) as function of RT
for s = 1:nSessions
    ax = subplot(2, nSessions, s); hold on;
    title(sprintf('%s - P(HighSal) vs RT', S(s).label), 'FontSize', 10);

    dtVals = S(s).deltaTValues;
    for d = 1:length(dtVals)
        mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf & (S(s).dt == dtVals(d));
        rts = S(s).srt(mask);
        chs = S(s).choseHS(mask);

        pHS_bin = NaN(1, nBins);
        for b = 1:nBins
            inBin = rts >= rtEdges(b) & rts < rtEdges(b+1);
            nB = sum(inBin);
            if nB >= 3
                pHS_bin(b) = sum(chs(inBin)) / nB;
            end
        end
        valid = ~isnan(pHS_bin);
        if dtVals(d) < 0
            plot(rtCenters(valid), pHS_bin(valid), '-o', 'Color', colOrange, 'LineWidth', 1.5, ...
                'MarkerFaceColor', colOrange, 'MarkerSize', 6);
        else
            plot(rtCenters(valid), pHS_bin(valid), '-o', 'Color', colBlue, 'LineWidth', 1.5, ...
                'MarkerFaceColor', colBlue, 'MarkerSize', 6);
        end
    end
    plot([50 600], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
    xlim([50 500]); ylim([0 1]);
    xlabel('SRT (ms)'); ylabel('P(HighSal)');
    set(gca, 'TickDir', 'out', 'FontSize', 9);
end

% Panel per session: P(high-sal) as function of RT - Phase 1
for s = 1:nSessions
    ax = subplot(2, nSessions, nSessions + s); hold on;
    title(sprintf('%s - Phase 1', S(s).label), 'FontSize', 10);

    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    rts = S(s).srt(mask);
    chs = S(s).choseHS(mask);

    pHS_bin = NaN(1, nBins);
    nPerBin = zeros(1, nBins);
    for b = 1:nBins
        inBin = rts >= rtEdges(b) & rts < rtEdges(b+1);
        nB = sum(inBin);
        nPerBin(b) = nB;
        if nB >= 3
            pHS_bin(b) = sum(chs(inBin)) / nB;
        end
    end
    valid = ~isnan(pHS_bin);
    plot(rtCenters(valid), pHS_bin(valid), '-o', 'Color', colGreen, 'LineWidth', 1.5, ...
        'MarkerFaceColor', colGreen, 'MarkerSize', 6);

    plot([50 600], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
    xlim([50 500]); ylim([0 1]);
    xlabel('SRT (ms)'); ylabel('P(HighSal)');
    set(gca, 'TickDir', 'out', 'FontSize', 9);
end

pdfSave(fullfile(outputDir, 'fig07_tachometric.pdf'), fig7);

%% ====================== FIGURE 8: WITHIN-SESSION LEARNING ======================
fprintf('\n====== FIGURE 8: WITHIN-SESSION LEARNING ======\n');
fig8 = figure('Position', [100 100 1400 500], 'Color', 'w', ...
    'Name', 'Fig8: Learning Curves', 'NumberTitle', 'off');

for s = 1:nSessions
    ax = subplot(1, nSessions, s); hold on;
    title(sprintf('%s (R=%.2f)', S(s).label, S(s).rewardRatioBig), 'FontSize', 10);

    % Identify good dual-stim trials in order
    mask = S(s).isSC & S(s).isDual;
    idx = find(mask);
    phases = S(s).phase(idx);

    % Running P(high-reward) in Phases 2-3
    p23idx = idx(phases >= 2);
    if ~isempty(p23idx)
        if S(s).hasPerTrialReward
            choseHR = (S(s).chosenSide(p23idx) == S(s).rwdSide(p23idx));
        else
            ph = S(s).phase(p23idx);
            cs = S(s).chosenSide(p23idx);
            choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
        end
        isConfLoc = logical(S(s).isConf(p23idx));

        % Separate conflict/congruent
        if sum(isConfLoc) > 5
            cumHR_conf = cumsum(double(choseHR(isConfLoc))) ./ (1:sum(isConfLoc));
            plot(1:sum(isConfLoc), cumHR_conf, '-', 'Color', colOrange, 'LineWidth', 1.5);
        end
        if sum(~isConfLoc) > 5
            cumHR_cong = cumsum(double(choseHR(~isConfLoc))) ./ (1:sum(~isConfLoc));
            plot(1:sum(~isConfLoc), cumHR_cong, '-', 'Color', colBlue, 'LineWidth', 1.5);
        end
    end

    plot([0 200], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
    ylim([0 1]); xlabel('Trial in P2-3'); ylabel('Cum. P(HighReward)');
    set(gca, 'TickDir', 'out', 'FontSize', 9);
    if s == nSessions
        legend({'Conflict', 'Congruent'}, 'Location', 'best', 'Box', 'off', 'FontSize', 8);
    end
end

pdfSave(fullfile(outputDir, 'fig08_learning_curves.pdf'), fig8);

%% ====================== FIGURE 9: SEQUENTIAL EFFECTS ======================
fprintf('\n====== FIGURE 9: SEQUENTIAL EFFECTS ======\n');
fig9 = figure('Position', [100 100 1200 500], 'Color', 'w', ...
    'Name', 'Fig9: Sequential Effects', 'NumberTitle', 'off');

% Win-stay analysis: P(same side) after choosing right vs left on previous trial
ax9a = subplot(1,2,1); hold on;
title('Win-Stay: P(same side as prev)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(Repeat Side)');

barW = 0.35;
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2);
    idx = find(mask);
    if length(idx) < 5, continue; end

    sides = S(s).chosenSide(idx);

    % After choosing RIGHT (win)
    afterR = (sides(1:end-1) == 2);
    stayR = (sides(2:end) == 2);
    pStayAfterR = sum(stayR(afterR)) / max(sum(afterR), 1);

    % After choosing LEFT (win)
    afterL = (sides(1:end-1) == 1);
    stayL = (sides(2:end) == 1);
    pStayAfterL = sum(stayL(afterL)) / max(sum(afterL), 1);

    bar(s - barW/2, pStayAfterR, barW, 'FaceColor', colBlue, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    bar(s + barW/2, pStayAfterL, barW, 'FaceColor', colOrange, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);
hR = bar(NaN, NaN, 'FaceColor', colBlue, 'EdgeColor', 'none');
hL = bar(NaN, NaN, 'FaceColor', colOrange, 'EdgeColor', 'none');
legend([hR hL], {'After chose R', 'After chose L'}, 'Location', 'best', 'Box', 'off');

% Panel B: P(choose high-reward) after high-reward-win vs low-reward-win
ax9b = subplot(1,2,2); hold on;
title('P(High Reward) After Reward Outcomes', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(High Reward on next trial)');

for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2);
    idx = find(mask);
    if length(idx) < 5, continue; end

    if S(s).hasPerTrialReward
        choseHR = (S(s).chosenSide(idx) == S(s).rwdSide(idx));
    else
        ph = S(s).phase(idx);
        cs = S(s).chosenSide(idx);
        choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
    end

    afterHR = choseHR(1:end-1); % previous trial chose high-reward
    nextHR  = choseHR(2:end);   % current trial chose high-reward

    pHR_afterHR = sum(nextHR(afterHR)) / max(sum(afterHR), 1);
    pHR_afterLR = sum(nextHR(~afterHR)) / max(sum(~afterHR), 1);

    bar(s - barW/2, pHR_afterHR, barW, 'FaceColor', colGreen, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    bar(s + barW/2, pHR_afterLR, barW, 'FaceColor', colPurple, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);
hHR = bar(NaN, NaN, 'FaceColor', colGreen, 'EdgeColor', 'none');
hLR = bar(NaN, NaN, 'FaceColor', colPurple, 'EdgeColor', 'none');
legend([hHR hLR], {'After HighReward', 'After LowReward'}, 'Location', 'best', 'Box', 'off');

pdfSave(fullfile(outputDir, 'fig09_sequential_effects.pdf'), fig9);

%% ====================== FIGURE 10: ERROR ANALYSIS ======================
fprintf('\n====== FIGURE 10: ERROR ANALYSIS ======\n');
fig10 = figure('Position', [100 100 1200 500], 'Color', 'w', ...
    'Name', 'Fig10: Errors', 'NumberTitle', 'off');

% Panel A: Error rates by type per session
ax10a = subplot(1,2,1); hold on;
title('Error Rates by Type', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('Count');

errData = zeros(nSessions, 4);
errLabels = {'FixBreak', 'NoResponse', 'Inaccurate', 'JoyBreak'};
errColors = [colOrange; colBlue; colPurple; colGray];

for s = 1:nSessions
    errData(s,:) = [S(s).nFixBreak, S(s).nNoResp, S(s).nInaccurate, S(s).nJoyBreak];
end

hb = bar(1:nSessions, errData, 'stacked');
for e = 1:4
    hb(e).FaceColor = errColors(e,:);
    hb(e).EdgeColor = 'none';
    hb(e).FaceAlpha = 0.8;
end
legend(errLabels, 'Location', 'best', 'Box', 'off', 'FontSize', 9);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', 'FontSize', 10);

% Panel B: Error rates by deltaT (Phase 2-3 only)
ax10b = subplot(1,2,2); hold on;
title('Inaccurate Rate by \Deltat (P2-3)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('\Deltat (ms)'); ylabel('Inaccurate Rate');

for s = 1:nSessions
    dtVals = S(s).deltaTValues;
    inaccRate = NaN(1, length(dtVals));
    for d = 1:length(dtVals)
        mask = S(s).isDual & (S(s).phase >= 2) & (S(s).dt == dtVals(d));
        nTotal = sum(mask);
        if isfield(S(s).p.state, 'inaccurate')
            nInacc = sum(S(s).endState(mask) == S(s).p.state.inaccurate);
        else
            nInacc = 0;
        end
        if nTotal > 0, inaccRate(d) = nInacc / nTotal; end
    end
    plot(dtVals, inaccRate, '-o', 'Color', colSession(s,:), 'LineWidth', 2, ...
        'MarkerSize', 8, 'MarkerFaceColor', colSession(s,:), 'DisplayName', S(s).label);
end
legend('Location', 'best', 'Box', 'off', 'FontSize', 9);
set(gca, 'XLim', [-200 200], 'TickDir', 'out', 'FontSize', 10);

pdfSave(fullfile(outputDir, 'fig10_errors.pdf'), fig10);

%% ====================== FIGURE 11: SACCADE ENDPOINTS ======================
fprintf('\n====== FIGURE 11: SACCADE ENDPOINTS ======\n');
fig11 = figure('Position', [100 100 1400 600], 'Color', 'w', ...
    'Name', 'Fig11: Saccade Endpoints', 'NumberTitle', 'off');

for s = 1:nSessions
    ax = subplot(1, nSessions, s); hold on;
    title(S(s).label, 'FontSize', 10);
    axis equal;

    % Gather endpoints from completed saccade trials
    mask = S(s).isSC & S(s).isDual;
    idx = find(mask);

    endX = []; endY = []; choiceCol = [];
    for iTr = idx
        if isfield(S(s).p.trData(iTr), 'postSacXY') && ~isempty(S(s).p.trData(iTr).postSacXY)
            xy = S(s).p.trData(iTr).postSacXY;
            if length(xy) == 2
                endX(end+1) = xy(1);
                endY(end+1) = xy(2);
                if S(s).choseHS(iTr)
                    choiceCol(end+1) = 1; % high sal
                else
                    choiceCol(end+1) = 2; % low sal
                end
            end
        end
    end

    if ~isempty(endX)
        hs = (choiceCol == 1);
        scatter(endX(hs), endY(hs), 15, colOrange, 'filled', 'MarkerFaceAlpha', 0.4);
        scatter(endX(~hs), endY(~hs), 15, colBlue, 'filled', 'MarkerFaceAlpha', 0.4);
    end

    % Draw fixation and target locations
    plot(0, 0, '+k', 'MarkerSize', 10, 'LineWidth', 2);
    ecc = 10;
    leftAngles = [135, 165, -165, -135];
    rightAngles = [45, 15, -15, -45];
    for a = leftAngles
        plot(ecc*cosd(a), ecc*sind(a), 'ko', 'MarkerSize', 8, 'LineWidth', 1.5);
    end
    for a = rightAngles
        plot(ecc*cosd(a), ecc*sind(a), 'ko', 'MarkerSize', 8, 'LineWidth', 1.5);
    end

    xlim([-15 15]); ylim([-15 15]);
    xlabel('X (deg)'); ylabel('Y (deg)');
    set(gca, 'TickDir', 'out', 'FontSize', 9);
end

pdfSave(fullfile(outputDir, 'fig11_saccade_endpoints.pdf'), fig11);

%% ====================== FIGURE 12: SPATIAL BIAS DECOMPOSITION ======================
fprintf('\n====== FIGURE 12: SPATIAL BIAS DECOMPOSITION ======\n');
fig12 = figure('Position', [100 100 1400 500], 'Color', 'w', ...
    'Name', 'Fig12: Bias Decomposition', 'NumberTitle', 'off');

% Panel A: P(right) by condition across all phases
ax12a = subplot(1,3,1); hold on;
title('P(Right) by Phase', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('P(Right)');

pRightByPhase = NaN(nSessions, 3);
for s = 1:nSessions
    for ph = 1:3
        mask = S(s).isSC & S(s).isDual & (S(s).phase == ph);
        nT = sum(mask);
        if nT > 0
            pRightByPhase(s, ph) = sum(S(s).chosenSide(mask) == 2) / nT;
        end
    end
end

xOff = [-0.25, 0, 0.25];
phColors = {colOrange, colBlue, colGreen};
phLabels = {'Phase 1', 'Phase 2', 'Phase 3'};
for ph = 1:3
    for s = 1:nSessions
        if ~isnan(pRightByPhase(s, ph))
            bar(s + xOff(ph), pRightByPhase(s, ph), 0.22, ...
                'FaceColor', phColors{ph}, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        end
    end
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 10);
hPh = [];
for ph = 1:3
    hPh(ph) = bar(NaN, NaN, 'FaceColor', phColors{ph}, 'EdgeColor', 'none');
end
legend(hPh, phLabels, 'Location', 'best', 'Box', 'off');

% Panel B: Salience discrimination (d') with spatial criterion
ax12b = subplot(1,3,2); hold on;
title('Salience Sensitivity (d'')', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('d'' for salience');

dPrime = NaN(1, nSessions);
criterion = NaN(1, nSessions);
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    nT = sum(mask);
    if nT < 10, continue; end

    % Signal = high salience on right side
    % "Hit" = choose right when high-sal right
    % "FA"  = choose right when high-sal left
    hsR = (S(s).hsSide(mask) == 2); % high sal on right
    chR = (S(s).chosenSide(mask) == 2); % chose right

    hitRate = sum(chR & hsR) / max(sum(hsR), 1);
    faRate  = sum(chR & ~hsR) / max(sum(~hsR), 1);

    % Clip to avoid infinite d'
    hitRate = max(min(hitRate, 1 - 1/(2*sum(hsR))), 1/(2*sum(hsR)));
    faRate  = max(min(faRate, 1 - 1/(2*sum(~hsR))), 1/(2*sum(~hsR)));

    dPrime(s)    = norminv(hitRate) - norminv(faRate);
    criterion(s) = -0.5 * (norminv(hitRate) + norminv(faRate));
end

yyaxis left;
bar(1:nSessions, dPrime, 0.5, 'FaceColor', colGreen, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
ylabel('d'' (salience sensitivity)');
plot([0.5 nSessions+0.5], [0 0], '-', 'Color', colGray, 'LineWidth', 1);

yyaxis right;
plot(1:nSessions, criterion, '-s', 'Color', colPurple, 'LineWidth', 2, 'MarkerSize', 8, ...
    'MarkerFaceColor', colPurple);
ylabel('Criterion (neg = rightward bias)');

set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'FontSize', 10);

fprintf('  Salience sensitivity (d'') and criterion:\n');
for s = 1:nSessions
    fprintf('    %s: d''=%.3f, c=%.3f\n', S(s).label, dPrime(s), criterion(s));
end

% Panel C: Median RT for rightward vs leftward saccades
ax12c = subplot(1,3,3); hold on;
title('Median RT: Left vs Right Saccade', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Session'); ylabel('Median SRT (ms)');

for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual;
    rts = S(s).srt(mask);
    sides = S(s).chosenSide(mask);

    rtL = rts(sides == 1); rtL = rtL(~isnan(rtL));
    rtR = rts(sides == 2); rtR = rtR(~isnan(rtR));

    if ~isempty(rtL)
        bar(s - barW/2, median(rtL), barW, 'FaceColor', colOrange, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    end
    if ~isempty(rtR)
        bar(s + barW/2, median(rtR), barW, 'FaceColor', colBlue, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
    end
end
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'FontSize', 10);
hL = bar(NaN, NaN, 'FaceColor', colOrange, 'EdgeColor', 'none');
hR = bar(NaN, NaN, 'FaceColor', colBlue, 'EdgeColor', 'none');
legend([hL hR], {'Leftward', 'Rightward'}, 'Location', 'best', 'Box', 'off');

pdfSave(fullfile(outputDir, 'fig12_bias_decomposition.pdf'), fig12);

%% ====================== FIGURE 13: CROSS-SESSION SUMMARY ======================
fprintf('\n====== FIGURE 13: CROSS-SESSION SUMMARY ======\n');
fig13 = figure('Position', [100 100 1400 900], 'Color', 'w', ...
    'Name', 'Fig13: Cross-Session Summary', 'NumberTitle', 'off');

% Panel A: P(right) Phase 1
ax13a = subplot(3,2,1); hold on;
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    nT = sum(mask);
    if nT > 0
        pR = sum(S(s).chosenSide(mask) == 2) / nT;
        ci = binomCI(sum(S(s).chosenSide(mask) == 2), nT, 0.95);
        plot(s, pR, 'o', 'Color', colBlue, 'MarkerSize', 10, 'MarkerFaceColor', colBlue);
        plot([s s], ci, '-', 'Color', colBlue, 'LineWidth', 1.5);
    end
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
title('P(Right) - Phase 1', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.5 nSessions+0.5], 'YLim', [0 1], 'FontSize', 10);
ylabel('P(Right)');

% Panel B: P(high-sal) conflict gap vs overlap
ax13b = subplot(3,2,2); hold on;
for s = 1:nSessions
    dtVals = S(s).deltaTValues;
    if length(dtVals) < 2, continue; end
    overlapDT = min(dtVals);
    gapDT = max(dtVals);

    maskO = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf & (S(s).dt == overlapDT);
    maskG = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf & (S(s).dt == gapDT);

    nO = sum(maskO); nG = sum(maskG);
    if nO > 0
        pO = sum(S(s).choseHS(maskO)) / nO;
        plot(s - 0.1, pO, 'o', 'Color', colOrange, 'MarkerSize', 10, 'MarkerFaceColor', colOrange);
    end
    if nG > 0
        pG = sum(S(s).choseHS(maskG)) / nG;
        plot(s + 0.1, pG, 's', 'Color', colBlue, 'MarkerSize', 10, 'MarkerFaceColor', colBlue);
    end
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
title('P(HighSal) Conflict: Gap vs Overlap', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.5 nSessions+0.5], 'YLim', [0 1], 'FontSize', 10);
ylabel('P(HighSal)');
hO = plot(NaN, NaN, 'o', 'Color', colOrange, 'MarkerFaceColor', colOrange, 'MarkerSize', 8);
hG = plot(NaN, NaN, 's', 'Color', colBlue, 'MarkerFaceColor', colBlue, 'MarkerSize', 8);
legend([hO hG], {'Overlap (-150)', 'Gap (+150)'}, 'Location', 'best', 'Box', 'off');

% Panel C: Median RT overall
ax13c = subplot(3,2,3); hold on;
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual;
    rts = S(s).srt(mask);
    rts = rts(~isnan(rts));
    if ~isempty(rts)
        mRT = median(rts);
        ci = bootCI(rts, 0.95);
        plot(s, mRT, 'o', 'Color', colGreen, 'MarkerSize', 10, 'MarkerFaceColor', colGreen);
        plot([s s], ci, '-', 'Color', colGreen, 'LineWidth', 1.5);
    end
end
title('Median SRT (all dual-stim)', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.5 nSessions+0.5], 'FontSize', 10);
ylabel('Median SRT (ms)');

% Panel D: P(high-reward) Phases 2-3
ax13d = subplot(3,2,4); hold on;
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2);
    nT = sum(mask);
    if nT == 0, continue; end
    if S(s).hasPerTrialReward
        choseHR = (S(s).chosenSide(mask) == S(s).rwdSide(mask));
    else
        ph = S(s).phase(mask);
        cs = S(s).chosenSide(mask);
        choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
    end
    nHR = sum(choseHR);
    pHR = nHR / nT;
    ci = binomCI(nHR, nT, 0.95);
    plot(s, pHR, 'o', 'Color', colPurple, 'MarkerSize', 10, 'MarkerFaceColor', colPurple);
    plot([s s], ci, '-', 'Color', colPurple, 'LineWidth', 1.5);
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray, 'LineWidth', 1);
title('P(High Reward) - Phases 2-3', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.5 nSessions+0.5], 'YLim', [0 1], 'FontSize', 10);
ylabel('P(HighReward)');

% Panel E: Error rate
ax13e = subplot(3,2,5); hold on;
for s = 1:nSessions
    nErr = S(s).nFixBreak + S(s).nNoResp + S(s).nInaccurate + S(s).nJoyBreak;
    errRate = nErr / S(s).nTrials;
    plot(s, errRate, 'o', 'Color', [0.8 0 0], 'MarkerSize', 10, 'MarkerFaceColor', [0.8 0 0]);
end
title('Overall Error Rate', 'FontSize', 11, 'FontWeight', 'bold');
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.5 nSessions+0.5], 'FontSize', 10);
ylabel('Error Rate');

% Panel F: Annotation panel with parameter changes
ax13f = subplot(3,2,6); hold on;
set(gca, 'Visible', 'off'); xlim([0 1]); ylim([0 1]);
text(0.5, 0.95, 'Parameter Changes', 'FontSize', 12, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');
annotations = {
    'Feb 9-11: rewardRatioBig=2.0, phase-level reward'
    'Feb 13: Per-trial reward, single-stim Phase 1'
    'Feb 16: Same as Feb 13'
    'Feb 18: rewardRatioBig lowered to 1.25'
    ''
    'Gap = +150ms (stim AFTER go signal)'
    'Overlap = -150ms (stim BEFORE go signal)'
    };
for a = 1:length(annotations)
    text(0.05, 0.85 - (a-1)*0.12, annotations{a}, 'FontSize', 9, 'Color', [0.3 0.3 0.3]);
end

pdfSave(fullfile(outputDir, 'fig13_cross_session_summary.pdf'), fig13);

%% ====================== PRINT COMPREHENSIVE REPORT ======================
printReport(S, nSessions, effectSize, dPrime, criterion, pRight, pRightByPhase);

fprintf('\n====== ANALYSIS COMPLETE ======\n');
fprintf('Figures saved to: %s\n', outputDir);
fprintf('  fig01_session_parameters.pdf\n');
fprintf('  fig02_rightward_bias.pdf\n');
fprintf('  fig03_exploration.pdf\n');
fprintf('  fig04_reward_vs_saliency.pdf\n');
fprintf('  fig05_reward_ratio.pdf\n');
fprintf('  fig06_rt_distributions.pdf\n');
fprintf('  fig07_tachometric.pdf\n');
fprintf('  fig08_learning_curves.pdf\n');
fprintf('  fig09_sequential_effects.pdf\n');
fprintf('  fig10_errors.pdf\n');
fprintf('  fig11_saccade_endpoints.pdf\n');
fprintf('  fig12_bias_decomposition.pdf\n');
fprintf('  fig13_cross_session_summary.pdf\n');

end

%% ==================== HELPER FUNCTIONS ====================

function val = safeField(s, fieldName, default)
    if isfield(s, fieldName)
        val = s.(fieldName);
    else
        val = default;
    end
end

function s = ternary(cond, trueVal, falseVal)
    if cond, s = trueVal; else, s = falseVal; end
end

function ci = binomCI(k, n, confidence)
    % Wilson score interval for binomial proportion
    z = norminv(1 - (1-confidence)/2);
    p = k / n;
    denom = 1 + z^2/n;
    center = (p + z^2/(2*n)) / denom;
    halfWidth = z * sqrt((p*(1-p) + z^2/(4*n)) / n) / denom;
    ci = [max(0, center - halfWidth), min(1, center + halfWidth)];
end

function ci = bootCI(data, confidence)
    % Bootstrap CI for median
    nBoot = 1000;
    bootMedians = NaN(nBoot, 1);
    n = length(data);
    for b = 1:nBoot
        bootMedians(b) = median(data(randi(n, n, 1)));
    end
    alpha = (1 - confidence)/2;
    ci = [quantile(bootMedians, alpha), quantile(bootMedians, 1-alpha)];
end

function annotateParamChanges(ax, S, paramName)
    nS = length(S);
    for s = 2:nS
        if ~isequal(S(s).(paramName), S(s-1).(paramName))
            yl = get(ax, 'YLim');
            text(s, yl(2)*0.95, sprintf('%s changed', paramName), ...
                'FontSize', 7, 'Color', [0.8 0 0], 'HorizontalAlignment', 'center', ...
                'Rotation', 45, 'Parent', ax);
        end
    end
end

function printParamSummary(S)
    nS = length(S);
    fprintf('\n--- Parameter Summary ---\n');
    fprintf('%-12s  %-6s  %-6s  %-5s  %-6s  %-14s  %-8s  %-10s\n', ...
        'Session', 'Ratio', 'pHigh', 'RwdMs', 'nTrials', 'TrialsPerPhase', 'SingleS', 'PerTrial');
    for s = 1:nS
        tpp = S(s).trialsPerPhase;
        tppStr = sprintf('[%s]', strjoin(arrayfun(@(x) sprintf('%d', x), tpp, 'UniformOutput', false), ','));
        fprintf('%-12s  %-6.2f  %-6.2f  %-5d  %-6d  %-14s  %-8s  %-10s\n', ...
            S(s).label, S(s).rewardRatioBig, S(s).rewardProbHigh, ...
            S(s).rewardDurationMs, S(s).nTrials, tppStr, ...
            ternary(S(s).hasSingleStim, 'Yes', 'No'), ...
            ternary(S(s).hasPerTrialReward, 'Yes', 'No'));
    end
end

function printReport(S, nSessions, effectSize, dPrime, criterion, pRight, pRightByPhase)
    fprintf('\n');
    fprintf('============================================================\n');
    fprintf('       CONFLICT TASK MULTI-SESSION ANALYSIS REPORT\n');
    fprintf('============================================================\n');

    fprintf('\n--- OBSERVATION 1: Rightward Saccade Bias ---\n');
    fprintf('Phase 1 P(Right) across sessions:\n');
    for s = 1:nSessions
        fprintf('  %s: P(Right) = %.3f (ratio=%.2f)\n', S(s).label, pRight(s), S(s).rewardRatioBig);
    end
    anyBias = any(pRight > 0.6) || any(pRight < 0.4);
    if anyBias
        fprintf('VERDICT: Rightward bias IS present in some sessions.\n');
        biasedSess = find(pRight > 0.55);
        for s = biasedSess
            fprintf('  -> %s shows rightward bias (P=%.3f)\n', S(s).label, pRight(s));
        end
    else
        fprintf('VERDICT: No strong rightward bias detected (all within 0.4-0.6).\n');
    end

    fprintf('\n--- OBSERVATION 2: Uncertainty & Exploration ---\n');
    % Pre-refactor vs post-refactor P(right)
    preIdx = [1 2]; postIdx = [3 4]; lowIdx = 5;
    prePR = mean(pRight(preIdx), 'omitnan');
    postPR = mean(pRight(postIdx), 'omitnan');
    if ~isnan(pRight(lowIdx))
        lowPR = pRight(lowIdx);
    else
        lowPR = NaN;
    end
    fprintf('  Pre-refactor (R=2, phase-level):   mean P(Right) = %.3f\n', prePR);
    fprintf('  Post-refactor (R=2, per-trial):    mean P(Right) = %.3f\n', postPR);
    fprintf('  Low ratio (R=1.25, per-trial):     P(Right) = %.3f\n', lowPR);
    if postPR < prePR - 0.05
        fprintf('VERDICT: Per-trial 50/50 assignment REDUCED rightward bias.\n');
    elseif postPR > prePR + 0.05
        fprintf('VERDICT: Per-trial 50/50 assignment INCREASED rightward bias.\n');
    else
        fprintf('VERDICT: Per-trial 50/50 assignment had MINIMAL effect on rightward bias.\n');
    end

    fprintf('\n--- OBSERVATION 3: Reward Dominates Over Saliency ---\n');
    fprintf('Delta-T effect on P(HighSal) in conflict trials (Gap - Overlap):\n');
    for s = 1:nSessions
        fprintf('  %s: effect = %.3f\n', S(s).label, effectSize(s));
    end
    meanEffect = mean(effectSize, 'omitnan');
    fprintf('  Mean effect across sessions: %.3f\n', meanEffect);
    if abs(meanEffect) < 0.05
        fprintf('VERDICT: NO systematic delta-T effect on saliency capture.\n');
        fprintf('  The gap/overlap manipulation does NOT differentially drive saliency-based choices.\n');
    elseif meanEffect > 0.05
        fprintf('VERDICT: Gap trials show MORE saliency capture than overlap (expected direction).\n');
    else
        fprintf('VERDICT: Gap trials show LESS saliency capture (unexpected direction).\n');
    end

    fprintf('\n--- OBSERVATION 4: Low Reward Ratio Effect ---\n');
    if nSessions >= 5
        fprintf('P(Right) by phase for Feb 18 (R=1.25) vs earlier sessions:\n');
        for ph = 1:3
            fprintf('  Phase %d: Feb18=%.3f, earlier mean=%.3f\n', ...
                ph, pRightByPhase(5, ph), mean(pRightByPhase(1:4, ph), 'omitnan'));
        end
    end

    fprintf('\n--- SALIENCE SENSITIVITY (d'') ---\n');
    for s = 1:nSessions
        fprintf('  %s: d''=%.3f, criterion=%.3f\n', S(s).label, dPrime(s), criterion(s));
    end
    meanDp = mean(dPrime, 'omitnan');
    if meanDp < 0.3
        fprintf('VERDICT: Salience sensitivity is LOW (d''<0.3).\n');
        fprintf('  The DKL hue manipulation may not be creating sufficient perceptual contrast.\n');
    elseif meanDp < 0.7
        fprintf('VERDICT: Salience sensitivity is MODERATE (0.3<d''<0.7).\n');
    else
        fprintf('VERDICT: Salience sensitivity is STRONG (d''>0.7).\n');
    end
    meanC = mean(criterion, 'omitnan');
    if meanC < -0.2
        fprintf('  Criterion is negative: consistent rightward spatial bias.\n');
    elseif meanC > 0.2
        fprintf('  Criterion is positive: leftward spatial bias.\n');
    else
        fprintf('  Criterion is near zero: no strong spatial bias.\n');
    end

    fprintf('\n--- DESIGN RECOMMENDATIONS ---\n');
    fprintf('Based on the data:\n\n');

    if abs(meanEffect) < 0.05
        fprintf('1. GAP/OVERLAP MANIPULATION: The current +/-150ms delta-T is INEFFECTIVE.\n');
        fprintf('   Consider:\n');
        fprintf('   a) Larger delta-T values (e.g., +/-300ms or +/-500ms)\n');
        fprintf('   b) A true "step-gap" paradigm: fixation OFF -> blank gap -> target ON\n');
        fprintf('      (rather than current overlap where stim appears before fix offset)\n');
        fprintf('   c) Stimulus onset asynchrony BETWEEN targets (one appears before the other)\n');
        fprintf('      This would directly test saliency capture by giving the high-sal target\n');
        fprintf('      a temporal advantage.\n\n');
    end

    if meanDp < 0.5
        fprintf('2. SALIENCE MANIPULATION: DKL hue contrast may be insufficient.\n');
        fprintf('   Consider:\n');
        fprintf('   a) Adding luminance contrast in addition to hue contrast\n');
        fprintf('   b) Using a larger hue separation (e.g., 225 deg instead of 180 deg)\n');
        fprintf('   c) Making the low-salience target even more similar to background\n');
        fprintf('      (e.g., 20 deg instead of 45 deg hue offset)\n');
        fprintf('   d) Verifying contrast with photometer measurements\n\n');
    end

    fprintf('3. REWARD RATIO: The monkey clearly tracks reward in Phases 2-3.\n');
    fprintf('   To create a regime where saliency can compete:\n');
    fprintf('   a) Use a SMALLER reward ratio (e.g., 1.1:1) so reward signal is weaker\n');
    fprintf('   b) Introduce reward noise (varying ratio trial-by-trial)\n');
    fprintf('   c) Consider equal reward with PROBABILISTIC delivery\n');
    fprintf('      (e.g., high-sal side: 80%% chance of reward, low-sal: 20%%)\n\n');

    fprintf('4. RESPONSE WINDOW: Currently 600ms allows deliberative choices.\n');
    fprintf('   To capture reflexive saccades:\n');
    fprintf('   a) Shorten response window to 300-400ms\n');
    fprintf('   b) This would force faster choices that are more likely saliency-driven\n');
    fprintf('   c) Risk: higher error rates, monkey frustration\n\n');

    fprintf('5. ALTERNATIVE "ONE KNOB" APPROACH:\n');
    fprintf('   Instead of gap/overlap, consider PROCESSING TIME manipulation:\n');
    fprintf('   a) Show targets for variable durations before requiring saccade\n');
    fprintf('   b) Short exposure (50-100ms flash) -> saliency dominates\n');
    fprintf('   c) Long exposure (500ms+) -> reward dominates\n');
    fprintf('   d) This is closer to the "tachometric function" approach\n');
    fprintf('      and has stronger evidence from the literature\n\n');

    fprintf('============================================================\n');
    fprintf('                    END OF REPORT\n');
    fprintf('============================================================\n');
end

function pdfSave(fileName, fig)
    set(fig, 'PaperUnits', 'Inches', 'PaperSize', fig.Position(3:4)/72);
    set(fig, 'PaperUnits', 'Normalized', 'PaperPosition', [0 0 1 1]);
    exportgraphics(fig, fileName, 'Resolution', 300, 'ContentType', 'image');
    fprintf('  Saved: %s\n', fileName);
end
