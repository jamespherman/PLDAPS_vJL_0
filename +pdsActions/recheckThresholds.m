function p = recheckThresholds(p)
% pdsActions.recheckThresholds  GUI-callable active threshold recheck.
%
% Runs pds.recheckSpikeThresholds: briefly acquires noise waveforms
% (0.3s at -3 uV test threshold) and compares current noise RMS to
% the init-time baseline. Reports per-channel drift to the command
% window. If p.trVarsInit.threshAutoAdjust is true, drifted channels
% get their thresholds updated.
%
% Call between trials via the PLDAPS GUI action menu.

if ~isfield(p.rig, 'ripple') || ~p.rig.ripple.status
    fprintf('recheckThresholds: Ripple not connected.\n');
    return;
end

fprintf('\n=== THRESHOLD RECHECK (active RMS estimation) ===\n');
p = pds.recheckSpikeThresholds(p);

if isfield(p.status, 'threshRecheck')
    rc = p.status.threshRecheck;
    if ~isempty(rc.initSigma) && any(~isnan(rc.currentSigma))
        valid = ~isnan(rc.currentSigma) & ~isnan(rc.initSigma);
        fprintf('  Init sigma range:    %.2f - %.2f uV\n', ...
            min(rc.initSigma(valid)), max(rc.initSigma(valid)));
        fprintf('  Current sigma range: %.2f - %.2f uV\n', ...
            min(rc.currentSigma(valid)), max(rc.currentSigma(valid)));
        fprintf('  Drift ratio range:   %.2f - %.2f\n', ...
            min(rc.sigmaRatio(valid)), max(rc.sigmaRatio(valid)));
    end
end
fprintf('=== END THRESHOLD RECHECK ===\n\n');

end
