function analyzeFeb23Session()
%   analyzeFeb23Session()
%
% Analyzes the Feb 23 conflict task session (deltaT=[-125,+125],
% rewardRatioBig=1.5, responseWindow=0.45s) with all previous sessions
% as comparison context.
%
% Output: PDF figures and console report saved to output/analysis/feb23/

%% ====================== SETUP ======================
pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
outputDir  = fullfile(pldapsHome, 'output', 'analysis', 'feb23');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

% All sessions (previous + new)
sessionFiles = {
    'output/20260209_t1010_conflict_task.mat'
    'output/20260211_t0929_conflict_task.mat'
    'output/20260213_t1018_conflict_task.mat'
    'output/20260216_t0837_conflict_task.mat'
    'output/20260218_t0934_conflict_task.mat'
    'output/20260220_t1023_conflict_task.mat'
    'output/20260223_t1016_conflict_task.mat'
    };
sessionLabels = {'Feb 9', 'Feb 11', 'Feb 13', 'Feb 16', 'Feb 18', 'Feb 20', 'Feb 23'};
nSessions = length(sessionFiles);
iFocal = nSessions;

% Colors
colOrange  = [0.850 0.325 0.098];
colBlue    = [0.000 0.447 0.741];
colGreen   = [0.466 0.674 0.188];
colPurple  = [0.494 0.184 0.556];
colRed     = [0.80 0.15 0.15];
colGray    = [0.5 0.5 0.5];
colLightGray = [0.85 0.85 0.85];
colPrev    = [0.65 0.65 0.65];
colFocal   = [0.85 0.33 0.10];

%% ====================== LOAD ALL SESSIONS ======================
fprintf('\n====== LOADING ALL SESSIONS ======\n');
S = struct();

for iSess = 1:nSessions
    fpath = fullfile(pldapsHome, sessionFiles{iSess});
    fprintf('Loading %s ... ', sessionLabels{iSess});
    data = load(fpath);
    if isfield(data, 'p'), p = data.p; else, p = data; end
    nTrials = length(p.trData);
    fprintf('%d trials\n', nTrials);

    if isfield(p, 'trVarsInit'), tv0 = p.trVarsInit; else, tv0 = p.trVars(1); end

    S(iSess).label   = sessionLabels{iSess};
    S(iSess).nTrials = nTrials;
    S(iSess).p       = p;
    S(iSess).rewardRatioBig  = safeField(tv0, 'rewardRatioBig', 2.0);
    S(iSess).rewardProbHigh  = safeField(tv0, 'rewardProbHigh', 0.9);

    allRW = arrayfun(@(x) x.responseWindow, p.trVars(:)');
    S(iSess).responseWindow = mode(allRW);

    % Derive deltaTValues from actual per-trial data (P2-3 ground truth)
    allDT = arrayfun(@(x) x.deltaT, p.trVars(:)');
    allPh = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
    p23DT = allDT(allPh >= 2);
    if ~isempty(p23DT)
        S(iSess).deltaTValues = unique(p23DT(~isnan(p23DT)))';
    else
        S(iSess).deltaTValues = unique(allDT(~isnan(allDT)))';
    end

    hasSS = isfield(p.trVars, 'singleStimSide');
    S(iSess).hasSingleStim = hasSS && any(arrayfun(@(x) x.singleStimSide, p.trVars(:)') > 0);
    S(iSess).hasPerTrialReward = isfield(p.trVars, 'rewardBigSide');

    % Per-trial extraction
    sacCompleteState = p.state.sacComplete;
    phase     = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
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
    choseRight = (chosenSide == 2);

    S(iSess).phase      = phase;
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
    S(iSess).choseRight = choseRight;
    S(iSess).endState   = endState;

    % Masks
    p1mask  = (phase == 1) & isDual & isSC;
    p2mask  = (phase == 2) & isDual & isSC;
    p3mask  = (phase == 3) & isDual & isSC;
    p23mask = (phase >= 2) & isDual & isSC;

    S(iSess).p1mask  = p1mask;
    S(iSess).p2mask  = p2mask;
    S(iSess).p3mask  = p3mask;
    S(iSess).p23mask = p23mask;

    % Summary stats
    S(iSess).nGood     = sum(isSC);
    S(iSess).nGoodP1   = sum(p1mask);
    S(iSess).nGoodP2   = sum(p2mask);
    S(iSess).nGoodP3   = sum(p3mask);
    S(iSess).nFixBreak  = sum(endState == p.state.fixBreak);
    S(iSess).nNoResp    = sum(endState == p.state.noResponse);
    S(iSess).nInaccurate= sum(endState == p.state.inaccurate);

    % P(Right) Phase 1
    if sum(p1mask) > 0
        S(iSess).pRightP1 = mean(choseRight(p1mask));
    else
        S(iSess).pRightP1 = NaN;
    end

    % P(HighSal) P2-3
    if sum(p23mask) > 0
        S(iSess).pHS_P23 = mean(choseHighSal(p23mask));
    else
        S(iSess).pHS_P23 = NaN;
    end

    % d' and criterion
    hsRight = p23mask & (hsSide == 2);
    hsLeft  = p23mask & (hsSide == 1);
    if sum(hsRight) > 0 && sum(hsLeft) > 0
        hr = mean(choseHighSal(hsRight));
        fa = 1 - mean(choseHighSal(hsLeft));
        hr = max(min(hr, 1-1/(2*sum(hsRight))), 1/(2*sum(hsRight)));
        fa = max(min(fa, 1-1/(2*sum(hsLeft))),  1/(2*sum(hsLeft)));
        S(iSess).dprime    = norminv(hr) - norminv(fa);
        S(iSess).criterion = -0.5*(norminv(hr) + norminv(fa));
    else
        S(iSess).dprime = NaN; S(iSess).criterion = NaN;
    end

    % Median RT
    S(iSess).medRT = nanmedian(srt(isSC));

    % Delta-T effect in conflict trials
    if length(S(iSess).deltaTValues) >= 2
        confGap = p23mask & logical(isConf) & (dt == max(S(iSess).deltaTValues));
        confOvr = p23mask & logical(isConf) & (dt == min(S(iSess).deltaTValues));
        if sum(confGap)>0 && sum(confOvr)>0
            S(iSess).dtEffect = mean(choseHighSal(confGap)) - mean(choseHighSal(confOvr));
        else
            S(iSess).dtEffect = NaN;
        end
    else
        S(iSess).dtEffect = NaN;
    end
end

%% ====================== FOCAL SESSION SUMMARY ======================
f = S(iFocal);
fprintf('\n====== FEB 23 SESSION SUMMARY ======\n');
fprintf('  Total trials:       %d\n', f.nTrials);
fprintf('  Completed (sacC):   %d\n', f.nGood);
fprintf('  Phase 1 dual-stim:  %d\n', f.nGoodP1);
fprintf('  Phase 2 dual-stim:  %d\n', f.nGoodP2);
fprintf('  Phase 3 dual-stim:  %d\n', f.nGoodP3);
fprintf('  Reward ratio:       %.2f\n', f.rewardRatioBig);
fprintf('  Reward prob:        %.2f\n', f.rewardProbHigh);
fprintf('  Response window:    %.2f s\n', f.responseWindow);
fprintf('  DeltaT values:      [%s]\n', strjoin(arrayfun(@(x) sprintf('%d', x), f.deltaTValues, 'UniformOutput', false), ', '));
fprintf('  Fix breaks:         %d (%.1f%%)\n', f.nFixBreak, 100*f.nFixBreak/f.nTrials);
fprintf('  No response:        %d (%.1f%%)\n', f.nNoResp, 100*f.nNoResp/f.nTrials);
fprintf('  Inaccurate:         %d (%.1f%%)\n', f.nInaccurate, 100*f.nInaccurate/f.nTrials);
fprintf('\n');
fprintf('  P(Right) Phase 1:   %.3f\n', f.pRightP1);
fprintf('  P(HighSal) P2-3:    %.3f\n', f.pHS_P23);
fprintf('  d'':                %.3f\n', f.dprime);
fprintf('  Criterion:          %.3f\n', f.criterion);
fprintf('  Median SRT:         %.0f ms\n', f.medRT);
fprintf('  DeltaT effect:      %.3f\n', f.dtEffect);

%% ====================== CROSS-SESSION COMPARISON TABLE ======================
fprintf('\n====== CROSS-SESSION COMPARISON ======\n');
fprintf('%-8s | %5s | %5s | %6s | %5s | %5s | %6s | %5s | %7s | %5s | %5s\n', ...
    'Session', 'Ratio', 'P(RW)', 'DeltaT', 'RW', 'nGood', 'P(R)P1', 'd''', 'Crit', 'medRT', 'dtEff');
fprintf('%s\n', repmat('-', 1, 95));
for s = 1:nSessions
    dtStr = sprintf('[%s]', strjoin(arrayfun(@(x) sprintf('%d',x), S(s).deltaTValues, 'UniformOutput', false), ','));
    isFoc = (s == iFocal);
    marker = '';
    if isFoc, marker = ' <--'; end
    fprintf('%-8s | %5.2f | %5.2f | %6s | %4.2f | %5d | %6.3f | %5.3f | %7.3f | %5.0f | %5.3f%s\n', ...
        S(s).label, S(s).rewardRatioBig, S(s).rewardProbHigh, dtStr, ...
        S(s).responseWindow, S(s).nGood, S(s).pRightP1, ...
        S(s).dprime, S(s).criterion, S(s).medRT, S(s).dtEffect, marker);
end

%% ====================== FOCAL DEEP DIVE ======================
fp = S(iFocal).p;
fprintf('\n====== PHASE 1 DETAILED (FEB 23) ======\n');
p1m = f.p1mask; p23m = f.p23mask;
p2m = f.p2mask; p3m = f.p3mask;
hs = f.hsSide; cs = f.chosenSide; cr = f.choseRight;
cHS = f.choseHS; srtF = f.srt; dtF = f.dt; isConfF = f.isConf;
rwdF = f.rwdSide;

% Phase 1 by HS side
p1_hsR = p1m & (hs == 2);
p1_hsL = p1m & (hs == 1);
fprintf('  HS-Right: P(Right)=%.3f, P(HS)=%.3f (n=%d)\n', ...
    mean(cr(p1_hsR)), mean(cHS(p1_hsR)), sum(p1_hsR));
fprintf('  HS-Left:  P(Right)=%.3f, P(HS)=%.3f (n=%d)\n', ...
    mean(cr(p1_hsL)), mean(cHS(p1_hsL)), sum(p1_hsL));

% Phase 1 by deltaT
for dv = f.deltaTValues(:)'
    dtM = p1m & (dtF == dv);
    if sum(dtM) > 0
        fprintf('  DeltaT=%+4d: P(Right)=%.3f, P(HS)=%.3f, medRT=%.0fms (n=%d)\n', ...
            dv, mean(cr(dtM)), mean(cHS(dtM)), nanmedian(srtF(dtM)), sum(dtM));
    end
end

% Phase 1 by reward side
if any(rwdF(p1m)==1) && any(rwdF(p1m)==2)
    p1_rwdR = p1m & (rwdF == 2);
    p1_rwdL = p1m & (rwdF == 1);
    fprintf('  Rwd-Right: P(Right)=%.3f (n=%d)\n', mean(cr(p1_rwdR)), sum(p1_rwdR));
    fprintf('  Rwd-Left:  P(Right)=%.3f (n=%d)\n', mean(cr(p1_rwdL)), sum(p1_rwdL));
end

fprintf('\n====== PHASES 2-3 DETAILED (FEB 23) ======\n');
% P(HighSal) by conflict x deltaT
for dv = f.deltaTValues(:)'
    confM = p23m & logical(isConfF) & (dtF == dv);
    congM = p23m & ~logical(isConfF) & (dtF == dv);
    if sum(confM)>0, pConf = mean(cHS(confM)); nConf = sum(confM);
    else, pConf = NaN; nConf = 0; end
    if sum(congM)>0, pCong = mean(cHS(congM)); nCong = sum(congM);
    else, pCong = NaN; nCong = 0; end
    fprintf('  DeltaT=%+4d: Conf P(HS)=%.3f (n=%d), Cong P(HS)=%.3f (n=%d)\n', ...
        dv, pConf, nConf, pCong, nCong);
end

% P(HighReward) tracking
choseHR = NaN(1, f.nTrials);
for iTr = 1:f.nTrials
    if f.isSC(iTr) && f.isDual(iTr) && f.phase(iTr) >= 2 && rwdF(iTr) > 0
        choseHR(iTr) = double(cs(iTr) == rwdF(iTr));
    end
end
confP23 = p23m & logical(isConfF);
congP23 = p23m & ~logical(isConfF);

fprintf('  P(HighReward) P2: %.3f (n=%d)\n', nanmean(choseHR(p2m)), sum(p2m));
fprintf('  P(HighReward) P3: %.3f (n=%d)\n', nanmean(choseHR(p3m)), sum(p3m));
fprintf('  P(HighReward) conflict:   %.3f (n=%d)\n', nanmean(choseHR(confP23)), sum(confP23));
fprintf('  P(HighReward) congruent:  %.3f (n=%d)\n', nanmean(choseHR(congP23)), sum(congP23));

% RT by condition
fprintf('\n====== RT BY CONDITION (FEB 23) ======\n');
fprintf('  Phase 1: %.0fms (n=%d)\n', nanmedian(srtF(p1m)), sum(p1m));
fprintf('  Phase 2: %.0fms (n=%d)\n', nanmedian(srtF(p2m)), sum(p2m));
fprintf('  Phase 3: %.0fms (n=%d)\n', nanmedian(srtF(p3m)), sum(p3m));

choseHS_conf = confP23 & logical(cHS);
choseLS_conf = confP23 & ~logical(cHS);
choseHR_conf = confP23 & (choseHR == 1);
fprintf('  Conflict chose HS: medRT=%.0fms (n=%d)\n', nanmedian(srtF(choseHS_conf)), sum(choseHS_conf));
fprintf('  Conflict chose HR: medRT=%.0fms (n=%d)\n', nanmedian(srtF(choseHR_conf)), sum(choseHR_conf));

% Sequential effects
fprintf('\n====== SEQUENTIAL EFFECTS (FEB 23) ======\n');
pRight_afterR = []; pRight_afterL = [];
p23sc = find(p23m);
for iT = 2:length(p23sc)
    prev = p23sc(iT-1); curr = p23sc(iT);
    if ~isnan(cs(prev)) && ~isnan(cs(curr))
        if cs(prev)==2, pRight_afterR(end+1)=cr(curr);
        else, pRight_afterL(end+1)=cr(curr); end
    end
end
if ~isempty(pRight_afterR), fprintf('  P(Right|prev right): %.3f (n=%d)\n', mean(pRight_afterR), length(pRight_afterR)); end
if ~isempty(pRight_afterL), fprintf('  P(Right|prev left):  %.3f (n=%d)\n', mean(pRight_afterL), length(pRight_afterL)); end

%% ====================== FIGURE 1: CROSS-SESSION OVERVIEW ======================
fprintf('\n====== GENERATING FIGURE 1: CROSS-SESSION OVERVIEW ======\n');
fig1 = figure('Position', [50 50 1400 800], 'Color', 'w', ...
    'Name', 'Fig1: Cross-Session', 'NumberTitle', 'off');

% --- Panel 1: P(Right) Phase 1 across sessions ---
subplot(2,3,1);
vals = [S.pRightP1];
cols = repmat(colPrev, nSessions, 1); cols(iFocal,:) = colFocal;
for s = 1:nSessions
    bar(s, vals(s), 0.6, 'FaceColor', cols(s,:), 'EdgeColor', 'none'); hold on;
end
yline(0.5, 'k--', 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'FontSize', 7);
ylabel('P(Right)'); title('Phase 1 Spatial Bias', 'FontWeight', 'bold');
ylim([0 1]); box off;

% --- Panel 2: d' across sessions ---
subplot(2,3,2);
vals = [S.dprime];
for s = 1:nSessions
    bar(s, vals(s), 0.6, 'FaceColor', cols(s,:), 'EdgeColor', 'none'); hold on;
end
yline(0, 'k--', 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'FontSize', 7);
ylabel('d'''); title('Salience Sensitivity (P2-3)', 'FontWeight', 'bold');
box off;

% --- Panel 3: Criterion across sessions ---
subplot(2,3,3);
vals = [S.criterion];
for s = 1:nSessions
    bar(s, vals(s), 0.6, 'FaceColor', cols(s,:), 'EdgeColor', 'none'); hold on;
end
yline(0, 'k--', 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'FontSize', 7);
ylabel('Criterion'); title('Spatial Bias (P2-3 SDT)', 'FontWeight', 'bold');
box off;

% --- Panel 4: DeltaT effect across sessions ---
subplot(2,3,4);
vals = [S.dtEffect];
for s = 1:nSessions
    bar(s, vals(s), 0.6, 'FaceColor', cols(s,:), 'EdgeColor', 'none'); hold on;
end
yline(0, 'k--', 'LineWidth', 1);
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'FontSize', 7);
ylabel('\Delta P(HS)'); title('DeltaT Effect (gap-overlap)', 'FontWeight', 'bold');
box off;

% --- Panel 5: Median RT across sessions ---
subplot(2,3,5);
vals = [S.medRT];
for s = 1:nSessions
    bar(s, vals(s), 0.6, 'FaceColor', cols(s,:), 'EdgeColor', 'none'); hold on;
end
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'FontSize', 7);
ylabel('Median SRT (ms)'); title('Response Speed', 'FontWeight', 'bold');
box off;

% --- Panel 6: Error rates ---
subplot(2,3,6);
errFB = arrayfun(@(x) 100*x.nFixBreak/x.nTrials, S);
errNR = arrayfun(@(x) 100*x.nNoResp/x.nTrials, S);
errIA = arrayfun(@(x) 100*x.nInaccurate/x.nTrials, S);
hb = bar(1:nSessions, [errFB' errNR' errIA'], 'stacked');
hb(1).FaceColor = colOrange; hb(1).EdgeColor = 'none';
hb(2).FaceColor = colBlue;   hb(2).EdgeColor = 'none';
hb(3).FaceColor = colRed;    hb(3).EdgeColor = 'none';
set(gca, 'XTick', 1:nSessions, 'XTickLabel', sessionLabels, 'FontSize', 7);
ylabel('Error Rate (%)'); title('Error Rates', 'FontWeight', 'bold');
legend(hb, {'Fix Break', 'No Response', 'Inaccurate'}, 'Location', 'best', 'Box', 'off', 'FontSize', 7);
box off;

sgtitle('Cross-Session Comparison (Feb 23 highlighted)', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig1, fullfile(outputDir, 'fig01_cross_session_overview.pdf'));

%% ====================== FIGURE 2: FEB 23 OVERVIEW (6 panels) ======================
fprintf('\n====== GENERATING FIGURE 2: FEB 23 OVERVIEW ======\n');
fig2 = figure('Position', [50 50 1400 900], 'Color', 'w', ...
    'Name', 'Fig2: Feb23 Overview', 'NumberTitle', 'off');

% --- Panel 1: P(Right) by phase ---
subplot(2,3,1);
pR = [f.pRightP1, mean(cr(p2m)), mean(cr(p3m))];
bar(1:3, pR, 0.6, 'FaceColor', colBlue, 'EdgeColor', 'none'); hold on;
yline(0.5, 'k--', 'LineWidth', 1);
masks = {p1m, p2m, p3m};
for ph = 1:3
    [clo, chi] = binomCI(sum(cr(masks{ph})), sum(masks{ph}));
    errorbar(ph, pR(ph), pR(ph)-clo, chi-pR(ph), 'k', 'LineWidth', 1.5, 'CapSize', 8);
end
set(gca, 'XTick', 1:3, 'XTickLabel', {'Phase 1', 'Phase 2', 'Phase 3'});
ylabel('P(Right)'); title('Spatial Bias by Phase', 'FontWeight', 'bold');
ylim([0 1]); box off;

% --- Panel 2: P(HS) conflict vs congruent by phase ---
subplot(2,3,2);
m2c = p2m & logical(isConfF); m2g = p2m & ~logical(isConfF);
m3c = p3m & logical(isConfF); m3g = p3m & ~logical(isConfF);
barData = NaN(2,2);
if sum(m2c)>0, barData(1,1) = mean(cHS(m2c)); end
if sum(m2g)>0, barData(1,2) = mean(cHS(m2g)); end
if sum(m3c)>0, barData(2,1) = mean(cHS(m3c)); end
if sum(m3g)>0, barData(2,2) = mean(cHS(m3g)); end
hb = bar([2 3], barData, 0.8);
hb(1).FaceColor = colRed;   hb(1).EdgeColor = 'none';
hb(2).FaceColor = colGreen; hb(2).EdgeColor = 'none';
hold on; yline(0.5, 'k--', 'LineWidth', 1);
set(gca, 'XTick', [2 3], 'XTickLabel', {'Phase 2', 'Phase 3'});
ylabel('P(High Salience)'); title('Salience: Conflict vs Congruent', 'FontWeight', 'bold');
legend(hb, {'Conflict', 'Congruent'}, 'Location', 'best', 'Box', 'off');
ylim([0 1]); box off;

% --- Panel 3: RT distributions by phase ---
subplot(2,3,3);
edges = 50:25:500;
centers = edges(1:end-1) + diff(edges)/2;
h1 = histcounts(srtF(p1m), edges);
h2 = histcounts(srtF(p2m), edges);
h3 = histcounts(srtF(p3m), edges);
plot(centers, h1/max(max(h1),1), '-', 'Color', colBlue, 'LineWidth', 2); hold on;
plot(centers, h2/max(max(h2),1), '-', 'Color', colOrange, 'LineWidth', 2);
plot(centers, h3/max(max(h3),1), '-', 'Color', colGreen, 'LineWidth', 2);
xlabel('SRT (ms)'); ylabel('Normalized count');
title('RT Distributions', 'FontWeight', 'bold');
legend({'Phase 1', 'Phase 2', 'Phase 3'}, 'Location', 'best', 'Box', 'off');
xlim([50 500]); box off;

% --- Panel 4: P(HS) by deltaT (conflict only) ---
subplot(2,3,4);
dtVals = f.deltaTValues;
pHS_dt = NaN(1, length(dtVals));
nDt = zeros(1, length(dtVals));
for iDt = 1:length(dtVals)
    dtM = p23m & logical(isConfF) & (dtF == dtVals(iDt));
    nDt(iDt) = sum(dtM);
    if nDt(iDt) > 0, pHS_dt(iDt) = mean(cHS(dtM)); end
end
bar(1:length(dtVals), pHS_dt, 0.6, 'FaceColor', colPurple, 'EdgeColor', 'none'); hold on;
for iDt = 1:length(dtVals)
    if nDt(iDt) > 0
        [clo, chi] = binomCI(round(pHS_dt(iDt)*nDt(iDt)), nDt(iDt));
        errorbar(iDt, pHS_dt(iDt), pHS_dt(iDt)-clo, chi-pHS_dt(iDt), 'k', 'LineWidth', 1.5, 'CapSize', 8);
    end
end
yline(0.5, 'k--', 'LineWidth', 1);
set(gca, 'XTick', 1:length(dtVals), 'XTickLabel', arrayfun(@(x) sprintf('%+d', x), dtVals, 'UniformOutput', false));
xlabel('Delta-T (ms)'); ylabel('P(High Salience)');
title('Conflict: Salience by DeltaT', 'FontWeight', 'bold');
ylim([0 1]); box off;

% --- Panel 5: Cumulative P(HighReward) ---
subplot(2,3,5);
confTrials = find(confP23);
congTrials = find(congP23);
if ~isempty(confTrials)
    cumHR_conf = cumsum(choseHR(confTrials)==1) ./ (1:length(confTrials));
    plot(1:length(confTrials), cumHR_conf, '-', 'Color', colRed, 'LineWidth', 1.5); hold on;
end
if ~isempty(congTrials)
    cumHR_cong = cumsum(choseHR(congTrials)==1) ./ (1:length(congTrials));
    plot(1:length(congTrials), cumHR_cong, '-', 'Color', colGreen, 'LineWidth', 1.5); hold on;
end
yline(0.5, 'k--', 'LineWidth', 1);
xlabel('Trial # (within type)'); ylabel('Cumulative P(HR)');
title('Reward Learning (P2-3)', 'FontWeight', 'bold');
legend({'Conflict', 'Congruent'}, 'Location', 'best', 'Box', 'off');
ylim([0 1]); box off;

% --- Panel 6: Error rates by phase ---
subplot(2,3,6);
phaseAll = f.phase; endAll = f.endState;
errData = zeros(3,3);
stCodes = [fp.state.fixBreak, fp.state.noResponse, fp.state.inaccurate];
for ph = 1:3
    phM = (phaseAll == ph);
    nPh = sum(phM);
    for e = 1:3
        errData(ph,e) = 100 * sum(phM & (endAll == stCodes(e))) / max(nPh,1);
    end
end
hb2 = bar(1:3, errData, 'stacked');
hb2(1).FaceColor = colOrange; hb2(1).EdgeColor = 'none';
hb2(2).FaceColor = colBlue;   hb2(2).EdgeColor = 'none';
hb2(3).FaceColor = colRed;    hb2(3).EdgeColor = 'none';
set(gca, 'XTick', 1:3, 'XTickLabel', {'Phase 1', 'Phase 2', 'Phase 3'});
ylabel('Error Rate (%)'); title('Error Rates by Phase', 'FontWeight', 'bold');
legend(hb2, {'Fix Break', 'No Response', 'Inaccurate'}, 'Location', 'best', 'Box', 'off');
box off;

sgtitle('Feb 23 Session Overview (R=1.5, \DeltaT=\pm125ms, RW=0.45s)', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig2, fullfile(outputDir, 'fig02_feb23_overview.pdf'));

%% ====================== FIGURE 3: TACHOMETRIC FUNCTION ======================
fprintf('\n====== GENERATING FIGURE 3: TACHOMETRIC ======\n');
fig3 = figure('Position', [50 50 1400 450], 'Color', 'w', ...
    'Name', 'Fig3: Tachometric', 'NumberTitle', 'off');

binEdges = [100 150 200 250 300 400 500];
binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
nBins = length(binCenters);

% --- Panel 1: Conflict tachometric ---
subplot(1,3,1);
confMask = p23m & logical(isConfF);
pHS_bin = NaN(1, nBins); n_bin = zeros(1, nBins);
for ib = 1:nBins
    bM = confMask & (srtF >= binEdges(ib)) & (srtF < binEdges(ib+1));
    n_bin(ib) = sum(bM);
    if n_bin(ib) > 2, pHS_bin(ib) = mean(cHS(bM)); end
end
plot(binCenters, pHS_bin, 'o-', 'Color', colRed, 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', colRed);
hold on;
for ib = 1:nBins
    if n_bin(ib) > 2
        [clo, chi] = binomCI(round(pHS_bin(ib)*n_bin(ib)), n_bin(ib));
        errorbar(binCenters(ib), pHS_bin(ib), pHS_bin(ib)-clo, chi-pHS_bin(ib), 'Color', colRed, 'LineWidth', 1, 'CapSize', 6);
    end
end
yline(0.5, 'k--', 'LineWidth', 1);
for ib = 1:nBins
    if n_bin(ib)>0, text(binCenters(ib), 0.05, sprintf('n=%d', n_bin(ib)), 'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', colGray); end
end
xlabel('SRT (ms)'); ylabel('P(High Salience)');
title('Tachometric: Conflict Trials', 'FontWeight', 'bold');
ylim([0 1]); xlim([50 500]); box off;

% --- Panel 2: Tachometric by deltaT ---
subplot(1,3,2);
colors_dt = {colBlue, colOrange};
for iDt = 1:length(dtVals)
    dtConfM = confMask & (dtF == dtVals(iDt));
    pHS_dtBin = NaN(1, nBins);
    for ib = 1:nBins
        bM = dtConfM & (srtF >= binEdges(ib)) & (srtF < binEdges(ib+1));
        if sum(bM) > 1, pHS_dtBin(ib) = mean(cHS(bM)); end
    end
    plot(binCenters, pHS_dtBin, 'o-', 'Color', colors_dt{iDt}, 'LineWidth', 2, ...
        'MarkerSize', 7, 'MarkerFaceColor', colors_dt{iDt}); hold on;
end
yline(0.5, 'k--', 'LineWidth', 1);
legend(arrayfun(@(x) sprintf('\\DeltaT=%+dms', x), dtVals, 'UniformOutput', false), ...
    'Location', 'best', 'Box', 'off');
xlabel('SRT (ms)'); ylabel('P(High Salience)');
title('Tachometric by DeltaT', 'FontWeight', 'bold');
ylim([0 1]); xlim([50 500]); box off;

% --- Panel 3: RT histograms: HS vs LS choices in conflict ---
subplot(1,3,3);
choseHS_c = confMask & logical(cHS);
choseLS_c = confMask & ~logical(cHS);
edgesRT = 50:25:500;
centersRT = edgesRT(1:end-1) + diff(edgesRT)/2;
hHS = histcounts(srtF(choseHS_c), edgesRT);
hLS = histcounts(srtF(choseLS_c), edgesRT);
if max(hHS)>0, hHS = hHS/max(hHS); end
if max(hLS)>0, hLS = hLS/max(hLS); end
bar(centersRT, hHS, 1, 'FaceColor', colPurple, 'FaceAlpha', 0.5, 'EdgeColor', 'none'); hold on;
bar(centersRT, -hLS, 1, 'FaceColor', colGray, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
xlabel('SRT (ms)'); ylabel('Normalized count');
title('Conflict RT: HS (up) vs LS (down)', 'FontWeight', 'bold');
legend({'Chose HS', 'Chose LS'}, 'Location', 'best', 'Box', 'off');
xlim([50 500]); box off;

sgtitle('Feb 23: Tachometric Analysis', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig3, fullfile(outputDir, 'fig03_feb23_tachometric.pdf'));

%% ====================== FIGURE 4: PHASE 1 DETAIL ======================
fprintf('\n====== GENERATING FIGURE 4: PHASE 1 DETAIL ======\n');
fig4 = figure('Position', [50 50 1200 450], 'Color', 'w', ...
    'Name', 'Fig4: Phase1', 'NumberTitle', 'off');

% --- Panel 1: Running P(Right) ---
subplot(1,3,1);
p1trials = find(p1m);
if ~isempty(p1trials)
    windowSize = 15;
    cumRight = cumsum(cr(p1trials));
    runRight = NaN(1, length(p1trials));
    for iTr = windowSize:length(p1trials)
        runRight(iTr) = (cumRight(iTr) - cumRight(max(1,iTr-windowSize)+1-1)) / windowSize;
    end
    plot(1:length(p1trials), runRight, '-', 'Color', colBlue, 'LineWidth', 2);
    hold on; yline(0.5, 'k--', 'LineWidth', 1);
    xlabel('Trial # (P1 dual-stim)'); ylabel('Running P(Right)');
    title(sprintf('Phase 1 Running Avg (win=%d)', windowSize), 'FontWeight', 'bold');
    ylim([0 1]);
end
box off;

% --- Panel 2: P(HS) by HS-side and deltaT ---
subplot(1,3,2);
condLabels = {}; condVals = []; ci = 1;
for dv = f.deltaTValues(:)'
    for hs = [1 2]
        mask = p1m & (dtF == dv) & (f.hsSide == hs);
        if sum(mask) > 0
            condVals(ci) = mean(cHS(mask));
            if hs==1, sStr='HS-L'; else, sStr='HS-R'; end
            condLabels{ci} = sprintf('%s\n%+dms', sStr, dv);
            ci = ci + 1;
        end
    end
end
if ~isempty(condVals)
    bar(1:length(condVals), condVals, 0.6, 'FaceColor', colPurple, 'EdgeColor', 'none');
    hold on; yline(0.5, 'k--', 'LineWidth', 1);
    set(gca, 'XTick', 1:length(condVals), 'XTickLabel', condLabels, 'FontSize', 8);
    ylabel('P(High Salience)'); title('P1: P(HS) by Condition', 'FontWeight', 'bold');
    ylim([0 1]);
end
box off;

% --- Panel 3: Phase 1 RT by HS side ---
subplot(1,3,3);
colors_hs = {colBlue, colOrange};
for hs = [1 2]
    mask = p1m & (f.hsSide == hs);
    if sum(mask) > 0
        xJ = hs + 0.15*(rand(1, sum(mask))-0.5);
        scatter(xJ, srtF(mask), 15, colors_hs{hs}, 'filled', 'MarkerFaceAlpha', 0.3); hold on;
        med = nanmedian(srtF(mask));
        plot([hs-0.2 hs+0.2], [med med], '-', 'Color', colors_hs{hs}, 'LineWidth', 3);
        q25 = prctile(srtF(mask), 25); q75 = prctile(srtF(mask), 75);
        plot([hs hs], [q25 q75], '-', 'Color', colors_hs{hs}, 'LineWidth', 2);
    end
end
set(gca, 'XTick', [1 2], 'XTickLabel', {'HS-Left', 'HS-Right'});
ylabel('SRT (ms)'); title('P1: RT by HS Side', 'FontWeight', 'bold');
xlim([0.5 2.5]); box off;

sgtitle('Feb 23: Phase 1 Detail', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig4, fullfile(outputDir, 'fig04_feb23_phase1_detail.pdf'));

%% ====================== FIGURE 5: REWARD & SEQUENTIAL ======================
fprintf('\n====== GENERATING FIGURE 5: REWARD & SEQUENTIAL ======\n');
fig5 = figure('Position', [50 50 1400 450], 'Color', 'w', ...
    'Name', 'Fig5: Reward+Seq', 'NumberTitle', 'off');

% --- Panel 1: P(HR) by deltaT x conflict ---
subplot(1,3,1);
barVals = []; barLabels = {}; barCols = []; ci = 1;
for dv = f.deltaTValues(:)'
    for confType = [1 0]
        mask = p23m & (logical(isConfF)==confType) & (dtF==dv);
        if sum(mask)>0
            barVals(ci) = nanmean(choseHR(mask));
            if confType, tStr='Conf'; else, tStr='Cong'; end
            barLabels{ci} = sprintf('%s\n%+dms', tStr, dv);
            if confType, barCols(ci,:)=colRed; else, barCols(ci,:)=colGreen; end
            ci=ci+1;
        end
    end
end
for ci = 1:length(barVals)
    bar(ci, barVals(ci), 0.7, 'FaceColor', barCols(ci,:), 'EdgeColor', 'none'); hold on;
end
yline(0.5, 'k--', 'LineWidth', 1);
set(gca, 'XTick', 1:length(barVals), 'XTickLabel', barLabels, 'FontSize', 8);
ylabel('P(High Reward)'); title('P(HR) by DeltaT x Type', 'FontWeight', 'bold');
ylim([0 1]); box off;

% --- Panel 2: Sequential effects ---
subplot(1,3,2);
if ~isempty(pRight_afterR) && ~isempty(pRight_afterL)
    prR = mean(pRight_afterR); prL = mean(pRight_afterL);
    bar(1, prR, 0.6, 'FaceColor', colOrange, 'EdgeColor', 'none'); hold on;
    bar(2, prL, 0.6, 'FaceColor', colBlue, 'EdgeColor', 'none');
    [cloR, chiR] = binomCI(sum(pRight_afterR), length(pRight_afterR));
    [cloL, chiL] = binomCI(sum(pRight_afterL), length(pRight_afterL));
    errorbar([1 2], [prR prL], [prR-cloR, prL-cloL], [chiR-prR, chiL-prL], ...
        'k', 'LineWidth', 1.5, 'CapSize', 8, 'LineStyle', 'none');
    yline(0.5, 'k--', 'LineWidth', 1);
    set(gca, 'XTick', [1 2], 'XTickLabel', {'After Right', 'After Left'});
    ylabel('P(Right) next trial'); title('Sequential Effects (P2-3)', 'FontWeight', 'bold');
    ylim([0 1]);
    text(1, 0.05, sprintf('n=%d',length(pRight_afterR)), 'HorizontalAlignment', 'center', 'FontSize', 8);
    text(2, 0.05, sprintf('n=%d',length(pRight_afterL)), 'HorizontalAlignment', 'center', 'FontSize', 8);
end
box off;

% --- Panel 3: Full session P(Right) running average ---
subplot(1,3,3);
allSC = find(f.isSC & f.isDual);
if ~isempty(allSC)
    windowSize = 20;
    cumR = cumsum(cr(allSC));
    runR = NaN(1, length(allSC));
    for iTr = windowSize:length(allSC)
        runR(iTr) = (cumR(iTr) - cumR(max(1,iTr-windowSize)+1-1)) / windowSize;
    end
    phaseOfTrial = f.phase(allSC);
    for ph = 1:3
        phIdx = (phaseOfTrial == ph);
        x = 1:length(allSC);
        if ph==1, col=colBlue; elseif ph==2, col=colOrange; else, col=colGreen; end
        scatter(x(phIdx), runR(phIdx), 8, col, 'filled', 'MarkerFaceAlpha', 0.6); hold on;
    end
    yline(0.5, 'k--', 'LineWidth', 1);
    for ph = [1 2]
        lastIdx = find(phaseOfTrial==ph, 1, 'last');
        if ~isempty(lastIdx)
            xline(lastIdx, 'k:', 'LineWidth', 1);
            text(lastIdx, 0.97, sprintf('P%d|P%d', ph, ph+1), 'FontSize', 8, 'HorizontalAlignment', 'center');
        end
    end
    xlabel('Completed dual-stim trial #'); ylabel(sprintf('Running P(Right) (win=%d)', windowSize));
    title('Full Session P(Right)', 'FontWeight', 'bold');
    ylim([0 1]);
end
box off;

sgtitle('Feb 23: Reward Tracking & Sequential Effects', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig5, fullfile(outputDir, 'fig05_feb23_reward_sequential.pdf'));

%% ====================== FIGURE 6: RT DETAIL & ENDPOINTS ======================
fprintf('\n====== GENERATING FIGURE 6: RT & ENDPOINTS ======\n');
fig6 = figure('Position', [50 50 1400 450], 'Color', 'w', ...
    'Name', 'Fig6: RT+Endpoints', 'NumberTitle', 'off');

% --- Panel 1: RT by trial type and choice ---
subplot(1,3,1);
groups = {}; gLabels = {}; gColors = {}; ci = 1;
m = confP23 & logical(cHS);
if sum(m)>0, groups{ci}=srtF(m); gLabels{ci}='Conf\nChoseHS'; gColors{ci}=colPurple; ci=ci+1; end
m = confP23 & ~logical(cHS);
if sum(m)>0, groups{ci}=srtF(m); gLabels{ci}='Conf\nChoseHR'; gColors{ci}=colRed; ci=ci+1; end
m = congP23;
if sum(m)>0, groups{ci}=srtF(m); gLabels{ci}='Cong'; gColors{ci}=colGreen; ci=ci+1; end
for g = 1:length(groups)
    xJ = g + 0.2*(rand(1,length(groups{g}))-0.5);
    scatter(xJ, groups{g}, 12, gColors{g}, 'filled', 'MarkerFaceAlpha', 0.3); hold on;
    med = nanmedian(groups{g});
    plot([g-0.25 g+0.25], [med med], '-', 'Color', gColors{g}, 'LineWidth', 3);
    q25 = prctile(groups{g}, 25); q75 = prctile(groups{g}, 75);
    plot([g g], [q25 q75], '-', 'Color', gColors{g}, 'LineWidth', 2);
end
set(gca, 'XTick', 1:length(gLabels), 'XTickLabel', gLabels, 'FontSize', 8);
ylabel('SRT (ms)'); title('RT by Type & Choice', 'FontWeight', 'bold'); box off;

% --- Panel 2: RT time course ---
subplot(1,3,2);
allSCidx = find(f.isSC);
plot(1:length(allSCidx), srtF(allSCidx), '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 4); hold on;
windowRT = 30;
runMed = NaN(1, length(allSCidx));
for iTr = windowRT:length(allSCidx)
    runMed(iTr) = nanmedian(srtF(allSCidx(max(1,iTr-windowRT+1):iTr)));
end
plot(1:length(allSCidx), runMed, '-', 'Color', colRed, 'LineWidth', 2);
xlabel('Completed trial #'); ylabel('SRT (ms)');
title(sprintf('RT Time Course (win=%d)', windowRT), 'FontWeight', 'bold');
ylim([0 500]); box off;

% --- Panel 3: Saccade endpoints (P2-3, HR vs LR) ---
subplot(1,3,3);
sacX = NaN(1, f.nTrials); sacY = NaN(1, f.nTrials);
for iTr = 1:f.nTrials
    if f.isSC(iTr) && isfield(fp.trData(iTr), 'postSacXY')
        xy = fp.trData(iTr).postSacXY;
        if ~isempty(xy) && length(xy) >= 2
            sacX(iTr) = xy(1); sacY(iTr) = xy(2);
        end
    end
end
p23sc = p23m & ~isnan(sacX);
hrM = p23sc & (choseHR==1);
lrM = p23sc & ~(choseHR==1);
scatter(sacX(hrM), sacY(hrM), 15, colOrange, 'filled', 'MarkerFaceAlpha', 0.4); hold on;
scatter(sacX(lrM), sacY(lrM), 15, colGray, 'filled', 'MarkerFaceAlpha', 0.3);
xlabel('X (deg)'); ylabel('Y (deg)');
title('P2-3 Endpoints: HR vs LR', 'FontWeight', 'bold');
legend({'Chose HR', 'Chose LR'}, 'Location', 'best', 'Box', 'off', 'FontSize', 7);
axis equal; grid on; box off;

sgtitle('Feb 23: RT Detail & Saccade Endpoints', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig6, fullfile(outputDir, 'fig06_feb23_rt_endpoints.pdf'));

%% ====================== FIGURE 7: FEB 16 vs FEB 23 DIRECT COMPARISON ======================
fprintf('\n====== GENERATING FIGURE 7: FEB 16 vs FEB 23 ======\n');
fig7 = figure('Position', [50 50 1400 450], 'Color', 'w', ...
    'Name', 'Fig7: Feb16 vs Feb23', 'NumberTitle', 'off');

i16 = 4; i23 = iFocal;
col16 = [0.30 0.60 0.90];
col23 = colFocal;

% --- Panel 1: P(Right) by phase ---
subplot(1,3,1);
pR16 = [S(i16).pRightP1, mean(S(i16).choseRight(S(i16).p2mask)), mean(S(i16).choseRight(S(i16).p3mask))];
pR23 = [S(i23).pRightP1, mean(S(i23).choseRight(S(i23).p2mask)), mean(S(i23).choseRight(S(i23).p3mask))];
hb = bar([1 2 3], [pR16; pR23]', 0.8);
hb(1).FaceColor = col16; hb(1).EdgeColor = 'none';
hb(2).FaceColor = col23; hb(2).EdgeColor = 'none';
hold on; yline(0.5, 'k--', 'LineWidth', 1);
set(gca, 'XTick', 1:3, 'XTickLabel', {'Phase 1', 'Phase 2', 'Phase 3'});
ylabel('P(Right)'); title('Spatial Bias by Phase', 'FontWeight', 'bold');
legend(hb, {'Feb 16', 'Feb 23'}, 'Location', 'best', 'Box', 'off');
ylim([0 1]); box off;

% --- Panel 2: d' and criterion ---
subplot(1,3,2);
bar([1 2], [S(i16).dprime S(i23).dprime; S(i16).criterion S(i23).criterion]');
hold on; yline(0, 'k--', 'LineWidth', 1);
set(gca, 'XTick', [1 2], 'XTickLabel', {'Feb 16', 'Feb 23'});
legend({'d''', 'Criterion'}, 'Location', 'best', 'Box', 'off');
title('SDT: Salience Sensitivity & Bias', 'FontWeight', 'bold');
box off;

% --- Panel 3: RT distributions ---
subplot(1,3,3);
edges = 50:25:500;
centers = edges(1:end-1) + diff(edges)/2;
h16 = histcounts(S(i16).srt(S(i16).isSC), edges);
h23 = histcounts(S(i23).srt(S(i23).isSC), edges);
plot(centers, h16/max(max(h16),1), '-', 'Color', col16, 'LineWidth', 2); hold on;
plot(centers, h23/max(max(h23),1), '-', 'Color', col23, 'LineWidth', 2);
xline(S(i16).medRT, '--', 'Color', col16, 'LineWidth', 1);
xline(S(i23).medRT, '--', 'Color', col23, 'LineWidth', 1);
xlabel('SRT (ms)'); ylabel('Normalized count');
title('RT Distributions', 'FontWeight', 'bold');
legend({'Feb 16', 'Feb 23'}, 'Location', 'best', 'Box', 'off');
xlim([50 500]); box off;

sgtitle('Feb 16 vs Feb 23 Comparison', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig7, fullfile(outputDir, 'fig07_feb16_vs_feb23.pdf'));

%% ====================== DONE ======================
fprintf('\n====== DONE ======\n');
fprintf('Figures saved to: %s\n', outputDir);
for i = 1:7
    fprintf('  fig%02d_*.pdf\n', i);
end

close all;
end

%% ====================== HELPER FUNCTIONS ======================

function v = safeField(s, fn, def)
    if isfield(s, fn)
        v = s.(fn);
        if isempty(v), v = def; end
    else
        v = def;
    end
end

function [ciLo, ciHi] = binomCI(k, n)
    if n == 0, ciLo = 0; ciHi = 1; return; end
    z = 1.96; phat = k/n;
    denom = 1 + z^2/n;
    center = (phat + z^2/(2*n)) / denom;
    halfwidth = (z * sqrt(phat*(1-phat)/n + z^2/(4*n^2))) / denom;
    ciLo = max(0, center - halfwidth);
    ciHi = min(1, center + halfwidth);
end

function pdfSave(fig, fname)
    try
        exportgraphics(fig, fname, 'ContentType', 'vector');
        fprintf('  Saved: %s\n', fname);
    catch
        print(fig, strrep(fname, '.pdf', ''), '-dpdf', '-bestfit');
        fprintf('  Saved (print): %s\n', fname);
    end
end
