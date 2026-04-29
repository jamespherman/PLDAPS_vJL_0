function analyzeRPT()
%   analyzeRPT()
%
% Computes rPT (raw Processing Time = saccade onset - stimulus onset)
% following Stanford & Salinas, and generates tachometric functions in
% rPT space. This normalizes across deltaT conditions by measuring how
% long the subject had to process the stimulus before responding.
%
%   SRT = saccade onset - fixOff        (traditional)
%   rPT = saccade onset - stimOn        (processing time)
%
% For overlap (deltaT<0): rPT = SRT + |deltaT|  (longer than SRT)
% For gap (deltaT>0):     rPT = SRT - deltaT    (shorter than SRT)
%
% Output: PDF figures to output/analysis/rPT/

%% ====================== SETUP ======================
pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
outputDir  = fullfile(pldapsHome, 'output', 'analysis', 'rPT');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

sessionFiles = {
    'output/20260216_t0837_conflict_task.mat'
    'output/20260220_t1023_conflict_task.mat'
    'output/20260223_t1016_conflict_task.mat'
    };
sessionLabels = {'Feb 16', 'Feb 20', 'Feb 23'};
nSessions = length(sessionFiles);

colSession = [
    0.30 0.60 0.90   % Feb 16 blue
    0.46 0.67 0.19   % Feb 20 green
    0.85 0.33 0.10   % Feb 23 orange
    ];
colOverlap = [0.000 0.447 0.741];  % blue
colGap     = [0.850 0.325 0.098];  % orange
colPurple  = [0.494 0.184 0.556];
colGray    = [0.5 0.5 0.5];
colRed     = [0.80 0.15 0.15];
colGreen   = [0.466 0.674 0.188];

%% ====================== LOAD & EXTRACT ======================
fprintf('\n====== LOADING SESSIONS ======\n');
S = struct();

for iSess = 1:nSessions
    fpath = fullfile(pldapsHome, sessionFiles{iSess});
    fprintf('Loading %s ... ', sessionLabels{iSess});
    data = load(fpath);
    if isfield(data,'p'), p=data.p; else, p=data; end
    nTrials = length(p.trData);
    fprintf('%d trials\n', nTrials);

    sacCompleteState = p.state.sacComplete;
    phase     = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
    dt        = arrayfun(@(x) x.deltaT, p.trVars(:)');
    hsSide    = arrayfun(@(x) x.highSalienceSide, p.trVars(:)');
    endState  = arrayfun(@(x) x.trialEndState, p.trData(:)');

    if isfield(p.trVars, 'singleStimSide')
        singleStim = arrayfun(@(x) x.singleStimSide, p.trVars(:)');
    else
        singleStim = zeros(1, nTrials);
    end

    if isfield(p.trVars, 'rewardBigSide')
        rwdSide = arrayfun(@(x) x.rewardBigSide, p.trVars(:)');
    else
        rwdSide = ones(1, nTrials);
        rwdSide(phase==2) = 2; rwdSide(phase==3) = 1; rwdSide(phase==1) = 0;
    end

    chosenSide = NaN(1, nTrials);
    for iTr = 1:nTrials
        if isfield(p.trData(iTr),'chosenSide') && ~isempty(p.trData(iTr).chosenSide)
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

    % Compute both SRT and rPT
    srt = NaN(1, nTrials);
    rpt = NaN(1, nTrials);
    for iTr = 1:nTrials
        if endState(iTr) == sacCompleteState
            fOff = p.trData(iTr).timing.fixOff;
            sOn  = p.trData(iTr).timing.saccadeOnset;
            stOn = p.trData(iTr).timing.stimOn;
            if fOff > 0 && sOn > 0
                srt(iTr) = (sOn - fOff) * 1000;  % ms
            end
            if stOn > 0 && sOn > 0
                rpt(iTr) = (sOn - stOn) * 1000;  % ms
            end
        end
    end

    % Derive deltaT values from P2-3
    allPh = phase;
    p23DT = dt(allPh >= 2);
    if ~isempty(p23DT)
        dtValues = unique(p23DT(~isnan(p23DT)))';
    else
        dtValues = unique(dt(~isnan(dt)))';
    end

    p1mask  = (phase==1) & isDual & isSC;
    p23mask = (phase>=2) & isDual & isSC;

    S(iSess).label     = sessionLabels{iSess};
    S(iSess).nTrials   = nTrials;
    S(iSess).phase     = phase;
    S(iSess).dt        = dt;
    S(iSess).hsSide    = hsSide;
    S(iSess).rwdSide   = rwdSide;
    S(iSess).choseHS   = choseHS;
    S(iSess).isConf    = isConf;
    S(iSess).isSC      = isSC;
    S(iSess).isDual    = isDual;
    S(iSess).srt       = srt;
    S(iSess).rpt       = rpt;
    S(iSess).p1mask    = p1mask;
    S(iSess).p23mask   = p23mask;
    S(iSess).dtValues  = dtValues;
end

%% ====================== PRINT rPT vs SRT STATS ======================
for iSess = 1:nSessions
    fprintf('\n====== %s: SRT vs rPT ======\n', S(iSess).label);
    dtVals = S(iSess).dtValues;
    for dv = dtVals(:)'
        for maskType = {'p1', 'p23'}
            if strcmp(maskType{1}, 'p1')
                mask = S(iSess).p1mask & (S(iSess).dt == dv);
                lbl = 'Phase1';
            else
                mask = S(iSess).p23mask & (S(iSess).dt == dv);
                lbl = 'P2-3';
            end
            if sum(mask) > 2
                medSRT = nanmedian(S(iSess).srt(mask));
                medRPT = nanmedian(S(iSess).rpt(mask));
                fprintf('  %s dT=%+4d: medSRT=%6.0fms, medRPT=%6.0fms, diff=%+.0fms (n=%d)\n', ...
                    lbl, dv, medSRT, medRPT, medRPT-medSRT, sum(mask));
            end
        end
    end

    % Conflict trials: rPT for HS vs HR choices
    confMask = S(iSess).p23mask & logical(S(iSess).isConf);
    hsChoice = confMask & logical(S(iSess).choseHS);
    hrChoice = confMask & ~logical(S(iSess).choseHS);
    if sum(hsChoice)>0 && sum(hrChoice)>0
        fprintf('  Conflict chose-HS: medSRT=%3.0f, medRPT=%3.0f (n=%d)\n', ...
            nanmedian(S(iSess).srt(hsChoice)), nanmedian(S(iSess).rpt(hsChoice)), sum(hsChoice));
        fprintf('  Conflict chose-HR: medSRT=%3.0f, medRPT=%3.0f (n=%d)\n', ...
            nanmedian(S(iSess).srt(hrChoice)), nanmedian(S(iSess).rpt(hrChoice)), sum(hrChoice));
    end
end

%% ====================== FIGURE 1: SRT vs rPT DISTRIBUTIONS ======================
fprintf('\n====== GENERATING FIGURE 1: SRT vs rPT DISTRIBUTIONS ======\n');
fig1 = figure('Position', [50 50 1400 800], 'Color', 'w', ...
    'Name', 'Fig1: SRT vs rPT', 'NumberTitle', 'off');

for iSess = 1:nSessions
    dtVals = S(iSess).dtValues;
    edges = 0:20:500;
    centers = edges(1:end-1) + diff(edges)/2;

    % SRT by deltaT
    subplot(2, nSessions, iSess);
    for iDt = 1:length(dtVals)
        mask = S(iSess).p23mask & (S(iSess).dt == dtVals(iDt));
        h = histcounts(S(iSess).srt(mask), edges);
        if dtVals(iDt) < 0, col = colOverlap; else, col = colGap; end
        plot(centers, h/max(max(h),1), '-', 'Color', col, 'LineWidth', 2); hold on;
        xline(nanmedian(S(iSess).srt(mask)), '--', 'Color', col, 'LineWidth', 1);
    end
    xlabel('SRT (ms)'); ylabel('Norm. count');
    title(sprintf('%s: SRT', S(iSess).label), 'FontWeight', 'bold');
    legend(arrayfun(@(x) sprintf('\\DeltaT=%+d', x), dtVals, 'UniformOutput', false), ...
        'Location', 'best', 'Box', 'off', 'FontSize', 7);
    xlim([0 500]); box off;

    % rPT by deltaT
    subplot(2, nSessions, nSessions + iSess);
    for iDt = 1:length(dtVals)
        mask = S(iSess).p23mask & (S(iSess).dt == dtVals(iDt));
        h = histcounts(S(iSess).rpt(mask), edges);
        if dtVals(iDt) < 0, col = colOverlap; else, col = colGap; end
        plot(centers, h/max(max(h),1), '-', 'Color', col, 'LineWidth', 2); hold on;
        xline(nanmedian(S(iSess).rpt(mask)), '--', 'Color', col, 'LineWidth', 1);
    end
    xlabel('rPT (ms)'); ylabel('Norm. count');
    title(sprintf('%s: rPT', S(iSess).label), 'FontWeight', 'bold');
    xlim([0 500]); box off;
end

sgtitle({'SRT (top) vs rPT (bottom) Distributions by \DeltaT condition', ...
    'Blue = overlap (\DeltaT<0), Orange = gap (\DeltaT>0)'}, ...
    'FontWeight', 'bold', 'FontSize', 13);
pdfSave(fig1, fullfile(outputDir, 'fig01_srt_vs_rpt_distributions.pdf'));

%% ====================== FIGURE 2: TACHOMETRIC IN SRT vs rPT SPACE ======================
fprintf('\n====== GENERATING FIGURE 2: TACHOMETRIC SRT vs rPT ======\n');
fig2 = figure('Position', [50 50 1400 800], 'Color', 'w', ...
    'Name', 'Fig2: Tachometric', 'NumberTitle', 'off');

binEdges = [50 100 150 200 250 300 400 500];
binCenters = (binEdges(1:end-1) + binEdges(2:end)) / 2;
nBins = length(binCenters);

for iSess = 1:nSessions
    dtVals = S(iSess).dtValues;
    confMask = S(iSess).p23mask & logical(S(iSess).isConf);

    % Tachometric in SRT space
    subplot(2, nSessions, iSess);
    for iDt = 1:length(dtVals)
        dtConfM = confMask & (S(iSess).dt == dtVals(iDt));
        pHS_bin = NaN(1, nBins);
        for ib = 1:nBins
            bM = dtConfM & (S(iSess).srt >= binEdges(ib)) & (S(iSess).srt < binEdges(ib+1));
            if sum(bM) > 2, pHS_bin(ib) = mean(S(iSess).choseHS(bM)); end
        end
        if dtVals(iDt) < 0, col = colOverlap; else, col = colGap; end
        plot(binCenters, pHS_bin, 'o-', 'Color', col, 'LineWidth', 2, ...
            'MarkerSize', 7, 'MarkerFaceColor', col); hold on;
    end
    yline(0.5, 'k--', 'LineWidth', 1);
    xlabel('SRT (ms)'); ylabel('P(High Salience)');
    title(sprintf('%s: SRT tachometric', S(iSess).label), 'FontWeight', 'bold');
    ylim([0 1]); xlim([50 500]); box off;
    if iSess == 1
        legend(arrayfun(@(x) sprintf('\\DeltaT=%+d', x), dtVals, 'UniformOutput', false), ...
            'Location', 'best', 'Box', 'off', 'FontSize', 7);
    end

    % Tachometric in rPT space
    subplot(2, nSessions, nSessions + iSess);
    for iDt = 1:length(dtVals)
        dtConfM = confMask & (S(iSess).dt == dtVals(iDt));
        pHS_bin = NaN(1, nBins);
        n_bin = zeros(1, nBins);
        for ib = 1:nBins
            bM = dtConfM & (S(iSess).rpt >= binEdges(ib)) & (S(iSess).rpt < binEdges(ib+1));
            n_bin(ib) = sum(bM);
            if n_bin(ib) > 2, pHS_bin(ib) = mean(S(iSess).choseHS(bM)); end
        end
        if dtVals(iDt) < 0, col = colOverlap; else, col = colGap; end
        plot(binCenters, pHS_bin, 'o-', 'Color', col, 'LineWidth', 2, ...
            'MarkerSize', 7, 'MarkerFaceColor', col); hold on;
    end
    yline(0.5, 'k--', 'LineWidth', 1);
    xlabel('rPT (ms)'); ylabel('P(High Salience)');
    title(sprintf('%s: rPT tachometric', S(iSess).label), 'FontWeight', 'bold');
    ylim([0 1]); xlim([50 500]); box off;
end

sgtitle({'Tachometric Functions: SRT (top) vs rPT (bottom)', ...
    'Conflict trials only — curves should align in rPT space if processing time governs choice'}, ...
    'FontWeight', 'bold', 'FontSize', 12);
pdfSave(fig2, fullfile(outputDir, 'fig02_tachometric_srt_vs_rpt.pdf'));

%% ====================== FIGURE 3: POOLED rPT TACHOMETRIC ======================
fprintf('\n====== GENERATING FIGURE 3: POOLED rPT TACHOMETRIC ======\n');
fig3 = figure('Position', [50 50 1400 450], 'Color', 'w', ...
    'Name', 'Fig3: Pooled rPT', 'NumberTitle', 'off');

% Finer bins for pooled analysis
binEdgesFine = [25 75 125 175 225 275 325 400 500];
binCentersFine = (binEdgesFine(1:end-1) + binEdgesFine(2:end)) / 2;
nBinsFine = length(binCentersFine);

% --- Panel 1: Per-session pooled (all deltaT) conflict tachometric in rPT ---
subplot(1,3,1);
for iSess = 1:nSessions
    confMask = S(iSess).p23mask & logical(S(iSess).isConf);
    pHS_bin = NaN(1, nBinsFine);
    n_bin = zeros(1, nBinsFine);
    for ib = 1:nBinsFine
        bM = confMask & (S(iSess).rpt >= binEdgesFine(ib)) & (S(iSess).rpt < binEdgesFine(ib+1));
        n_bin(ib) = sum(bM);
        if n_bin(ib) > 2, pHS_bin(ib) = mean(S(iSess).choseHS(bM)); end
    end
    plot(binCentersFine, pHS_bin, 'o-', 'Color', colSession(iSess,:), 'LineWidth', 2, ...
        'MarkerSize', 7, 'MarkerFaceColor', colSession(iSess,:)); hold on;
end
yline(0.5, 'k--', 'LineWidth', 1);
xlabel('rPT (ms)'); ylabel('P(High Salience)');
title('Conflict Tachometric (rPT)', 'FontWeight', 'bold');
legend(sessionLabels, 'Location', 'best', 'Box', 'off');
ylim([0 1]); xlim([25 500]); box off;

% --- Panel 2: Per-session Phase 1 (no reward conflict) tachometric in rPT ---
subplot(1,3,2);
for iSess = 1:nSessions
    p1mask = S(iSess).p1mask;
    pHS_bin = NaN(1, nBinsFine);
    for ib = 1:nBinsFine
        bM = p1mask & (S(iSess).rpt >= binEdgesFine(ib)) & (S(iSess).rpt < binEdgesFine(ib+1));
        if sum(bM) > 2, pHS_bin(ib) = mean(S(iSess).choseHS(bM)); end
    end
    plot(binCentersFine, pHS_bin, 'o-', 'Color', colSession(iSess,:), 'LineWidth', 2, ...
        'MarkerSize', 7, 'MarkerFaceColor', colSession(iSess,:)); hold on;
end
yline(0.5, 'k--', 'LineWidth', 1);
xlabel('rPT (ms)'); ylabel('P(High Salience)');
title('Phase 1 Tachometric (rPT)', 'FontWeight', 'bold');
legend(sessionLabels, 'Location', 'best', 'Box', 'off');
ylim([0 1]); xlim([25 500]); box off;

% --- Panel 3: Feb 23 all trial types in rPT space ---
subplot(1,3,3);
iF = nSessions;  % focal session (Feb 23)
confMask = S(iF).p23mask & logical(S(iF).isConf);
congMask = S(iF).p23mask & ~logical(S(iF).isConf);
p1Mask   = S(iF).p1mask;

for maskIdx = 1:3
    switch maskIdx
        case 1, mask = confMask; col = colRed;   lbl = 'P2-3 Conflict';
        case 2, mask = congMask; col = colGreen;  lbl = 'P2-3 Congruent';
        case 3, mask = p1Mask;   col = colPurple; lbl = 'Phase 1';
    end
    pHS_bin = NaN(1, nBinsFine);
    for ib = 1:nBinsFine
        bM = mask & (S(iF).rpt >= binEdgesFine(ib)) & (S(iF).rpt < binEdgesFine(ib+1));
        if sum(bM) > 2, pHS_bin(ib) = mean(S(iF).choseHS(bM)); end
    end
    plot(binCentersFine, pHS_bin, 'o-', 'Color', col, 'LineWidth', 2, ...
        'MarkerSize', 7, 'MarkerFaceColor', col); hold on;
end
yline(0.5, 'k--', 'LineWidth', 1);
xlabel('rPT (ms)'); ylabel('P(High Salience)');
title('Feb 23: All Types (rPT)', 'FontWeight', 'bold');
legend({'Conflict', 'Congruent', 'Phase 1'}, 'Location', 'best', 'Box', 'off');
ylim([0 1]); xlim([25 500]); box off;

sgtitle('Tachometric Functions in rPT (Processing Time) Space', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig3, fullfile(outputDir, 'fig03_pooled_rpt_tachometric.pdf'));

%% ====================== FIGURE 4: CRITICAL COMPARISON — Feb 16 vs Feb 23 in rPT ======================
fprintf('\n====== GENERATING FIGURE 4: FEB 16 vs FEB 23 rPT ======\n');
fig4 = figure('Position', [50 50 1200 450], 'Color', 'w', ...
    'Name', 'Fig4: Feb16 vs Feb23 rPT', 'NumberTitle', 'off');

i16 = 1; i23 = 3;  % indices in S
col16 = colSession(1,:);
col23 = colSession(3,:);

% --- Panel 1: Conflict tachometric overlay in rPT ---
subplot(1,3,1);
for iS = [i16 i23]
    confM = S(iS).p23mask & logical(S(iS).isConf);
    pHS_bin = NaN(1, nBinsFine);
    n_bin = zeros(1, nBinsFine);
    for ib = 1:nBinsFine
        bM = confM & (S(iS).rpt >= binEdgesFine(ib)) & (S(iS).rpt < binEdgesFine(ib+1));
        n_bin(ib) = sum(bM);
        if n_bin(ib) > 2, pHS_bin(ib) = mean(S(iS).choseHS(bM)); end
    end
    if iS==i16, col=col16; else, col=col23; end
    plot(binCentersFine, pHS_bin, 'o-', 'Color', col, 'LineWidth', 2, ...
        'MarkerSize', 7, 'MarkerFaceColor', col); hold on;
    % Add CIs
    for ib = 1:nBinsFine
        if n_bin(ib) > 2 && ~isnan(pHS_bin(ib))
            [clo, chi] = binomCI(round(pHS_bin(ib)*n_bin(ib)), n_bin(ib));
            errorbar(binCentersFine(ib), pHS_bin(ib), pHS_bin(ib)-clo, chi-pHS_bin(ib), ...
                'Color', col, 'LineWidth', 0.8, 'CapSize', 4);
        end
    end
end
yline(0.5, 'k--', 'LineWidth', 1);
xlabel('rPT (ms)'); ylabel('P(High Salience)');
title('Conflict Tachometric (rPT)', 'FontWeight', 'bold');
legend({'Feb 16', 'Feb 23'}, 'Location', 'best', 'Box', 'off');
ylim([0 1]); xlim([25 500]); box off;

% --- Panel 2: rPT distributions for HS vs HR choices (Feb 16) ---
subplot(1,3,2);
confM = S(i16).p23mask & logical(S(i16).isConf);
hsM = confM & logical(S(i16).choseHS);
lsM = confM & ~logical(S(i16).choseHS);
edgesH = 0:20:500;
centersH = edgesH(1:end-1) + diff(edgesH)/2;
hHS = histcounts(S(i16).rpt(hsM), edgesH);
hLS = histcounts(S(i16).rpt(lsM), edgesH);
if max(hHS)>0, hHS = hHS/max(hHS); end
if max(hLS)>0, hLS = hLS/max(hLS); end
bar(centersH, hHS, 1, 'FaceColor', colPurple, 'FaceAlpha', 0.5, 'EdgeColor', 'none'); hold on;
bar(centersH, -hLS, 1, 'FaceColor', colGray, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
xlabel('rPT (ms)'); ylabel('Normalized count');
title('Feb 16 Conflict rPT: HS vs HR', 'FontWeight', 'bold');
legend({'Chose HS', 'Chose HR'}, 'Location', 'best', 'Box', 'off');
xlim([0 500]); box off;

% --- Panel 3: rPT distributions for HS vs HR choices (Feb 23) ---
subplot(1,3,3);
confM = S(i23).p23mask & logical(S(i23).isConf);
hsM = confM & logical(S(i23).choseHS);
lsM = confM & ~logical(S(i23).choseHS);
hHS = histcounts(S(i23).rpt(hsM), edgesH);
hLS = histcounts(S(i23).rpt(lsM), edgesH);
if max(hHS)>0, hHS = hHS/max(hHS); end
if max(hLS)>0, hLS = hLS/max(hLS); end
bar(centersH, hHS, 1, 'FaceColor', colPurple, 'FaceAlpha', 0.5, 'EdgeColor', 'none'); hold on;
bar(centersH, -hLS, 1, 'FaceColor', colGray, 'FaceAlpha', 0.5, 'EdgeColor', 'none');
xlabel('rPT (ms)'); ylabel('Normalized count');
title('Feb 23 Conflict rPT: HS vs HR', 'FontWeight', 'bold');
legend({'Chose HS', 'Chose HR'}, 'Location', 'best', 'Box', 'off');
xlim([0 500]); box off;

sgtitle('Feb 16 vs Feb 23: rPT Analysis', 'FontWeight', 'bold', 'FontSize', 14);
pdfSave(fig4, fullfile(outputDir, 'fig04_feb16_vs_feb23_rpt.pdf'));

%% ====================== DONE ======================
fprintf('\n====== DONE ======\n');
fprintf('Figures saved to: %s\n', outputDir);
for i = 1:4
    fprintf('  fig%02d_*.pdf\n', i);
end

close all;
end

%% ====================== HELPERS ======================

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
