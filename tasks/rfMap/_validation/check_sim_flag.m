function check_sim_flag()

t1 = load('/home/herman_lab/Documents/PLDAPS_vK2_MASTER/output/20260601_t1302_rfMap_denseChromatic/trial0001.mat');
fprintf('=== Trial 1 trVars ===\n');
if isfield(t1.trVars, 'useSimulatedSpikes')
    fprintf('trVars.useSimulatedSpikes: %d (class=%s)\n', ...
        t1.trVars.useSimulatedSpikes, class(t1.trVars.useSimulatedSpikes));
else
    fprintf('trVars.useSimulatedSpikes: FIELD DOES NOT EXIST\n');
end
if isfield(t1.trVars, 'passEye')
    fprintf('trVars.passEye: %d\n', t1.trVars.passEye);
else
    fprintf('trVars.passEye: FIELD DOES NOT EXIST\n');
end

p = load('/home/herman_lab/Documents/PLDAPS_vK2_MASTER/output/20260601_t1302_rfMap_denseChromatic/p.mat');
fprintf('\n=== p.mat levels ===\n');
if isfield(p.trVarsInit, 'useSimulatedSpikes')
    fprintf('trVarsInit.useSimulatedSpikes: %d (class=%s)\n', ...
        p.trVarsInit.useSimulatedSpikes, class(p.trVarsInit.useSimulatedSpikes));
else
    fprintf('trVarsInit.useSimulatedSpikes: FIELD DOES NOT EXIST\n');
end
if isfield(p.trVarsGuiComm, 'useSimulatedSpikes')
    fprintf('trVarsGuiComm.useSimulatedSpikes: %d (class=%s)\n', ...
        p.trVarsGuiComm.useSimulatedSpikes, class(p.trVarsGuiComm.useSimulatedSpikes));
else
    fprintf('trVarsGuiComm.useSimulatedSpikes: FIELD DOES NOT EXIST\n');
end
if isfield(p.trVars, 'useSimulatedSpikes')
    fprintf('trVars.useSimulatedSpikes (on p.mat): %d (class=%s)\n', ...
        p.trVars.useSimulatedSpikes, class(p.trVars.useSimulatedSpikes));
else
    fprintf('trVars.useSimulatedSpikes (on p.mat): FIELD DOES NOT EXIST\n');
end

fprintf('\n=== Ripple state ===\n');
fprintf('ripple.status: %d\n', p.rig.ripple.status);
if isfield(p.rig.ripple, 'recChans')
    fprintf('ripple.recChans: %d channels\n', numel(p.rig.ripple.recChans));
else
    fprintf('ripple.recChans: NOT SET\n');
end

fprintf('\n=== Spike data on trial 1 ===\n');
nSpk = numel(t1.trData.spikeTimes);
fprintf('nSpikes: %d\n', nSpk);
if nSpk > 0
    fprintf('spikeTimes range: [%.4f, %.4f]\n', ...
        min(t1.trData.spikeTimes), max(t1.trData.spikeTimes));
    fprintf('stimOn (timing): %.6f\n', t1.trData.timing.stimOn);
    fprintf('trialStartPTB: %.6f\n', t1.trData.timing.trialStartPTB);
    spkRelStimOn = t1.trData.spikeTimes - t1.trData.timing.stimOn;
    fprintf('spikes rel to stimOn: [%.4f, %.4f]\n', min(spkRelStimOn), max(spkRelStimOn));
    spkRelAbsStimOn = t1.trData.spikeTimes - (t1.trData.timing.trialStartPTB + t1.trData.timing.stimOn);
    fprintf('spikes rel to ABSOLUTE stimOn: [%.4f, %.4f]\n', min(spkRelAbsStimOn), max(spkRelAbsStimOn));
end

fprintf('\n=== Event data on trial 1 ===\n');
fprintf('eventValues: %s\n', mat2str(t1.trData.eventValues'));
fprintf('eventTimes:  %s\n', mat2str(t1.trData.eventTimes', 4));

% Check if simKernelBank was saved (it's stripped before save)
fprintf('\n=== simKernelBank ===\n');
if isfield(p.init, 'simKernelBank')
    fprintf('PRESENT (nSimulated=%d)\n', p.init.simKernelBank.nSimulated);
else
    fprintf('NOT present on p.mat (stripped before save)\n');
    % Check trial init
    if isfield(t1.init, 'simKernelBank')
        fprintf('PRESENT on trial1.init\n');
    else
        fprintf('NOT present on trial1.init either\n');
    end
end

end
