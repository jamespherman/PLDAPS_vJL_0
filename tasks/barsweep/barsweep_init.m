function p = barsweep_init(p)
%   p = barsweep_init(p)
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% Initialization function for barsweep task. Executed once after settings.

%% (1) define rig-specific information
p = pds.initRigConfigFile(p);

%% (2) define color look-up-table
p = initClut(p);

%% (3) initialize VIEWPixx/DATAPixx
p = pds.initDataPixx(p);

%% (4) define audio waveforms and load to VIEWPixx
p = pds.initAudio(p);

%% (5) define grid lines for experimenter display
p = pds.defineGridLines(p);

%% (6) define visual draw constants (luminance palette in CLUT terms)
p = defineVisuals(p);

%% (7) set task codes and unique task code
p.init.codes    = pds.initCodes;
p.init.taskCode = p.init.codes.uniqueTaskCode_barsweep;

%% (8) define classyStrobe
p.init.strb = pds.classyStrobe;

%% (9) initialize random seed
RandStream.setGlobalStream(RandStream('mt19937ar', 'Seed', sum(100 * clock)));

%% (10) initialize barsweep schedule
% angleList lives only here. The PLDAPS GUI cannot represent non-scalars
% (PLDAPS_vK2_GUI.m:54-63, :88-106 — scalar-only via str2double), so
% angleList is settings-file-only. The exptType field selects the schedule;
% rfmap12 broadens it to 12 directions (= 6 unique orientations after
% opposite-direction pooling) so iradon has enough angular coverage for
% filtered back-projection.
switch p.init.exptType
    case 'barsweep_cardinal4'
        p.init.barsweepSchedule.angleList = [0 90 180 270];
    case 'barsweep_rfmap12'
        p.init.barsweepSchedule.angleList = 0:30:330;
    otherwise
        error('barsweep_init: unknown exptType "%s". Expected barsweep_cardinal4 or barsweep_rfmap12.', ...
            p.init.exptType);
end

% setRepeats is lazy-frozen on the first _next.m call to capture the
% operator's GUI value at Run time (GUI edits flow through trVarsGuiComm
% post-Initialize). NaN sentinel so a stale value from a prior session
% cannot leak in.
p.init.barsweepSchedule.setRepeats  = NaN;

% Validate angleList: non-empty, all finite.
assert(~isempty(p.init.barsweepSchedule.angleList) && ...
    all(isfinite(p.init.barsweepSchedule.angleList)), ...
    'barsweep_init: angleList must be non-empty and finite.');

% Build initial shuffled pool. The pool exists from end of _init.m onward
% so that even a first-trial nonStart's initial p.mat write captures a
% real shuffled pool, not an empty placeholder. Pair-shuffle (when
% enabled) draws opposite-direction pairs as a unit; see §10 of the
% online RF mapping plan and supportFunctions/shuffleAngleList.m.
p.status.barsweepPool = shuffleAngleList( ...
    p.init.barsweepSchedule.angleList, ...
    p.trVarsInit.barsweepPairShuffle);
p.status.barsweepSetsCompleted = 0;

%% (11) compile-time strobeList validation
% Verify every code name in p.init.strobeList exists in p.init.codes.
% pds.strobeTrialData wraps each eval in a silent try/catch (see
% +pds/strobeTrialData.m:14), so a missing/typo'd code would otherwise
% drop that strobe with no warning at runtime.
nS = size(p.init.strobeList, 1);
for ii = 1:nS
    nm = p.init.strobeList{ii, 1};
    assert(isfield(p.init.codes, nm), ...
        ['barsweep_init: strobeList row ' num2str(ii) ' references ' ...
         'code "' nm '" which does not exist in p.init.codes. ' ...
         'Add it to +pds/initCodes.m or fix the strobeList entry.']);
end

%% (12) Ripple connection (only if online RF or online sort is requested)
% The legacy barsweep task did not initialize Ripple at all. Online RF
% mapping requires p.trData.spikeTimes/spikeClusters/eventTimes/
% eventValues, which pds.getRippleData populates. Initialize unconditionally
% so the legacy useOnlineRF=false code path still exercises Ripple if the
% user has connectRipple=1; the _finish.m guard skips accumulation when
% useOnlineRF=false regardless of Ripple state.
if p.trVarsInit.connectRipple
    p = pds.initRipple(p);
else
    p.rig.ripple.status   = false;
    p.rig.ripple.recChans = [];
end

%% (13) Online RF mapping setup (if requested)
if p.trVarsInit.useOnlineRF
    % Online sort and online RF can't coexist in v1: getRippleData
    % populates spikeClusters with channel index iff useOnlineSort=0
    % (see +pds/getRippleData.m:19-29 and rfMap_finish.m:147-155). The
    % accumulator keys off spikeClusters as channel index. Fail loudly
    % rather than silently misbehave.
    assert(p.trVarsInit.useOnlineSort == 0, ...
        ['barsweep_init: Online RF mapping requires p.trVars.useOnlineSort = 0; got %d. ' ...
         'Either disable online sort in the GUI or disable useOnlineRF.'], ...
        p.trVarsInit.useOnlineSort);

    if p.rig.ripple.status
        p = initBarsweepRF(p);
        p.init.barsweepRF.figData = initBarsweepRFDisplay(p);
    else
        warning('barsweep_init:rippleUnavailable', ...
            ['Online RF mapping requested (useOnlineRF=true) but Ripple is ' ...
             'not connected. Per-trial accumulation will be skipped. The ' ...
             'task will run normally otherwise.']);
        % Set a sentinel so _finish.m's guard short-circuits cleanly.
        p.init.barsweepRF = struct('enabled', false);
    end
end

end
