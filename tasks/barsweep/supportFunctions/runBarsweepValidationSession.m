function p = runBarsweepValidationSession(regime, varargin)
% p = runBarsweepValidationSession(regime, ...)
%
% Convenience wrapper for the rig-side dry-run validation pass (plan §7).
% Loads the requested settings file, applies the dry-run defaults
% described below, and prints rig-side instructions. Returns the loaded
% p struct so the experimenter can hand it to the GUI's Initialize step
% without further edits.
%
% This wrapper does NOT start the trial loop and does NOT touch Trellis.
% The experimenter:
%   1. starts Trellis recording manually,
%   2. calls runBarsweepValidationSession('cardinal4') (or 'rfmap12'),
%   3. clicks Initialize then Run in the PLDAPS GUI,
%   4. introduces fixBreak / nonStart perturbations (§7) until the
%      per-outcome targets are met, then lets the schedule terminate
%      naturally so the post-completion no-op cycle is exercised in-band.
%
% regime: 'cardinal4' | 'rfmap12'
%
% Optional name-value args:
%   'setRepeats'      Override schedule setRepeats (default chosen so the
%                     full pass yields ~200 trials).
%   'fixWaitDur'      Seconds to wait for fixation acquisition (default
%                     5.0 — generous so eye-tracker-off mode rarely
%                     triggers spurious nonStart).
%   'iti'             Inter-trial interval seconds (default 0.5).
%   'mouseEyeSim'     Use mouseEyeSim instead of eye-tracker-off mode
%                     (default false). Fall back to true if the rig's
%                     baseline eye-signal noise is pushing the gaze
%                     indicator out of the fix window unpredictably.
%   'useOnlineRF'     Default true (the validation pass exercises the
%                     online-RF path as well as the strobe path).

ip = inputParser;
ip.addRequired('regime', @(x) ischar(x) || isstring(x));
ip.addParameter('setRepeats',    [], @(x) isempty(x) || (isscalar(x) && x >= 1));
ip.addParameter('fixWaitDur',    5.0, @(x) isscalar(x) && x > 0);
ip.addParameter('iti',           0.5, @(x) isscalar(x) && x >= 0);
ip.addParameter('mouseEyeSim',   false, @islogical);
ip.addParameter('useOnlineRF',   true,  @islogical);
ip.parse(regime, varargin{:});
opt = ip.Results;
regime = char(opt.regime);

switch lower(regime)
    case 'cardinal4'
        p = barsweep_cardinal4_settings();
        defaultRepeats = 50;       % 50 reps * 4 angles = 200 trials
    case 'rfmap12'
        p = barsweep_rfmap12_settings();
        defaultRepeats = 17;       % 17 reps * 12 angles = 204 trials
    otherwise
        error('runBarsweepValidationSession:badRegime', ...
            'Unknown regime "%s". Expected cardinal4 or rfmap12.', regime);
end

if isempty(opt.setRepeats)
    opt.setRepeats = defaultRepeats;
end

% Apply dry-run overrides. These DO NOT modify the on-disk settings file
% -- they only mutate the returned struct.
p.trVarsInit.setRepeats     = opt.setRepeats;
p.trVarsInit.fixWaitDur     = opt.fixWaitDur;
p.trVarsInit.iti            = opt.iti;
p.trVarsInit.mouseEyeSim    = double(opt.mouseEyeSim);
p.trVarsInit.useOnlineRF    = opt.useOnlineRF;
% Mirror to trVarsGuiComm so the GUI shows the dry-run defaults.
p.trVarsGuiComm = p.trVarsInit;

% Print the rig-side checklist so the experimenter doesn't have to reread
% plan §7 every time.
fprintf('\n========================================================\n');
fprintf('  Barsweep validation session: regime=%s\n', regime);
fprintf('========================================================\n');
fprintf('  Settings overrides applied:\n');
fprintf('    setRepeats   : %d  (~%d trials at full schedule)\n', ...
    opt.setRepeats, opt.setRepeats * numel(angleListForRegime(regime)));
fprintf('    fixWaitDur   : %.2f s\n', opt.fixWaitDur);
fprintf('    iti          : %.2f s\n', opt.iti);
fprintf('    mouseEyeSim  : %d (%s)\n', double(opt.mouseEyeSim), ...
    ternary(opt.mouseEyeSim, 'fallback', 'eye-tracker-off mode'));
fprintf('    useOnlineRF  : %d\n', opt.useOnlineRF);
fprintf('\n');
fprintf('  Per plan §7, before pressing Run:\n');
fprintf('    1. Confirm Trellis is recording to .nev (cardinal4: barsweep_cardinal4_validation_YYYYMMDD.nev)\n');
fprintf('    2. Confirm NPMK is on the path: exist(''openNEV'', ''file'') == 2\n');
fprintf('    3. Run auditBarsweepStrobes(''%s'') and confirm it prints PASS\n', regime);
fprintf('\n');
fprintf('  During the run, periodically introduce perturbations (§2):\n');
fprintf('    fixBreak : disturb the eye-position signal (or shrink fix window) mid-sweep\n');
fprintf('    nonStart : shrink fix window below baseline noise OR offset fix point\n');
fprintf('  Per-outcome targets (sufficient for a thorough pass):\n');
fprintf('    ~100 trialComplete (default; no intervention)\n');
fprintf('    ~50 fixBreak\n');
fprintf('    ~50 nonStart\n');
fprintf('\n');
fprintf('  Mid-session, deliberately edit a spatial knob (e.g. nudge\n');
fprintf('  pathCenterXDeg past one bin width, or change rfPosBinDeg) at\n');
fprintf('  least once to force an online-RF reset. Make at least one\n');
fprintf('  sub-bin pathCenterDeg move that should NOT trigger a reset.\n');
fprintf('\n');
fprintf('  Let the run terminate naturally on barsweepSessionDone so the\n');
fprintf('  post-completion no-op cycle is exercised in-band, then stop\n');
fprintf('  Trellis recording.\n');
fprintf('\n');
fprintf('  After the run, validate:\n');
fprintf('    report = validateBarsweepSession( ...\n');
fprintf('        ''sessionFolder'', ''%s'', ...\n', p.init.sessionFolder);
fprintf('        ''nevFile'',       ''<path-to-nev>'');\n');
fprintf('========================================================\n\n');

end


function al = angleListForRegime(regime)
switch lower(regime)
    case 'cardinal4', al = [0 90 180 270];
    case 'rfmap12',   al = 0:30:330;
end
end


function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
