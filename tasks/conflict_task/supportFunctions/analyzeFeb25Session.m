function analyzeFeb25Session()
%   analyzeFeb25Session()
%
% Analyzes the Feb 25 conflict task session — first session with the new
% parameter set: deltaT=[0,+125], R=1.0 in Phase 1, R=1.5 in P2-3,
% rewardProbHigh=0.85, fixHold=[1.0,1.2], single-stim first.
%
% Output: PDF figures and console report to output/analysis/feb25/

%% ====================== SETUP ======================
pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
outputDir  = fullfile(pldapsHome, 'output', 'analysis', 'feb25');
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

sessionFiles = {
    'output/20260209_t1010_conflict_task.mat'
    'output/20260211_t0929_conflict_task.mat'
    'output/20260213_t1018_conflict_task.mat'
    'output/20260216_t0837_conflict_task.mat'
    'output/20260218_t0934_conflict_task.mat'
    'output/20260220_t1023_conflict_task.mat'
    'output/20260223_t1016_conflict_task.mat'
    'output/20260225_t1037_conflict_task.mat'
    };
sessionLabels = {'Feb 9','Feb 11','Feb 13','Feb 16','Feb 18','Feb 20','Feb 23','Feb 25'};
nSessions = length(sessionFiles);
iFocal = nSessions;

colOrange=[.85 .325 .098]; colBlue=[0 .447 .741]; colGreen=[.466 .674 .188];
colPurple=[.494 .184 .556]; colRed=[.8 .15 .15]; colGray=[.5 .5 .5];
colPrev=[.65 .65 .65]; colFocal=[.85 .33 .10];

%% ====================== LOAD ALL SESSIONS ======================
fprintf('\n====== LOADING ALL SESSIONS ======\n');
S = struct();
for iSess = 1:nSessions
    fpath = fullfile(pldapsHome, sessionFiles{iSess});
    fprintf('Loading %s ... ', sessionLabels{iSess});
    data = load(fpath);
    if isfield(data,'p'), p=data.p; else, p=data; end
    nTrials = length(p.trData);
    fprintf('%d trials\n', nTrials);

    if isfield(p,'trVarsInit'), tv0=p.trVarsInit; else, tv0=p.trVars(1); end
    sacSt = p.state.sacComplete;

    S(iSess).label = sessionLabels{iSess};
    S(iSess).nTrials = nTrials;
    S(iSess).p = p;
    S(iSess).rewardRatioBig = safeField(tv0,'rewardRatioBig',2.0);
    S(iSess).rewardProbHigh = safeField(tv0,'rewardProbHigh',0.9);

    allRW = arrayfun(@(x) x.responseWindow, p.trVars(:)');
    S(iSess).responseWindow = mode(allRW);

    allDT = arrayfun(@(x) x.deltaT, p.trVars(:)');
    allPh = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
    p23DT = allDT(allPh>=2);
    if ~isempty(p23DT), S(iSess).dtValues = unique(p23DT(~isnan(p23DT)))';
    else, S(iSess).dtValues = unique(allDT(~isnan(allDT)))'; end

    phase = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
    dt = arrayfun(@(x) x.deltaT, p.trVars(:)');
    hsSide = arrayfun(@(x) x.highSalienceSide, p.trVars(:)');
    endState = arrayfun(@(x) x.trialEndState, p.trData(:)');

    if isfield(p.trVars,'rewardBigSide')
        rwdSide = arrayfun(@(x) x.rewardBigSide, p.trVars(:)');
    else
        rwdSide = ones(1,nTrials); rwdSide(phase==2)=2; rwdSide(phase==3)=1; rwdSide(phase==1)=0;
    end
    if isfield(p.trVars,'singleStimSide')
        ss = arrayfun(@(x) x.singleStimSide, p.trVars(:)');
    else, ss = zeros(1,nTrials); end

    chosenSide = NaN(1,nTrials);
    for iTr=1:nTrials
        if isfield(p.trData(iTr),'chosenSide') && ~isempty(p.trData(iTr).chosenSide)
            chosenSide(iTr) = p.trData(iTr).chosenSide;
        end
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

    isSC = (endState==sacSt); isDual = (ss==0); choseRight = (chosenSide==2);

    % SRT and rPT
    srt = NaN(1,nTrials); rpt = NaN(1,nTrials);
    for iTr=1:nTrials
        if endState(iTr)==sacSt
            fOff=p.trData(iTr).timing.fixOff; sOn=p.trData(iTr).timing.saccadeOnset;
            stOn=p.trData(iTr).timing.stimOn;
            if fOff>0 && sOn>0, srt(iTr)=(sOn-fOff)*1000; end
            if stOn>0 && sOn>0, rpt(iTr)=(sOn-stOn)*1000; end
        end
    end

    p1m=(phase==1)&isDual&isSC; p2m=(phase==2)&isDual&isSC;
    p3m=(phase==3)&isDual&isSC; p23m=(phase>=2)&isDual&isSC;

    S(iSess).phase=phase; S(iSess).dt=dt; S(iSess).hsSide=hsSide;
    S(iSess).rwdSide=rwdSide; S(iSess).ss=ss; S(iSess).chosenSide=chosenSide;
    S(iSess).choseHS=choseHS; S(iSess).isConf=isConf; S(iSess).isSC=isSC;
    S(iSess).isDual=isDual; S(iSess).choseRight=choseRight;
    S(iSess).srt=srt; S(iSess).rpt=rpt; S(iSess).endState=endState;
    S(iSess).p1m=p1m; S(iSess).p2m=p2m; S(iSess).p3m=p3m; S(iSess).p23m=p23m;

    S(iSess).nGood=sum(isSC); S(iSess).nGoodP1=sum(p1m);
    S(iSess).nGoodP2=sum(p2m); S(iSess).nGoodP3=sum(p3m);
    S(iSess).nFB=sum(endState==p.state.fixBreak);
    S(iSess).nNR=sum(endState==p.state.noResponse);
    S(iSess).nIA=sum(endState==p.state.inaccurate);

    if sum(p1m)>0, S(iSess).pRightP1=mean(choseRight(p1m)); else, S(iSess).pRightP1=NaN; end
    if sum(p23m)>0, S(iSess).pHS_P23=mean(choseHS(p23m)); else, S(iSess).pHS_P23=NaN; end

    hsR=p23m&(hsSide==2); hsL=p23m&(hsSide==1);
    if sum(hsR)>0 && sum(hsL)>0
        hr=mean(choseHS(hsR)); fa=1-mean(choseHS(hsL));
        hr=max(min(hr,1-1/(2*sum(hsR))),1/(2*sum(hsR)));
        fa=max(min(fa,1-1/(2*sum(hsL))),1/(2*sum(hsL)));
        S(iSess).dprime=norminv(hr)-norminv(fa);
        S(iSess).criterion=-0.5*(norminv(hr)+norminv(fa));
    else, S(iSess).dprime=NaN; S(iSess).criterion=NaN; end

    S(iSess).medRT=nanmedian(srt(isSC));

    if length(S(iSess).dtValues)>=2
        confGap=p23m&logical(isConf)&(dt==max(S(iSess).dtValues));
        confSim=p23m&logical(isConf)&(dt==min(S(iSess).dtValues));
        if sum(confGap)>0&&sum(confSim)>0
            S(iSess).dtEffect=mean(choseHS(confGap))-mean(choseHS(confSim));
        else, S(iSess).dtEffect=NaN; end
    else, S(iSess).dtEffect=NaN; end
end

%% ====================== FOCAL SUMMARY ======================
f = S(iFocal); fp = f.p;
fprintf('\n====== FEB 25 SESSION SUMMARY ======\n');
fprintf('  Total trials:       %d\n', f.nTrials);
fprintf('  Completed (sacC):   %d\n', f.nGood);
fprintf('  Phase 1 dual-stim:  %d\n', f.nGoodP1);
fprintf('  Phase 2 dual-stim:  %d\n', f.nGoodP2);
fprintf('  Phase 3 dual-stim:  %d\n', f.nGoodP3);
fprintf('  Single-stim compl:  %d\n', sum(f.isSC & (f.ss>0)));
fprintf('  Reward ratio:       %.2f (P1: 1.0)\n', f.rewardRatioBig);
fprintf('  Reward prob:        %.2f\n', f.rewardProbHigh);
fprintf('  Response window:    %.2f s\n', f.responseWindow);
fprintf('  DeltaT values:      [%s]\n', strjoin(arrayfun(@(x) sprintf('%d',x), f.dtValues, 'UniformOutput', false), ', '));
fprintf('  Fix breaks:         %d (%.1f%%)\n', f.nFB, 100*f.nFB/f.nTrials);
fprintf('  No response:        %d (%.1f%%)\n', f.nNR, 100*f.nNR/f.nTrials);
fprintf('  Inaccurate:         %d (%.1f%%)\n', f.nIA, 100*f.nIA/f.nTrials);
fprintf('\n');
fprintf('  P(Right) Phase 1:   %.3f\n', f.pRightP1);
fprintf('  P(HighSal) P2-3:    %.3f\n', f.pHS_P23);
fprintf('  d'':                %.3f\n', f.dprime);
fprintf('  Criterion:          %.3f\n', f.criterion);
fprintf('  Median SRT:         %.0f ms\n', f.medRT);
fprintf('  DeltaT effect:      %.3f\n', f.dtEffect);

%% ====================== CROSS-SESSION TABLE ======================
fprintf('\n====== CROSS-SESSION COMPARISON ======\n');
fprintf('%-8s | %5s | %5s | %8s | %4s | %5s | %6s | %5s | %7s | %5s | %5s\n', ...
    'Session','Ratio','P(RW)','DeltaT','RW','nGood','P(R)P1','d''','Crit','medRT','dtEff');
fprintf('%s\n', repmat('-',1,100));
for s=1:nSessions
    dtStr=sprintf('[%s]',strjoin(arrayfun(@(x) sprintf('%d',x),S(s).dtValues,'UniformOutput',false),','));
    marker=''; if s==iFocal, marker=' <--'; end
    fprintf('%-8s | %5.2f | %5.2f | %8s | %4.2f | %5d | %6.3f | %5.3f | %7.3f | %5.0f | %5.3f%s\n', ...
        S(s).label, S(s).rewardRatioBig, S(s).rewardProbHigh, dtStr, ...
        S(s).responseWindow, S(s).nGood, S(s).pRightP1, ...
        S(s).dprime, S(s).criterion, S(s).medRT, S(s).dtEffect, marker);
end

%% ====================== DETAILED STATS ======================
p1m=f.p1m; p23m=f.p23m; p2m=f.p2m; p3m=f.p3m;
hs=f.hsSide; cr=f.choseRight; cHS=f.choseHS; srtF=f.srt; rptF=f.rpt;
dtF=f.dt; isConfF=f.isConf; rwdF=f.rwdSide; cs=f.chosenSide;

fprintf('\n====== PHASE 1 DETAILED ======\n');
p1_hsR=p1m&(hs==2); p1_hsL=p1m&(hs==1);
fprintf('  HS-Right: P(Right)=%.3f, P(HS)=%.3f (n=%d)\n', mean(cr(p1_hsR)), mean(cHS(p1_hsR)), sum(p1_hsR));
fprintf('  HS-Left:  P(Right)=%.3f, P(HS)=%.3f (n=%d)\n', mean(cr(p1_hsL)), mean(cHS(p1_hsL)), sum(p1_hsL));
for dv=f.dtValues(:)'
    dtM=p1m&(dtF==dv);
    if sum(dtM)>0
        fprintf('  DeltaT=%+4d: P(Right)=%.3f, P(HS)=%.3f, medSRT=%.0f, medRPT=%.0f (n=%d)\n', ...
            dv, mean(cr(dtM)), mean(cHS(dtM)), nanmedian(srtF(dtM)), nanmedian(rptF(dtM)), sum(dtM));
    end
end

fprintf('\n====== PHASES 2-3 DETAILED ======\n');
confP23=p23m&logical(isConfF); congP23=p23m&~logical(isConfF);
for dv=f.dtValues(:)'
    confM=p23m&logical(isConfF)&(dtF==dv); congM=p23m&~logical(isConfF)&(dtF==dv);
    if sum(confM)>0, pConf=mean(cHS(confM)); nConf=sum(confM); else, pConf=NaN; nConf=0; end
    if sum(congM)>0, pCong=mean(cHS(congM)); nCong=sum(congM); else, pCong=NaN; nCong=0; end
    fprintf('  DeltaT=%+4d: Conf P(HS)=%.3f (n=%d), Cong P(HS)=%.3f (n=%d)\n', dv, pConf, nConf, pCong, nCong);
end

choseHR=NaN(1,f.nTrials);
for iTr=1:f.nTrials
    if f.isSC(iTr)&&f.isDual(iTr)&&f.phase(iTr)>=2&&rwdF(iTr)>0
        choseHR(iTr)=double(cs(iTr)==rwdF(iTr));
    end
end
fprintf('  P(HighReward) P2: %.3f (n=%d)\n', nanmean(choseHR(p2m)), sum(p2m));
fprintf('  P(HighReward) P3: %.3f (n=%d)\n', nanmean(choseHR(p3m)), sum(p3m));
fprintf('  P(HighReward) conflict:  %.3f (n=%d)\n', nanmean(choseHR(confP23)), sum(confP23));
fprintf('  P(HighReward) congruent: %.3f (n=%d)\n', nanmean(choseHR(congP23)), sum(congP23));

fprintf('\n====== RT BY CONDITION ======\n');
fprintf('  Phase 1: SRT=%.0f, rPT=%.0f (n=%d)\n', nanmedian(srtF(p1m)), nanmedian(rptF(p1m)), sum(p1m));
fprintf('  Phase 2: SRT=%.0f, rPT=%.0f (n=%d)\n', nanmedian(srtF(p2m)), nanmedian(rptF(p2m)), sum(p2m));
fprintf('  Phase 3: SRT=%.0f, rPT=%.0f (n=%d)\n', nanmedian(srtF(p3m)), nanmedian(rptF(p3m)), sum(p3m));
choseHS_conf=confP23&logical(cHS); choseHR_conf=confP23&(choseHR==1);
fprintf('  Conflict chose-HS: SRT=%.0f, rPT=%.0f (n=%d)\n', nanmedian(srtF(choseHS_conf)), nanmedian(rptF(choseHS_conf)), sum(choseHS_conf));
fprintf('  Conflict chose-HR: SRT=%.0f, rPT=%.0f (n=%d)\n', nanmedian(srtF(choseHR_conf)), nanmedian(rptF(choseHR_conf)), sum(choseHR_conf));

%% ====================== rPT TACHOMETRIC (all sessions pooled + focal) ======================
fprintf('\n====== rPT TACHOMETRIC: CONFLICT TRIALS ======\n');
binEdges=[0 75 100 125 150 175 200 250 300 400 500];
nBins=length(binEdges)-1;
binLabels=cell(1,nBins);
for ib=1:nBins, binLabels{ib}=sprintf('%d-%d',binEdges(ib),binEdges(ib+1)); end

fprintf('\n%-8s | %5s | ','Session','dT');
for ib=1:nBins, fprintf('%8s ',binLabels{ib}); end
fprintf('\n%s\n',repmat('-',1,8+3+5+3+9*nBins));

for iSess=[iFocal-1 iFocal]  % Feb 23 and Feb 25
    confMask=S(iSess).p23m&logical(S(iSess).isConf);
    for iDt=1:length(S(iSess).dtValues)
        dv=S(iSess).dtValues(iDt);
        dtConfM=confMask&(S(iSess).dt==dv);
        fprintf('%-8s | %+5d | ',S(iSess).label,dv);
        for ib=1:nBins
            bM=dtConfM&(S(iSess).rpt>=binEdges(ib))&(S(iSess).rpt<binEdges(ib+1));
            n=sum(bM);
            if n>0
                pHS=mean(S(iSess).choseHS(bM));
                if pHS>0.5, fprintf(' %4.2f/%2d*',pHS,n);
                else, fprintf(' %4.2f/%2d ',pHS,n); end
            else, fprintf('   --    '); end
        end
        fprintf('\n');
    end
    fprintf('\n');
end

%% ====================== FIGURE 1: CROSS-SESSION OVERVIEW ======================
fprintf('\n====== GENERATING FIGURES ======\n');
fig1=figure('Position',[50 50 1400 800],'Color','w','Name','Fig1','NumberTitle','off');
cols_bar=repmat(colPrev,nSessions,1); cols_bar(iFocal,:)=colFocal;

subplot(2,3,1);
for s=1:nSessions, bar(s,[S(s).pRightP1],0.6,'FaceColor',cols_bar(s,:),'EdgeColor','none'); hold on; end
yline(0.5,'k--','LineWidth',1);
set(gca,'XTick',1:nSessions,'XTickLabel',sessionLabels,'FontSize',6);
ylabel('P(Right)'); title('Phase 1 Spatial Bias','FontWeight','bold'); ylim([0 1]); box off;

subplot(2,3,2);
for s=1:nSessions, bar(s,[S(s).dprime],0.6,'FaceColor',cols_bar(s,:),'EdgeColor','none'); hold on; end
yline(0,'k--','LineWidth',1);
set(gca,'XTick',1:nSessions,'XTickLabel',sessionLabels,'FontSize',6);
ylabel('d'''); title('Salience Sensitivity','FontWeight','bold'); box off;

subplot(2,3,3);
for s=1:nSessions, bar(s,[S(s).criterion],0.6,'FaceColor',cols_bar(s,:),'EdgeColor','none'); hold on; end
yline(0,'k--','LineWidth',1);
set(gca,'XTick',1:nSessions,'XTickLabel',sessionLabels,'FontSize',6);
ylabel('Criterion'); title('Spatial Bias (SDT)','FontWeight','bold'); box off;

subplot(2,3,4);
for s=1:nSessions, bar(s,[S(s).dtEffect],0.6,'FaceColor',cols_bar(s,:),'EdgeColor','none'); hold on; end
yline(0,'k--','LineWidth',1);
set(gca,'XTick',1:nSessions,'XTickLabel',sessionLabels,'FontSize',6);
ylabel('\Delta P(HS)'); title('DeltaT Effect','FontWeight','bold'); box off;

subplot(2,3,5);
for s=1:nSessions, bar(s,[S(s).medRT],0.6,'FaceColor',cols_bar(s,:),'EdgeColor','none'); hold on; end
set(gca,'XTick',1:nSessions,'XTickLabel',sessionLabels,'FontSize',6);
ylabel('Median SRT (ms)'); title('Response Speed','FontWeight','bold'); box off;

subplot(2,3,6);
errFB=arrayfun(@(x)100*x.nFB/x.nTrials,S);
errNR=arrayfun(@(x)100*x.nNR/x.nTrials,S);
errIA=arrayfun(@(x)100*x.nIA/x.nTrials,S);
hb=bar(1:nSessions,[errFB' errNR' errIA'],'stacked');
hb(1).FaceColor=colOrange; hb(1).EdgeColor='none';
hb(2).FaceColor=colBlue; hb(2).EdgeColor='none';
hb(3).FaceColor=colRed; hb(3).EdgeColor='none';
set(gca,'XTick',1:nSessions,'XTickLabel',sessionLabels,'FontSize',6);
ylabel('Error Rate (%)'); title('Error Rates','FontWeight','bold');
legend(hb,{'Fix Break','No Response','Inaccurate'},'Location','best','Box','off','FontSize',7); box off;

sgtitle('Cross-Session Comparison (Feb 25 highlighted)','FontWeight','bold','FontSize',14);
pdfSave(fig1,fullfile(outputDir,'fig01_cross_session.pdf'));

%% ====================== FIGURE 2: FEB 25 OVERVIEW ======================
fig2=figure('Position',[50 50 1400 900],'Color','w','Name','Fig2','NumberTitle','off');

subplot(2,3,1);
pR=[f.pRightP1, mean(cr(p2m)), mean(cr(p3m))];
bar(1:3,pR,0.6,'FaceColor',colBlue,'EdgeColor','none'); hold on;
yline(0.5,'k--','LineWidth',1);
masks={p1m,p2m,p3m};
for ph=1:3, [clo,chi]=binomCI(sum(cr(masks{ph})),sum(masks{ph}));
    errorbar(ph,pR(ph),pR(ph)-clo,chi-pR(ph),'k','LineWidth',1.5,'CapSize',8); end
set(gca,'XTick',1:3,'XTickLabel',{'Phase 1','Phase 2','Phase 3'});
ylabel('P(Right)'); title('Spatial Bias by Phase','FontWeight','bold'); ylim([0 1]); box off;

subplot(2,3,2);
m2c=p2m&logical(isConfF); m2g=p2m&~logical(isConfF);
m3c=p3m&logical(isConfF); m3g=p3m&~logical(isConfF);
bd=NaN(2,2);
if sum(m2c)>0, bd(1,1)=mean(cHS(m2c)); end; if sum(m2g)>0, bd(1,2)=mean(cHS(m2g)); end
if sum(m3c)>0, bd(2,1)=mean(cHS(m3c)); end; if sum(m3g)>0, bd(2,2)=mean(cHS(m3g)); end
hb2=bar([2 3],bd,0.8); hb2(1).FaceColor=colRed; hb2(1).EdgeColor='none';
hb2(2).FaceColor=colGreen; hb2(2).EdgeColor='none';
hold on; yline(0.5,'k--','LineWidth',1);
set(gca,'XTick',[2 3],'XTickLabel',{'Phase 2','Phase 3'});
ylabel('P(HS)'); title('Salience: Conflict vs Congruent','FontWeight','bold');
legend(hb2,{'Conflict','Congruent'},'Location','best','Box','off'); ylim([0 1]); box off;

subplot(2,3,3);
edges=50:25:500; centers=edges(1:end-1)+diff(edges)/2;
h1=histcounts(srtF(p1m),edges); h2=histcounts(srtF(p2m),edges); h3=histcounts(srtF(p3m),edges);
plot(centers,h1/max(max(h1),1),'-','Color',colBlue,'LineWidth',2); hold on;
plot(centers,h2/max(max(h2),1),'-','Color',colOrange,'LineWidth',2);
plot(centers,h3/max(max(h3),1),'-','Color',colGreen,'LineWidth',2);
xlabel('SRT (ms)'); ylabel('Norm. count'); title('RT Distributions','FontWeight','bold');
legend({'P1','P2','P3'},'Location','best','Box','off'); xlim([50 500]); box off;

subplot(2,3,4);
dtVals=f.dtValues;
pHS_dt=NaN(1,length(dtVals)); nDt=zeros(1,length(dtVals));
for iDt=1:length(dtVals)
    dtM=p23m&logical(isConfF)&(dtF==dtVals(iDt));
    nDt(iDt)=sum(dtM); if nDt(iDt)>0, pHS_dt(iDt)=mean(cHS(dtM)); end
end
bar(1:length(dtVals),pHS_dt,0.6,'FaceColor',colPurple,'EdgeColor','none'); hold on;
for iDt=1:length(dtVals)
    if nDt(iDt)>0, [clo,chi]=binomCI(round(pHS_dt(iDt)*nDt(iDt)),nDt(iDt));
        errorbar(iDt,pHS_dt(iDt),pHS_dt(iDt)-clo,chi-pHS_dt(iDt),'k','LineWidth',1.5,'CapSize',8); end
end
yline(0.5,'k--','LineWidth',1);
set(gca,'XTick',1:length(dtVals),'XTickLabel',arrayfun(@(x) sprintf('%+d',x),dtVals,'UniformOutput',false));
xlabel('Delta-T (ms)'); ylabel('P(HS)'); title('Conflict: Salience by DeltaT','FontWeight','bold');
ylim([0 1]); box off;

subplot(2,3,5);
confTrials=find(confP23); congTrials=find(congP23);
if ~isempty(confTrials), cumC=cumsum(choseHR(confTrials)==1)./(1:length(confTrials));
    plot(1:length(confTrials),cumC,'-','Color',colRed,'LineWidth',1.5); hold on; end
if ~isempty(congTrials), cumG=cumsum(choseHR(congTrials)==1)./(1:length(congTrials));
    plot(1:length(congTrials),cumG,'-','Color',colGreen,'LineWidth',1.5); hold on; end
yline(0.5,'k--','LineWidth',1);
xlabel('Trial #'); ylabel('Cumul P(HR)'); title('Reward Learning (P2-3)','FontWeight','bold');
legend({'Conflict','Congruent'},'Location','best','Box','off'); ylim([0 1]); box off;

subplot(2,3,6);
phaseAll=f.phase; endAll=f.endState;
stCodes=[fp.state.fixBreak,fp.state.noResponse,fp.state.inaccurate];
errD=zeros(3,3);
for ph=1:3, phM=(phaseAll==ph); nPh=sum(phM);
    for e=1:3, errD(ph,e)=100*sum(phM&(endAll==stCodes(e)))/max(nPh,1); end; end
hb3=bar(1:3,errD,'stacked');
hb3(1).FaceColor=colOrange; hb3(1).EdgeColor='none';
hb3(2).FaceColor=colBlue; hb3(2).EdgeColor='none';
hb3(3).FaceColor=colRed; hb3(3).EdgeColor='none';
set(gca,'XTick',1:3,'XTickLabel',{'P1','P2','P3'});
ylabel('Error Rate (%)'); title('Errors by Phase','FontWeight','bold');
legend(hb3,{'FB','NR','IA'},'Location','best','Box','off'); box off;

sgtitle('Feb 25 Overview (R=1.0/1.5, \DeltaT=[0,+125], RW=0.45, P=0.85)','FontWeight','bold','FontSize',13);
pdfSave(fig2,fullfile(outputDir,'fig02_feb25_overview.pdf'));

%% ====================== FIGURE 3: rPT TACHOMETRIC ======================
fig3=figure('Position',[50 50 1400 450],'Color','w','Name','Fig3','NumberTitle','off');

binE=[50 100 150 200 250 300 400 500]; binC=(binE(1:end-1)+binE(2:end))/2; nB=length(binC);

subplot(1,3,1);
confMask=p23m&logical(isConfF);
pHS_bin=NaN(1,nB); n_bin=zeros(1,nB);
for ib=1:nB, bM=confMask&(rptF>=binE(ib))&(rptF<binE(ib+1));
    n_bin(ib)=sum(bM); if n_bin(ib)>2, pHS_bin(ib)=mean(cHS(bM)); end; end
plot(binC,pHS_bin,'o-','Color',colRed,'LineWidth',2,'MarkerSize',8,'MarkerFaceColor',colRed); hold on;
for ib=1:nB, if n_bin(ib)>2, [clo,chi]=binomCI(round(pHS_bin(ib)*n_bin(ib)),n_bin(ib));
    errorbar(binC(ib),pHS_bin(ib),pHS_bin(ib)-clo,chi-pHS_bin(ib),'Color',colRed,'LineWidth',1,'CapSize',6); end; end
yline(0.5,'k--','LineWidth',1);
for ib=1:nB, if n_bin(ib)>0, text(binC(ib),0.05,sprintf('n=%d',n_bin(ib)),'HorizontalAlignment','center','FontSize',7,'Color',colGray); end; end
xlabel('rPT (ms)'); ylabel('P(HS)'); title('Conflict Tachometric (rPT)','FontWeight','bold');
ylim([0 1]); xlim([50 500]); box off;

subplot(1,3,2);
colsDT={colBlue,colOrange};
for iDt=1:length(dtVals)
    dtConfM=confMask&(dtF==dtVals(iDt));
    pHS_dtB=NaN(1,nB);
    for ib=1:nB, bM=dtConfM&(rptF>=binE(ib))&(rptF<binE(ib+1));
        if sum(bM)>1, pHS_dtB(ib)=mean(cHS(bM)); end; end
    plot(binC,pHS_dtB,'o-','Color',colsDT{iDt},'LineWidth',2,'MarkerSize',7,'MarkerFaceColor',colsDT{iDt}); hold on;
end
yline(0.5,'k--','LineWidth',1);
legend(arrayfun(@(x) sprintf('\\DeltaT=%+d',x),dtVals,'UniformOutput',false),'Location','best','Box','off');
xlabel('rPT (ms)'); ylabel('P(HS)'); title('Tachometric by DeltaT','FontWeight','bold');
ylim([0 1]); xlim([50 500]); box off;

subplot(1,3,3);
choseHS_c=confMask&logical(cHS); choseLS_c=confMask&~logical(cHS);
edgesRT=0:20:500; centersRT=edgesRT(1:end-1)+diff(edgesRT)/2;
hHS=histcounts(rptF(choseHS_c),edgesRT); hLS=histcounts(rptF(choseLS_c),edgesRT);
if max(hHS)>0, hHS=hHS/max(hHS); end; if max(hLS)>0, hLS=hLS/max(hLS); end
bar(centersRT,hHS,1,'FaceColor',colPurple,'FaceAlpha',0.5,'EdgeColor','none'); hold on;
bar(centersRT,-hLS,1,'FaceColor',colGray,'FaceAlpha',0.5,'EdgeColor','none');
xlabel('rPT (ms)'); ylabel('Norm. count'); title('Conflict rPT: HS vs HR','FontWeight','bold');
legend({'Chose HS','Chose HR'},'Location','best','Box','off'); xlim([0 500]); box off;

sgtitle('Feb 25: rPT Tachometric Analysis','FontWeight','bold','FontSize',14);
pdfSave(fig3,fullfile(outputDir,'fig03_feb25_tachometric_rpt.pdf'));

%% ====================== FIGURE 4: PHASE 1 DETAIL ======================
fig4=figure('Position',[50 50 1200 450],'Color','w','Name','Fig4','NumberTitle','off');

subplot(1,3,1);
p1trials=find(p1m);
if ~isempty(p1trials)
    ws=15; cumR=cumsum(cr(p1trials));
    runR=NaN(1,length(p1trials));
    for iTr=ws:length(p1trials), runR(iTr)=(cumR(iTr)-cumR(max(1,iTr-ws)+1-1))/ws; end
    plot(1:length(p1trials),runR,'-','Color',colBlue,'LineWidth',2); hold on;
    yline(0.5,'k--','LineWidth',1);
    xlabel('Trial # (P1 dual)'); ylabel('Running P(Right)');
    title(sprintf('P1 Running Avg (win=%d)',ws),'FontWeight','bold'); ylim([0 1]);
end
box off;

subplot(1,3,2);
condLabels={}; condVals=[]; ci=1;
for dv=f.dtValues(:)', for hss=[1 2]
    mask=p1m&(dtF==dv)&(hs==hss);
    if sum(mask)>0, condVals(ci)=mean(cHS(mask));
        if hss==1, sStr='HS-L'; else, sStr='HS-R'; end
        condLabels{ci}=sprintf('%s\n%+dms',sStr,dv); ci=ci+1;
    end
end; end
if ~isempty(condVals)
    bar(1:length(condVals),condVals,0.6,'FaceColor',colPurple,'EdgeColor','none');
    hold on; yline(0.5,'k--','LineWidth',1);
    set(gca,'XTick',1:length(condVals),'XTickLabel',condLabels,'FontSize',8);
    ylabel('P(HS)'); title('P1: P(HS) by Condition','FontWeight','bold'); ylim([0 1]);
end
box off;

subplot(1,3,3);
colsHS={colBlue,colOrange};
for hss=[1 2], mask=p1m&(hs==hss);
    if sum(mask)>0
        xJ=hss+0.15*(rand(1,sum(mask))-0.5);
        scatter(xJ,srtF(mask),15,colsHS{hss},'filled','MarkerFaceAlpha',0.3); hold on;
        med=nanmedian(srtF(mask));
        plot([hss-0.2 hss+0.2],[med med],'-','Color',colsHS{hss},'LineWidth',3);
        q25=prctile(srtF(mask),25); q75=prctile(srtF(mask),75);
        plot([hss hss],[q25 q75],'-','Color',colsHS{hss},'LineWidth',2);
    end
end
set(gca,'XTick',[1 2],'XTickLabel',{'HS-Left','HS-Right'});
ylabel('SRT (ms)'); title('P1: RT by HS Side','FontWeight','bold'); xlim([0.5 2.5]); box off;

sgtitle('Feb 25: Phase 1 Detail','FontWeight','bold','FontSize',14);
pdfSave(fig4,fullfile(outputDir,'fig04_feb25_phase1.pdf'));

%% ====================== FIGURE 5: FULL SESSION TRAJECTORY ======================
fig5=figure('Position',[50 50 1200 450],'Color','w','Name','Fig5','NumberTitle','off');

subplot(1,3,1);
allSC=find(f.isSC&f.isDual);
if ~isempty(allSC)
    ws=20; cumR=cumsum(cr(allSC));
    runR=NaN(1,length(allSC));
    for iTr=ws:length(allSC), runR(iTr)=(cumR(iTr)-cumR(max(1,iTr-ws)+1-1))/ws; end
    phOT=f.phase(allSC);
    for ph=1:3
        phIdx=(phOT==ph); x=1:length(allSC);
        if ph==1, col=colBlue; elseif ph==2, col=colOrange; else, col=colGreen; end
        scatter(x(phIdx),runR(phIdx),8,col,'filled','MarkerFaceAlpha',0.6); hold on;
    end
    yline(0.5,'k--','LineWidth',1);
    for ph=[1 2], li=find(phOT==ph,1,'last');
        if ~isempty(li), xline(li,'k:','LineWidth',1);
            text(li,0.97,sprintf('P%d|P%d',ph,ph+1),'FontSize',8,'HorizontalAlignment','center'); end; end
    xlabel('Completed dual trial #'); ylabel(sprintf('Running P(R) (w=%d)',ws));
    title('Full Session P(Right)','FontWeight','bold'); ylim([0 1]);
end
box off;

subplot(1,3,2);
allSCidx=find(f.isSC);
plot(1:length(allSCidx),srtF(allSCidx),'.','Color',[.7 .7 .7],'MarkerSize',4); hold on;
wRT=30; runMed=NaN(1,length(allSCidx));
for iTr=wRT:length(allSCidx), runMed(iTr)=nanmedian(srtF(allSCidx(max(1,iTr-wRT+1):iTr))); end
plot(1:length(allSCidx),runMed,'-','Color',colRed,'LineWidth',2);
xlabel('Completed trial #'); ylabel('SRT (ms)');
title(sprintf('RT Time Course (w=%d)',wRT),'FontWeight','bold'); ylim([0 500]); box off;

subplot(1,3,3);
pRAfterR=[]; pRAfterL=[];
p23sc=find(p23m);
for iT=2:length(p23sc), prev=p23sc(iT-1); curr=p23sc(iT);
    if ~isnan(cs(prev))&&~isnan(cs(curr))
        if cs(prev)==2, pRAfterR(end+1)=cr(curr); else, pRAfterL(end+1)=cr(curr); end
    end; end
if ~isempty(pRAfterR)&&~isempty(pRAfterL)
    prR=mean(pRAfterR); prL=mean(pRAfterL);
    bar(1,prR,0.6,'FaceColor',colOrange,'EdgeColor','none'); hold on;
    bar(2,prL,0.6,'FaceColor',colBlue,'EdgeColor','none');
    [cloR,chiR]=binomCI(sum(pRAfterR),length(pRAfterR));
    [cloL,chiL]=binomCI(sum(pRAfterL),length(pRAfterL));
    errorbar([1 2],[prR prL],[prR-cloR,prL-cloL],[chiR-prR,chiL-prL],...
        'k','LineWidth',1.5,'CapSize',8,'LineStyle','none');
    yline(0.5,'k--','LineWidth',1);
    set(gca,'XTick',[1 2],'XTickLabel',{'After R','After L'});
    ylabel('P(Right) next'); title('Sequential Effects (P2-3)','FontWeight','bold'); ylim([0 1]);
    text(1,0.05,sprintf('n=%d',length(pRAfterR)),'HorizontalAlignment','center','FontSize',8);
    text(2,0.05,sprintf('n=%d',length(pRAfterL)),'HorizontalAlignment','center','FontSize',8);
end
box off;

sgtitle('Feb 25: Session Trajectory & Sequential Effects','FontWeight','bold','FontSize',14);
pdfSave(fig5,fullfile(outputDir,'fig05_feb25_trajectory.pdf'));

%% ====================== DONE ======================
fprintf('\n====== DONE ======\n');
fprintf('Figures saved to: %s\n', outputDir);
for i=1:5, fprintf('  fig%02d_*.pdf\n',i); end
close all;
end

%% ====================== HELPERS ======================
function v=safeField(s,fn,def)
    if isfield(s,fn), v=s.(fn); if isempty(v), v=def; end; else, v=def; end
end
function [ciLo,ciHi]=binomCI(k,n)
    if n==0, ciLo=0; ciHi=1; return; end
    z=1.96; phat=k/n; denom=1+z^2/n;
    center=(phat+z^2/(2*n))/denom;
    hw=(z*sqrt(phat*(1-phat)/n+z^2/(4*n^2)))/denom;
    ciLo=max(0,center-hw); ciHi=min(1,center+hw);
end
function pdfSave(fig,fname)
    try, exportgraphics(fig,fname,'ContentType','vector'); fprintf('  Saved: %s\n',fname);
    catch, print(fig,strrep(fname,'.pdf',''),'-dpdf','-bestfit'); fprintf('  Saved (print): %s\n',fname); end
end
