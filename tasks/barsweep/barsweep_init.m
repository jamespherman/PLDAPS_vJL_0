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
% angleList is settings-file-only. Edit barsweep_settings.m or this file
% to change angles.
p.init.barsweepSchedule.angleList   = [0 90 180 270];

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
% real shuffled pool, not an empty placeholder.
nA = numel(p.init.barsweepSchedule.angleList);
p.status.barsweepPool = ...
    p.init.barsweepSchedule.angleList(randperm(nA));
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

end
