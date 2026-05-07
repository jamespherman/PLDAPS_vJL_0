function report = auditSession(sessionPath, varargin)
% auditSession  Validate a saved rfMap session.
%
%   report = auditSession(sessionPath)
%   report = auditSession(sessionPath, 'NevPath',         '/path/to/file.nev', ...
%                                      'FrameTimingTol',  0.005, ...
%                                      'MissedFrameTol',  0.005, ...
%                                      'Verbose',         true)
%
% Phase 5d of the rfMap unified merge plan. Pure analyzer: takes a saved
% session (folder containing p.mat + trial<N>.mat) and reports pass/fail
% on six integrity checks. No infra changes, no rig time required.
%
% Inputs:
%   sessionPath    - Folder produced by pds.saveP. Must contain p.mat and
%                    trial<N>.mat files. (Concatenated single-file output
%                    from the GUI's "Concatenate Output" button is also
%                    supported as a string ending in .mat.)
%
% Optional name-value pairs:
%   'NevPath'        - Path to .nev recording (NPMK openNEV) for strobe
%                      cross-check. Default '' (skip cross-check).
%   'FrameTimingTol' - Allowed |mean(dt) - frameDuration| / frameDuration.
%                      Default 0.005 (0.5 %).
%   'MissedFrameTol' - Max fraction of inter-flip gaps exceeding
%                      1.5 * frameDuration. Default 0.005 (0.5 %).
%   'Verbose'        - Print human-readable report (default true).
%
% Output:
%   report - struct with fields:
%       .pass        (bool, overall)
%       .sessionId   (string)
%       .stimType    (string)
%       .formatVersion (int)
%       .nTrialsSaved, .nTrialsCompleted (int)
%       .checks      (struct: each check has .pass, .status, .detail)
%       .summary     (one-line text)
%
% Checks performed:
%   1. schema           - p.init has required fields; sessionFormatVersion
%                         in {1,2}; stimType is one of the four; taskCode
%                         is rfMap.
%   2. rng_roundtrip    - Regenerate the noise tensor twice from the saved
%                         seed and confirm byte-identical output. For
%                         chromatic v2 this is per-trial. Checkerboard
%                         is skipped (texture-pair, no time-indexed tensor).
%   3. strobe_coverage  - For every completed trial, every name in
%                         p.init.strobeList has its corresponding code
%                         present in p.trData(iTr).strobed.
%   4. strobe_nev       - If NevPath is given, every code that appeared
%                         in the in-task strobedList also appears in
%                         the NEV digital-event stream.
%   5. frame_timing     - mean(diff(flipTime)) within FrameTimingTol of
%                         p.rig.frameDuration; fraction of inter-flip
%                         gaps > 1.5 * frameDuration below MissedFrameTol.
%   6. checker_reversal - Phase 3 only. Without NEV: confirms saved
%                         checkInfo.framesPerReversal matches refresh /
%                         checkReversalHz. With NEV: confirms recorded
%                         rfMapCheckReversalEvent (16150) timestamps
%                         are spaced at 1 / checkReversalHz.
%
% Run from anywhere:
%   addpath tasks/rfMap/supportFunctions tasks/rfMap/_validation
%   r = auditSession('/path/to/session/folder');

%% --- parse inputs ----------------------------------------------------
ip = inputParser;
ip.addRequired('sessionPath', @(x) ischar(x) || isstring(x));
ip.addParameter('NevPath',         '',    @(x) ischar(x) || isstring(x));
ip.addParameter('FrameTimingTol',  0.005, @(x) isnumeric(x) && x > 0);
ip.addParameter('MissedFrameTol',  0.005, @(x) isnumeric(x) && x > 0);
ip.addParameter('Verbose',         true,  @islogical);
ip.parse(sessionPath, varargin{:});
opt = ip.Results;
sessionPath = char(opt.sessionPath);
nevPath = char(opt.NevPath);

%% --- load session ----------------------------------------------------
% pds.loadP handles the folder case. The concatenated-single-file case
% loads via plain `load` and reshapes to match the loadP output shape.
if exist(sessionPath, 'dir')
    p = pds.loadP(sessionPath);
elseif endsWith(sessionPath, '.mat', 'IgnoreCase', true) && exist(sessionPath, 'file')
    p = load(sessionPath);
else
    error('auditSession:badPath', ...
        'sessionPath is neither a folder nor a .mat file: %s', sessionPath);
end

if ~isfield(p, 'init') || ~isfield(p, 'trData')
    error('auditSession:notPldaps', ...
        ['Session at %s is missing p.init or p.trData; not a ' ...
         'PLDAPS session output.'], sessionPath);
end

nTrialsSaved = numel(p.trData);
if nTrialsSaved < 1
    error('auditSession:noTrials', ...
        ['No saved trials found in %s. PLDAPS only writes trial files ' ...
         'for trials that progressed past nonStart, so an empty session ' ...
         'is not auditable.'], sessionPath);
end
% rfMap completion state is p.state.noiseComplete = 21 (commonSettings).
completedMask = arrayfun(@(td) isfield(td, 'trialEndState') && ...
    td.trialEndState == p.state.noiseComplete, p.trData);
nCompleted = sum(completedMask);

report = initReport(p, sessionPath, nTrialsSaved, nCompleted);

%% --- load NEV once (if provided) -------------------------------------
% Both check_strobe_nev and check_checker_reversal need the digital event
% stream; loading once here halves the openNEV warnings and the I/O.
NEV = [];
if ~isempty(nevPath) && exist(nevPath, 'file') && exist('openNEV', 'file')
    NEV = openNEV(nevPath, 'noread', 'nosave', 'nomat');
end

%% --- run checks ------------------------------------------------------
report.checks.schema           = check_schema(p);
report.checks.rng_roundtrip    = check_rng_roundtrip(p, completedMask);
report.checks.strobe_coverage  = check_strobe_coverage(p, completedMask);
report.checks.strobe_nev       = check_strobe_nev(p, completedMask, nevPath, NEV);
report.checks.frame_timing     = check_frame_timing(p, completedMask, ...
    opt.FrameTimingTol, opt.MissedFrameTol);
report.checks.checker_reversal = check_checker_reversal(p, completedMask, nevPath, NEV);

%% --- summarise -------------------------------------------------------
checkNames = fieldnames(report.checks);
nPass = 0; nFail = 0; nOther = 0;
for k = 1:numel(checkNames)
    switch report.checks.(checkNames{k}).status
        case 'PASS', nPass = nPass + 1;
        case 'FAIL', nFail = nFail + 1;
        otherwise,   nOther = nOther + 1;  % SKIP / N/A
    end
end
report.pass = (nFail == 0);
report.summary = sprintf('%s (%d PASS, %d FAIL, %d N/A or SKIP)', ...
    ternary(report.pass, 'PASS', 'FAIL'), nPass, nFail, nOther);

if opt.Verbose
    printReport(report);
end

end % auditSession


%% =====================================================================
%% Sub-checks
%% =====================================================================

function r = check_schema(p)
% Required p.init fields per data_dictionaries/rfMap_data_dictionary.md.
required = {'taskName', 'taskCode', 'sessionFormatVersion', 'stimType', ...
    'sessionId', 'noiseRngSeed', 'noiseGridSize', 'nNoiseFrames', ...
    'codes', 'strobeList'};
missing = required(~isfield(p.init, required));

problems = {};
if ~isempty(missing)
    problems{end+1} = sprintf('missing fields: %s', strjoin(missing, ', '));
end
if isfield(p.init, 'taskName') && ~strcmp(p.init.taskName, 'rfMap')
    problems{end+1} = sprintf('taskName=%s (expected rfMap)', p.init.taskName);
end
if isfield(p.init, 'taskCode') && p.init.taskCode ~= 32020
    problems{end+1} = sprintf('taskCode=%d (expected 32020)', p.init.taskCode);
end
if isfield(p.init, 'sessionFormatVersion') && ...
        ~ismember(p.init.sessionFormatVersion, [1 2])
    problems{end+1} = sprintf('sessionFormatVersion=%d (supported: 1, 2)', ...
        p.init.sessionFormatVersion);
end
validStimTypes = {'denseAchromatic', 'denseChromatic', 'sparse', 'checkerboard'};
if isfield(p.init, 'stimType') && ~ismember(p.init.stimType, validStimTypes)
    problems{end+1} = sprintf('stimType=%s (expected one of %s)', ...
        p.init.stimType, strjoin(validStimTypes, '|'));
end

r = makeResult(isempty(problems), ...
    ternary(isempty(problems), ...
        sprintf('all required fields present, taskCode=32020, version %d', ...
            getField(p.init, 'sessionFormatVersion', NaN)), ...
        strjoin(problems, '; ')));
end


function r = check_rng_roundtrip(p, completedMask)
% Determinism check: regenerate the noise tensor twice from the saved
% seed and byte-compare. Confirms that (seed, params) is sufficient for
% offline reconstruction.
required = {'stimType', 'noiseRngSeed', 'noiseGridSize', 'nNoiseFrames'};
if ~all(isfield(p.init, required))
    miss = required(~isfield(p.init, required));
    r = makeResult(false, sprintf('cannot run: missing p.init.{%s}', ...
        strjoin(miss, ', ')));
    return;
end
stimType = p.init.stimType;
seed     = p.init.noiseRngSeed;
nY       = p.init.noiseGridSize(1);
nX       = p.init.noiseGridSize(2);

switch stimType
    case 'denseAchromatic'
        nFrames = p.init.nNoiseFrames;
        isBinary = true;
        if isfield(p.trVars, 'contrastBinary') && ~isempty(p.trVars(1).contrastBinary)
            isBinary = logical(p.trVars(1).contrastBinary);
        end
        m1 = generateStim_denseAchromatic(nY, nX, nFrames, isBinary, seed);
        m2 = generateStim_denseAchromatic(nY, nX, nFrames, isBinary, seed);
        ok = isequal(m1, m2);
        h = hashFingerprint(m1);
        r = makeResult(ok, sprintf('byte-identical regen, hash %s', h));

    case 'sparse'
        nFrames = p.init.nNoiseFrames;
        nSpots = p.trVars(1).nSparseSpots;
        m1 = generateStim_sparseBalanced(nY, nX, nFrames, nSpots, seed);
        m2 = generateStim_sparseBalanced(nY, nX, nFrames, nSpots, seed);
        ok = isequal(m1, m2);
        h = hashFingerprint(m1);
        r = makeResult(ok, sprintf('byte-identical regen, hash %s', h));

    case 'denseChromatic'
        % v2: per-trial seeds. Pull from trialsArray, regen each completed
        % trial's drive twice, byte-compare. v1: whole-session.
        if p.init.sessionFormatVersion >= 2
            seedCol = strcmp(p.init.trialArrayColumnNames, 'chromaticSeed');
            if ~any(seedCol)
                r = makeResult(false, ...
                    'sessionFormatVersion>=2 but no chromaticSeed column in trialsArray');
                return;
            end
            completedIdx = find(completedMask);
            if isempty(completedIdx)
                r = makeResult(true, 'no completed trials to regenerate (vacuous)');
                return;
            end
            % Sample first completed trial; regenerating every trial is
            % expensive and adds no information beyond "the generator is
            % deterministic" (the round-trip property does not depend on
            % which trial we pick).
            iTr = completedIdx(1);
            tSeed = double(p.init.trialsArray(iTr, seedCol));
            tFrames = p.trVars(iTr).trialEndFrame - p.trVars(iTr).trialStartFrame + 1;
            dklAxes = p.trVars(iTr).dklAxes;
            dklContrasts = p.trVars(iTr).dklContrasts;
            [m1, d1] = generateStim_denseChromatic(nY, nX, tFrames, ...
                dklAxes, dklContrasts, tSeed);
            [m2, d2] = generateStim_denseChromatic(nY, nX, tFrames, ...
                dklAxes, dklContrasts, tSeed);
            ok = isequal(m1, m2) && isequal(d1, d2);
            h = hashFingerprint(d1);
            r = makeResult(ok, sprintf( ...
                'per-trial regen byte-identical (sampled trial %d), drive hash %s', ...
                iTr, h));
        else
            % v1 whole-session
            nFrames = p.init.nNoiseFrames;
            dklAxes = p.trVars(1).dklAxes;
            dklContrasts = p.trVars(1).dklContrasts;
            [m1, d1] = generateStim_denseChromatic(nY, nX, nFrames, ...
                dklAxes, dklContrasts, seed);
            [m2, d2] = generateStim_denseChromatic(nY, nX, nFrames, ...
                dklAxes, dklContrasts, seed);
            ok = isequal(m1, m2) && isequal(d1, d2);
            h = hashFingerprint(d1);
            r = makeResult(ok, sprintf( ...
                'v1 whole-session regen byte-identical, drive hash %s', h));
        end

    case 'checkerboard'
        % Checkerboard is texture-pair pre-rendering, not a time-indexed
        % tensor. The relevant determinism check is that polarity-sequence
        % derivation (run-time) reproduces given the same RNG seed; that's
        % verified at session-init by prepareStim_checkerboard's validators.
        % Audit-side: confirm checkInfo struct is internally consistent.
        if ~isfield(p.init, 'checkInfo') || isempty(p.init.checkInfo)
            r = makeResult(false, 'checkerboard session missing p.init.checkInfo');
            return;
        end
        ci = p.init.checkInfo;
        expected = round(p.rig.refreshRate / p.trVars(1).checkReversalHz);
        ok = ci.framesPerReversal == expected;
        r = makeResult(ok, sprintf( ...
            'framesPerReversal=%d (expected %d at %.1f Hz refresh / %.2f Hz reversal); skipping tensor regen (texture pair)', ...
            ci.framesPerReversal, expected, p.rig.refreshRate, p.trVars(1).checkReversalHz));

    otherwise
        r = makeResult(false, sprintf('unknown stimType: %s', stimType));
end
end


function r = check_strobe_coverage(p, completedMask)
% For each completed trial, every code name listed in p.init.strobeList
% must have its integer code present in p.trData(iTr).strobed.
if ~isfield(p.init, 'strobeList') || ~isfield(p.init, 'codes')
    r = makeResult(false, 'p.init.strobeList or p.init.codes missing');
    return;
end
nCompleted = sum(completedMask);
if nCompleted == 0
    r = makeResult(true, 'no completed trials (vacuous)');
    return;
end

names  = p.init.strobeList(:, 1);
codeNums = nan(numel(names), 1);
for k = 1:numel(names)
    if isfield(p.init.codes, names{k})
        codeNums(k) = p.init.codes.(names{k});
    end
end
unknown = names(isnan(codeNums));
if ~isempty(unknown)
    r = makeResult(false, sprintf( ...
        'strobeList references codes missing from p.init.codes: %s', ...
        strjoin(unknown, ', ')));
    return;
end

% Per-trial coverage: every code in `names` should appear at least once
% in p.trData(iTr).strobed (which is a flat alternating [code, val, ...]
% array recorded by pds.classyStrobe).
completedIdx = find(completedMask);
trialMissing = cell(numel(completedIdx), 1);
for ii = 1:numel(completedIdx)
    iTr = completedIdx(ii);
    s = p.trData(iTr).strobed;
    if isempty(s)
        trialMissing{ii} = names; continue;
    end
    miss = names(~ismember(codeNums, s(:)));
    trialMissing{ii} = miss;
end
nWithMissing = sum(~cellfun(@isempty, trialMissing));
if nWithMissing == 0
    r = makeResult(true, sprintf('%d / %d strobeList codes present in all %d trials', ...
        numel(names), numel(names), nCompleted));
else
    % Aggregate: which codes were missing in any trial, and how often.
    allMissing = vertcat(trialMissing{:});
    [u, ~, ic] = unique(allMissing);
    counts = accumarray(ic, 1);
    detail = sprintf('%d / %d trials missing some code; offenders: %s', ...
        nWithMissing, nCompleted, ...
        strjoin(arrayfun(@(k) sprintf('%s (%d)', u{k}, counts(k)), ...
            1:numel(u), 'UniformOutput', false), ', '));
    r = makeResult(false, detail);
end
end


function r = check_strobe_nev(p, completedMask, nevPath, NEV)
if isempty(nevPath)
    r = makeResult(true, 'skipped (no NevPath provided)');
    r.status = 'SKIP';
    return;
end
if ~exist(nevPath, 'file')
    r = makeResult(false, sprintf('NevPath does not exist: %s', nevPath));
    return;
end
if ~exist('openNEV', 'file')
    r = makeResult(false, 'openNEV not found on path (NPMK install?)');
    return;
end
if isempty(NEV) || ~isfield(NEV, 'Data') || ~isfield(NEV.Data, 'SerialDigitalIO') || ...
        isempty(NEV.Data.SerialDigitalIO.UnparsedData)
    r = makeResult(false, 'NEV has no SerialDigitalIO data');
    return;
end
nevCodes = double(NEV.Data.SerialDigitalIO.UnparsedData(:));

% Aggregate the in-task strobed values from all completed trials.
inTask = [];
completedIdx = find(completedMask);
for ii = 1:numel(completedIdx)
    s = p.trData(completedIdx(ii)).strobed;
    if ~isempty(s), inTask = [inTask; s(:)]; end %#ok<AGROW>
end
if isempty(inTask)
    r = makeResult(false, 'in-task strobedList is empty across all completed trials');
    return;
end

% Coverage: every distinct in-task code value should also be present in
% the NEV stream. (Counts will not match exactly because the NEV stream
% includes between-trial events the in-task list does not record.)
inTaskUnique = unique(inTask);
nevSet = unique(nevCodes);
missing = setdiff(inTaskUnique, nevSet);
ok = isempty(missing);
detail = sprintf('%d unique in-task values, %d unique NEV values; %d missing in NEV%s', ...
    numel(inTaskUnique), numel(nevSet), numel(missing), ...
    ternary(isempty(missing), '', sprintf(' (e.g. %s)', ...
        mat2str(missing(1:min(5, end))))));
r = makeResult(ok, detail);
end


function r = check_frame_timing(p, completedMask, frameTol, missedTol)
if ~isfield(p.rig, 'frameDuration') || isempty(p.rig.frameDuration)
    r = makeResult(false, 'p.rig.frameDuration missing');
    return;
end
fd = p.rig.frameDuration;

completedIdx = find(completedMask);
if isempty(completedIdx)
    r = makeResult(true, 'no completed trials (vacuous)');
    return;
end

allDt = [];
for ii = 1:numel(completedIdx)
    iTr = completedIdx(ii);
    if ~isfield(p.trData(iTr), 'timing') || ~isfield(p.trData(iTr).timing, 'flipTime')
        continue;
    end
    ft = p.trData(iTr).timing.flipTime(:);
    ft = ft(ft > 0);
    if numel(ft) >= 2
        allDt = [allDt; diff(ft)]; %#ok<AGROW>
    end
end
if isempty(allDt)
    r = makeResult(false, 'no valid flipTime samples across completed trials');
    return;
end

meanDt = mean(allDt);
relErr = abs(meanDt - fd) / fd;
fracMissed = mean(allDt > 1.5 * fd);

okMean   = relErr  <= frameTol;
okMissed = fracMissed <= missedTol;
ok = okMean && okMissed;
detail = sprintf('mean dt = %.4f ms (target %.4f, |err| %.2f%%); missed %.3f%% (tol %.2f%%)', ...
    meanDt * 1000, fd * 1000, relErr * 100, fracMissed * 100, missedTol * 100);
r = makeResult(ok, detail);
end


function r = check_checker_reversal(p, completedMask, nevPath, NEV)
stimTypeStr = getField(p.init, 'stimType', '<unknown>');
if ~strcmp(stimTypeStr, 'checkerboard')
    r = makeResult(true, sprintf('N/A (stimType=%s)', stimTypeStr));
    r.status = 'N/A';
    return;
end

% In-task: framesPerReversal already validated in check_rng_roundtrip
% for checkerboard; this check focuses on reversal-event spacing.
if isempty(nevPath)
    r = makeResult(true, ...
        'in-task only: see rng_roundtrip for framesPerReversal sanity; supply NevPath for timestamp check');
    r.status = 'SKIP';
    return;
end
if isempty(NEV) || ~isfield(NEV, 'Data') || ~isfield(NEV.Data, 'SerialDigitalIO')
    r = makeResult(false, 'NEV unavailable or missing SerialDigitalIO');
    return;
end
sdio = NEV.Data.SerialDigitalIO;
codes = double(sdio.UnparsedData(:));
ts    = double(sdio.TimeStampSec(:));
revCode = p.init.codes.rfMapCheckReversalEvent; % 16150

% rfMapCheckReversalEvent is strobed code-then-value, so the code itself
% appears followed immediately by the polarity value. The reversal flips
% are at the timestamps of the code occurrences.
revIdx = find(codes == revCode);
if numel(revIdx) < 4
    r = makeResult(false, sprintf( ...
        'only %d rfMapCheckReversalEvent strobes in NEV (expected many)', ...
        numel(revIdx)));
    return;
end
revTs = ts(revIdx);
revDt = diff(revTs);
expDt = 1 / p.trVars(1).checkReversalHz;
% Reversal events span trial boundaries; large gaps between trials are
% expected. Filter to the median-cluster of dts (within 50 % of expected)
% to avoid contaminating the cadence estimate with inter-trial gaps.
inCluster = revDt > 0.5 * expDt & revDt < 1.5 * expDt;
medDt = median(revDt(inCluster));
relErr = abs(medDt - expDt) / expDt;
ok = relErr <= 0.02; % 2 % absolute cadence tolerance
detail = sprintf('NEV reversal cadence: median %.3f ms (target %.3f, |err| %.2f%%) over %d events', ...
    medDt * 1000, expDt * 1000, relErr * 100, numel(revIdx));
r = makeResult(ok, detail);
end


%% =====================================================================
%% Helpers
%% =====================================================================

function rep = initReport(p, sessionPath, nSaved, nCompleted)
rep = struct();
rep.sessionId = getField(p.init, 'sessionId', '<unknown>');
rep.sessionPath = sessionPath;
rep.stimType = getField(p.init, 'stimType', '<unknown>');
rep.formatVersion = getField(p.init, 'sessionFormatVersion', NaN);
rep.nTrialsSaved = nSaved;
rep.nTrialsCompleted = nCompleted;
rep.checks = struct();
rep.pass = false;
rep.summary = '';
end


function r = makeResult(pass, detail)
r = struct('pass', logical(pass), ...
           'status', ternary(pass, 'PASS', 'FAIL'), ...
           'detail', detail);
end


function v = getField(s, name, default)
if isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = default;
end
end


function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end


function h = hashFingerprint(x)
% 8-character truncated hash of array contents. Pure determinism check
% across runs; not cryptographic. Uses Java's MD5 which is always
% available in MATLAB.
md = java.security.MessageDigest.getInstance('MD5');
md.update(uint8(typecast(x(:), 'uint8')));
b = typecast(md.digest, 'uint8');
h = sprintf('%02x', b(1:4));
end


function printReport(rep)
fprintf('\n=== rfMap session audit: %s ===\n', rep.sessionId);
fprintf('   Path:           %s\n', rep.sessionPath);
fprintf('   Stim type:      %s\n', rep.stimType);
fprintf('   Format version: %d\n', rep.formatVersion);
fprintf('   Trials saved:   %d  (%d completed)\n\n', ...
    rep.nTrialsSaved, rep.nTrialsCompleted);

names = fieldnames(rep.checks);
% Pretty labels
labels = struct( ...
    'schema',           'Schema check', ...
    'rng_roundtrip',    'RNG round-trip', ...
    'strobe_coverage',  'Strobe coverage (in-task)', ...
    'strobe_nev',       'Strobe NEV cross-check', ...
    'frame_timing',     'Frame timing', ...
    'checker_reversal', 'Checkerboard reversal');
for k = 1:numel(names)
    c = rep.checks.(names{k});
    label = labels.(names{k});
    fprintf('[ %d/%d ] %-30s %-4s  %s\n', k, numel(names), ...
        label, c.status, c.detail);
end
fprintf('\nOverall: %s\n\n', rep.summary);
end
