function report = validateBarsweepSession(varargin)
% report = validateBarsweepSession('sessionFolder', path, ...
%                                  'nevFile',       path, ...   % optional
%                                  'savePlots',     true)        % optional
%
% Offline pass/fail report on a recorded barsweep session. Implements the
% per-trial and across-session checks defined in plan §6.
%
% Two input modes for the Ripple event stream:
%   - nevFile present: read NPMK openNEV; use the contiguous Ripple
%     stream. Authoritative source.
%   - nevFile absent: concatenate p.trData.eventValues / eventTimes from
%     the per-trial trial####.mat files. A degenerate mode that catches
%     everything except a couple of hardware-side issues, useful before
%     NPMK is installed (plan §9 step 5). Note: the param batch and
%     trialEnd of the very last trial are lost in this mode because
%     pds.getRippleData drains the buffer BEFORE strobeTrialData+trialEnd
%     in barsweep_finish.m, so per-trial-N's eventValues actually contain
%     the param batch + trialEnd of trial N-1.
%
% Returns a struct report with .summary (top-line pass/fail counts) and
% .perTrial / .acrossSession sub-reports. Optionally saves the report
% and a multi-panel figure to the session folder.

%% --- Parse args. ---------------------------------------------------------
ip = inputParser;
ip.addParameter('sessionFolder', '', @(x) ischar(x) || isstring(x));
ip.addParameter('nevFile',       '', @(x) ischar(x) || isstring(x));
ip.addParameter('savePlots',     true, @islogical);
ip.addParameter('verbose',       true, @islogical);
ip.parse(varargin{:});
args = ip.Results;
sessionFolder = char(args.sessionFolder);
nevFile       = char(args.nevFile);
assert(~isempty(sessionFolder) && exist(sessionFolder, 'dir') == 7, ...
    'validateBarsweepSession: sessionFolder "%s" does not exist.', sessionFolder);

%% --- Load session-level p.mat. ------------------------------------------
pMatPath = fullfile(sessionFolder, 'p.mat');
assert(exist(pMatPath, 'file') == 2, ...
    'validateBarsweepSession: p.mat not found in %s.', sessionFolder);
pSession = load(pMatPath);
assert(isfield(pSession, 'init'), ...
    'validateBarsweepSession: p.mat missing top-level "init" struct.');
exptType = pSession.init.exptType;
codes    = pds.initCodes();

%% --- Discover trial files. ----------------------------------------------
trialFiles = dir(fullfile(sessionFolder, 'trial*.mat'));
trialFiles = trialFiles(~[trialFiles.isdir]);
% Sort by numeric trial index (lexicographic order is fine because of
% pds.saveP's %04d zero-padding, but be defensive).
[~, ord] = sort({trialFiles.name});
trialFiles = trialFiles(ord);

if args.verbose
    fprintf('validateBarsweepSession: %s\n', sessionFolder);
    fprintf('  exptType: %s\n', exptType);
    fprintf('  trial####.mat files found: %d\n', numel(trialFiles));
end

%% --- Build the (eventValues, eventTimes) stream. ------------------------
if ~isempty(nevFile)
    assert(exist('openNEV', 'file') == 2, ...
        ['validateBarsweepSession: nevFile passed but openNEV not on path. ' ...
         'Install NPMK or omit nevFile to use the per-trial-saved path.']);
    NEV = openNEV(nevFile, 'nosave', 'nomat'); %#ok<NASGU>
    % Strobed parallel word: low 15 bits of UnparsedData are the value.
    eventValues = double(bitand(NEV.Data.SerialDigitalIO.UnparsedData, 32767));
    eventTimes  = double(NEV.Data.SerialDigitalIO.TimeStampSec);
    streamSource = 'nev';
else
    [eventValues, eventTimes] = concatPerTrialEvents(trialFiles);
    streamSource = 'perTrial';
end
if args.verbose
    fprintf('  event stream source: %s (%d strobes total)\n', ...
        streamSource, numel(eventValues));
end

%% --- Decode the stream into structured trials. --------------------------
decoded = decodeRippleEvents(eventValues, eventTimes, codes);
if args.verbose
    fprintf('  decoded trials (by trialBegin/End brackets): %d\n', numel(decoded));
end

% Sanity: regime agreement.
agreedExpt = '';
for tt = 1:numel(decoded)
    if ~isempty(decoded(tt).exptType)
        agreedExpt = decoded(tt).exptType;
        break
    end
end
if ~isempty(agreedExpt) && ~strcmp(agreedExpt, exptType)
    warning('validateBarsweepSession:exptTypeMismatch', ...
        'p.init.exptType="%s" but decoded stream says "%s".', ...
        exptType, agreedExpt);
end

%% --- Per-trial check loop. ----------------------------------------------
nTrials = numel(decoded);
perTrial = repmat(makeEmptyPerTrial(), 1, nTrials);

% Build a map iTrial -> trialFile index (filenames look like trial0042.mat).
fileByITrial = containers.Map('KeyType', 'double', 'ValueType', 'any');
for ii = 1:numel(trialFiles)
    nm = trialFiles(ii).name;
    iT = sscanf(nm, 'trial%d.mat');
    if ~isempty(iT)
        fileByITrial(iT) = trialFiles(ii);
    end
end

% Frame duration for timing tolerance. From p.mat (rig).
frameDur = NaN;
if isfield(pSession, 'rig') && isfield(pSession.rig, 'frameDuration')
    frameDur = pSession.rig.frameDuration;
end
if ~isfinite(frameDur) || frameDur <= 0
    warning('validateBarsweepSession:frameDurationUnknown', ...
        'p.rig.frameDuration not in p.mat; using fallback 1/100 s for timing tolerance.');
    frameDur = 0.01;
end

for tt = 1:nTrials
    pt = perTrial(tt);
    pt.iTrial    = decoded(tt).iTrial;
    pt.outcome   = decoded(tt).outcome;
    pt.exptType  = decoded(tt).exptType;

    % Try to locate the matching trial####.mat (nonStart trials have none).
    trial = [];
    if ~isnan(pt.iTrial) && fileByITrial.isKey(pt.iTrial)
        trial = load(fullfile(sessionFolder, ...
            fileByITrial(pt.iTrial).name));
    end
    pt.haveTrialFile = ~isempty(trial);

    % Check 1: strobe inventory.
    [pt.check1.pass, pt.check1.detail] = checkStrobeInventory(decoded(tt), codes);

    % Check 4: ordering.
    [pt.check4.pass, pt.check4.detail] = checkOrdering(decoded(tt), codes);

    % Check 5: timing (needs the trial file for PLDAPS-side timing).
    if pt.haveTrialFile
        [pt.check5.pass, pt.check5.detail] = checkTiming(decoded(tt), trial, frameDur);
    else
        pt.check5.pass = NaN; pt.check5.detail = 'no trial file (nonStart)';
    end

    % Check 6: aborted-trial sanity.
    [pt.check6.pass, pt.check6.detail] = checkAbortedSanity(decoded(tt));

    % Check 2 + 3: param round-trip (forward eval) and encoding round-trip
    % (inverse decode). Need trial file to eval expressions against.
    if pt.haveTrialFile
        [pt.check2.pass, pt.check2.detail] = checkParamRoundTrip(decoded(tt), trial, codes);
        [pt.check3.pass, pt.check3.detail] = checkEncodingRoundTrip(decoded(tt), trial);
    else
        pt.check2.pass = NaN; pt.check2.detail = 'no trial file (nonStart)';
        pt.check3.pass = NaN; pt.check3.detail = 'no trial file (nonStart)';
    end

    pt.allPass = allChecksPass(pt);
    perTrial(tt) = pt;
end

%% --- Across-session checks. --------------------------------------------
acrossSession = struct();

% Check 8: trial-count consistency.
nBegin = nnz(eventValues == codes.trialBegin);
nEnd   = nnz(eventValues == codes.trialEnd);
nFiles = numel(trialFiles);
% In perTrial mode, the last trialEnd may or may not be present depending
% on the drain order of pds.getRippleData vs strobeTrialData; accept
% either nEnd == nBegin or nEnd == nBegin - 1. In nev mode require exact.
if strcmp(streamSource, 'perTrial')
    pass8 = (nEnd == nBegin) || (nEnd == nBegin - 1);
else
    pass8 = (nEnd == nBegin);
end
acrossSession.check8 = struct( ...
    'nBegin', nBegin, 'nEnd', nEnd, 'nFiles', nFiles, ...
    'streamSource', streamSource, ...
    'pass',   pass8);

% Check 9: pool integrity (basic version).
acrossSession.check9 = checkPoolIntegrity(trialFiles, sessionFolder, ...
    pSession.init.barsweepSchedule.angleList);

% Check 10: no strobes after barsweepSessionDone (last trialEnd).
% In 'nev' mode: lastTrialEndIdx = max(find(...)). Anything after must be empty.
% In 'perTrial' mode: last trialEnd is missing; defer to the no-op-cycle
% check via trialBegin count vs file count (the no-op cycle would create
% an extra trialBegin without a trial file, which the check would catch).
if strcmp(streamSource, 'nev') && nEnd > 0
    lastEndIdx = find(eventValues == codes.trialEnd, 1, 'last');
    after = eventValues(lastEndIdx + 1:end);
    acrossSession.check10 = struct( ...
        'nStrobesAfterLastTrialEnd', numel(after), ...
        'pass', isempty(after));
else
    acrossSession.check10 = struct( ...
        'pass', NaN, ...
        'detail', 'requires nev mode (per-trial mode drops last trialEnd)');
end

% Check 11 + 12: online-RF sidecar + reset snapshots.
[acrossSession.check11, acrossSession.check12, replayHistory] = ...
    checkOnlineRfReplay(sessionFolder, pSession, trialFiles, fileByITrial);

% Check 13: bypass-path sidecar invariant (acceptance criterion #8).
% Sidecar must be present iff useOnlineRF=true AND Ripple was alive AND
% the per-trial RF accumulator was actually enabled. Otherwise no
% sidecar may exist on disk.
acrossSession.check13 = checkBypassSidecarInvariant(sessionFolder, pSession);

%% --- Aggregate report. -------------------------------------------------
report = struct();
report.sessionFolder  = sessionFolder;
report.exptType       = exptType;
report.streamSource   = streamSource;
report.nDecodedTrials = nTrials;
report.nTrialFiles    = nFiles;
report.perTrial       = perTrial;
report.acrossSession  = acrossSession;

% Tally pass/fail. NaN = not applicable -> not counted as fail.
counts = struct('total', 0, 'pass', 0, 'fail', 0, 'na', 0);
checkNames = {'check1', 'check2', 'check3', 'check4', 'check5', 'check6'};
for tt = 1:nTrials
    for cc = 1:numel(checkNames)
        v = perTrial(tt).(checkNames{cc}).pass;
        counts.total = counts.total + 1;
        if isnan(v)
            counts.na   = counts.na   + 1;
        elseif v
            counts.pass = counts.pass + 1;
        else
            counts.fail = counts.fail + 1;
        end
    end
end
acrossNames = fieldnames(acrossSession);
for cc = 1:numel(acrossNames)
    v = acrossSession.(acrossNames{cc}).pass;
    counts.total = counts.total + 1;
    if isnan(v)
        counts.na   = counts.na   + 1;
    elseif v
        counts.pass = counts.pass + 1;
    else
        counts.fail = counts.fail + 1;
    end
end
report.summary = counts;
report.summary.allPass = (counts.fail == 0);

if args.verbose
    fprintf('\n================ SUMMARY ================\n');
    fprintf('  per-trial checks   : %d\n', 6 * nTrials);
    fprintf('  across checks      : %d\n', numel(acrossNames));
    fprintf('  total pass / fail / NA : %d / %d / %d\n', ...
        counts.pass, counts.fail, counts.na);
    if counts.fail == 0
        fprintf('  Result: PASS\n');
    else
        fprintf('  Result: FAIL\n');
        printFailures(report);
    end
end

%% --- Save report and figure. -------------------------------------------
if args.savePlots
    save(fullfile(sessionFolder, 'validationReport.mat'), 'report');
    figPath = fullfile(sessionFolder, 'validationReport.png');
    try
        renderReportFigure(report, decoded, frameDur, replayHistory, figPath);
        if args.verbose
            fprintf('  -> %s\n', figPath);
        end
    catch me
        warning('validateBarsweepSession:figureFailed', ...
            'Figure rendering failed: %s', me.message);
    end
end

end


%% ====================================================================
%% Stream construction
%% ====================================================================

function [vals, times] = concatPerTrialEvents(trialFiles)
vals = [];
times = [];
for ii = 1:numel(trialFiles)
    s = load(fullfile(trialFiles(ii).folder, trialFiles(ii).name), 'trData');
    if ~isfield(s, 'trData'), continue; end
    if ~isfield(s.trData, 'eventValues') || ~isfield(s.trData, 'eventTimes')
        continue
    end
    vals  = [vals;  double(s.trData.eventValues(:))]; %#ok<AGROW>
    times = [times; double(s.trData.eventTimes(:))]; %#ok<AGROW>
end
end


%% ====================================================================
%% Per-trial checks
%% ====================================================================

function pt = makeEmptyPerTrial()
emptyCheck = struct('pass', NaN, 'detail', '');
pt = struct( ...
    'iTrial',       NaN, ...
    'outcome',      'unknown', ...
    'exptType',     '', ...
    'haveTrialFile', false, ...
    'check1', emptyCheck, ...
    'check2', emptyCheck, ...
    'check3', emptyCheck, ...
    'check4', emptyCheck, ...
    'check5', emptyCheck, ...
    'check6', emptyCheck, ...
    'allPass', false);
end


function tf = allChecksPass(pt)
flds = {'check1', 'check2', 'check3', 'check4', 'check5', 'check6'};
tf = true;
for ii = 1:numel(flds)
    v = pt.(flds{ii}).pass;
    if isnan(v), continue; end       % NA does not fail
    tf = tf && v;
end
end


function [pass, detail] = checkStrobeInventory(tr, codes) %#ok<INUSD>
% §6.1: required events present, no extras outside the allowed set.
% required = backbone + aux (must appear). allowed = required + optional
% (extras outside allowed are flagged).
spec = canonicalSpecForOutcome(tr.outcome);
required = [spec.backbone, {spec.aux.name}];
allowed  = spec.allNames;
actualNames = tr.events.codeName;
missing = setdiff(required,    actualNames);
extra   = setdiff(actualNames, allowed);
pass = isempty(missing) && isempty(extra);
if pass
    detail = '';
else
    detail = sprintf('missing=[%s] extra=[%s]', ...
        strjoin(missing, ','), strjoin(extra, ','));
end
end


function [pass, detail] = checkOrdering(tr, codes) %#ok<INUSD>
% §6.4: backbone events appear in strict canonical order; aux events
% (currently just `reward` on trialComplete) appear within their
% documented window. Aux events are ordered loosely because their exact
% Ripple-time position depends on the polling-vs-flip race in
% drawMachine: `reward` is strobeNow during the polling iteration after
% the holdFixAndSweep -> trialComplete transition, while `stimOff` is
% postFlip-bound and waits for the next actual flip; the two can land
% in either order across runs.
spec = canonicalSpecForOutcome(tr.outcome);
actualNames = tr.events.codeName;

% Backbone: every name present and in order.
backboneIdx = nan(1, numel(spec.backbone));
for ii = 1:numel(spec.backbone)
    idx = find(strcmp(actualNames, spec.backbone{ii}), 1);
    if isempty(idx)
        pass = false;
        detail = sprintf('backbone event %s missing', spec.backbone{ii});
        return
    end
    backboneIdx(ii) = idx;
end
if ~isequal(backboneIdx, sort(backboneIdx))
    pass = false;
    detail = sprintf('backbone events out of canonical order; ord=[%s], expected=[%s]', ...
        strjoin(actualNames(backboneIdx)', ','), ...
        strjoin(spec.backbone, ','));
    return
end

% Aux events: present + within window.
for ii = 1:numel(spec.aux)
    ax = spec.aux(ii);
    auxIdx = find(strcmp(actualNames, ax.name), 1);
    if isempty(auxIdx)
        pass = false; detail = sprintf('aux event %s missing', ax.name); return
    end
    afterIdx  = find(strcmp(actualNames, ax.afterEvent),  1);
    beforeIdx = find(strcmp(actualNames, ax.beforeEvent), 1, 'last');
    if isempty(afterIdx) || isempty(beforeIdx) || ...
            auxIdx <= afterIdx || auxIdx >= beforeIdx
        pass = false;
        detail = sprintf('aux event %s outside window (%s, %s)', ...
            ax.name, ax.afterEvent, ax.beforeEvent);
        return
    end
end

pass = true;
detail = '';
end


function [pass, detail] = checkTiming(tr, trial, frameDur)
% §6.5: per-event delta vs PLDAPS-side timing within tolerance.
% postFlip: ±1 frame; strobeNow: ±1.5 ms.
%
% Both Ripple-side and PLDAPS-side times are aligned to the trialBegin
% strobe so the deltas are meaningful. The Ripple stream is naturally
% zeroed at trialBegin (tr.startTime). PLDAPS-side timing fields are
% recorded relative to trialStartPTB, which is set BEFORE the loop body
% (barsweep_run.m:29-30), so the PLDAPS-side trialBegin time is itself
% nonzero (the time PLDAPS took to enter the trialBegun state and fire
% the strobe). Subtract trial.trData.timing.trialBegin from each
% PLDAPS-side time to put both clocks on a common origin.
postFlipEvents = {'fixOn', 'stimOn', 'stimOff'};
strobeNowEvents = {'fixAq', 'fixBreak', 'nonStart', 'trialBegin', ...
                   'trialRunDone', 'trialEnd'};
postFlipTol = frameDur;
strobeNowTol = 1.5e-3;

t0Ripple = tr.startTime;
t0Pldaps = trial.trData.timing.trialBegin;
if ~(t0Pldaps > 0)
    % Cannot meaningfully align without a recorded PLDAPS trialBegin;
    % treat as unknown rather than fail.
    pass   = false;
    detail = 'PLDAPS-side timing.trialBegin missing or non-positive; cannot align';
    return
end

deltas = [];
labels = {};
for ii = 1:height(tr.events)
    nm = tr.events.codeName{ii};
    if ~isfield(trial.trData.timing, nm), continue; end
    tPldaps = trial.trData.timing.(nm);
    if tPldaps < 0, continue; end       % event never assigned
    tPldapsRel = tPldaps - t0Pldaps;
    tRippleRel = tr.events.time(ii) - t0Ripple;
    deltas(end + 1) = tRippleRel - tPldapsRel; %#ok<AGROW>
    labels{end + 1}  = nm; %#ok<AGROW>
end

isPostFlip   = ismember(labels, postFlipEvents);
isStrobeNow  = ismember(labels, strobeNowEvents);
absDelta     = abs(deltas);
overPostFlip = isPostFlip & (absDelta > postFlipTol);
overStrobe   = isStrobeNow & (absDelta > strobeNowTol);
pass = ~any(overPostFlip) & ~any(overStrobe);

% Sweep duration consistency: compare Ripple-side (stimOff-stimOn) to
% PLDAPS-side (timing.stimOff - timing.stimOn) directly. Both are real
% measurements of the same flips, so they should agree to within a frame.
% We deliberately do NOT compare to sweepDurationS_visible because that
% value is computed from p.rig.frameDuration in nextParams.m, which is
% a config-time *prediction* of frame duration -- if the rig's true
% refresh rate diverges from p.rig.frameDuration, sweepDurationS_visible
% will diverge from reality even though the actual flips (and therefore
% the strobes) are still consistent across the two clocks. That's a rig
% calibration issue, not a strobe-correctness issue.
%
% Skip on fixBreak: the bar truncates early on fixBreak by design, and
% stimOff may not fire at all (see canonicalSpecForOutcome).
swDurOk = true;
isFixBreak = strcmp(tr.outcome, 'fixBreak');
if ~isFixBreak
    onIdx  = find(strcmp(tr.events.codeName, 'stimOn'),  1);
    offIdx = find(strcmp(tr.events.codeName, 'stimOff'), 1);
    if ~isempty(onIdx) && ~isempty(offIdx) && ...
            isfield(trial.trData.timing, 'stimOn') && ...
            isfield(trial.trData.timing, 'stimOff') && ...
            trial.trData.timing.stimOn > 0 && trial.trData.timing.stimOff > 0
        swDurRipple = tr.events.time(offIdx) - tr.events.time(onIdx);
        swDurPldaps = trial.trData.timing.stimOff - trial.trData.timing.stimOn;
        swDurOk = abs(swDurRipple - swDurPldaps) <= frameDur;
        if ~swDurOk
            pass = false;
        end
    end
end

if pass
    detail = '';
else
    badIdx = find(overPostFlip | overStrobe);
    detail = sprintf('events out of tol: %s; sweepDurOk=%d', ...
        strjoin(labels(badIdx), ','), swDurOk);
end
end


function [pass, detail] = checkAbortedSanity(tr)
% §6.6: nonStart -> no stimOn/stimOff/fixBreak.
%       fixBreak -> stimOn present, stimOff follows it. Reward absent on aborts.
codeNames = tr.events.codeName;
hasOn   = any(strcmp(codeNames, 'stimOn'));
hasOff  = any(strcmp(codeNames, 'stimOff'));
hasBrk  = any(strcmp(codeNames, 'fixBreak'));
hasReward = any(strcmp(codeNames, 'reward'));    % shouldn't appear in events anyway
pass = true; detail = '';

switch tr.outcome
    case 'nonStart'
        if hasOn || hasOff || hasBrk || hasReward
            pass = false;
            detail = sprintf('nonStart sees on=%d off=%d brk=%d rwd=%d', ...
                hasOn, hasOff, hasBrk, hasReward);
        end
    case 'fixBreak'
        if ~hasOn || ~hasBrk
            pass = false;
            detail = sprintf('fixBreak missing on=%d brk=%d', hasOn, hasBrk);
        elseif hasReward
            pass = false;
            detail = 'fixBreak has reward strobe';
        elseif hasOff
            % stimOff is optional on fixBreak (see canonicalSpecForOutcome).
            % If present, must follow stimOn.
            onT  = tr.events.time(find(strcmp(codeNames, 'stimOn'),  1));
            offT = tr.events.time(find(strcmp(codeNames, 'stimOff'), 1, 'last'));
            if offT < onT
                pass = false; detail = 'stimOff present but precedes stimOn';
            end
        end
end
end


function [pass, detail] = checkParamRoundTrip(tr, trial, codes) %#ok<INUSD>
% §6.2: every (codeName, valueExpr) in p.init.strobeList eval'd against
% the trial's saved p reproduces the Ripple-decoded value.
sl = trial.init.strobeList;
nMis = 0;
mismatchNames = {};
for ii = 1:size(sl, 1)
    nm   = sl{ii, 1};
    expr = sl{ii, 2};
    % Build the eval-time scope: local variable `p` from the saved trial.
    try
        v = evalStrobeExpr(expr, trial);
    catch
        nMis = nMis + 1;
        mismatchNames{end + 1} = sprintf('%s(eval-failed)', nm); %#ok<AGROW>
        continue
    end
    if ~isfield(tr.params, nm), continue; end
    if ~isequal(double(v), double(tr.params.(nm)))
        nMis = nMis + 1;
        mismatchNames{end + 1} = sprintf('%s(saved=%s decoded=%s)', ...
            nm, mat2str(v), mat2str(tr.params.(nm))); %#ok<AGROW>
    end
end
pass = (nMis == 0);
if pass
    detail = '';
else
    detail = strjoin(mismatchNames, '; ');
end
end


function [pass, detail] = checkEncodingRoundTrip(tr, trial)
% §6.3: invert encoded params and verify they round-trip to the saved
% trVars/trData/init field. Uses the documented inversions in
% decodeRippleEvents (paramsDecoded). Compares against the canonical
% on-PLDAPS-side value, which for some params is a derived quantity
% (e.g. centerTheta is NOT a stored field; we synthesize it here).
mismatches = {};
pd = tr.paramsDecoded;
v  = trial.trVars;
in = trial.init;

addCheck = @(name, decoded, expected, tol) ...
    addMismatchIf(mismatches, name, decoded, expected, tol);

if isfield(pd, 'barsweepAngle_x10')
    expected = mod(v.pathAngleDeg, 360);
    mismatches = addCheck('pathAngleDeg', pd.barsweepAngle_x10, expected, 0.1);
end
if isfield(pd, 'barsweepCenterTheta_x10')
    expected = atan2d(v.pathCenterYDeg, v.pathCenterXDeg);
    mismatches = addCheck('pathCenterTheta', pd.barsweepCenterTheta_x10, expected, 0.1);
end
if isfield(pd, 'barsweepCenterRadius_x100')
    expected = hypot(v.pathCenterXDeg, v.pathCenterYDeg);
    mismatches = addCheck('pathCenterRadius', pd.barsweepCenterRadius_x100, expected, 0.01);
end
if isfield(pd, 'barsweepPathLength_x100')
    mismatches = addCheck('pathLengthDeg', pd.barsweepPathLength_x100, v.pathLengthDeg, 0.01);
end
if isfield(pd, 'barsweepSpeed_x100')
    mismatches = addCheck('speedDegPerSec', pd.barsweepSpeed_x100, v.speedDegPerSec, 0.01);
end
if isfield(pd, 'barsweepWidth_x100')
    mismatches = addCheck('barWidthDeg', pd.barsweepWidth_x100, v.barWidthDeg, 0.01);
end
if isfield(pd, 'barsweepLength_x100')
    mismatches = addCheck('barLengthDeg', pd.barsweepLength_x100, v.barLengthDeg, 0.01);
end
if isfield(pd, 'barsweepRfLatency')
    mismatches = addCheck('rfLatencyMs', pd.barsweepRfLatency, v.rfLatencyMs, 0.5);
end
if isfield(pd, 'barsweepRfPosBin_x100')
    mismatches = addCheck('rfPosBinDeg', pd.barsweepRfPosBin_x100, v.rfPosBinDeg, 0.01);
end
if isfield(pd, 'barsweepExptType') && ~strcmp(pd.barsweepExptType, in.exptType)
    mismatches{end + 1} = sprintf('exptType decoded=%s expected=%s', ...
        pd.barsweepExptType, in.exptType); %#ok<AGROW>
end
if isfield(pd, 'barsweepRfRampFilter') && ~strcmp(pd.barsweepRfRampFilter, v.rfRampFilter)
    mismatches{end + 1} = sprintf('rfRampFilter decoded=%s expected=%s', ...
        pd.barsweepRfRampFilter, v.rfRampFilter); %#ok<AGROW>
end
if isfield(pd, 'barsweepRfRampCutoff_x100')
    mismatches = addCheck('rfRampCutoff', pd.barsweepRfRampCutoff_x100, v.rfRampCutoff, 0.01);
end

pass = isempty(mismatches);
if pass
    detail = '';
else
    detail = strjoin(mismatches, '; ');
end
end


function mismatches = addMismatchIf(mismatches, name, decoded, expected, tol)
if abs(double(decoded) - double(expected)) > tol
    mismatches{end + 1} = sprintf('%s decoded=%g expected=%g', name, decoded, expected); %#ok<AGROW>
end
end


function v = evalStrobeExpr(expr, trial)
% Eval the strobe expression in a scope where `p` is reconstructed from
% the saved trial fields. Mirrors the call site in pds.strobeTrialData.
p = struct(); %#ok<NASGU>
p.trVars = trial.trVars;
p.trData = trial.trData;
p.status = trial.status;
p.init   = trial.init;
v = eval(expr);
end


function spec = canonicalSpecForOutcome(outcome)
% Returns:
%   spec.backbone   cell array of event names in strict canonical order
%   spec.aux        struct array of required events with positional
%                   constraints (window between two backbone events)
%   spec.optional   cell array of allowed-but-not-required event names;
%                   their presence is OK, their absence is OK, no
%                   ordering constraint is applied
%   spec.allNames   union of backbone + aux + optional, used by the
%                   inventory check to decide whether a given strobe
%                   is "extra" (i.e. truly unexpected)
%
% `reward` is an aux event on trialComplete: strobeNow inside the
% trialComplete state, fires sometime between stimOn and trialRunDone.
% Its Ripple-time position relative to stimOff is not deterministic
% (depends on polling-vs-flip race in drawMachine), so we constrain its
% window without enforcing a fixed slot.
%
% `stimOff` is OPTIONAL on fixBreak: barsweep_run.m:140 arms it as a
% postFlip strobe when fixBreak is detected, but the loop typically
% exits within 1-2 polling iterations (~sub-ms) of the fixBreak strobe,
% before drawMachine has a chance to flip. So in practice stimOff is
% almost always absent on fixBreak. We don't require it because (a)
% the design intent is that it stays flip-locked rather than degrading
% to strobeNow, and (b) on a trial where the animal broke fixation, the
% precise bar-offset time has no analytical value -- the fixBreak
% strobe itself is the trial-end marker.
emptyAux = struct('name', {}, 'afterEvent', {}, 'beforeEvent', {});
switch outcome
    case 'trialComplete'
        spec.backbone = {'trialBegin', 'fixOn', 'fixAq', 'stimOn', 'stimOff', ...
                         'trialRunDone', 'trialEnd'};
        spec.aux = struct('name', 'reward', ...
            'afterEvent', 'stimOn', 'beforeEvent', 'trialRunDone');
        spec.optional = {};
    case 'fixBreak'
        spec.backbone = {'trialBegin', 'fixOn', 'fixAq', 'stimOn', 'fixBreak', ...
                         'trialRunDone', 'trialEnd'};
        spec.aux      = emptyAux;
        spec.optional = {'stimOff'};
    case 'nonStart'
        spec.backbone = {'trialBegin', 'fixOn', 'nonStart', 'trialRunDone', 'trialEnd'};
        spec.aux      = emptyAux;
        spec.optional = {};
    otherwise
        spec.backbone = {'trialBegin', 'trialEnd'};
        spec.aux      = emptyAux;
        spec.optional = {};
end
spec.allNames = [spec.backbone, {spec.aux.name}, spec.optional];
end


%% ====================================================================
%% Across-session checks
%% ====================================================================

function info = checkPoolIntegrity(trialFiles, sessionFolder, angleList)
% §6.9 (basic). Walks per-trial p.status.barsweepPoolAtTrialStart snapshots
% and asserts each set draws angleList without replacement.

info = struct('pass', NaN, 'detail', '', 'nSetsObserved', 0);
poolsAtStart = {};
anglesShown  = [];
for ii = 1:numel(trialFiles)
    s = load(fullfile(sessionFolder, trialFiles(ii).name), 'status', 'trData');
    if isfield(s, 'status') && isfield(s.status, 'barsweepPoolAtTrialStart')
        poolsAtStart{end + 1} = s.status.barsweepPoolAtTrialStart; %#ok<AGROW>
    end
    if isfield(s, 'trData') && isfield(s.trData, 'pathAngleDeg')
        anglesShown(end + 1) = s.trData.pathAngleDeg; %#ok<AGROW>
    end
end
if isempty(poolsAtStart)
    info.detail = 'no per-trial barsweepPoolAtTrialStart snapshots';
    return
end

% A "set" is a consecutive run where pool-at-start sizes go N, N-1, ..., 1
% then back to N. Walk the snapshots and detect set boundaries.
sizes = cellfun(@numel, poolsAtStart);
nSetCompletes = sum(sizes(1:end - 1) == 1);   % a completed set ends right
                                              %  before the next size-N start.
info.nSetsObserved = nSetCompletes;

% Within-set draw-without-replacement: every consecutive snapshot inside
% a set must drop exactly one element from the front.
mismatches = 0;
for ii = 2:numel(poolsAtStart)
    prev = poolsAtStart{ii - 1};
    curr = poolsAtStart{ii};
    % If size dropped by 1 and current is prev(2:end), good.
    if numel(curr) == numel(prev) - 1 && isequal(curr(:), prev(2:end)')
        % ok
    elseif numel(curr) == numel(angleList)
        % start of a new set; verify it's a permutation of angleList.
        if ~isequal(sort(curr(:)'), sort(angleList(:)'))
            mismatches = mismatches + 1;
        end
    elseif numel(curr) == numel(prev)
        % aborted trial repeat (pool unchanged is OK)
    else
        mismatches = mismatches + 1;
    end
end
info.pass = (mismatches == 0);
if ~info.pass
    info.detail = sprintf('%d pool transitions are anomalous', mismatches);
end
end


function [c11, c12, replayHistory] = checkOnlineRfReplay(...
        sessionFolder, pSession, trialFiles, fileByITrial) %#ok<INUSL>
% §6.11: replay-vs-sidecar round-trip, broken by resets.
% §6.12: reset snapshot integrity (count + monotonic numbering).
%
% The persisted sidecar holds the accumulator state since the most
% recent reset, NOT cumulative-from-zero. To validate, we walk trial
% files in iTrial order, accumulating into a fresh accumulator, and
% at each reset boundary compare to that reset's snapshot, then zero.
% After the last reset, the remaining trials should match the final
% sidecar.
%
% The boundary trial for each reset is the snapshot's lastUpdateTrial:
% the reset path snapshots the OLD pre-reset accumulator before
% zeroing, so the snapshot's lastUpdateTrial is the iTrial of the
% last eligible trial that contributed to it.

c11 = struct('pass', NaN, 'detail', 'no sidecar found');
c12 = struct('pass', NaN, 'detail', 'no reset snapshots');
replayHistory = struct('used', false);

if ~isfield(pSession, 'init') || ~isfield(pSession.init, 'sessionId')
    return
end
sessionId = pSession.init.sessionId;

sidecar = fullfile(sessionFolder, [sessionId '_barsweepRF.mat']);
if exist(sidecar, 'file') ~= 2
    return
end
S = load(sidecar);
assert(isfield(S, 'barsweepRF'), 'sidecar missing barsweepRF struct');
finalPersisted = S.barsweepRF;

% Discover and load reset snapshots, sorted by N.
resetGlob = dir(fullfile(sessionFolder, [sessionId '_barsweepRF_reset*.mat']));
nums = nan(1, numel(resetGlob));
for ii = 1:numel(resetGlob)
    tok = regexp(resetGlob(ii).name, 'reset(\d+)\.mat$', 'tokens', 'once');
    if ~isempty(tok), nums(ii) = str2double(tok{1}); end
end
[nums, ord] = sort(nums);
resetGlob = resetGlob(ord);

resetSnapshots  = cell(1, numel(resetGlob));
resetBoundaries = nan(1, numel(resetGlob));
for ii = 1:numel(resetGlob)
    rs = load(fullfile(sessionFolder, resetGlob(ii).name));
    resetSnapshots{ii}  = rs.barsweepRF;
    resetBoundaries(ii) = rs.barsweepRF.lastUpdateTrial;
end

% Each range has its own schema: pathCenterDeg, positionEdges,
% pathLengthDeg, etc. depend on the spatial-knob configuration that was
% live during that range. Range k's configuration is the one that the
% live accumulator was operating with when the range's snapshot was
% taken (or, for the final range, when the session ended). Build a
% template per range by zero-ing the accumulator arrays of the
% corresponding snapshot/sidecar.
rangeTemplates = cell(1, numel(resetSnapshots) + 1);
for ii = 1:numel(resetSnapshots)
    rangeTemplates{ii} = zeroAccumulators(resetSnapshots{ii});
end
rangeTemplates{end} = zeroAccumulators(finalPersisted);

% Walk trial files in iTrial order. After each trial whose iTrial matches
% the next reset boundary, compare to that snapshot and switch to the
% next range's template before continuing.
keys = sort(cell2mat(fileByITrial.keys));
replayHistory.iTrials = keys;
replayHistory.perTrialState = cell(1, numel(keys));
nextResetIdx = 1;
rf = rangeTemplates{1};
rangeDiffs = struct('label', {}, 'spikeHist', {}, 'dwellTime', {}, ...
    'spikeCount', {}, 'trialsByDirection', {}, 'pass', {});

for kk = 1:numel(keys)
    iT = keys(kk);
    s = load(fullfile(sessionFolder, fileByITrial(iT).name));

    % Mimic the live path's sub-bin pathCenterDeg tracking. Per
    % barsweepRF_detectAndReset (barsweep_finish.m), a per-trial change in
    % p.trVars.pathCenterX/YDeg with magnitude < rf.rfPosBinDeg on every
    % axis is "absorbed" -- rf.pathCenterDeg is updated in place so future
    % accumulation uses the new origin, but the accumulator arrays are
    % preserved. Super-bin changes trigger a reset (handled by the range
    % boundary below). The replay must do the same in-place update or the
    % position-bin assignment for subsequent trials will diverge.
    livePathCenter = [s.trVars.pathCenterXDeg; s.trVars.pathCenterYDeg];
    delta = abs(livePathCenter - rf.pathCenterDeg);
    if all(delta < rf.rfPosBinDeg) && any(delta > 0)
        rf.pathCenterDeg = livePathCenter;
    end

    try
        rf = replayBarsweepRF(s, rf);
    catch me
        c11.detail = sprintf('replay failed at trial %d: %s', iT, me.message);
        return
    end
    replayHistory.perTrialState{kk} = rf;

    if nextResetIdx <= numel(resetBoundaries) && ...
            iT == resetBoundaries(nextResetIdx)
        d = computeRfDiff(rf, resetSnapshots{nextResetIdx}, ...
            sprintf('reset%d', nums(nextResetIdx)));
        rangeDiffs(end + 1) = d; %#ok<AGROW>
        nextResetIdx = nextResetIdx + 1;
        rf = rangeTemplates{nextResetIdx};
    end
end

% Any remaining reset boundaries with value 0 (zero-snapshot, plan §6.12
% warn-not-fail).
while nextResetIdx <= numel(resetBoundaries) && ...
        resetBoundaries(nextResetIdx) == 0
    d = computeRfDiff(rangeTemplates{nextResetIdx}, ...
        resetSnapshots{nextResetIdx}, ...
        sprintf('reset%d (zero-snapshot)', nums(nextResetIdx)));
    rangeDiffs(end + 1) = d; %#ok<AGROW>
    nextResetIdx = nextResetIdx + 1;
    if nextResetIdx <= numel(rangeTemplates)
        rf = rangeTemplates{nextResetIdx};
    end
end

% Compare the post-last-reset state to the final sidecar.
finalDiff = computeRfDiff(rf, finalPersisted, 'final');
rangeDiffs(end + 1) = finalDiff;

replayHistory.used        = true;
replayHistory.finalState  = rf;
replayHistory.rangeDiffs  = rangeDiffs;

% c11 passes if every range matched.
c11.pass = all([rangeDiffs.pass]);
c11.rangeDiffs = rangeDiffs;
if c11.pass
    c11.detail = sprintf('replay matches across %d range(s) (%d trials, %d resets)', ...
        numel(rangeDiffs), numel(keys), numel(resetGlob));
else
    failLabels = {rangeDiffs(~[rangeDiffs.pass]).label};
    c11.detail = sprintf('replay mismatch in: %s', strjoin(failLabels, ', '));
end

% c12: reset snapshot integrity. Monotonic 1..N, no gaps. Snapshots that
% are all-zero (boundary == 0) are noted but not failed.
if isempty(resetGlob)
    c12.detail = 'no reset snapshots present';
    return
end
expected = 1:numel(nums);
c12.pass = isequal(nums(:)', expected) && all(~isnan(nums));
zeroSnapshots = sum(resetBoundaries == 0);
if c12.pass
    c12.detail = sprintf('%d reset snapshots, monotonically 1..%d (boundaries=[%s], %d zero-snapshot warnings)', ...
        numel(nums), numel(nums), num2str(resetBoundaries), zeroSnapshots);
else
    c12.detail = sprintf('reset N values: %s (expected 1..%d, no gaps)', ...
        mat2str(nums), numel(nums));
end
end


function info = checkBypassSidecarInvariant(sessionFolder, pSession)
% Acceptance criterion #8: bypass-path sidecar invariant.
%
% Sidecar present iff useOnlineRF was true AND Ripple was alive at init
% AND the per-trial accumulator was enabled. We read the conditions from
% the saved p.mat (trVarsInit.useOnlineRF, rig.ripple.status) and the
% on-disk absence/presence of <sessionId>_barsweepRF.mat. Reset
% snapshots also must be absent when no main sidecar exists (they're
% only ever written from a bypass-disabled accumulator path).

info = struct('pass', NaN, 'detail', '');

useOnlineRF = false;
rippleStatus = false;
if isfield(pSession, 'trVarsInit') && isfield(pSession.trVarsInit, 'useOnlineRF')
    useOnlineRF = logical(pSession.trVarsInit.useOnlineRF);
end
if isfield(pSession, 'rig') && isfield(pSession.rig, 'ripple') && ...
        isfield(pSession.rig.ripple, 'status')
    rippleStatus = logical(pSession.rig.ripple.status);
end
if ~isfield(pSession, 'init') || ~isfield(pSession.init, 'sessionId')
    info.detail = 'p.init.sessionId missing; cannot resolve sidecar path';
    return
end
sessionId = pSession.init.sessionId;

mainSidecar  = fullfile(sessionFolder, [sessionId '_barsweepRF.mat']);
resetSidecars = dir(fullfile(sessionFolder, [sessionId '_barsweepRF_reset*.mat']));
hasMain  = exist(mainSidecar, 'file') == 2;
hasReset = ~isempty(resetSidecars);

expectSidecar = useOnlineRF && rippleStatus;

info.useOnlineRF   = useOnlineRF;
info.rippleStatus  = rippleStatus;
info.expectSidecar = expectSidecar;
info.hasMainSidecar  = hasMain;
info.hasResetSidecar = hasReset;

if expectSidecar
    info.pass = hasMain;        % main is mandatory; resets optional
    if info.pass
        info.detail = sprintf(['expected sidecar present (useOnlineRF=1, ripple.status=1); ' ...
            'main=1, reset_files=%d'], numel(resetSidecars));
    else
        info.detail = ['useOnlineRF=true and ripple.status=true but main sidecar is missing; ' ...
            'something prevented the per-trial sidecar write in barsweep_finish.m'];
    end
else
    info.pass = ~hasMain && ~hasReset;
    if info.pass
        if ~useOnlineRF
            info.detail = 'bypass run (useOnlineRF=false): no sidecar files written, as expected';
        else
            info.detail = 'bypass run (useOnlineRF=true but ripple.status=false): no sidecar files written, as expected';
        end
    else
        info.detail = sprintf(['bypass run (useOnlineRF=%d, ripple.status=%d) should not have ' ...
            'written any sidecar, but found main=%d, reset_files=%d'], ...
            useOnlineRF, rippleStatus, hasMain, numel(resetSidecars));
    end
end
end


function d = computeRfDiff(rfA, rfB, label)
d.label             = label;
d.spikeHist         = max(abs(rfA.spikeHist(:)         - rfB.spikeHist(:)));
d.dwellTime         = max(abs(rfA.dwellTime(:)         - rfB.dwellTime(:)));
d.spikeCount        = max(abs(rfA.spikeCount(:)        - rfB.spikeCount(:)));
d.trialsByDirection = max(abs(rfA.trialsByDirection(:) - rfB.trialsByDirection(:)));
d.pass = (d.spikeHist == 0) && (d.spikeCount == 0) && ...
    (d.trialsByDirection == 0) && (d.dwellTime <= 1e-9);
end


function rfZ = zeroAccumulators(rf)
% Return a copy of rf with the four accumulator arrays zeroed and
% lastUpdateTrial reset, but everything else (pathCenterDeg,
% positionEdges, schema fields, ...) preserved.
rfZ = rf;
rfZ.spikeHist         = zeros(size(rfZ.spikeHist));
rfZ.dwellTime         = zeros(size(rfZ.dwellTime));
rfZ.spikeCount        = zeros(size(rfZ.spikeCount));
rfZ.trialsByDirection = zeros(size(rfZ.trialsByDirection));
rfZ.lastUpdateTrial   = 0;
end


%% ====================================================================
%% Output
%% ====================================================================

function printFailures(report)
fprintf('\n--- failures ---\n');
flds = {'check1', 'check2', 'check3', 'check4', 'check5', 'check6'};
for tt = 1:numel(report.perTrial)
    pt = report.perTrial(tt);
    for ii = 1:numel(flds)
        c = pt.(flds{ii});
        if ~isnan(c.pass) && ~c.pass
            fprintf('  trial %d %s FAIL: %s\n', ...
                pt.iTrial, flds{ii}, c.detail);
        end
    end
end
acrossNames = fieldnames(report.acrossSession);
for cc = 1:numel(acrossNames)
    info = report.acrossSession.(acrossNames{cc});
    if ~isnan(info.pass) && ~info.pass
        d = '';
        if isfield(info, 'detail'), d = info.detail; end
        fprintf('  across %s FAIL: %s\n', acrossNames{cc}, d);
    end
end
end


function renderReportFigure(report, decoded, frameDur, replayHistory, figPath) %#ok<INUSD>
fig = figure('Visible', 'off', 'Position', [50 50 1400 900], 'Color', 'w');

% (a) Strobe inventory: trial x checkN matrix, color = pass/fail/NA.
ax1 = subplot(2, 3, 1);
checkFlds = {'check1', 'check2', 'check3', 'check4', 'check5', 'check6'};
M = NaN(numel(report.perTrial), numel(checkFlds));
for tt = 1:numel(report.perTrial)
    for cc = 1:numel(checkFlds)
        v = report.perTrial(tt).(checkFlds{cc}).pass;
        if isnan(v)
            M(tt, cc) = 0.5;        % NA = grey
        else
            M(tt, cc) = double(v);  % 1 = pass, 0 = fail
        end
    end
end
imagesc(ax1, M);
set(ax1, 'XTick', 1:numel(checkFlds), 'XTickLabel', ...
    {'inv', 'param', 'enc', 'order', 'time', 'abort'});
ylabel(ax1, 'trial #');
title(ax1, 'per-trial checks (1=pass, 0=fail, 0.5=NA)');
colormap(ax1, [1 0.5 0.5; 0.85 0.85 0.85; 0.5 1 0.5]);
colorbar(ax1);

% (b) Sweep duration histogram.
ax2 = subplot(2, 3, 2);
swDur = NaN(1, numel(decoded));
for tt = 1:numel(decoded)
    onIdx  = find(strcmp(decoded(tt).events.codeName, 'stimOn'),  1);
    offIdx = find(strcmp(decoded(tt).events.codeName, 'stimOff'), 1);
    if ~isempty(onIdx) && ~isempty(offIdx)
        swDur(tt) = decoded(tt).events.time(offIdx) - decoded(tt).events.time(onIdx);
    end
end
histogram(ax2, swDur(~isnan(swDur)), 30);
xlabel(ax2, 'stimOff - stimOn (s, Ripple)');
ylabel(ax2, 'count');
title(ax2, sprintf('sweep duration  (frame=%.4fs)', frameDur));

% (c) Outcome counts.
ax3 = subplot(2, 3, 3);
outcomes = {'trialComplete', 'fixBreak', 'nonStart'};
counts = zeros(1, 3);
for tt = 1:numel(decoded)
    idx = find(strcmp(outcomes, decoded(tt).outcome), 1);
    if ~isempty(idx), counts(idx) = counts(idx) + 1; end
end
bar(ax3, counts);
set(ax3, 'XTick', 1:3, 'XTickLabel', outcomes);
ylabel(ax3, 'trial count');
title(ax3, 'outcomes');

% (d) Param round-trip residual heatmap.
ax4 = subplot(2, 3, 4);
text(ax4, 0.05, 0.5, sprintf( ...
    ['cumulative RF replay vs sidecar:\n%s\n\nsee report.acrossSession.check11 ' ...
     'for max-abs diffs.'], ...
    report.acrossSession.check11.detail), 'Interpreter', 'none');
axis(ax4, 'off');
title(ax4, 'online-RF replay round-trip');

% (e) Trial-count consistency.
ax5 = subplot(2, 3, 5);
c8 = report.acrossSession.check8;
text(ax5, 0.05, 0.6, sprintf( ...
    'trialBegin: %d\ntrialEnd:   %d\ntrial####.mat: %d\npass: %d', ...
    c8.nBegin, c8.nEnd, c8.nFiles, c8.pass), 'FontName', 'Courier');
axis(ax5, 'off');
title(ax5, 'trial-count consistency');

% (f) Summary text.
ax6 = subplot(2, 3, 6);
s = report.summary;
text(ax6, 0.05, 0.6, sprintf( ...
    ['session: %s\nexptType: %s\nstream: %s\n\n' ...
     'pass=%d  fail=%d  NA=%d  total=%d\nResult: %s'], ...
    report.sessionFolder, report.exptType, report.streamSource, ...
    s.pass, s.fail, s.na, s.total, ...
    ternary(s.allPass, 'PASS', 'FAIL')), 'Interpreter', 'none');
axis(ax6, 'off');
title(ax6, 'summary');

exportgraphics(fig, figPath, 'Resolution', 120);
close(fig);
end


function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
