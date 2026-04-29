function verifyTrialArray()
% Quick verification of trial array counterbalancing

pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
p = conflict_task_settings;

% Minimal setup for initTrialStructure
p.trVars = p.trVarsInit;
p = initTrialStructure(p);

cols = struct();
colNames = p.init.trialArrayColumnNames;
for i = 1:length(colNames), cols.(colNames{i}) = i; end
ta = p.init.trialsArray;

% Phase 1 single-stim
p1single = ta(ta(:,cols.phaseNumber)==1 & ta(:,cols.singleStimSide)>0, :);
fprintf('\n=== Phase 1 SINGLE-STIM: %d trials ===\n', size(p1single,1));
fprintf('  Single-Left (HS=1):  %d\n', sum(p1single(:,cols.singleStimSide)==1));
fprintf('  Single-Right (HS=2): %d\n', sum(p1single(:,cols.singleStimSide)==2));

% Phase 1 dual-stim
p1dual = ta(ta(:,cols.phaseNumber)==1 & ta(:,cols.singleStimSide)==0, :);
fprintf('\n=== Phase 1 DUAL-STIM: %d trials ===\n', size(p1dual,1));
fprintf('  HS-Left:  %d\n', sum(p1dual(:,cols.highSalienceSide)==1));
fprintf('  HS-Right: %d\n', sum(p1dual(:,cols.highSalienceSide)==2));
fprintf('  DeltaT=0:   %d\n', sum(p1dual(:,cols.deltaT)==0));
fprintf('  DeltaT=125: %d\n', sum(p1dual(:,cols.deltaT)==125));

% Cross-tabulation: HS side x deltaT
for hs = [1 2]
    for dt = [0 125]
        n = sum(p1dual(:,cols.highSalienceSide)==hs & p1dual(:,cols.deltaT)==dt);
        if hs==1, sStr='HS-L'; else, sStr='HS-R'; end
        fprintf('  %s, dT=%+4d: %d trials\n', sStr, dt, n);
    end
end

% Phase 2 and 3
for ph = [2 3]
    phData = ta(ta(:,cols.phaseNumber)==ph, :);
    fprintf('\n=== Phase %d: %d trials ===\n', ph, size(phData,1));
    fprintf('  HS-Left:  %d\n', sum(phData(:,cols.highSalienceSide)==1));
    fprintf('  HS-Right: %d\n', sum(phData(:,cols.highSalienceSide)==2));
    fprintf('  RwdBig-Left:  %d\n', sum(phData(:,cols.rewardBigSide)==1));
    fprintf('  RwdBig-Right: %d\n', sum(phData(:,cols.rewardBigSide)==2));
end

% Show how Phase 1 dual-stim rows are ordered in the array
% (This is the order in the ARRAY, but chooseRow picks randomly)
p1dualRows = find(ta(:,cols.phaseNumber)==1 & ta(:,cols.singleStimSide)==0);
fprintf('\n=== Phase 1 dual-stim row ordering (first 30) ===\n');
fprintf('  (Note: chooseRow picks RANDOMLY from remaining, ignoring order)\n');
cumHSL = 0; cumHSR = 0;
for i = 1:min(30, length(p1dualRows))
    r = p1dualRows(i);
    hs = ta(r, cols.highSalienceSide);
    if hs==1, cumHSL=cumHSL+1; else, cumHSR=cumHSR+1; end
    fprintf('  %2d: row %3d HS=%d dT=%+4d  (cumul: L=%d R=%d)\n', ...
        i, r, hs, ta(r,cols.deltaT), cumHSL, cumHSR);
end

fprintf('\n=== REWARD PROBABILITY CHECK ===\n');
fprintf('  rewardProbHigh = %.2f\n', p.trVarsInit.rewardProbHigh);
fprintf('  Phase 2 canonical (big-right): %d/%d = %.1f%%\n', ...
    sum(ta(ta(:,cols.phaseNumber)==2, cols.rewardBigSide)==2), ...
    sum(ta(:,cols.phaseNumber)==2), ...
    100*mean(ta(ta(:,cols.phaseNumber)==2, cols.rewardBigSide)==2));
fprintf('  Phase 3 canonical (big-left):  %d/%d = %.1f%%\n', ...
    sum(ta(ta(:,cols.phaseNumber)==3, cols.rewardBigSide)==1), ...
    sum(ta(:,cols.phaseNumber)==3), ...
    100*mean(ta(ta(:,cols.phaseNumber)==3, cols.rewardBigSide)==1));

end
