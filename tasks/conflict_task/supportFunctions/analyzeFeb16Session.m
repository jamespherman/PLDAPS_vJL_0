function analyzeFeb16Session()
%   analyzeFeb16Session()
%
% Detailed analysis of the Feb 16 conflict task session — the session with
% the best behavioral profile (d'=1.399, criterion=0.025). Generates
% overview, tachometric, and sequential-effects figures.
%
% Output: PDF figures and console stats saved to output/analysis/feb16/

%% ====================== SETUP ======================
pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
outputDir  = fullfile(pldapsHome, 'output', 'analysis', 'feb16');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

% Colors
colOrange  = [0.850 0.325 0.098];
colBlue    = [0.000 0.447 0.741];
colGreen   = [0.466 0.674 0.188];
colPurple  = [0.494 0.184 0.556];
colRed     = [0.80 0.15 0.15];
colGray    = [0.5 0.5 0.5];
colLightGray = [0.85 0.85 0.85];

%% ====================== LOAD DATA ======================
fprintf('\n====== LOADING FEB 16 SESSION ======\n');
fpath = fullfile(pldapsHome, 'output', '20260216_t0837_conflict_task.mat');
data = load(fpath);
if isfield(data, 'p'), p = data.p; else, p = data; end
nTrials = length(p.trData);
fprintf('  Total trials: %d\n', nTrials);

% State codes
sacCompleteState = p.state.sacComplete;
fixBreakState    = p.state.fixBreak;
noRespState      = p.state.noResponse;
inaccState       = p.state.inaccurate;

%% ====================== EXTRACT PER-TRIAL DATA ======================
phase      = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
dt         = arrayfun(@(x) x.deltaT, p.trVars(:)');
hsSide     = arrayfun(@(x) x.highSalienceSide, p.trVars(:)');
endState   = arrayfun(@(x) x.trialEndState, p.trData(:)');
respWin    = arrayfun(@(x) x.responseWindow, p.trVars(:)');

if isfield(p.trVars, 'rewardBigSide')
    rwdSide = arrayfun(@(x) x.rewardBigSide, p.trVars(:)');
else
    rwdSide = ones(1, nTrials);
    rwdSide(phase == 2) = 2; rwdSide(phase == 3) = 1; rwdSide(phase == 1) = 0;
end

if isfield(p.trVars, 'singleStimSide')
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

choseHS = zeros(1, nTrials);
if isfield(p.trData, 'choseHighSalience')
    for iTr = 1:nTrials
        val = p.trData(iTr).choseHighSalience;
        if ~isempty(val), choseHS(iTr) = double(val); end
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

% Derived indices
isSC   = (endState == sacCompleteState);
isDual = (singleStim == 0);
isFB   = (endState == fixBreakState);
isNR   = (endState == noRespState);
isIA   = (endState == inaccState);
choseRight = (chosenSide == 2);

% Phase-specific masks
p1mask = (phase == 1) & isDual & isSC;
p2mask = (phase == 2) & isDual & isSC;
p3mask = (phase == 3) & isDual & isSC;
p23mask = (phase >= 2) & isDual & isSC;

% DeltaT conditions
dtValues = unique(dt(p23mask & ~isnan(dt)));
fprintf('  DeltaT values:     [%s] ms\n', strjoin(arrayfun(@(x) sprintf('%d', x), dtValues, 'UniformOutput', false), ', '));
fprintf('  Response window:   %.2f s\n', mode(respWin));

% Completed trial counts
nGood = sum(isSC);
nGoodP1 = sum(p1mask);
nGoodP2 = sum(p2mask);
nGoodP3 = sum(p3mask);
nSingleStim = sum(isSC & (singleStim > 0));
fprintf('  Completed:         %d (P1 dual=%d, P2=%d, P3=%d, single-stim=%d)\n', ...
    nGood, nGoodP1, nGoodP2, nGoodP3, nSingleStim);

%% ====================== BASIC STATS ======================
fprintf('\n====== BASIC BEHAVIORAL STATS ======\n');

% Phase 1 bias
pRight_P1 = mean(choseRight(p1mask));
nP1 = sum(p1mask);
[ciLo_P1, ciHi_P1] = binomCI(sum(choseRight(p1mask)), nP1);
fprintf('  Phase 1 P(Right):  %.3f [%.3f, %.3f] (n=%d)\n', pRight_P1, ciLo_P1, ciHi_P1, nP1);

% Phase 2 P(Right)
pRight_P2 = mean(choseRight(p2mask));
fprintf('  Phase 2 P(Right):  %.3f (n=%d)\n', pRight_P2, sum(p2mask));

% Phase 3 P(Right)
pRight_P3 = mean(choseRight(p3mask));
fprintf('  Phase 3 P(Right):  %.3f (n=%d)\n', pRight_P3, sum(p3mask));

% Overall salience sensitivity
pHS_all = mean(choseHS(p23mask));
fprintf('  P2-3 P(HighSal):   %.3f (n=%d)\n', pHS_all, sum(p23mask));

% Signal detection
hsRight = p23mask & (hsSide == 2);
hsLeft  = p23mask & (hsSide == 1);
hitRate  = mean(choseHS(hsRight));   % chose HS when HS=right = chose right when HS=right
faRate   = 1 - mean(choseHS(hsLeft)); % chose right when HS=left (false alarm)
hitRate  = max(min(hitRate, 1 - 1/(2*sum(hsRight))), 1/(2*sum(hsRight)));
faRate   = max(min(faRate,  1 - 1/(2*sum(hsLeft))),  1/(2*sum(hsLeft)));
dprime   = norminv(hitRate) - norminv(faRate);
criterion = -0.5 * (norminv(hitRate) + norminv(faRate));
fprintf('  d'':               %.3f\n', dprime);
fprintf('  Criterion:         %.3f\n', criterion);

% RT stats
medRT = nanmedian(srt(isSC));
fprintf('  Median SRT:        %.0f ms\n', medRT);

% Error rates
nErrors = sum(isFB) + sum(isNR) + sum(isIA);
fprintf('  Fix breaks:        %d (%.1f%%)\n', sum(isFB), 100*sum(isFB)/nTrials);
fprintf('  No response:       %d (%.1f%%)\n', sum(isNR), 100*sum(isNR)/nTrials);
fprintf('  Inaccurate:        %d (%.1f%%)\n', sum(isIA), 100*sum(isIA)/nTrials);
fprintf('  Total error rate:  %.1f%%\n', 100*nErrors/nTrials);

%% ====================== DELTA-T ANALYSIS ======================
fprintf('\n====== DELTA-T ANALYSIS ======\n');
for dv = dtValues(:)'
    dtMask = p23mask & (dt == dv);
    confMask = dtMask & logical(isConf);
    congMask = dtMask & ~logical(isConf);

    if sum(confMask) > 0
        pHS_conf = mean(choseHS(confMask));
        nConf = sum(confMask);
    else
        pHS_conf = NaN; nConf = 0;
    end
    if sum(congMask) > 0
        pHS_cong = mean(choseHS(congMask));
        nCong = sum(congMask);
    else
        pHS_cong = NaN; nCong = 0;
    end

    fprintf('  deltaT=%+4d: Conflict P(HS)=%.3f (n=%d), Congruent P(HS)=%.3f (n=%d)\n', ...
        dv, pHS_conf, nConf, pHS_cong, nCong);
end

% Gap vs overlap effect
if length(dtValues) == 2
    gapMask = p23mask & logical(isConf) & (dt == max(dtValues));
    ovrMask = p23mask & logical(isConf) & (dt == min(dtValues));
    pHS_gap = mean(choseHS(gapMask));
    pHS_ovr = mean(choseHS(ovrMask));
    dtEffect = pHS_gap - pHS_ovr;
    fprintf('  Delta-T effect (gap-overlap) in conflict: %.3f\n', dtEffect);
end

%% ====================== REWARD TRACKING ======================
fprintf('\n====== REWARD TRACKING (P2-3) ======\n');
% P(chose high-reward)
choseHR = NaN(1, nTrials);
for iTr = 1:nTrials
    if isSC(iTr) && isDual(iTr) && phase(iTr) >= 2 && rwdSide(iTr) > 0
        choseHR(iTr) = double(chosenSide(iTr) == rwdSide(iTr));
    end
end
pHR_P2 = nanmean(choseHR(p2mask));
pHR_P3 = nanmean(choseHR(p3mask));
pHR_all = nanmean(choseHR(p23mask));
fprintf('  P(HighReward) Phase 2: %.3f (n=%d)\n', pHR_P2, sum(p2mask));
fprintf('  P(HighReward) Phase 3: %.3f (n=%d)\n', pHR_P3, sum(p3mask));
fprintf('  P(HighReward) P2-3:    %.3f (n=%d)\n', pHR_all, sum(p23mask));

% Conflict vs congruent reward tracking
confP23 = p23mask & logical(isConf);
congP23 = p23mask & ~logical(isConf);
pHR_conf = nanmean(choseHR(confP23));
pHR_cong = nanmean(choseHR(congP23));
fprintf('  P(HighReward) conflict:   %.3f (n=%d)\n', pHR_conf, sum(confP23));
fprintf('  P(HighReward) congruent:  %.3f (n=%d)\n', pHR_cong, sum(congP23));

%% ====================== PHASE 1 DETAILED ======================
fprintf('\n====== PHASE 1 DETAILED ======\n');
% By high-salience side
p1_hsR = p1mask & (hsSide == 2);
p1_hsL = p1mask & (hsSide == 1);
fprintf('  HS-Right: P(Right)=%.3f, P(HS)=%.3f (n=%d)\n', ...
    mean(choseRight(p1_hsR)), mean(choseHS(p1_hsR)), sum(p1_hsR));
fprintf('  HS-Left:  P(Right)=%.3f, P(HS)=%.3f (n=%d)\n', ...
    mean(choseRight(p1_hsL)), mean(choseHS(p1_hsL)), sum(p1_hsL));

% By deltaT
for dv = dtValues(:)'
    dtM = p1mask & (dt == dv);
    if sum(dtM) > 0
        fprintf('  DeltaT=%+4d: P(Right)=%.3f, P(HS)=%.3f, medRT=%.0fms (n=%d)\n', ...
            dv, mean(choseRight(dtM)), mean(choseHS(dtM)), nanmedian(srt(dtM)), sum(dtM));
    end
end

% By reward big side in Phase 1
if any(rwdSide(p1mask) == 1) && any(rwdSide(p1mask) == 2)
    p1_rwdR = p1mask & (rwdSide == 2);
    p1_rwdL = p1mask & (rwdSide == 1);
    fprintf('  Rwd-Right: P(Right)=%.3f (n=%d)\n', mean(choseRight(p1_rwdR)), sum(p1_rwdR));
    fprintf('  Rwd-Left:  P(Right)=%.3f (n=%d)\n', mean(choseRight(p1_rwdL)), sum(p1_rwdL));
end

%% ====================== RT BY CONDITION ======================
fprintf('\n====== RT BY CONDITION ======\n');
% Phase 1
fprintf('  Phase 1 median RT:  %.0f ms (n=%d)\n', nanmedian(srt(p1mask)), sum(p1mask));
fprintf('  Phase 2 median RT:  %.0f ms (n=%d)\n', nanmedian(srt(p2mask)), sum(p2mask));
fprintf('  Phase 3 median RT:  %.0f ms (n=%d)\n', nanmedian(srt(p3mask)), sum(p3mask));

% By choice x salience in P2-3
choseHS_p23 = p23mask & logical(choseHS);
choseLS_p23 = p23mask & ~logical(choseHS);
fprintf('  P2-3 Chose HS: medRT=%.0fms (n=%d)\n', nanmedian(srt(choseHS_p23)), sum(choseHS_p23));
fprintf('  P2-3 Chose LS: medRT=%.0fms (n=%d)\n', nanmedian(srt(choseLS_p23)), sum(choseLS_p23));

% By conflict x choice
choseHR_conf = confP23 & ~isnan(choseHR) & (choseHR == 1);
choseHS_conf = confP23 & logical(choseHS); % in conflict: choseHS = chose low reward
fprintf('  Conflict, chose HR: medRT=%.0fms (n=%d)\n', nanmedian(srt(choseHR_conf)), sum(choseHR_conf));
fprintf('  Conflict, chose HS: medRT=%.0fms (n=%d)\n', nanmedian(srt(choseHS_conf)), sum(choseHS_conf));

%% ====================== SEQUENTIAL EFFECTS ======================
fprintf('\n====== SEQUENTIAL EFFECTS ======\n');
% Win-stay: after correct sacComplete, probability of repeating same side
stayCount = 0; stayTotal = 0;
switchCount = 0; switchTotal = 0;
for iTr = 2:nTrials
    if isSC(iTr-1) && isSC(iTr) && ~isnan(chosenSide(iTr-1)) && ~isnan(chosenSide(iTr))
        if chosenSide(iTr) == chosenSide(iTr-1)
            stayCount = stayCount + 1;
        end
        stayTotal = stayTotal + 1;
    end
end
if stayTotal > 0
    pStay = stayCount / stayTotal;
    fprintf('  P(stay | prev correct): %.3f (n=%d)\n', pStay, stayTotal);
end

% By previous reward side
stayCountR = 0; stayTotalR = 0;
stayCountL = 0; stayTotalL = 0;
for iTr = 2:nTrials
    if isSC(iTr-1) && isSC(iTr) && ~isnan(chosenSide(iTr-1)) && ~isnan(chosenSide(iTr))
        if chosenSide(iTr-1) == 2  % prev chose right
            stayTotalR = stayTotalR + 1;
            if chosenSide(iTr) == 2, stayCountR = stayCountR + 1; end
        else  % prev chose left
            stayTotalL = stayTotalL + 1;
            if chosenSide(iTr) == 1, stayCountL = stayCountL + 1; end
        end
    end
end
if stayTotalR > 0
    fprintf('  P(stay | prev right): %.3f (n=%d)\n', stayCountR/stayTotalR, stayTotalR);
end
if stayTotalL > 0
    fprintf('  P(stay | prev left):  %.3f (n=%d)\n', stayCountL/stayTotalL, stayTotalL);
end

%% ====================== FIGURE 1: OVERVIEW (6 panels) ======================
fprintf('\n====== GENERATING FIGURE 1: OVERVIEW ======\n');
fig1 = figure('Position', [50 50 1400 900], 'Color', 'w', ...
    'Name', 'Feb16 Overview', 'NumberTitle', 'off');

% --- Panel 1: P(Right) by phase ---
ax1 = subplot(2, 3, 1);
pR = [pRight_P1, pRight_P2, pRight_P3];
bar(1:3, pR, 0.6, 'FaceColor', colBlue, 'EdgeColor', 'none');
hold on;
yline(0.5, 'k--', 'LineWidth', 1);
% CIs
for ph = 1:3
    if ph == 1, mask = p1mask; elseif ph == 2, mask = p2mask; else, mask = p3mask; end
    [clo, chi] = binomCI(sum(choseRight(mask)), sum(mask));
    errorbar(ph, pR(ph), pR(ph)-clo, chi-pR(ph), 'k', 'LineWidth', 1.5, 'CapSize', 8);
end
set(gca, 'XTick', 1:3, 'XTickLabel', {'Phase 1', 'Phase 2', 'Phase 3'});
ylabel('P(Right)');
title('Spatial Bias by Phase', 'FontWeight', 'bold');
ylim([0 1]);
box off;

% --- Panel 2: P(HighSal) conflict vs congruent by phase ---
ax2 = subplot(2, 3, 2);
% Compute per-phase
pHS_conf_p2 = NaN; pHS_cong_p2 = NaN;
pHS_conf_p3 = NaN; pHS_cong_p3 = NaN;
m2c = p2mask & logical(isConf); m2g = p2mask & ~logical(isConf);
m3c = p3mask & logical(isConf); m3g = p3mask & ~logical(isConf);
if sum(m2c)>0, pHS_conf_p2 = mean(choseHS(m2c)); end
if sum(m2g)>0, pHS_cong_p2 = mean(choseHS(m2g)); end
if sum(m3c)>0, pHS_conf_p3 = mean(choseHS(m3c)); end
if sum(m3g)>0, pHS_cong_p3 = mean(choseHS(m3g)); end

barData = [pHS_conf_p2, pHS_cong_p2; pHS_conf_p3, pHS_cong_p3];
hb = bar([2 3], barData, 0.8);
hb(1).FaceColor = colRed;   hb(1).EdgeColor = 'none';
hb(2).FaceColor = colGreen; hb(2).EdgeColor = 'none';
hold on;
yline(0.5, 'k--', 'LineWidth', 1);
set(gca, 'XTick', [2 3], 'XTickLabel', {'Phase 2', 'Phase 3'});
ylabel('P(High Salience)');
title('Salience Choice: Conflict vs Congruent', 'FontWeight', 'bold');
legend(hb, {'Conflict', 'Congruent'}, 'Location', 'best', 'Box', 'off');
ylim([0 1]);
box off;

% --- Panel 3: RT distributions by phase ---
ax3 = subplot(2, 3, 3);
edges = 50:25:500;
h1 = histcounts(srt(p1mask), edges);
h2 = histcounts(srt(p2mask), edges);
h3 = histcounts(srt(p3mask), edges);
centers = edges(1:end-1) + diff(edges)/2;
plot(centers, h1/max(h1+eps), '-', 'Color', colBlue, 'LineWidth', 2); hold on;
plot(centers, h2/max(h2+eps), '-', 'Color', colOrange, 'LineWidth', 2);
plot(centers, h3/max(h3+eps), '-', 'Color', colGreen, 'LineWidth', 2);
xline(nanmedian(srt(p1mask)), '--', 'Color', colBlue, 'LineWidth', 1);
xline(nanmedian(srt(p2mask)), '--', 'Color', colOrange, 'LineWidth', 1);
xline(nanmedian(srt(p3mask)), '--', 'Color', colGreen, 'LineWidth', 1);
xlabel('SRT (ms)'); ylabel('Normalized count');
title('RT Distributions by Phase', 'FontWeight', 'bold');
legend({'Phase 1', 'Phase 2', 'Phase 3'}, 'Location', 'best', 'Box', 'off');
xlim([50 500]);
box off;

% --- Panel 4: P(HS) by deltaT (conflict trials only) ---
ax4 = subplot(2, 3, 4);
if length(dtValues) >= 2
    pHS_dt = NaN(1, length(dtValues));
    nDt = NaN(1, length(dtValues));
    for iDt = 1:length(dtValues)
        dtM = p23mask & logical(isConf) & (dt == dtValues(iDt));
        if sum(dtM) > 0
            pHS_dt(iDt) = mean(choseHS(dtM));
            nDt(iDt) = sum(dtM);
        end
    end
    bar(1:length(dtValues), pHS_dt, 0.6, 'FaceColor', colPurple, 'EdgeColor', 'none');
    hold on;
    for iDt = 1:length(dtValues)
        if ~isnan(pHS_dt(iDt))
            [clo, chi] = binomCI(round(pHS_dt(iDt)*nDt(iDt)), nDt(iDt));
            errorbar(iDt, pHS_dt(iDt), pHS_dt(iDt)-clo, chi-pHS_dt(iDt), 'k', 'LineWidth', 1.5, 'CapSize', 8);
        end
    end
    yline(0.5, 'k--', 'LineWidth', 1);
    set(gca, 'XTick', 1:length(dtValues), 'XTickLabel', arrayfun(@(x) sprintf('%+d', x), dtValues, 'UniformOutput', false));
    xlabel('Delta-T (ms)');
end
ylabel('P(High Salience)');
title('Conflict Trials: Salience by DeltaT', 'FontWeight', 'bold');
ylim([0 1]);
box off;

% --- Panel 5: P(HighReward) running average (P2-3) ---
ax5 = subplot(2, 3, 5);
% Get P2-3 trial indices in order
p23trials = find(p23mask);
if ~isempty(p23trials)
    cumHR = cumsum(choseHR(p23trials) == 1) ./ (1:length(p23trials));

    % Also split by conflict/congruent
    confTrials = find(confP23);
    congTrials = find(congP23);
    if ~isempty(confTrials)
        cumHR_conf = cumsum(choseHR(confTrials) == 1) ./ (1:length(confTrials));
        plot(1:length(confTrials), cumHR_conf, '-', 'Color', colRed, 'LineWidth', 1.5); hold on;
    end
    if ~isempty(congTrials)
        cumHR_cong = cumsum(choseHR(congTrials) == 1) ./ (1:length(congTrials));
        plot(1:length(congTrials), cumHR_cong, '-', 'Color', colGreen, 'LineWidth', 1.5); hold on;
    end
    yline(0.5, 'k--', 'LineWidth', 1);

    % Phase boundary
    nP2good = sum(p2mask);
    % Find which trial in the P2-3 sequence corresponds to start of Phase 3
    p2trials = find(p2mask);
    p3trials = find(p3mask);
    if ~isempty(p3trials) && ~isempty(p2trials)
        % For conflict trace: find how many conflict trials are in P2
        nConfP2 = sum(confP23 & (phase == 2));
        nCongP2 = sum(congP23 & (phase == 2));
        xline(nConfP2, ':', 'Color', colRed, 'LineWidth', 1);
        xline(nCongP2, ':', 'Color', colGreen, 'LineWidth', 1);
    end
    xlabel('Trial # (within type)');
    ylabel('Cumulative P(High Reward)');
    title('Reward Learning (P2-3)', 'FontWeight', 'bold');
    legend({'Conflict', 'Congruent'}, 'Location', 'best', 'Box', 'off');
    ylim([0 1]);
end
box off;

% --- Panel 6: Error rate by condition ---
ax6 = subplot(2, 3, 6);
% Error rates by phase
for ph = 1:3
    phMask = (phase == ph);
    nPh = sum(phMask);
    nFB_ph = sum(phMask & isFB);
    nNR_ph = sum(phMask & isNR);
    nIA_ph = sum(phMask & isIA);
    errData(ph,:) = 100 * [nFB_ph, nNR_ph, nIA_ph] / max(nPh, 1);
end
hb2 = bar(1:3, errData, 'stacked');
hb2(1).FaceColor = colOrange; hb2(1).EdgeColor = 'none';
hb2(2).FaceColor = colBlue;   hb2(2).EdgeColor = 'none';
hb2(3).FaceColor = colRed;    hb2(3).EdgeColor = 'none';
set(gca, 'XTick', 1:3, 'XTickLabel', {'Phase 1', 'Phase 2', 'Phase 3'});
ylabel('Error Rate (%)');
title('Error Rates by Phase', 'FontWeight', 'bold');
legend(hb2, {'Fix Break', 'No Response', 'Inaccurate'}, 'Location', 'best', 'Box', 'off');
box off;

sgtitle('Feb 16 Session Overview (R=1.5, \DeltaT=\pm150ms, RW=0.6s)', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig1, fullfile(outputDir, 'fig01_feb16_overview.pdf'));

%% ====================== FIGURE 2: TACHOMETRIC FUNCTION ======================
fprintf('\n====== GENERATING FIGURE 2: TACHOMETRIC FUNCTION ======\n');
fig2 = figure('Position', [50 50 1400 450], 'Color', 'w', ...
    'Name', 'Feb16 Tachometric', 'NumberTitle', 'off');

% RT bins
binEdges = [100 150 200 250 300 400 500];
binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
nBins = length(binCenters);

% --- Panel 1: Tachometric for conflict trials (P2-3) ---
ax1 = subplot(1, 3, 1);
confMask = p23mask & logical(isConf);
pHS_bin = NaN(1, nBins);
n_bin = zeros(1, nBins);
for ib = 1:nBins
    bMask = confMask & (srt >= binEdges(ib)) & (srt < binEdges(ib+1));
    n_bin(ib) = sum(bMask);
    if n_bin(ib) > 2
        pHS_bin(ib) = mean(choseHS(bMask));
    end
end
plot(binCenters, pHS_bin, 'o-', 'Color', colRed, 'LineWidth', 2, 'MarkerSize', 8, ...
    'MarkerFaceColor', colRed);
hold on;
for ib = 1:nBins
    if n_bin(ib) > 2
        [clo, chi] = binomCI(round(pHS_bin(ib)*n_bin(ib)), n_bin(ib));
        errorbar(binCenters(ib), pHS_bin(ib), pHS_bin(ib)-clo, chi-pHS_bin(ib), ...
            'Color', colRed, 'LineWidth', 1, 'CapSize', 6);
    end
end
yline(0.5, 'k--', 'LineWidth', 1);
xlabel('SRT (ms)'); ylabel('P(High Salience)');
title('Tachometric: Conflict Trials', 'FontWeight', 'bold');
ylim([0 1]); xlim([50 500]);
% Add n per bin
for ib = 1:nBins
    if n_bin(ib) > 0
        text(binCenters(ib), 0.05, sprintf('n=%d', n_bin(ib)), ...
            'HorizontalAlignment', 'center', 'FontSize', 7, 'Color', colGray);
    end
end
box off;

% --- Panel 2: Tachometric by deltaT ---
ax2 = subplot(1, 3, 2);
if length(dtValues) >= 2
    colors_dt = {colBlue, colOrange};
    for iDt = 1:length(dtValues)
        dtConfMask = confMask & (dt == dtValues(iDt));
        pHS_dtBin = NaN(1, nBins);
        n_dtBin = zeros(1, nBins);
        for ib = 1:nBins
            bMask = dtConfMask & (srt >= binEdges(ib)) & (srt < binEdges(ib+1));
            n_dtBin(ib) = sum(bMask);
            if n_dtBin(ib) > 1
                pHS_dtBin(ib) = mean(choseHS(bMask));
            end
        end
        plot(binCenters, pHS_dtBin, 'o-', 'Color', colors_dt{iDt}, 'LineWidth', 2, ...
            'MarkerSize', 7, 'MarkerFaceColor', colors_dt{iDt});
        hold on;
    end
    yline(0.5, 'k--', 'LineWidth', 1);
    legend(arrayfun(@(x) sprintf('\\DeltaT=%+dms', x), dtValues, 'UniformOutput', false), ...
        'Location', 'best', 'Box', 'off');
end
xlabel('SRT (ms)'); ylabel('P(High Salience)');
title('Tachometric by DeltaT (Conflict)', 'FontWeight', 'bold');
ylim([0 1]); xlim([50 500]);
box off;

% --- Panel 3: RT distributions for HS vs LS choices in conflict ---
ax3 = subplot(1, 3, 3);
choseHS_conf = confMask & logical(choseHS);
choseLS_conf = confMask & ~logical(choseHS);
edges_rt = 50:25:500;
centers_rt = edges_rt(1:end-1) + diff(edges_rt)/2;

hHS = histcounts(srt(choseHS_conf), edges_rt);
hLS = histcounts(srt(choseLS_conf), edges_rt);
if max(hHS) > 0, hHS = hHS / max(hHS); end
if max(hLS) > 0, hLS = hLS / max(hLS); end

bar(centers_rt, hHS, 1, 'FaceColor', colPurple, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
hold on;
bar(centers_rt, -hLS, 1, 'FaceColor', colGray, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
xlabel('SRT (ms)'); ylabel('Normalized count');
title('RT: Chose HS (up) vs LS (down)', 'FontWeight', 'bold');
legend({'Chose High-Sal', 'Chose Low-Sal'}, 'Location', 'best', 'Box', 'off');
xlim([50 500]);
box off;

sgtitle('Feb 16: Tachometric Analysis', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig2, fullfile(outputDir, 'fig02_feb16_tachometric.pdf'));

%% ====================== FIGURE 3: PHASE 1 DETAIL ======================
fprintf('\n====== GENERATING FIGURE 3: PHASE 1 DETAIL ======\n');
fig3 = figure('Position', [50 50 1200 450], 'Color', 'w', ...
    'Name', 'Feb16 Phase1', 'NumberTitle', 'off');

% --- Panel 1: Running P(Right) in Phase 1 dual-stim ---
ax1 = subplot(1, 3, 1);
p1trials = find(p1mask);
if ~isempty(p1trials)
    windowSize = 15;
    cumRight = cumsum(choseRight(p1trials));
    runRight = NaN(1, length(p1trials));
    for iTr = windowSize:length(p1trials)
        runRight(iTr) = (cumRight(iTr) - cumRight(max(1,iTr-windowSize)+1-1)) / windowSize;
    end
    plot(1:length(p1trials), runRight, '-', 'Color', colBlue, 'LineWidth', 2);
    hold on;
    yline(0.5, 'k--', 'LineWidth', 1);
    xlabel('Trial # (Phase 1 dual-stim)');
    ylabel('Running P(Right)');
    title(sprintf('Phase 1 Running Avg (win=%d)', windowSize), 'FontWeight', 'bold');
    ylim([0 1]);
end
box off;

% --- Panel 2: P(HS) by hsSide and deltaT in Phase 1 ---
ax2 = subplot(1, 3, 2);
condLabels = {};
condVals = [];
ci = 1;
for dv = dtValues(:)'
    for hs = [1 2]
        mask = p1mask & (dt == dv) & (hsSide == hs);
        if sum(mask) > 0
            condVals(ci) = mean(choseHS(mask));
            if hs == 1, sideStr = 'HS-L'; else, sideStr = 'HS-R'; end
            condLabels{ci} = sprintf('%s\n%+dms', sideStr, dv);
            ci = ci + 1;
        end
    end
end
if ~isempty(condVals)
    bar(1:length(condVals), condVals, 0.6, 'FaceColor', colPurple, 'EdgeColor', 'none');
    hold on;
    yline(0.5, 'k--', 'LineWidth', 1);
    set(gca, 'XTick', 1:length(condVals), 'XTickLabel', condLabels, 'FontSize', 8);
    ylabel('P(High Salience)');
    title('Phase 1: P(HS) by Condition', 'FontWeight', 'bold');
    ylim([0 1]);
end
box off;

% --- Panel 3: Phase 1 RT by hsSide ---
ax3 = subplot(1, 3, 3);
rtData = {};
rtLabels = {};
ci = 1;
for hs = [1 2]
    mask = p1mask & (hsSide == hs);
    if sum(mask) > 0
        rtData{ci} = srt(mask);
        if hs == 1, rtLabels{ci} = 'HS-Left'; else, rtLabels{ci} = 'HS-Right'; end
        ci = ci + 1;
    end
end
% Simple box-style with dots
colors_hs = {colBlue, colOrange};
for ci = 1:length(rtData)
    xJitter = ci + 0.15*(rand(1, length(rtData{ci})) - 0.5);
    scatter(xJitter, rtData{ci}, 15, colors_hs{ci}, 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    plot([ci-0.2 ci+0.2], [nanmedian(rtData{ci}) nanmedian(rtData{ci})], '-', ...
        'Color', colors_hs{ci}, 'LineWidth', 3);
    % IQR
    q25 = prctile(rtData{ci}, 25); q75 = prctile(rtData{ci}, 75);
    plot([ci ci], [q25 q75], '-', 'Color', colors_hs{ci}, 'LineWidth', 2);
end
set(gca, 'XTick', 1:length(rtLabels), 'XTickLabel', rtLabels);
ylabel('SRT (ms)');
title('Phase 1: RT by High-Sal Side', 'FontWeight', 'bold');
xlim([0.5 length(rtLabels)+0.5]);
box off;

sgtitle('Feb 16: Phase 1 Detail', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig3, fullfile(outputDir, 'fig03_feb16_phase1_detail.pdf'));

%% ====================== FIGURE 4: REWARD TRACKING DETAIL ======================
fprintf('\n====== GENERATING FIGURE 4: REWARD TRACKING DETAIL ======\n');
fig4 = figure('Position', [50 50 1200 450], 'Color', 'w', ...
    'Name', 'Feb16 Reward', 'NumberTitle', 'off');

% --- Panel 1: P(HighReward) by deltaT x conflict ---
ax1 = subplot(1, 3, 1);
barVals = [];
barLabels = {};
ci = 1;
for dv = dtValues(:)'
    for confType = [1 0]  % 1=conflict, 0=congruent
        mask = p23mask & (dt == dv) & (logical(isConf) == confType);
        if sum(mask) > 0
            barVals(ci) = nanmean(choseHR(mask));
            if confType, typeStr = 'Conf'; else, typeStr = 'Cong'; end
            barLabels{ci} = sprintf('%s\n%+dms', typeStr, dv);
            ci = ci + 1;
        end
    end
end
if ~isempty(barVals)
    colors_bar = repmat([colRed; colGreen], ceil(length(barVals)/2), 1);
    for ci = 1:length(barVals)
        bar(ci, barVals(ci), 0.7, 'FaceColor', colors_bar(ci,:), 'EdgeColor', 'none');
        hold on;
    end
    yline(0.5, 'k--', 'LineWidth', 1);
    set(gca, 'XTick', 1:length(barVals), 'XTickLabel', barLabels, 'FontSize', 8);
    ylabel('P(High Reward)');
    title('P(HR) by DeltaT x Trial Type', 'FontWeight', 'bold');
    ylim([0 1]);
end
box off;

% --- Panel 2: P(HighReward) over time, separate by phase ---
ax2 = subplot(1, 3, 2);
for ph = [2 3]
    phTrials = find(p23mask & (phase == ph));
    if ~isempty(phTrials)
        cumHR_ph = cumsum(choseHR(phTrials) == 1) ./ (1:length(phTrials));
        if ph == 2, col = colOrange; else, col = colGreen; end
        plot(1:length(phTrials), cumHR_ph, '-', 'Color', col, 'LineWidth', 2);
        hold on;
    end
end
yline(0.5, 'k--', 'LineWidth', 1);
xlabel('Trial # (within phase)');
ylabel('Cumulative P(High Reward)');
title('Learning Curve by Phase', 'FontWeight', 'bold');
legend({'Phase 2', 'Phase 3'}, 'Location', 'best', 'Box', 'off');
ylim([0 1]);
box off;

% --- Panel 3: P(Right) over entire session ---
ax3 = subplot(1, 3, 3);
allSC = find(isSC & isDual);
if ~isempty(allSC)
    windowSize = 20;
    cumR = cumsum(choseRight(allSC));
    runR = NaN(1, length(allSC));
    for iTr = windowSize:length(allSC)
        runR(iTr) = (cumR(iTr) - cumR(max(1,iTr-windowSize)+1-1)) / windowSize;
    end

    % Color by phase
    phaseOfTrial = phase(allSC);
    for ph = 1:3
        phIdx = (phaseOfTrial == ph);
        x = 1:length(allSC);
        if ph == 1, col = colBlue; elseif ph == 2, col = colOrange; else, col = colGreen; end
        scatter(x(phIdx), runR(phIdx), 8, col, 'filled', 'MarkerFaceAlpha', 0.6);
        hold on;
    end
    yline(0.5, 'k--', 'LineWidth', 1);

    % Phase boundaries
    phaseTrials = phaseOfTrial;
    for ph = [1 2]
        lastIdx = find(phaseTrials == ph, 1, 'last');
        if ~isempty(lastIdx)
            xline(lastIdx, 'k:', 'LineWidth', 1);
            text(lastIdx, 0.97, sprintf('P%d|P%d', ph, ph+1), 'FontSize', 8, ...
                'HorizontalAlignment', 'center');
        end
    end
    xlabel('Completed dual-stim trial #');
    ylabel(sprintf('Running P(Right) (win=%d)', windowSize));
    title('Full Session P(Right)', 'FontWeight', 'bold');
    ylim([0 1]);
end
box off;

sgtitle('Feb 16: Reward Tracking Detail', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig4, fullfile(outputDir, 'fig04_feb16_reward_tracking.pdf'));

%% ====================== FIGURE 5: SACCADE ENDPOINTS ======================
fprintf('\n====== GENERATING FIGURE 5: SACCADE ENDPOINTS ======\n');
fig5 = figure('Position', [50 50 1200 500], 'Color', 'w', ...
    'Name', 'Feb16 Endpoints', 'NumberTitle', 'off');

% Collect endpoints
sacX = NaN(1, nTrials);
sacY = NaN(1, nTrials);
for iTr = 1:nTrials
    if isSC(iTr) && isfield(p.trData(iTr), 'postSacXY')
        xy = p.trData(iTr).postSacXY;
        if ~isempty(xy) && length(xy) >= 2
            sacX(iTr) = xy(1);
            sacY(iTr) = xy(2);
        end
    end
end

% Phase 1
ax1 = subplot(1, 3, 1);
p1sc = p1mask & ~isnan(sacX);
scatter(sacX(p1sc), sacY(p1sc), 15, colBlue, 'filled', 'MarkerFaceAlpha', 0.4);
hold on;
% Mark chosen HS vs LS
p1_cHS = p1sc & logical(choseHS);
p1_cLS = p1sc & ~logical(choseHS);
% Replot with different colors
cla;
scatter(sacX(p1_cHS), sacY(p1_cHS), 15, colPurple, 'filled', 'MarkerFaceAlpha', 0.5);
hold on;
scatter(sacX(p1_cLS), sacY(p1_cLS), 15, colGray, 'filled', 'MarkerFaceAlpha', 0.3);
xlabel('X (deg)'); ylabel('Y (deg)');
title('Phase 1: Endpoints', 'FontWeight', 'bold');
legend({'Chose HS', 'Chose LS'}, 'Location', 'best', 'Box', 'off', 'FontSize', 7);
axis equal; grid on;
box off;

% Phase 2
ax2 = subplot(1, 3, 2);
p2sc = p2mask & ~isnan(sacX);
p2_cHR = p2sc & (choseHR == 1);
p2_cLR = p2sc & ~(choseHR == 1);
scatter(sacX(p2_cHR), sacY(p2_cHR), 15, colOrange, 'filled', 'MarkerFaceAlpha', 0.5);
hold on;
scatter(sacX(p2_cLR), sacY(p2_cLR), 15, colGray, 'filled', 'MarkerFaceAlpha', 0.3);
xlabel('X (deg)'); ylabel('Y (deg)');
title('Phase 2: Endpoints', 'FontWeight', 'bold');
legend({'Chose HR', 'Chose LR'}, 'Location', 'best', 'Box', 'off', 'FontSize', 7);
axis equal; grid on;
box off;

% Phase 3
ax3 = subplot(1, 3, 3);
p3sc = p3mask & ~isnan(sacX);
p3_cHR = p3sc & (choseHR == 1);
p3_cLR = p3sc & ~(choseHR == 1);
scatter(sacX(p3_cHR), sacY(p3_cHR), 15, colGreen, 'filled', 'MarkerFaceAlpha', 0.5);
hold on;
scatter(sacX(p3_cLR), sacY(p3_cLR), 15, colGray, 'filled', 'MarkerFaceAlpha', 0.3);
xlabel('X (deg)'); ylabel('Y (deg)');
title('Phase 3: Endpoints', 'FontWeight', 'bold');
legend({'Chose HR', 'Chose LR'}, 'Location', 'best', 'Box', 'off', 'FontSize', 7);
axis equal; grid on;
box off;

sgtitle('Feb 16: Saccade Endpoints by Phase', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig5, fullfile(outputDir, 'fig05_feb16_endpoints.pdf'));

%% ====================== FIGURE 6: SEQUENTIAL & TIMING ======================
fprintf('\n====== GENERATING FIGURE 6: SEQUENTIAL & TIMING ======\n');
fig6 = figure('Position', [50 50 1200 450], 'Color', 'w', ...
    'Name', 'Feb16 Sequential', 'NumberTitle', 'off');

% --- Panel 1: RT by conflict status and choice ---
ax1 = subplot(1, 3, 1);
groups = {};
groupLabels = {};
groupColors = {};
ci = 1;

% Conflict: chose HS (=chose LS reward in conflict)
m = confP23 & logical(choseHS);
if sum(m)>0, groups{ci} = srt(m); groupLabels{ci} = 'Conf\nChoseHS'; groupColors{ci} = colPurple; ci=ci+1; end

% Conflict: chose HR (=chose LS salience in conflict)
m = confP23 & ~logical(choseHS);
if sum(m)>0, groups{ci} = srt(m); groupLabels{ci} = 'Conf\nChoseHR'; groupColors{ci} = colRed; ci=ci+1; end

% Congruent
m = congP23;
if sum(m)>0, groups{ci} = srt(m); groupLabels{ci} = 'Cong'; groupColors{ci} = colGreen; ci=ci+1; end

for g = 1:length(groups)
    xJ = g + 0.2*(rand(1,length(groups{g}))-0.5);
    scatter(xJ, groups{g}, 12, groupColors{g}, 'filled', 'MarkerFaceAlpha', 0.3);
    hold on;
    med = nanmedian(groups{g});
    plot([g-0.25 g+0.25], [med med], '-', 'Color', groupColors{g}, 'LineWidth', 3);
    q25 = prctile(groups{g}, 25); q75 = prctile(groups{g}, 75);
    plot([g g], [q25 q75], '-', 'Color', groupColors{g}, 'LineWidth', 2);
end
set(gca, 'XTick', 1:length(groupLabels), 'XTickLabel', groupLabels, 'FontSize', 8);
ylabel('SRT (ms)');
title('RT by Trial Type & Choice', 'FontWeight', 'bold');
box off;

% --- Panel 2: Sequential choice probability ---
ax2 = subplot(1, 3, 2);
% P(chose right on trial t | side chosen on trial t-1)
p23sc = find(p23mask);
pRight_afterR = [];
pRight_afterL = [];
for iT = 2:length(p23sc)
    prevTr = p23sc(iT-1);
    currTr = p23sc(iT);
    if ~isnan(chosenSide(prevTr)) && ~isnan(chosenSide(currTr))
        if chosenSide(prevTr) == 2  % prev right
            pRight_afterR(end+1) = choseRight(currTr);
        else  % prev left
            pRight_afterL(end+1) = choseRight(currTr);
        end
    end
end
prAfterR = mean(pRight_afterR);
prAfterL = mean(pRight_afterL);
bar([1 2], [prAfterR prAfterL], 0.6);
hold on;
colormap([colOrange; colBlue]);
yline(0.5, 'k--', 'LineWidth', 1);
[cloR, chiR] = binomCI(sum(pRight_afterR), length(pRight_afterR));
[cloL, chiL] = binomCI(sum(pRight_afterL), length(pRight_afterL));
errorbar([1 2], [prAfterR prAfterL], [prAfterR-cloR, prAfterL-cloL], [chiR-prAfterR, chiL-prAfterL], ...
    'k', 'LineWidth', 1.5, 'CapSize', 8, 'LineStyle', 'none');
set(gca, 'XTick', [1 2], 'XTickLabel', {'After Right', 'After Left'});
ylabel('P(Right) on next trial');
title('Sequential Effects (P2-3)', 'FontWeight', 'bold');
ylim([0 1]);
text(1, 0.05, sprintf('n=%d', length(pRight_afterR)), 'HorizontalAlignment', 'center', 'FontSize', 8);
text(2, 0.05, sprintf('n=%d', length(pRight_afterL)), 'HorizontalAlignment', 'center', 'FontSize', 8);
box off;

% --- Panel 3: RT across session (time course) ---
ax3 = subplot(1, 3, 3);
allSCidx = find(isSC);
plot(1:length(allSCidx), srt(allSCidx), '.', 'Color', [0.7 0.7 0.7], 'MarkerSize', 4);
hold on;
% Running median
windowRT = 30;
runMed = NaN(1, length(allSCidx));
for iTr = windowRT:length(allSCidx)
    runMed(iTr) = nanmedian(srt(allSCidx(max(1,iTr-windowRT+1):iTr)));
end
plot(1:length(allSCidx), runMed, '-', 'Color', colRed, 'LineWidth', 2);
xlabel('Completed trial #');
ylabel('SRT (ms)');
title(sprintf('RT Time Course (running med, win=%d)', windowRT), 'FontWeight', 'bold');
ylim([0 500]);
box off;

sgtitle('Feb 16: Sequential Effects & Timing', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig6, fullfile(outputDir, 'fig06_feb16_sequential.pdf'));

%% ====================== DONE ======================
fprintf('\n====== DONE ======\n');
fprintf('Figures saved to: %s\n', outputDir);
fprintf('  fig01_feb16_overview.pdf\n');
fprintf('  fig02_feb16_tachometric.pdf\n');
fprintf('  fig03_feb16_phase1_detail.pdf\n');
fprintf('  fig04_feb16_reward_tracking.pdf\n');
fprintf('  fig05_feb16_endpoints.pdf\n');
fprintf('  fig06_feb16_sequential.pdf\n');

close all;
end


%% ====================== HELPER FUNCTIONS ======================

function [ciLo, ciHi] = binomCI(k, n)
    % Wilson score interval
    if n == 0, ciLo = 0; ciHi = 1; return; end
    z = 1.96;
    phat = k / n;
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
