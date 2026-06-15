% check_real_fields.m  Check field names for offline reconstruction.
projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
outDir = fullfile(projRoot, 'output', '20260601_t1258_rfMap_denseChromatic');

d = load(fullfile(outDir, 'trial0001.mat'));

% DKL axes and contrasts
fprintf('Has dklAxes (trVars): %d\n', isfield(d.trVars, 'dklAxes'));
fprintf('Has dklContrasts (trVars): %d\n', isfield(d.trVars, 'dklContrasts'));
if isfield(d.trVars, 'dklAxes')
    fprintf('dklAxes: [%s]\n', num2str(d.trVars.dklAxes));
end
if isfield(d.trVars, 'dklContrasts')
    fprintf('dklContrasts: [%s]\n', num2str(d.trVars.dklContrasts));
end

% Check init fields
fprintf('\nHas dklAxes (init): %d\n', isfield(d.init, 'dklAxes'));
fprintf('Has dklContrasts (init): %d\n', isfield(d.init, 'dklContrasts'));

% chromaticTrialSeed
fprintf('\nchromaticTrialSeed: %d\n', d.trVars.chromaticTrialSeed);
fprintf('nFramesThisTrial: %d\n', d.trVars.nFramesThisTrial);

% Check if thisTrialDklDrive got saved
fprintf('\nHas thisTrialDklDrive: %d\n', isfield(d.trVars, 'thisTrialDklDrive'));
if isfield(d.trVars, 'thisTrialDklDrive')
    fprintf('thisTrialDklDrive size: [%s]\n', num2str(size(d.trVars.thisTrialDklDrive)));
    fprintf('thisTrialDklDrive empty: %d\n', isempty(d.trVars.thisTrialDklDrive));
end

% Trial array for seed column
fprintf('\nTrials array columns: %s\n', strjoin(d.init.trialArrayColumnNames, ', '));
fprintf('Trials array size: [%s]\n', num2str(size(d.init.trialsArray)));

% Event codes
fprintf('\nstimOn code: %d\n', d.init.codes.stimOn);

% Check spike counts in a few trials to understand the session
fprintf('\nSpike counts per trial (first 5):\n');
for ti = 1:5
    T = load(fullfile(outDir, sprintf('trial%04d.mat', ti)), 'trData');
    fprintf('  trial%04d: %d spikes, %d events\n', ti, ...
        numel(T.trData.spikeTimes), numel(T.trData.eventValues));
end

% Check trial 1 spike timing relative to stimOn
evIdx = find(d.trData.eventValues == d.init.codes.stimOn, 1, 'last');
if ~isempty(evIdx)
    stimOnT = d.trData.eventTimes(evIdx);
    fprintf('\nTrial 1 stimOn time: %.3f s\n', stimOnT);
    fprintf('Spike time range: [%.3f, %.3f]\n', min(d.trData.spikeTimes), max(d.trData.spikeTimes));
    trialDur = d.trVars.nFramesThisTrial * d.trVars.noiseFrameDurS;
    inWin = d.trData.spikeTimes >= stimOnT & d.trData.spikeTimes < stimOnT + trialDur;
    fprintf('Spikes in stimulus window: %d / %d\n', sum(inWin), numel(d.trData.spikeTimes));
end

exit;
