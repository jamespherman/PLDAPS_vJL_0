function probeFeb23()
pldapsHome = fileparts(which('PLDAPS_vK2_GUI.m'));
data = load(fullfile(pldapsHome, 'output', '20260223_t1016_conflict_task.mat'));
if isfield(data,'p'), p=data.p; else p=data; end
nTrials = length(p.trData);
fprintf('nTrials: %d\n', nTrials);

allDT = arrayfun(@(x) x.deltaT, p.trVars(:)');
allPh = arrayfun(@(x) x.phaseNumber, p.trVars(:)');
allRW = arrayfun(@(x) x.responseWindow, p.trVars(:)');

fprintf('Phases present: %s\n', mat2str(unique(allPh)));
fprintf('DeltaT values (all): %s\n', mat2str(unique(allDT(~isnan(allDT)))'));
p23DT = allDT(allPh>=2);
if ~isempty(p23DT), fprintf('DeltaT values (P2-3): %s\n', mat2str(unique(p23DT(~isnan(p23DT)))'));  end
fprintf('ResponseWindow: %s\n', mat2str(unique(allRW)));

if isfield(p.trVars, 'rewardRatioBig')
    allRR = arrayfun(@(x) x.rewardRatioBig, p.trVars(:)');
    fprintf('RewardRatioBig: %s\n', mat2str(unique(allRR(~isnan(allRR)))));
end
if isfield(p.trVars, 'rewardProbHigh')
    allRP = arrayfun(@(x) x.rewardProbHigh, p.trVars(:)');
    fprintf('RewardProbHigh: %s\n', mat2str(unique(allRP(~isnan(allRP)))));
end

for ph = unique(allPh)
    fprintf('Phase %d: %d trials\n', ph, sum(allPh==ph));
end

sacSt = p.state.sacComplete;
endSt = arrayfun(@(x) x.trialEndState, p.trData(:)');
fprintf('sacComplete: %d\n', sum(endSt==sacSt));
fprintf('fixBreak: %d\n', sum(endSt==p.state.fixBreak));
fprintf('noResponse: %d\n', sum(endSt==p.state.noResponse));
fprintf('inaccurate: %d\n', sum(endSt==p.state.inaccurate));

if isfield(p.trVars, 'singleStimSide')
    ss = arrayfun(@(x) x.singleStimSide, p.trVars(:)');
    fprintf('Single-stim trials: %d\n', sum(ss > 0));
end

fprintf('States: %s\n', strjoin(fieldnames(p.state), ', '));
end
