function analyzeFeb20Session()
%   analyzeFeb20Session()
%
% Analyzes the Feb 20 conflict task session (deltaT=[-100,+100],
% rewardRatioBig=1.5, responseWindow=0.45s) with previous sessions
% as comparison context.
%
% Output: PDF figures and markdown report saved to output/analysis/feb20/

%% ====================== SETUP ======================
pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
outputDir  = fullfile(pldapsHome, 'output', 'analysis', 'feb20');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

% All sessions (previous + new)
sessionFiles = {
    'output/20260209_t1010_conflict_task.mat'
    'output/20260211_t0929_conflict_task.mat'
    'output/20260213_t1018_conflict_task.mat'
    'output/20260216_t0837_conflict_task.mat'
    'output/20260218_t0934_conflict_task.mat'
    'output/20260220_t1023_conflict_task.mat'
    };
sessionLabels = {'Feb 9', 'Feb 11', 'Feb 13', 'Feb 16', 'Feb 18', 'Feb 20'};
nSessions = length(sessionFiles);
iFocal = nSessions; % Feb 20 is the focal session

% Colors
colPrev    = [0.65 0.65 0.65]; % gray for previous sessions
colFocal   = [0.85 0.33 0.10]; % orange for Feb 20
colOrange  = [0.850 0.325 0.098];
colBlue    = [0.000 0.447 0.741];
colGreen   = [0.466 0.674 0.188];
colPurple  = [0.494 0.184 0.556];
colGray    = [0.5 0.5 0.5];
colRed     = [0.80 0.15 0.15];
colSession = [repmat(colPrev, nSessions-1, 1); colFocal];

%% ====================== LOAD ALL SESSIONS ======================
fprintf('\n====== LOADING SESSIONS ======\n');
S = struct();

for iSess = 1:nSessions
    fpath = fullfile(pldapsHome, sessionFiles{iSess});
    fprintf('Loading %s ... ', sessionLabels{iSess});
    data = load(fpath);
    if isfield(data, 'p'), p = data.p; else, p = data; end
    nTrials = length(p.trData);
    fprintf('%d trials\n', nTrials);

    % Parameters
    if isfield(p, 'trVarsInit'), tv0 = p.trVarsInit; else, tv0 = p.trVars(1); end

    S(iSess).label   = sessionLabels{iSess};
    S(iSess).nTrials = nTrials;
    S(iSess).p       = p;
    S(iSess).rewardRatioBig  = safeField(tv0, 'rewardRatioBig', 2.0);
    S(iSess).rewardProbHigh  = safeField(tv0, 'rewardProbHigh', 0.9);
    S(iSess).rewardDurationMs = safeField(tv0, 'rewardDurationMs', 400);

    % Use per-trial responseWindow (may differ from trVarsInit if changed mid-session)
    allRW = arrayfun(@(x) x.responseWindow, p.trVars(:)');
    S(iSess).responseWindow = mode(allRW); % most common value

    % ALWAYS derive deltaTValues from actual per-trial data (p.status may be stale)
    allDT = arrayfun(@(x) x.deltaT, p.trVars(:)');
    % For sessions with mixed values (e.g., mid-session change), use Phases 2-3
    % trials as ground truth since Phase 1 may have stale trial array entries
    allPh = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
    p23DT = allDT(allPh >= 2);
    if ~isempty(p23DT)
        S(iSess).deltaTValues = unique(p23DT(~isnan(p23DT)))';
    else
        S(iSess).deltaTValues = unique(allDT(~isnan(allDT)))';
    end

    if isfield(p.init, 'trialsPerPhaseList')
        S(iSess).trialsPerPhase = p.init.trialsPerPhaseList;
    else
        S(iSess).trialsPerPhase = [128 128 128];
    end

    hasSS = isfield(p.trVars, 'singleStimSide');
    S(iSess).hasSingleStim = hasSS && any(arrayfun(@(x) x.singleStimSide, p.trVars(:)') > 0);
    S(iSess).hasPerTrialReward = isfield(p.trVars, 'rewardBigSide');

    % Per-trial data (all forced to row vectors)
    sacCompleteState = p.state.sacComplete;
    phase     = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
    dtIdx     = arrayfun(@(x) x.deltaTIdx, p.trVars(:)');
    dt        = arrayfun(@(x) x.deltaT, p.trVars(:)');
    hsSide    = arrayfun(@(x) x.highSalienceSide, p.trVars(:)');
    endState  = arrayfun(@(x) x.trialEndState, p.trData(:)');

    if isfield(p.trVars, 'rewardBigSide')
        rwdSide = arrayfun(@(x) x.rewardBigSide, p.trVars(:)');
    else
        rwdSide = ones(1, nTrials);
        rwdSide(phase == 2) = 2; rwdSide(phase == 3) = 1; rwdSide(phase == 1) = 0;
    end

    if hasSS
        singleStim = arrayfun(@(x) x.singleStimSide, p.trVars(:)');
    else
        singleStim = zeros(1, nTrials);
    end

    chosenSide = NaN(1, nTrials);
    for iTr = 1:nTrials
        if isfield(p.trData(iTr), 'chosenSide') && ~isempty(p.trData(iTr).chosenSide)
            chosenSide(iTr) = p.trData(iTr).chosenSide;
        end
    end

    choseHighSal = zeros(1, nTrials);
    if isfield(p.trData, 'choseHighSalience')
        for iTr = 1:nTrials
            val = p.trData(iTr).choseHighSalience;
            if ~isempty(val), choseHighSal(iTr) = double(val); end
        end
    end

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

    if isfield(p.trVars, 'isConflict')
        isConf = zeros(1, nTrials);
        for iTr = 1:nTrials
            val = p.trVars(iTr).isConflict;
            if ~isempty(val), isConf(iTr) = double(val); end
        end
    else
        isConf = double((rwdSide ~= hsSide) & (rwdSide > 0) & (singleStim == 0));
    end

    isSC   = (endState == sacCompleteState);
    isDual = (singleStim == 0);

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
    S(iSess).endState   = endState;

    % Error counts
    S(iSess).nFixBreak   = sum(endState == p.state.fixBreak);
    S(iSess).nNoResp     = sum(endState == p.state.noResponse);
    S(iSess).nInaccurate = sum(endState == p.state.inaccurate);
    if isfield(p.state, 'joyBreak'), S(iSess).nJoyBreak = sum(endState == p.state.joyBreak);
    else, S(iSess).nJoyBreak = 0; end
    if isfield(p.state, 'nonStart'), S(iSess).nNonStart = sum(endState == p.state.nonStart);
    else, S(iSess).nNonStart = 0; end

    % Count completed trials per phase
    S(iSess).nGood = sum(isSC);
    S(iSess).nGoodP1 = sum(isSC & isDual & (phase == 1));
    S(iSess).nGoodP2 = sum(isSC & isDual & (phase == 2));
    S(iSess).nGoodP3 = sum(isSC & isDual & (phase == 3));
end

%% ====================== FOCAL SESSION SUMMARY ======================
f = S(iFocal);
fprintf('\n====== FEB 20 SESSION SUMMARY ======\n');
fprintf('  Total trials:       %d\n', f.nTrials);
fprintf('  Good (sacComplete): %d\n', f.nGood);
fprintf('  Phase 1 dual-stim:  %d\n', f.nGoodP1);
fprintf('  Phase 2 dual-stim:  %d\n', f.nGoodP2);
fprintf('  Phase 3 dual-stim:  %d\n', f.nGoodP3);
fprintf('  Reward ratio:       %.2f\n', f.rewardRatioBig);
fprintf('  Response window:    %.2f s\n', f.responseWindow);
fprintf('  DeltaT values:      [%s]\n', strjoin(arrayfun(@(x) sprintf('%d', x), f.deltaTValues, 'UniformOutput', false), ', '));
fprintf('  Fix breaks:         %d\n', f.nFixBreak);
fprintf('  No response:        %d\n', f.nNoResp);
fprintf('  Inaccurate:         %d\n', f.nInaccurate);

%% ====================== FIGURE 1: PARAMETER COMPARISON ======================
fprintf('\n====== FIGURE 1: PARAMETER COMPARISON ======\n');
fig1 = figure('Position', [100 100 1000 350], 'Color', 'w', ...
    'Name', 'Fig1: Parameters', 'NumberTitle', 'off');
ax = axes('Position', [0.05 0.05 0.9 0.85], 'Visible', 'off');
xlim([0 1]); ylim([0 1]);

headers = {'Parameter', sessionLabels{:}};
nCols = length(headers);
colX = linspace(0.02, 0.98, nCols + 1);
colX = colX(1:end-1) + diff(colX(1:2))/2;

rowParams = {
    'rewardRatioBig',   'Reward Ratio'
    'responseWindow',   'Response Window (s)'
    'deltaTValues',     'DeltaT Values (ms)'
    'trialsPerPhase',   'Trials Per Phase'
    'nTrials',          'Total Trial Files'
    'nGood',            'Completed Trials'
    };
nRows = size(rowParams, 1);
rowY = linspace(0.82, 0.10, nRows);

for c = 1:nCols
    fw = 'normal'; fc = [0 0 0];
    if c == nCols + 1 - (nSessions - iFocal), fw = 'bold'; fc = colFocal; end
    text(colX(c), 0.93, headers{c}, 'FontSize', 10, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'Parent', ax, 'Color', fc);
end
plot(ax, [0.01 0.99], [0.88 0.88], 'k-', 'LineWidth', 1.5);

for r = 1:nRows
    fn = rowParams{r, 1}; dn = rowParams{r, 2};
    text(colX(1), rowY(r), dn, 'FontSize', 9, 'HorizontalAlignment', 'center', 'Parent', ax);
    for s = 1:nSessions
        val = S(s).(fn);
        if isnumeric(val) && isscalar(val)
            if val == round(val), valStr = sprintf('%d', val);
            else, valStr = sprintf('%.2f', val); end
        elseif isnumeric(val) && isvector(val)
            valStr = sprintf('[%s]', strjoin(arrayfun(@(x) sprintf('%d', x), val, 'UniformOutput', false), ','));
        else, valStr = '?'; end

        fw = 'normal'; fc = [0 0 0];
        if s == iFocal, fw = 'bold'; fc = colFocal; end
        if s > 1 && ~isequal(val, S(s-1).(fn)), fc = colRed; fw = 'bold'; end
        text(colX(s+1), rowY(r), valStr, 'FontSize', 9, 'FontWeight', fw, ...
            'Color', fc, 'HorizontalAlignment', 'center', 'Parent', ax);
    end
end
title(ax, 'Session Parameter Comparison (Feb 20 highlighted)', ...
    'FontSize', 13, 'FontWeight', 'bold', 'Visible', 'on');
pdfSave(fullfile(outputDir, 'fig01_parameters.pdf'), fig1);

%% ====================== FIGURE 2: P(RIGHT) ACROSS SESSIONS ======================
fprintf('\n====== FIGURE 2: RIGHTWARD BIAS ======\n');
fig2 = figure('Position', [100 100 1200 450], 'Color', 'w', ...
    'Name', 'Fig2: Rightward Bias', 'NumberTitle', 'off');

% Panel A: P(right) Phase 1 bar chart
ax2a = subplot(1,3,1); hold on;
title('Phase 1: P(Right)', 'FontSize', 12, 'FontWeight', 'bold');
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    nR = sum(S(s).chosenSide(mask) == 2); nT = sum(mask);
    if nT > 0
        pR = nR / nT; ci = binomCI(nR, nT, 0.95);
        fc = colPrev; if s == iFocal, fc = colFocal; end
        bar(s, pR, 0.6, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
        plot([s s], ci, 'k-', 'LineWidth', 1.5);
        fprintf('  %s: P(right)=%.3f  n=%d\n', S(s).label, pR, nT);
    end
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 9);
ylabel('P(Right)');

% Panel B: P(high-sal) by salience side for Feb 20
ax2b = subplot(1,3,2); hold on;
title('Feb 20 Phase 1: P(HighSal) by Side', 'FontSize', 12, 'FontWeight', 'bold');
dtVals = f.deltaTValues;
for d = 1:length(dtVals)
    maskL = f.isSC & f.isDual & (f.phase == 1) & (f.hsSide == 1) & (f.dt == dtVals(d));
    maskR = f.isSC & f.isDual & (f.phase == 1) & (f.hsSide == 2) & (f.dt == dtVals(d));
    nL = sum(maskL); nR = sum(maskR);
    pL = sum(f.choseHS(maskL)) / max(nL,1);
    pR = sum(f.choseHS(maskR)) / max(nR,1);

    xOff = (d - 1.5) * 0.15;
    if nL > 0
        ciL = binomCI(sum(f.choseHS(maskL)), nL, 0.95);
        bar(1 + xOff, pL, 0.12, 'FaceColor', colOrange, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        plot([1+xOff 1+xOff], ciL, 'k-', 'LineWidth', 1.5);
    end
    if nR > 0
        ciR = binomCI(sum(f.choseHS(maskR)), nR, 0.95);
        bar(2 + xOff, pR, 0.12, 'FaceColor', colBlue, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        plot([2+xOff 2+xOff], ciR, 'k-', 'LineWidth', 1.5);
    end
end
plot([0.3 2.7], [0.5 0.5], '--', 'Color', colGray);
set(gca, 'XTick', [1 2], 'XTickLabel', {'HighSal LEFT', 'HighSal RIGHT'}, ...
    'TickDir', 'out', 'XLim', [0.5 2.5], 'YLim', [0 1], 'FontSize', 9);
ylabel('P(High Salience)');
% Legend for delta-T
hLeg = [];
for d = 1:length(dtVals)
    hLeg(d) = bar(NaN, NaN, 'FaceColor', colGray, 'FaceAlpha', 0.3+0.4*d/length(dtVals));
end
legend(hLeg, arrayfun(@(x) sprintf('\\Deltat=%d', x), dtVals, 'UniformOutput', false), ...
    'Box', 'off', 'FontSize', 8, 'Location', 'best');

% Panel C: Running P(right) in Phase 1 for Feb 20 vs previous
ax2c = subplot(1,3,3); hold on;
title('Phase 1: Running P(Right)', 'FontSize', 12, 'FontWeight', 'bold');
winSize = 20;
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    chosen = S(s).chosenSide(mask);
    nT = sum(mask);
    if nT < winSize, continue; end
    isRight = double(chosen == 2);
    runP = movmean(isRight, [winSize-1 0]);
    lw = 1; alph = 0.4; col = colPrev;
    if s == iFocal, lw = 2.5; alph = 1; col = colFocal; end
    plot(1:nT, runP, '-', 'Color', [col alph], 'LineWidth', lw, ...
        'DisplayName', S(s).label);
end
plot([0 200], [0.5 0.5], '--', 'Color', colGray, 'HandleVisibility', 'off');
legend('Location', 'best', 'Box', 'off', 'FontSize', 8);
xlabel('Trial in Phase 1'); ylabel('P(Right)');
set(gca, 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 9);

pdfSave(fullfile(outputDir, 'fig02_rightward_bias.pdf'), fig2);

%% ====================== FIGURE 3: REWARD vs SALIENCY (Focus Feb 20) ======================
fprintf('\n====== FIGURE 3: REWARD vs SALIENCY ======\n');
fig3 = figure('Position', [100 100 1400 800], 'Color', 'w', ...
    'Name', 'Fig3: Reward vs Saliency', 'NumberTitle', 'off');

% Panel A: P(HighSal) conflict by deltaT - Feb 20 vs all sessions
ax3a = subplot(2,3,1); hold on;
title({'P(HighSal) Conflict Trials', 'by \Deltat (Phases 2-3)'}, 'FontSize', 11, 'FontWeight', 'bold');
for s = 1:nSessions
    dtV = S(s).deltaTValues; pHS = NaN(1, length(dtV));
    for d = 1:length(dtV)
        mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf & (S(s).dt == dtV(d));
        nT = sum(mask);
        if nT > 0, pHS(d) = sum(S(s).choseHS(mask)) / nT; end
    end
    lw = 1; ms = 5; col = colPrev;
    if s == iFocal, lw = 2.5; ms = 10; col = colFocal; end
    plot(dtV, pHS, '-o', 'Color', col, 'LineWidth', lw, 'MarkerSize', ms, ...
        'MarkerFaceColor', col, 'DisplayName', S(s).label);
end
plot([-200 200], [0.5 0.5], '--', 'Color', colGray, 'HandleVisibility', 'off');
legend('Location', 'best', 'Box', 'off', 'FontSize', 8);
set(gca, 'XLim', [-200 200], 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 9);
xlabel('\Deltat (ms)'); ylabel('P(HighSal)');

% Panel B: P(HighSal) congruent by deltaT
ax3b = subplot(2,3,2); hold on;
title({'P(HighSal) Congruent Trials', 'by \Deltat (Phases 2-3)'}, 'FontSize', 11, 'FontWeight', 'bold');
for s = 1:nSessions
    dtV = S(s).deltaTValues; pHS = NaN(1, length(dtV));
    for d = 1:length(dtV)
        mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & ~S(s).isConf & (S(s).dt == dtV(d));
        nT = sum(mask);
        if nT > 0, pHS(d) = sum(S(s).choseHS(mask)) / nT; end
    end
    lw = 1; ms = 5; col = colPrev;
    if s == iFocal, lw = 2.5; ms = 10; col = colFocal; end
    plot(dtV, pHS, '-o', 'Color', col, 'LineWidth', lw, 'MarkerSize', ms, ...
        'MarkerFaceColor', col, 'DisplayName', S(s).label);
end
plot([-200 200], [0.5 0.5], '--', 'Color', colGray, 'HandleVisibility', 'off');
set(gca, 'XLim', [-200 200], 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 9);
xlabel('\Deltat (ms)'); ylabel('P(HighSal)');

% Panel C: P(HighReward) by deltaT
ax3c = subplot(2,3,3); hold on;
title({'P(High Reward)', 'by \Deltat (Phases 2-3)'}, 'FontSize', 11, 'FontWeight', 'bold');
for s = 1:nSessions
    dtV = S(s).deltaTValues; pHR = NaN(1, length(dtV));
    for d = 1:length(dtV)
        mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & (S(s).dt == dtV(d));
        nT = sum(mask);
        if nT > 0
            if S(s).hasPerTrialReward
                choseHR = (S(s).chosenSide(mask) == S(s).rwdSide(mask));
            else
                ph = S(s).phase(mask); cs = S(s).chosenSide(mask);
                choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
            end
            pHR(d) = sum(choseHR) / nT;
        end
    end
    lw = 1; ms = 5; col = colPrev;
    if s == iFocal, lw = 2.5; ms = 10; col = colFocal; end
    plot(dtV, pHR, '-o', 'Color', col, 'LineWidth', lw, 'MarkerSize', ms, ...
        'MarkerFaceColor', col, 'DisplayName', S(s).label);
end
plot([-200 200], [0.5 0.5], '--', 'Color', colGray, 'HandleVisibility', 'off');
legend('Location', 'best', 'Box', 'off', 'FontSize', 8);
set(gca, 'XLim', [-200 200], 'YLim', [0 1], 'TickDir', 'out', 'FontSize', 9);
xlabel('\Deltat (ms)'); ylabel('P(HighReward)');

% Panel D: Delta-T effect size across sessions
ax3d = subplot(2,3,4); hold on;
title({'\Deltat Effect on P(HighSal)', 'Conflict: Gap - Overlap'}, 'FontSize', 11, 'FontWeight', 'bold');
effectSize = NaN(1, nSessions);
for s = 1:nSessions
    dtV = S(s).deltaTValues;
    if length(dtV) < 2, continue; end
    overlapDT = min(dtV); gapDT = max(dtV);
    maskO = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf & (S(s).dt == overlapDT);
    maskG = S(s).isSC & S(s).isDual & (S(s).phase >= 2) & S(s).isConf & (S(s).dt == gapDT);
    nO = sum(maskO); nG = sum(maskG);
    if nO > 0 && nG > 0
        effectSize(s) = sum(S(s).choseHS(maskG))/nG - sum(S(s).choseHS(maskO))/nO;
    end
    fc = colPrev; if s == iFocal, fc = colFocal; end
    bar(s, effectSize(s), 0.6, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
end
plot([0.5 nSessions+0.5], [0 0], '-', 'Color', colGray);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'FontSize', 9);
ylabel('\DeltaP(HighSal)');
fprintf('  Feb 20 delta-T effect (conflict): %.3f\n', effectSize(iFocal));

% Panel E: Conflict vs Congruent P(HighSal) - Feb 20 only
ax3e = subplot(2,3,5); hold on;
title('Feb 20: Conflict vs Congruent', 'FontSize', 11, 'FontWeight', 'bold');
dtV = f.deltaTValues;
barW = 0.3;
for d = 1:length(dtV)
    maskConf = f.isSC & f.isDual & (f.phase >= 2) & f.isConf & (f.dt == dtV(d));
    maskCong = f.isSC & f.isDual & (f.phase >= 2) & ~f.isConf & (f.dt == dtV(d));
    nConf = sum(maskConf); nCong = sum(maskCong);

    xBase = d;
    if nConf > 0
        pConf = sum(f.choseHS(maskConf))/nConf;
        ci = binomCI(sum(f.choseHS(maskConf)), nConf, 0.95);
        bar(xBase - barW/2, pConf, barW, 'FaceColor', colOrange, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
        plot([xBase-barW/2 xBase-barW/2], ci, 'k-', 'LineWidth', 1.5);
    end
    if nCong > 0
        pCong = sum(f.choseHS(maskCong))/nCong;
        ci = binomCI(sum(f.choseHS(maskCong)), nCong, 0.95);
        bar(xBase + barW/2, pCong, barW, 'FaceColor', colBlue, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
        plot([xBase+barW/2 xBase+barW/2], ci, 'k-', 'LineWidth', 1.5);
    end
end
plot([0.3 length(dtV)+0.7], [0.5 0.5], '--', 'Color', colGray);
set(gca, 'XTick', 1:length(dtV), 'XTickLabel', arrayfun(@(x) sprintf('%d ms', x), dtV, 'UniformOutput', false), ...
    'TickDir', 'out', 'XLim', [0.3 length(dtV)+0.7], 'YLim', [0 1], 'FontSize', 9);
xlabel('\Deltat'); ylabel('P(HighSal)');
hConf = bar(NaN, NaN, 'FaceColor', colOrange, 'EdgeColor', 'none');
hCong = bar(NaN, NaN, 'FaceColor', colBlue, 'EdgeColor', 'none');
legend([hConf hCong], {'Conflict', 'Congruent'}, 'Box', 'off', 'FontSize', 8);

% Panel F: Phase 2 vs Phase 3 P(HighSal) - Feb 20
ax3f = subplot(2,3,6); hold on;
title('Feb 20: Phase 2 vs Phase 3', 'FontSize', 11, 'FontWeight', 'bold');
for d = 1:length(dtV)
    for ph = 2:3
        maskConf = f.isSC & f.isDual & (f.phase == ph) & f.isConf & (f.dt == dtV(d));
        nT = sum(maskConf);
        if nT > 0
            pHS = sum(f.choseHS(maskConf))/nT;
            ci = binomCI(sum(f.choseHS(maskConf)), nT, 0.95);
            xPos = (d-1)*2 + (ph-1);
            fc = colOrange; if ph == 3, fc = colGreen; end
            bar(xPos, pHS, 0.7, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
            plot([xPos xPos], ci, 'k-', 'LineWidth', 1.5);
        end
    end
end
plot([0 5], [0.5 0.5], '--', 'Color', colGray);
nDT = length(dtV);
xLabels = {};
for d = 1:nDT
    xLabels{(d-1)*2+1} = sprintf('P2 %dms', dtV(d));
    xLabels{(d-1)*2+2} = sprintf('P3 %dms', dtV(d));
end
set(gca, 'XTick', 1:(nDT*2), 'XTickLabel', xLabels, 'XTickLabelRotation', 30, ...
    'TickDir', 'out', 'XLim', [0.3 nDT*2+0.7], 'YLim', [0 1], 'FontSize', 8);
ylabel('P(HighSal) Conflict');
hP2 = bar(NaN, NaN, 'FaceColor', colOrange, 'EdgeColor', 'none');
hP3 = bar(NaN, NaN, 'FaceColor', colGreen, 'EdgeColor', 'none');
legend([hP2 hP3], {'Phase 2', 'Phase 3'}, 'Box', 'off', 'FontSize', 8);

pdfSave(fullfile(outputDir, 'fig03_reward_vs_saliency.pdf'), fig3);

%% ====================== FIGURE 4: RT ANALYSIS ======================
fprintf('\n====== FIGURE 4: REACTION TIMES ======\n');
fig4 = figure('Position', [100 100 1400 800], 'Color', 'w', ...
    'Name', 'Fig4: Reaction Times', 'NumberTitle', 'off');

rtBins = 50:10:600;

% Panel A: Feb 20 Phase 1 RT distributions by deltaT
ax4a = subplot(2,3,1); hold on;
title('Feb 20 Phase 1: RT by \Deltat', 'FontSize', 11, 'FontWeight', 'bold');
dtV = f.deltaTValues;
for d = 1:length(dtV)
    mask = f.isSC & f.isDual & (f.phase == 1) & (f.dt == dtV(d));
    rts = f.srt(mask); rts = rts(~isnan(rts));
    if ~isempty(rts)
        fc = colOrange; if dtV(d) > 0, fc = colBlue; end
        histogram(rts, rtBins, 'FaceColor', fc, 'FaceAlpha', 0.5, 'EdgeColor', 'none', ...
            'DisplayName', sprintf('\\Deltat=%d (med=%.0f)', dtV(d), median(rts)));
    end
end
legend('Box', 'off', 'FontSize', 8); xlabel('SRT (ms)'); ylabel('Count');
xlim([50 600]); set(gca, 'TickDir', 'out', 'FontSize', 9);

% Panel B: Feb 20 Phases 2-3 RT distributions by deltaT
ax4b = subplot(2,3,2); hold on;
title('Feb 20 Phases 2-3: RT by \Deltat', 'FontSize', 11, 'FontWeight', 'bold');
for d = 1:length(dtV)
    mask = f.isSC & f.isDual & (f.phase >= 2) & (f.dt == dtV(d));
    rts = f.srt(mask); rts = rts(~isnan(rts));
    if ~isempty(rts)
        fc = colOrange; if dtV(d) > 0, fc = colBlue; end
        histogram(rts, rtBins, 'FaceColor', fc, 'FaceAlpha', 0.5, 'EdgeColor', 'none', ...
            'DisplayName', sprintf('\\Deltat=%d (med=%.0f)', dtV(d), median(rts)));
    end
end
legend('Box', 'off', 'FontSize', 8); xlabel('SRT (ms)'); ylabel('Count');
xlim([50 600]); set(gca, 'TickDir', 'out', 'FontSize', 9);

% Panel C: Feb 20 RT by choice (high-sal vs low-sal, conflict trials)
ax4c = subplot(2,3,3); hold on;
title('Feb 20: RT by Choice (Conflict)', 'FontSize', 11, 'FontWeight', 'bold');
mask = f.isSC & f.isDual & (f.phase >= 2) & logical(f.isConf);
rtsHS = f.srt(mask & logical(f.choseHS)); rtsHS = rtsHS(~isnan(rtsHS));
rtsLS = f.srt(mask & ~logical(f.choseHS)); rtsLS = rtsLS(~isnan(rtsLS));
if ~isempty(rtsHS)
    histogram(rtsHS, rtBins, 'FaceColor', colOrange, 'FaceAlpha', 0.5, 'EdgeColor', 'none', ...
        'DisplayName', sprintf('Chose HighSal (med=%.0f, n=%d)', median(rtsHS), length(rtsHS)));
end
if ~isempty(rtsLS)
    histogram(rtsLS, rtBins, 'FaceColor', colBlue, 'FaceAlpha', 0.5, 'EdgeColor', 'none', ...
        'DisplayName', sprintf('Chose LowSal (med=%.0f, n=%d)', median(rtsLS), length(rtsLS)));
end
legend('Box', 'off', 'FontSize', 8); xlabel('SRT (ms)'); ylabel('Count');
xlim([50 600]); set(gca, 'TickDir', 'out', 'FontSize', 9);

% Panel D: Median RT across sessions
ax4d = subplot(2,3,4); hold on;
title('Median SRT Across Sessions', 'FontSize', 11, 'FontWeight', 'bold');
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual;
    rts = S(s).srt(mask); rts = rts(~isnan(rts));
    if ~isempty(rts)
        mRT = median(rts); ci = bootCI(rts, 0.95);
        fc = colPrev; if s == iFocal, fc = colFocal; end
        bar(s, mRT, 0.6, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
        plot([s s], ci, 'k-', 'LineWidth', 1.5);
    end
end
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'FontSize', 9);
ylabel('Median SRT (ms)');

% Panel E: Tachometric - P(HighSal) vs RT (Feb 20 conflict, by deltaT)
ax4e = subplot(2,3,5); hold on;
title('Feb 20: Tachometric (Conflict)', 'FontSize', 11, 'FontWeight', 'bold');
rtEdges = [0 125 175 225 275 350 600];
rtCenters = (rtEdges(1:end-1) + rtEdges(2:end)) / 2;
nBins = length(rtCenters);
for d = 1:length(dtV)
    mask = f.isSC & f.isDual & (f.phase >= 2) & logical(f.isConf) & (f.dt == dtV(d));
    rts = f.srt(mask); chs = f.choseHS(mask);
    pHS_bin = NaN(1, nBins);
    for b = 1:nBins
        inBin = rts >= rtEdges(b) & rts < rtEdges(b+1);
        nB = sum(inBin);
        if nB >= 3, pHS_bin(b) = sum(chs(inBin)) / nB; end
    end
    valid = ~isnan(pHS_bin);
    fc = colOrange; if dtV(d) > 0, fc = colBlue; end
    plot(rtCenters(valid), pHS_bin(valid), '-o', 'Color', fc, 'LineWidth', 2, ...
        'MarkerFaceColor', fc, 'MarkerSize', 7, ...
        'DisplayName', sprintf('\\Deltat=%d', dtV(d)));
end
plot([50 600], [0.5 0.5], '--', 'Color', colGray, 'HandleVisibility', 'off');
legend('Box', 'off', 'FontSize', 8); xlabel('SRT (ms)'); ylabel('P(HighSal)');
xlim([50 500]); ylim([0 1]); set(gca, 'TickDir', 'out', 'FontSize', 9);

% Panel F: Median RT left vs right across sessions
ax4f = subplot(2,3,6); hold on;
title('Median SRT: Left vs Right', 'FontSize', 11, 'FontWeight', 'bold');
barW = 0.35;
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual;
    rtL = S(s).srt(mask & (S(s).chosenSide == 1)); rtL = rtL(~isnan(rtL));
    rtR = S(s).srt(mask & (S(s).chosenSide == 2)); rtR = rtR(~isnan(rtR));
    if ~isempty(rtL), bar(s - barW/2, median(rtL), barW, 'FaceColor', colOrange, 'EdgeColor', 'none', 'FaceAlpha', 0.7); end
    if ~isempty(rtR), bar(s + barW/2, median(rtR), barW, 'FaceColor', colBlue, 'EdgeColor', 'none', 'FaceAlpha', 0.7); end
end
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'FontSize', 9);
ylabel('Median SRT (ms)');
hL = bar(NaN, NaN, 'FaceColor', colOrange, 'EdgeColor', 'none');
hR = bar(NaN, NaN, 'FaceColor', colBlue, 'EdgeColor', 'none');
legend([hL hR], {'Leftward', 'Rightward'}, 'Box', 'off', 'FontSize', 8);

pdfSave(fullfile(outputDir, 'fig04_reaction_times.pdf'), fig4);

%% ====================== FIGURE 5: LEARNING & EVOLUTION ======================
fprintf('\n====== FIGURE 5: LEARNING & EVOLUTION ======\n');
fig5 = figure('Position', [100 100 1400 500], 'Color', 'w', ...
    'Name', 'Fig5: Learning', 'NumberTitle', 'off');

% Panel A: Feb 20 cumulative P(HighReward) in Phases 2-3
ax5a = subplot(1,3,1); hold on;
title('Feb 20: Cum. P(HighReward) P2-3', 'FontSize', 11, 'FontWeight', 'bold');
mask = f.isSC & f.isDual & (f.phase >= 2);
idx = find(mask);
if ~isempty(idx)
    if f.hasPerTrialReward
        choseHR = (f.chosenSide(idx) == f.rwdSide(idx));
    else
        ph = f.phase(idx); cs = f.chosenSide(idx);
        choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
    end
    isConfLoc = logical(f.isConf(idx));
    if sum(isConfLoc) > 5
        cumHR_conf = cumsum(double(choseHR(isConfLoc))) ./ (1:sum(isConfLoc));
        plot(1:sum(isConfLoc), cumHR_conf, '-', 'Color', colOrange, 'LineWidth', 2);
    end
    if sum(~isConfLoc) > 5
        cumHR_cong = cumsum(double(choseHR(~isConfLoc))) ./ (1:sum(~isConfLoc));
        plot(1:sum(~isConfLoc), cumHR_cong, '-', 'Color', colBlue, 'LineWidth', 2);
    end
end
plot([0 300], [0.5 0.5], '--', 'Color', colGray);
xlabel('Trial in P2-3'); ylabel('Cum. P(HighReward)');
ylim([0 1]); set(gca, 'TickDir', 'out', 'FontSize', 9);
legend({'Conflict', 'Congruent'}, 'Box', 'off', 'FontSize', 8, 'Location', 'best');

% Panel B: Full-session choice evolution (Feb 20)
ax5b = subplot(1,3,2); hold on;
title('Feb 20: Full Session Evolution', 'FontSize', 11, 'FontWeight', 'bold');
mask = f.isSC & f.isDual;
idx = find(mask);
phases = f.phase(idx);
sides = f.chosenSide(idx);
chHS = f.choseHS(idx);

% Running P(right)
if length(idx) > winSize
    runPR = movmean(double(sides == 2), [winSize-1 0]);
    plot(1:length(idx), runPR, '-', 'Color', colBlue, 'LineWidth', 1.5, 'DisplayName', 'P(Right)');
end
% Running P(HighSal)
if length(idx) > winSize
    runPHS = movmean(double(chHS), [winSize-1 0]);
    plot(1:length(idx), runPHS, '-', 'Color', colOrange, 'LineWidth', 1.5, 'DisplayName', 'P(HighSal)');
end

% Phase boundaries
if isfield(f.p.init, 'trialsPerPhaseList')
    tpp = f.p.init.trialsPerPhaseList;
    pb1 = sum(phases <= 1); pb2 = pb1 + sum(phases == 2);
    plot([pb1 pb1], [0 1], ':', 'Color', colGray, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    plot([pb2 pb2], [0 1], ':', 'Color', colGray, 'LineWidth', 1.5, 'HandleVisibility', 'off');
    text(pb1/2, 0.97, 'P1', 'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', colGray);
    text((pb1+pb2)/2, 0.97, 'P2', 'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', colGray);
    text((pb2+length(idx))/2, 0.97, 'P3', 'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', colGray);
end

plot([0 length(idx)], [0.5 0.5], '--', 'Color', colGray, 'HandleVisibility', 'off');
xlabel('Dual-stim trial'); ylabel('Running proportion');
ylim([0 1]); set(gca, 'TickDir', 'out', 'FontSize', 9);
legend('Location', 'best', 'Box', 'off', 'FontSize', 8);

% Panel C: Sequential effects - Feb 20
ax5c = subplot(1,3,3); hold on;
title('Feb 20: Win-Stay (P2-3)', 'FontSize', 11, 'FontWeight', 'bold');
mask = f.isSC & f.isDual & (f.phase >= 2);
idx = find(mask);
if length(idx) > 5
    sides = f.chosenSide(idx);
    if f.hasPerTrialReward
        choseHR = (f.chosenSide(idx) == f.rwdSide(idx));
    else
        ph = f.phase(idx); cs = f.chosenSide(idx);
        choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
    end
    % After high-reward vs low-reward
    afterHR = choseHR(1:end-1);
    nextHR = choseHR(2:end);
    pHR_afterHR = sum(nextHR(afterHR)) / max(sum(afterHR), 1);
    pHR_afterLR = sum(nextHR(~afterHR)) / max(sum(~afterHR), 1);

    bar(1, pHR_afterHR, 0.6, 'FaceColor', colGreen, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    bar(2, pHR_afterLR, 0.6, 'FaceColor', colPurple, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    if sum(afterHR) > 2
        ci = binomCI(sum(nextHR(afterHR)), sum(afterHR), 0.95);
        plot([1 1], ci, 'k-', 'LineWidth', 1.5);
    end
    if sum(~afterHR) > 2
        ci = binomCI(sum(nextHR(~afterHR)), sum(~afterHR), 0.95);
        plot([2 2], ci, 'k-', 'LineWidth', 1.5);
    end
end
plot([0.3 2.7], [0.5 0.5], '--', 'Color', colGray);
set(gca, 'XTick', [1 2], 'XTickLabel', {'After HighRwd', 'After LowRwd'}, ...
    'TickDir', 'out', 'XLim', [0.3 2.7], 'YLim', [0 1], 'FontSize', 9);
ylabel('P(HighReward next)');

pdfSave(fullfile(outputDir, 'fig05_learning.pdf'), fig5);

%% ====================== FIGURE 6: ERROR & ENDPOINT ANALYSIS ======================
fprintf('\n====== FIGURE 6: ERRORS & ENDPOINTS ======\n');
fig6 = figure('Position', [100 100 1400 500], 'Color', 'w', ...
    'Name', 'Fig6: Errors & Endpoints', 'NumberTitle', 'off');

% Panel A: Error rates across sessions
ax6a = subplot(1,3,1); hold on;
title('Error Rates by Session', 'FontSize', 11, 'FontWeight', 'bold');
errColors = [colOrange; colBlue; colPurple; colGray];
errData = zeros(nSessions, 4);
for s = 1:nSessions
    errData(s,:) = [S(s).nFixBreak, S(s).nNoResp, S(s).nInaccurate, S(s).nJoyBreak];
end
% Normalize to rates
errRates = errData ./ [S.nTrials]';
hb = bar(1:nSessions, errRates, 'stacked');
for e = 1:4, hb(e).FaceColor = errColors(e,:); hb(e).EdgeColor = 'none'; hb(e).FaceAlpha = 0.8; end
legend({'FixBreak', 'NoResp', 'Inaccurate', 'JoyBreak'}, 'Box', 'off', 'FontSize', 8);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', 'FontSize', 9);
ylabel('Error Rate');

% Panel B: No-response rate comparison (response window effect)
ax6b = subplot(1,3,2); hold on;
title('No-Response Rate', 'FontSize', 11, 'FontWeight', 'bold');
for s = 1:nSessions
    nrRate = S(s).nNoResp / S(s).nTrials;
    fc = colPrev; if s == iFocal, fc = colFocal; end
    bar(s, nrRate, 0.6, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    text(s, nrRate + 0.005, sprintf('%.0fms', S(s).responseWindow*1000), ...
        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
end
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'FontSize', 9);
ylabel('No-Response Rate');

% Panel C: Feb 20 saccade endpoints
ax6c = subplot(1,3,3); hold on;
title('Feb 20: Saccade Endpoints', 'FontSize', 11, 'FontWeight', 'bold');
axis equal;
mask = f.isSC & f.isDual;
idx = find(mask);
endX = []; endY = []; choiceCol = [];
for iTr = idx
    if isfield(f.p.trData(iTr), 'postSacXY') && ~isempty(f.p.trData(iTr).postSacXY)
        xy = f.p.trData(iTr).postSacXY;
        if length(xy) == 2
            endX(end+1) = xy(1); endY(end+1) = xy(2);
            if f.choseHS(iTr), choiceCol(end+1) = 1; else, choiceCol(end+1) = 2; end
        end
    end
end
if ~isempty(endX)
    hs = (choiceCol == 1);
    scatter(endX(hs), endY(hs), 15, colOrange, 'filled', 'MarkerFaceAlpha', 0.4);
    scatter(endX(~hs), endY(~hs), 15, colBlue, 'filled', 'MarkerFaceAlpha', 0.4);
end
plot(0, 0, '+k', 'MarkerSize', 10, 'LineWidth', 2);
ecc = 10;
for a = [135, 165, -165, -135, 45, 15, -15, -45]
    plot(ecc*cosd(a), ecc*sind(a), 'ko', 'MarkerSize', 8, 'LineWidth', 1.5);
end
xlim([-15 15]); ylim([-15 15]); xlabel('X (deg)'); ylabel('Y (deg)');
set(gca, 'TickDir', 'out', 'FontSize', 9);
legend({'Chose HighSal', 'Chose LowSal'}, 'Box', 'off', 'FontSize', 8, 'Location', 'southeast');

pdfSave(fullfile(outputDir, 'fig06_errors_endpoints.pdf'), fig6);

%% ====================== FIGURE 7: d' AND CROSS-SESSION SUMMARY ======================
fprintf('\n====== FIGURE 7: SENSITIVITY & SUMMARY ======\n');
fig7 = figure('Position', [100 100 1200 450], 'Color', 'w', ...
    'Name', 'Fig7: Summary', 'NumberTitle', 'off');

% Panel A: d' across sessions
ax7a = subplot(1,3,1); hold on;
title('Salience Sensitivity (d'')', 'FontSize', 11, 'FontWeight', 'bold');
dPrime = NaN(1, nSessions);
criterion = NaN(1, nSessions);
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
    nT = sum(mask);
    if nT < 10, continue; end
    hsR = (S(s).hsSide(mask) == 2);
    chR = (S(s).chosenSide(mask) == 2);
    hitRate = sum(chR & hsR) / max(sum(hsR), 1);
    faRate  = sum(chR & ~hsR) / max(sum(~hsR), 1);
    hitRate = max(min(hitRate, 1 - 1/(2*sum(hsR))), 1/(2*sum(hsR)));
    faRate  = max(min(faRate, 1 - 1/(2*sum(~hsR))), 1/(2*sum(~hsR)));
    dPrime(s) = norminv(hitRate) - norminv(faRate);
    criterion(s) = -0.5 * (norminv(hitRate) + norminv(faRate));
end

yyaxis left;
for s = 1:nSessions
    fc = colPrev; if s == iFocal, fc = colFocal; end
    bar(s, dPrime(s), 0.5, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.7);
end
ylabel('d'''); plot([0.5 nSessions+0.5], [0 0], '-', 'Color', colGray);

yyaxis right;
plot(1:nSessions, criterion, '-s', 'Color', colPurple, 'LineWidth', 2, 'MarkerSize', 8, ...
    'MarkerFaceColor', colPurple);
ylabel('Criterion');
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'FontSize', 9);

fprintf('  Feb 20: d''=%.3f, criterion=%.3f\n', dPrime(iFocal), criterion(iFocal));

% Panel B: P(HighReward) across sessions
ax7b = subplot(1,3,2); hold on;
title('P(High Reward) Phases 2-3', 'FontSize', 11, 'FontWeight', 'bold');
for s = 1:nSessions
    mask = S(s).isSC & S(s).isDual & (S(s).phase >= 2);
    nT = sum(mask);
    if nT == 0, continue; end
    if S(s).hasPerTrialReward
        choseHR = (S(s).chosenSide(mask) == S(s).rwdSide(mask));
    else
        ph = S(s).phase(mask); cs = S(s).chosenSide(mask);
        choseHR = (ph == 2 & cs == 2) | (ph == 3 & cs == 1);
    end
    nHR = sum(choseHR); pHR = nHR / nT;
    ci = binomCI(nHR, nT, 0.95);
    fc = colPrev; if s == iFocal, fc = colFocal; end
    bar(s, pHR, 0.6, 'FaceColor', fc, 'EdgeColor', 'none', 'FaceAlpha', 0.8);
    plot([s s], ci, 'k-', 'LineWidth', 1.5);
end
plot([0.5 nSessions+0.5], [0.5 0.5], '--', 'Color', colGray);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'TickDir', 'out', ...
    'XLim', [0.3 nSessions+0.7], 'YLim', [0 1], 'FontSize', 9);
ylabel('P(HighReward)');

% Panel C: Annotation
ax7c = subplot(1,3,3); hold on;
set(gca, 'Visible', 'off'); xlim([0 1]); ylim([0 1]);
text(0.5, 0.95, 'Feb 20 Changes', 'FontSize', 13, 'FontWeight', 'bold', ...
    'HorizontalAlignment', 'center');
annotations = {
    sprintf('Reward ratio: 1.5 (was 1.25)')
    sprintf('Response window: 450ms (was 600ms)')
    sprintf('DeltaT: [-100, +100] (was [-150, +150])')
    ''
    sprintf('Completed trials: %d', f.nGood)
    sprintf('P(Right) Phase 1: %.3f', sum(f.chosenSide(f.isSC & f.isDual & f.phase==1)==2)/max(sum(f.isSC & f.isDual & f.phase==1),1))
    sprintf('No-response rate: %.1f%%', 100*f.nNoResp/f.nTrials)
    sprintf('d'' (salience): %.2f', dPrime(iFocal))
    sprintf('Criterion: %.2f', criterion(iFocal))
    sprintf('DeltaT effect (conflict): %.3f', effectSize(iFocal))
    };
for a = 1:length(annotations)
    fc = [0.2 0.2 0.2]; if a <= 3, fc = colRed; end
    text(0.05, 0.85 - (a-1)*0.085, annotations{a}, 'FontSize', 10, 'Color', fc);
end

pdfSave(fullfile(outputDir, 'fig07_summary.pdf'), fig7);

%% ====================== WRITE REPORT ======================
fprintf('\n====== WRITING REPORT ======\n');
writeReport(outputDir, S, nSessions, iFocal, effectSize, dPrime, criterion);

fprintf('\n====== ANALYSIS COMPLETE ======\n');
fprintf('Output saved to: %s\n', outputDir);

end

%% ==================== HELPER FUNCTIONS ====================

function val = safeField(s, fieldName, default)
    if isfield(s, fieldName), val = s.(fieldName); else, val = default; end
end

function ci = binomCI(k, n, confidence)
    z = norminv(1 - (1-confidence)/2);
    p = k / n;
    denom = 1 + z^2/n;
    center = (p + z^2/(2*n)) / denom;
    halfWidth = z * sqrt((p*(1-p) + z^2/(4*n)) / n) / denom;
    ci = [max(0, center - halfWidth), min(1, center + halfWidth)];
end

function ci = bootCI(data, confidence)
    nBoot = 1000; n = length(data);
    bootMedians = NaN(nBoot, 1);
    for b = 1:nBoot, bootMedians(b) = median(data(randi(n, n, 1))); end
    alpha = (1 - confidence)/2;
    ci = [quantile(bootMedians, alpha), quantile(bootMedians, 1-alpha)];
end

function pdfSave(fileName, fig)
    set(fig, 'PaperUnits', 'Inches', 'PaperSize', fig.Position(3:4)/72);
    set(fig, 'PaperUnits', 'Normalized', 'PaperPosition', [0 0 1 1]);
    exportgraphics(fig, fileName, 'Resolution', 300, 'ContentType', 'image');
    fprintf('  Saved: %s\n', fileName);
end

function writeReport(outputDir, S, nSessions, iFocal, effectSize, dPrime, criterion)
    f = S(iFocal);
    fid = fopen(fullfile(outputDir, 'feb20_analysis_report.md'), 'w');

    fprintf(fid, '# Conflict Task Analysis: Feb 20, 2026 Session\n\n');
    fprintf(fid, '**Date:** 2026-02-23\n');
    fprintf(fid, '**Session:** 20260220_t1023_conflict_task\n');
    fprintf(fid, '**Parameter changes:** rewardRatioBig=1.5, responseWindow=0.45s, deltaT=[-100,+100]ms\n\n');
    fprintf(fid, '---\n\n');

    % Parameter table
    fprintf(fid, '## 1. Session Parameters\n\n');
    fprintf(fid, '| Parameter | Previous (Feb 18) | **Feb 20** |\n');
    fprintf(fid, '|-----------|:-:|:-:|\n');
    fprintf(fid, '| Reward Ratio | %.2f | **%.2f** |\n', S(iFocal-1).rewardRatioBig, f.rewardRatioBig);
    fprintf(fid, '| Response Window | %.2f s | **%.2f s** |\n', S(iFocal-1).responseWindow, f.responseWindow);
    dtPrev = S(iFocal-1).deltaTValues;
    dtCurr = f.deltaTValues;
    fprintf(fid, '| DeltaT Values | [%d, %d] ms | **[%d, %d] ms** |\n', dtPrev(1), dtPrev(end), dtCurr(1), dtCurr(end));
    fprintf(fid, '| Total Trials | %d | **%d** |\n', S(iFocal-1).nTrials, f.nTrials);
    fprintf(fid, '| Completed Trials | %d | **%d** |\n', S(iFocal-1).nGood, f.nGood);
    fprintf(fid, '\n');

    % Rightward bias
    pRightFocal = sum(f.chosenSide(f.isSC & f.isDual & f.phase==1)==2) / max(sum(f.isSC & f.isDual & f.phase==1),1);
    pRightPrev = sum(S(iFocal-1).chosenSide(S(iFocal-1).isSC & S(iFocal-1).isDual & S(iFocal-1).phase==1)==2) / ...
        max(sum(S(iFocal-1).isSC & S(iFocal-1).isDual & S(iFocal-1).phase==1),1);

    fprintf(fid, '## 2. Rightward Bias (Phase 1)\n\n');
    fprintf(fid, '| Session | P(Right) | Reward Ratio |\n');
    fprintf(fid, '|---------|:-:|:-:|\n');
    for s = 1:nSessions
        mask = S(s).isSC & S(s).isDual & (S(s).phase == 1);
        pR = sum(S(s).chosenSide(mask)==2)/max(sum(mask),1);
        marker = ''; if s == iFocal, marker = ' **'; end
        fprintf(fid, '| %s%s%s | %.3f | %.2f |\n', marker, S(s).label, marker, pR, S(s).rewardRatioBig);
    end
    fprintf(fid, '\n');
    if pRightFocal > 0.55
        fprintf(fid, 'Feb 20 shows a rightward bias (P=%.3f). ', pRightFocal);
    elseif pRightFocal < 0.45
        fprintf(fid, 'Feb 20 shows a leftward bias (P=%.3f). ', pRightFocal);
    else
        fprintf(fid, 'Feb 20 shows approximately unbiased choices (P=%.3f). ', pRightFocal);
    end
    fprintf(fid, 'Compared to Feb 18 (P=%.3f, R=1.25), the increase to R=1.5 ', pRightPrev);
    if abs(pRightFocal - 0.5) < abs(pRightPrev - 0.5)
        fprintf(fid, 'REDUCED the spatial bias.\n\n');
    else
        fprintf(fid, 'did NOT reduce the spatial bias.\n\n');
    end

    % Delta-T effect
    fprintf(fid, '## 3. Delta-T Effect (Gap vs Overlap)\n\n');
    fprintf(fid, '| Session | Effect (Gap - Overlap) | DeltaT Values |\n');
    fprintf(fid, '|---------|:-:|:-:|\n');
    for s = 1:nSessions
        marker = ''; if s == iFocal, marker = ' **'; end
        dtV = S(s).deltaTValues;
        fprintf(fid, '| %s%s%s | %.3f | [%d, %d] |\n', marker, S(s).label, marker, effectSize(s), dtV(1), dtV(end));
    end
    fprintf(fid, '\n');
    if abs(effectSize(iFocal)) < 0.05
        fprintf(fid, 'The delta-T effect remains negligible (%.3f) with the new [-100, +100]ms values.\n\n', effectSize(iFocal));
    elseif effectSize(iFocal) > 0.05
        fprintf(fid, 'There is a positive delta-T effect (%.3f): gap trials show MORE saliency capture.\n\n', effectSize(iFocal));
    else
        fprintf(fid, 'There is a negative delta-T effect (%.3f): unexpected direction.\n\n', effectSize(iFocal));
    end

    % d' and criterion
    fprintf(fid, '## 4. Salience Sensitivity\n\n');
    fprintf(fid, '| Session | d'' | Criterion |\n');
    fprintf(fid, '|---------|:-:|:-:|\n');
    for s = 1:nSessions
        marker = ''; if s == iFocal, marker = ' **'; end
        fprintf(fid, '| %s%s%s | %.3f | %.3f |\n', marker, S(s).label, marker, dPrime(s), criterion(s));
    end
    fprintf(fid, '\n');

    % Error rates
    fprintf(fid, '## 5. Error Rates (Response Window Effect)\n\n');
    fprintf(fid, '| Session | Response Window | No-Response Rate | Total Error Rate |\n');
    fprintf(fid, '|---------|:-:|:-:|:-:|\n');
    for s = 1:nSessions
        marker = ''; if s == iFocal, marker = ' **'; end
        nrRate = S(s).nNoResp / S(s).nTrials;
        totErr = (S(s).nFixBreak + S(s).nNoResp + S(s).nInaccurate + S(s).nJoyBreak) / S(s).nTrials;
        fprintf(fid, '| %s%s%s | %.0f ms | %.1f%% | %.1f%% |\n', marker, S(s).label, marker, ...
            S(s).responseWindow*1000, nrRate*100, totErr*100);
    end
    fprintf(fid, '\n');
    nrFocal = f.nNoResp / f.nTrials;
    nrPrev = S(iFocal-1).nNoResp / S(iFocal-1).nTrials;
    if nrFocal > nrPrev + 0.02
        fprintf(fid, 'The shorter response window (450ms vs 600ms) increased the no-response rate from %.1f%% to %.1f%%.\n\n', nrPrev*100, nrFocal*100);
    else
        fprintf(fid, 'The shorter response window (450ms vs 600ms) did NOT meaningfully increase the no-response rate.\n\n');
    end

    % Median RT
    fprintf(fid, '## 6. Reaction Times\n\n');
    fprintf(fid, '| Session | Median SRT (ms) | Response Window |\n');
    fprintf(fid, '|---------|:-:|:-:|\n');
    for s = 1:nSessions
        marker = ''; if s == iFocal, marker = ' **'; end
        rts = S(s).srt(S(s).isSC & S(s).isDual); rts = rts(~isnan(rts));
        if ~isempty(rts)
            fprintf(fid, '| %s%s%s | %.0f | %.0f ms |\n', marker, S(s).label, marker, median(rts), S(s).responseWindow*1000);
        end
    end
    fprintf(fid, '\n');

    % Figures
    fprintf(fid, '## Figures\n\n');
    fprintf(fid, '| Figure | Description |\n');
    fprintf(fid, '|--------|-------------|\n');
    fprintf(fid, '| fig01_parameters.pdf | Parameter comparison across all sessions |\n');
    fprintf(fid, '| fig02_rightward_bias.pdf | Phase 1 rightward bias analysis |\n');
    fprintf(fid, '| fig03_reward_vs_saliency.pdf | Reward vs saliency (6 panels) |\n');
    fprintf(fid, '| fig04_reaction_times.pdf | RT distributions and tachometric functions |\n');
    fprintf(fid, '| fig05_learning.pdf | Learning curves and session evolution |\n');
    fprintf(fid, '| fig06_errors_endpoints.pdf | Error rates and saccade endpoints |\n');
    fprintf(fid, '| fig07_summary.pdf | d'', P(HighReward), and summary dashboard |\n');

    fclose(fid);
    fprintf('  Report saved: %s\n', fullfile(outputDir, 'feb20_analysis_report.md'));
end
