function rptDetailedStats()
% Detailed rPT tachometric stats across ALL sessions and deltaT conditions
% to inform optimal deltaT recommendations.

pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));

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

%% Load all sessions
fprintf('\n====== LOADING ALL SESSIONS ======\n');
S = struct();
for iSess = 1:nSessions
    fpath = fullfile(pldapsHome, sessionFiles{iSess});
    data = load(fpath);
    if isfield(data,'p'), p=data.p; else, p=data; end
    nTrials = length(p.trData);
    fprintf('%s: %d trials\n', sessionLabels{iSess}, nTrials);

    sacCompleteState = p.state.sacComplete;
    phase = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
    dt    = arrayfun(@(x) x.deltaT, p.trVars(:)');
    hsSide = arrayfun(@(x) x.highSalienceSide, p.trVars(:)');
    endState = arrayfun(@(x) x.trialEndState, p.trData(:)');

    if isfield(p.trVars,'singleStimSide')
        ss = arrayfun(@(x) x.singleStimSide, p.trVars(:)');
    else
        ss = zeros(1,nTrials);
    end
    if isfield(p.trVars,'rewardBigSide')
        rwdSide = arrayfun(@(x) x.rewardBigSide, p.trVars(:)');
    else
        rwdSide = ones(1,nTrials);
        rwdSide(phase==2)=2; rwdSide(phase==3)=1; rwdSide(phase==1)=0;
    end

    choseHS = zeros(1,nTrials);
    if isfield(p.trData,'choseHighSalience')
        for iTr=1:nTrials
            val = p.trData(iTr).choseHighSalience;
            if ~isempty(val), choseHS(iTr) = double(val); end
        end
    end

    if isfield(p.trVars,'isConflict')
        isConf = zeros(1,nTrials);
        for iTr=1:nTrials
            val = p.trVars(iTr).isConflict;
            if ~isempty(val), isConf(iTr) = double(val); end
        end
    else
        isConf = double((rwdSide~=hsSide) & (rwdSide>0) & (ss==0));
    end

    isSC = (endState == sacCompleteState);
    isDual = (ss == 0);

    % Compute SRT and rPT
    srt = NaN(1,nTrials); rpt = NaN(1,nTrials);
    for iTr = 1:nTrials
        if endState(iTr)==sacCompleteState
            fOff = p.trData(iTr).timing.fixOff;
            sOn  = p.trData(iTr).timing.saccadeOnset;
            stOn = p.trData(iTr).timing.stimOn;
            if fOff>0 && sOn>0, srt(iTr) = (sOn-fOff)*1000; end
            if stOn>0 && sOn>0, rpt(iTr) = (sOn-stOn)*1000; end
        end
    end

    % Derive deltaT from P2-3
    p23DT = dt(phase>=2);
    if ~isempty(p23DT), dtVals = unique(p23DT(~isnan(p23DT)))';
    else, dtVals = unique(dt(~isnan(dt)))'; end

    % Error rates by deltaT
    allEndState = endState;

    p1mask  = (phase==1) & isDual & isSC;
    p23mask = (phase>=2) & isDual & isSC;

    S(iSess).label = sessionLabels{iSess};
    S(iSess).phase = phase; S(iSess).dt = dt;
    S(iSess).choseHS = choseHS; S(iSess).isConf = isConf;
    S(iSess).isSC = isSC; S(iSess).isDual = isDual;
    S(iSess).srt = srt; S(iSess).rpt = rpt;
    S(iSess).p1mask = p1mask; S(iSess).p23mask = p23mask;
    S(iSess).dtVals = dtVals;
    S(iSess).endState = endState;
    S(iSess).nTrials = nTrials;
    S(iSess).p = p;
end

%% ===== PER-SESSION, PER-DELTAT: rPT tachometric in fine bins =====
fprintf('\n====================================================================\n');
fprintf('  CONFLICT-TRIAL TACHOMETRIC: P(HS) by rPT bin, per session & deltaT\n');
fprintf('====================================================================\n');

binEdges = [0 75 100 125 150 175 200 250 300 400 500];
nBins = length(binEdges)-1;
binLabels = cell(1,nBins);
for ib=1:nBins
    binLabels{ib} = sprintf('%d-%d', binEdges(ib), binEdges(ib+1));
end

% Header
fprintf('\n%-8s | %5s | ', 'Session', 'dT');
for ib=1:nBins, fprintf('%8s ', binLabels{ib}); end
fprintf('| %5s\n', 'medRPT');
fprintf('%s\n', repmat('-', 1, 8+3+5+3 + 9*nBins + 8));

for iSess = 1:nSessions
    dtVals = S(iSess).dtVals;
    confMask = S(iSess).p23mask & logical(S(iSess).isConf);

    for iDt = 1:length(dtVals)
        dv = dtVals(iDt);
        dtConfM = confMask & (S(iSess).dt == dv);

        fprintf('%-8s | %+5d | ', S(iSess).label, dv);
        for ib = 1:nBins
            bM = dtConfM & (S(iSess).rpt >= binEdges(ib)) & (S(iSess).rpt < binEdges(ib+1));
            n = sum(bM);
            if n > 0
                pHS = mean(S(iSess).choseHS(bM));
                if pHS > 0.5
                    fprintf(' %4.2f/%2d*', pHS, n);
                else
                    fprintf(' %4.2f/%2d ', pHS, n);
                end
            else
                fprintf('   --    ');
            end
        end
        fprintf('| %5.0f\n', nanmedian(S(iSess).rpt(dtConfM)));
    end

    % Also pooled across deltaT
    fprintf('%-8s | %5s | ', S(iSess).label, 'ALL');
    for ib = 1:nBins
        bM = confMask & (S(iSess).rpt >= binEdges(ib)) & (S(iSess).rpt < binEdges(ib+1));
        n = sum(bM);
        if n > 0
            pHS = mean(S(iSess).choseHS(bM));
            if pHS > 0.5
                fprintf(' %4.2f/%2d*', pHS, n);
            else
                fprintf(' %4.2f/%2d ', pHS, n);
            end
        else
            fprintf('   --    ');
        end
    end
    fprintf('| %5.0f\n', nanmedian(S(iSess).rpt(confMask)));
    fprintf('\n');
end

%% ===== PHASE 1 (no reward conflict) tachometric =====
fprintf('\n====================================================================\n');
fprintf('  PHASE 1 (EQUAL REWARD) TACHOMETRIC: P(HS) by rPT bin\n');
fprintf('====================================================================\n');

fprintf('\n%-8s | %5s | ', 'Session', 'dT');
for ib=1:nBins, fprintf('%8s ', binLabels{ib}); end
fprintf('| %5s\n', 'medRPT');
fprintf('%s\n', repmat('-', 1, 8+3+5+3 + 9*nBins + 8));

for iSess = 1:nSessions
    dtVals = S(iSess).dtVals;
    p1mask = S(iSess).p1mask;
    if sum(p1mask) == 0, continue; end

    for iDt = 1:length(dtVals)
        dv = dtVals(iDt);
        dtP1M = p1mask & (S(iSess).dt == dv);
        if sum(dtP1M) == 0, continue; end

        fprintf('%-8s | %+5d | ', S(iSess).label, dv);
        for ib = 1:nBins
            bM = dtP1M & (S(iSess).rpt >= binEdges(ib)) & (S(iSess).rpt < binEdges(ib+1));
            n = sum(bM);
            if n > 0
                pHS = mean(S(iSess).choseHS(bM));
                if pHS > 0.5
                    fprintf(' %4.2f/%2d*', pHS, n);
                else
                    fprintf(' %4.2f/%2d ', pHS, n);
                end
            else
                fprintf('   --    ');
            end
        end
        fprintf('| %5.0f\n', nanmedian(S(iSess).rpt(dtP1M)));
    end

    fprintf('%-8s | %5s | ', S(iSess).label, 'ALL');
    for ib = 1:nBins
        bM = p1mask & (S(iSess).rpt >= binEdges(ib)) & (S(iSess).rpt < binEdges(ib+1));
        n = sum(bM);
        if n > 0
            pHS = mean(S(iSess).choseHS(bM));
            if pHS > 0.5
                fprintf(' %4.2f/%2d*', pHS, n);
            else
                fprintf(' %4.2f/%2d ', pHS, n);
            end
        else
            fprintf('   --    ');
        end
    end
    fprintf('| %5.0f\n', nanmedian(S(iSess).rpt(p1mask)));
    fprintf('\n');
end

%% ===== rPT DISTRIBUTION PERCENTILES PER SESSION & DELTAT =====
fprintf('\n====================================================================\n');
fprintf('  rPT DISTRIBUTION PERCENTILES (completed dual-stim P2-3 trials)\n');
fprintf('====================================================================\n');
fprintf('%-8s | %5s | %6s | %6s | %6s | %6s | %6s | %4s | %6s\n', ...
    'Session', 'dT', 'p10', 'p25', 'p50', 'p75', 'p90', 'n', '%%<125');
fprintf('%s\n', repmat('-', 1, 75));

for iSess = 1:nSessions
    dtVals = S(iSess).dtVals;
    for iDt = 1:length(dtVals)
        dv = dtVals(iDt);
        mask = S(iSess).p23mask & (S(iSess).dt == dv);
        r = S(iSess).rpt(mask);
        r = r(~isnan(r));
        if length(r) > 5
            fprintf('%-8s | %+5d | %6.0f | %6.0f | %6.0f | %6.0f | %6.0f | %4d | %5.1f%%\n', ...
                S(iSess).label, dv, prctile(r,10), prctile(r,25), ...
                prctile(r,50), prctile(r,75), prctile(r,90), ...
                length(r), 100*mean(r < 125));
        end
    end
end

%% ===== ERROR RATES BY DELTAT =====
fprintf('\n====================================================================\n');
fprintf('  ERROR RATES BY DELTAT (all trial types)\n');
fprintf('====================================================================\n');
fprintf('%-8s | %5s | %5s | %6s | %6s | %6s | %6s\n', ...
    'Session', 'dT', 'nTot', 'pctSC', 'pctFB', 'pctNR', 'pctIA');
fprintf('%s\n', repmat('-', 1, 55));

for iSess = 1:nSessions
    p = S(iSess).p;
    dtVals = S(iSess).dtVals;
    for iDt = 1:length(dtVals)
        dv = dtVals(iDt);
        mask = (S(iSess).dt == dv) & (S(iSess).phase >= 2) & S(iSess).isDual;
        nTot = sum(mask);
        if nTot > 0
            pSC = 100*sum(mask & S(iSess).isSC)/nTot;
            pFB = 100*sum(mask & (S(iSess).endState==p.state.fixBreak))/nTot;
            pNR = 100*sum(mask & (S(iSess).endState==p.state.noResponse))/nTot;
            pIA = 100*sum(mask & (S(iSess).endState==p.state.inaccurate))/nTot;
            fprintf('%-8s | %+5d | %5d | %5.1f%% | %5.1f%% | %5.1f%% | %5.1f%%\n', ...
                S(iSess).label, dv, nTot, pSC, pFB, pNR, pIA);
        end
    end
end

%% ===== POOLED ACROSS ALL SESSIONS: rPT tachometric for conflict =====
fprintf('\n====================================================================\n');
fprintf('  POOLED ACROSS ALL SESSIONS: Conflict tachometric by rPT\n');
fprintf('====================================================================\n');

allRPT = []; allChoseHS = []; allDT = [];
for iSess = 1:nSessions
    confM = S(iSess).p23mask & logical(S(iSess).isConf);
    allRPT = [allRPT, S(iSess).rpt(confM)];
    allChoseHS = [allChoseHS, S(iSess).choseHS(confM)];
    allDT = [allDT, S(iSess).dt(confM)];
end

fprintf('\nrPT bin   | P(HS)  |   n   | 95%% CI\n');
fprintf('%s\n', repmat('-', 1, 40));
for ib = 1:nBins
    bM = (allRPT >= binEdges(ib)) & (allRPT < binEdges(ib+1));
    n = sum(bM & ~isnan(allRPT));
    if n > 0
        pHS = mean(allChoseHS(bM & ~isnan(allRPT)));
        [clo, chi] = binomCI(round(pHS*n), n);
        marker = '';
        if pHS > 0.5 && clo > 0.5, marker = ' ***';
        elseif pHS > 0.5, marker = ' *'; end
        fprintf('%4d-%-4d | %5.3f  | %5d | [%.3f, %.3f]%s\n', ...
            binEdges(ib), binEdges(ib+1), pHS, n, clo, chi, marker);
    else
        fprintf('%4d-%-4d |   --   |   0   |\n', binEdges(ib), binEdges(ib+1));
    end
end

% Also by gap vs overlap
fprintf('\nPooled by condition:\n');
gapM = allDT > 0; ovrM = allDT < 0;
for ib = 1:nBins
    bGap = gapM & (allRPT >= binEdges(ib)) & (allRPT < binEdges(ib+1)) & ~isnan(allRPT);
    bOvr = ovrM & (allRPT >= binEdges(ib)) & (allRPT < binEdges(ib+1)) & ~isnan(allRPT);
    nG = sum(bGap); nO = sum(bOvr);
    pG = NaN; pO = NaN;
    if nG>0, pG = mean(allChoseHS(bGap)); end
    if nO>0, pO = mean(allChoseHS(bOvr)); end
    fprintf('%4d-%-4d | Gap: %5.3f (n=%3d) | Overlap: %5.3f (n=%3d)\n', ...
        binEdges(ib), binEdges(ib+1), pG, nG, pO, nO);
end

fprintf('\n====== DONE ======\n');
end

function [ciLo, ciHi] = binomCI(k, n)
    if n==0, ciLo=0; ciHi=1; return; end
    z = 1.96; phat = k/n;
    denom = 1 + z^2/n;
    center = (phat + z^2/(2*n)) / denom;
    halfwidth = (z * sqrt(phat*(1-phat)/n + z^2/(4*n^2))) / denom;
    ciLo = max(0, center-halfwidth);
    ciHi = min(1, center+halfwidth);
end
