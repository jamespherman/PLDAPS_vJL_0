function report = auditBarsweepStrobes(target)
% report = auditBarsweepStrobes(target)
%
% Static lint pass for the barsweep strobe surface. Run from the MATLAB
% command line before pressing Initialize. No hardware required.
%
% Verifies, against the on-disk barsweep settings file(s) and the current
% +pds/initCodes.m, that:
%   1. Every code name in p.init.strobeList exists in p.init.codes.
%   2. Every p.init.codes.<name> reference in barsweep_run.m and
%      barsweep_finish.m resolves in initCodes (catches typos in
%      hardcoded event strobes that strobeTrialData's silent try/catch
%      would otherwise swallow without a runtime error).
%   3. Every value expression in column 2 of p.init.strobeList eval's
%      against several worst-case synthetic trVars configurations and
%      yields a scalar nonneg integer in [0, 32767] (DataPixx 15-bit).
%   4. Every timing field used by _run.m / _finish.m is initialized to
%      "-1" in _settings.m (plus flipIdxStimOn).
%   5. pds.barsweepRampFilterEnum returns an integer in [1, 4] for the
%      configured rfRampFilter string.
%   6. useOnlineSort == 0 whenever useOnlineRF == true.
%   7. rfNChannels is a sane positive integer (soft warning).
%   8. For barsweep_rfmap12_settings.m: barsweepExptType evaluates to 2
%      and the two appended rows (barsweepRfRampCutoff_x100,
%      barsweepRfRampFilter) are present. For barsweep_cardinal4_settings.m:
%      barsweepExptType evaluates to 1 and the rfmap12-only rows are
%      absent.
%
% target: 'cardinal4' | 'rfmap12' | 'all' (default 'all').
%
% Returns a struct: report.errors, report.warnings, and one sub-struct
% per audited settings file with per-check details. Prints per-check
% [OK]/[WARN]/[ERROR] lines and a final PASS/FAIL line. A clean run
% prints zero [ERROR] lines.

if nargin < 1 || isempty(target)
    target = 'all';
end

switch lower(target)
    case 'all'
        settingsToAudit = {'barsweep_cardinal4_settings', 'barsweep_rfmap12_settings'};
    case 'cardinal4'
        settingsToAudit = {'barsweep_cardinal4_settings'};
    case 'rfmap12'
        settingsToAudit = {'barsweep_rfmap12_settings'};
    otherwise
        error('auditBarsweepStrobes:badTarget', ...
            'Unknown target "%s". Expected cardinal4, rfmap12, or all.', target);
end

codes = pds.initCodes();

runPath    = which('barsweep_run');
finishPath = which('barsweep_finish');
assert(~isempty(runPath), ...
    'auditBarsweepStrobes: cannot locate barsweep_run.m on path.');
assert(~isempty(finishPath), ...
    'auditBarsweepStrobes: cannot locate barsweep_finish.m on path.');

report          = struct();
report.errors   = 0;
report.warnings = 0;

for ii = 1:numel(settingsToAudit)
    name = settingsToAudit{ii};
    fprintf('\n================ Auditing %s ================\n', name);
    [r, errs, warns] = auditOneSettingsFile(name, codes, runPath, finishPath);
    report.(name)   = r;
    report.errors   = report.errors   + errs;
    report.warnings = report.warnings + warns;
end

fprintf('\n================ SUMMARY ================\n');
fprintf('Total errors   : %d\n', report.errors);
fprintf('Total warnings : %d\n', report.warnings);
if report.errors == 0
    fprintf('Result         : PASS\n');
else
    fprintf('Result         : FAIL\n');
end

end


function [r, errs, warns] = auditOneSettingsFile(settingsName, codes, runPath, finishPath)

r     = struct();
errs  = 0;
warns = 0;

p = feval(settingsName);

% Synthesize the runtime state that _init.m would have set, so strobe
% expressions referring to p.init.taskCode resolve.
p.init.codes    = codes;
p.init.taskCode = codes.uniqueTaskCode_barsweep;

sl = p.init.strobeList;
nS = size(sl, 1);

%% Check 1: every strobeList code name exists in initCodes.
missingNames = {};
for ii = 1:nS
    nm = sl{ii, 1};
    if ~isfield(codes, nm)
        missingNames{end + 1} = nm; %#ok<AGROW>
    end
end
r.check1_missingCodeNames = missingNames;
if isempty(missingNames)
    fprintf('[OK]    Check 1: all %d strobeList code names exist in initCodes.\n', nS);
else
    errs = errs + numel(missingNames);
    for ii = 1:numel(missingNames)
        fprintf('[ERROR] Check 1: strobeList code "%s" missing from +pds/initCodes.m.\n', ...
            missingNames{ii});
    end
end

%% Check 2: hardcoded p.init.codes.<name> refs in _run.m and _finish.m resolve.
refs = unique([scanCodeRefs(runPath); scanCodeRefs(finishPath)]);
missingRefs = {};
for ii = 1:numel(refs)
    nm = refs{ii};
    if ~isfield(codes, nm)
        missingRefs{end + 1} = nm; %#ok<AGROW>
    end
end
r.check2_codeRefs        = refs;
r.check2_missingCodeRefs = missingRefs;
if isempty(missingRefs)
    fprintf('[OK]    Check 2: all %d hardcoded p.init.codes.* references resolve.\n', ...
        numel(refs));
else
    errs = errs + numel(missingRefs);
    for ii = 1:numel(missingRefs)
        fprintf(['[ERROR] Check 2: hardcoded p.init.codes.%s referenced in ' ...
                 '_run.m or _finish.m but missing from +pds/initCodes.m.\n'], ...
            missingRefs{ii});
    end
end

%% Check 3: every value expression yields scalar nonneg integer in [0, 32767]
%% across several worst-case parameter configurations.
worstCases = buildWorstCaseTrVars(p);
badExprs = {};
for cc = 1:numel(worstCases)
    pAudit         = p;
    pAudit.trVars  = worstCases(cc).trVars;
    pAudit.trData  = struct();
    pAudit.status  = struct('iTrial', 1);
    label          = worstCases(cc).label;
    for ii = 1:nS
        nm   = sl{ii, 1};
        expr = sl{ii, 2};
        try
            v = evalExpr(expr, pAudit);
        catch me
            badExprs{end + 1} = sprintf( ...
                'row %d (%s) [%s]: eval failed: %s', ...
                ii, nm, label, me.message); %#ok<AGROW>
            continue
        end
        if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v) || ...
                v < 0 || v > 32767 || v ~= round(v)
            badExprs{end + 1} = sprintf( ...
                'row %d (%s) [%s]: produced %s (need scalar integer in [0, 32767])', ...
                ii, nm, label, mat2str(v)); %#ok<AGROW>
        end
    end
end
r.check3_badExpressions = badExprs;
if isempty(badExprs)
    fprintf('[OK]    Check 3: %d strobeList expressions valid across %d worst-case configs.\n', ...
        nS, numel(worstCases));
else
    errs = errs + numel(badExprs);
    for ii = 1:numel(badExprs)
        fprintf('[ERROR] Check 3: %s\n', badExprs{ii});
    end
end

%% Check 4: required timing fields initialized to "-1" in _settings.m.
required = {'fixOn', 'fixAq', 'stimOn', 'stimOff', 'fixBreak', 'nonStart', ...
            'reward', 'trialBegin', 'trialEnd', 'trialRunDone', 'flipIdxStimOn'};
initList = p.init.trDataInitList;
missingInit = {};
for ii = 1:numel(required)
    fld    = required{ii};
    rowIdx = find(strcmp(initList(:, 1), ['p.trData.timing.' fld]), 1);
    if isempty(rowIdx)
        missingInit{end + 1} = sprintf('%s (no init entry)', fld); %#ok<AGROW>
        continue
    end
    initStr = strtrim(initList{rowIdx, 2});
    if ~strcmp(initStr, '-1')
        missingInit{end + 1} = sprintf( ...
            '%s (init = "%s", expected "-1")', fld, initStr); %#ok<AGROW>
    end
end
r.check4_missingTimingInits = missingInit;
if isempty(missingInit)
    fprintf('[OK]    Check 4: all %d required timing fields initialized to -1.\n', ...
        numel(required));
else
    errs = errs + numel(missingInit);
    for ii = 1:numel(missingInit)
        fprintf('[ERROR] Check 4: timing field %s\n', missingInit{ii});
    end
end

%% Check 5: filter-enum maps configured rfRampFilter to integer in [1, 4].
filterStr = p.trVarsInit.rfRampFilter;
try
    k = pds.barsweepRampFilterEnum(filterStr);
    if ~isnumeric(k) || ~isscalar(k) || k < 1 || k > 4 || k ~= round(k)
        errs = errs + 1;
        fprintf('[ERROR] Check 5: barsweepRampFilterEnum("%s") returned %s; expected integer in [1, 4].\n', ...
            filterStr, mat2str(k));
        r.check5_filterEnum = sprintf('bad value %s', mat2str(k));
    else
        fprintf('[OK]    Check 5: rfRampFilter "%s" -> enum %d.\n', filterStr, k);
        r.check5_filterEnum = k;
    end
catch me
    errs = errs + 1;
    fprintf('[ERROR] Check 5: barsweepRampFilterEnum("%s") raised: %s\n', ...
        filterStr, me.message);
    r.check5_filterEnum = me.message;
end

%% Check 6: useOnlineSort must be 0 when useOnlineRF is true.
if p.trVarsInit.useOnlineRF && p.trVarsInit.useOnlineSort ~= 0
    errs = errs + 1;
    fprintf('[ERROR] Check 6: useOnlineRF=true but useOnlineSort=%d (must be 0).\n', ...
        p.trVarsInit.useOnlineSort);
    r.check6_useOnlineSort = 'fail';
else
    fprintf('[OK]    Check 6: useOnlineRF/useOnlineSort consistent (useOnlineRF=%d, useOnlineSort=%d).\n', ...
        p.trVarsInit.useOnlineRF, p.trVarsInit.useOnlineSort);
    r.check6_useOnlineSort = 'ok';
end

%% Check 7: rfNChannels sanity (soft warning).
nCh = p.trVarsInit.rfNChannels;
if ~isnumeric(nCh) || ~isscalar(nCh) || nCh < 1 || nCh > 256 || nCh ~= round(nCh)
    warns = warns + 1;
    fprintf('[WARN]  Check 7: rfNChannels = %s; expected positive integer in [1, 256].\n', ...
        mat2str(nCh));
    r.check7_rfNChannels = 'warn';
elseif ~ismember(nCh, [16 24 32 64 96 128 256])
    warns = warns + 1;
    fprintf('[WARN]  Check 7: rfNChannels = %d is unusual; common values are 16/24/32/64/96/128/256. Confirm against rig hardware.\n', ...
        nCh);
    r.check7_rfNChannels = 'warn';
else
    fprintf('[OK]    Check 7: rfNChannels = %d.\n', nCh);
    r.check7_rfNChannels = 'ok';
end

%% Check 8: regime-specific strobeList shape.
switch p.init.exptType
    case 'barsweep_rfmap12'
        [c8errs, info] = checkRfmap12Overrides(p);
        errs = errs + c8errs;
        r.check8_rfmap12 = info;
    case 'barsweep_cardinal4'
        [c8errs, info] = checkCardinal4Shape(p);
        errs = errs + c8errs;
        r.check8_cardinal4 = info;
    otherwise
        warns = warns + 1;
        fprintf('[WARN]  Check 8: unknown exptType "%s"; skipping regime-specific shape check.\n', ...
            p.init.exptType);
        r.check8_unknownExptType = p.init.exptType;
end

end


%% -------------------- helpers --------------------

function v = evalExpr(expr, p) %#ok<INUSD>
% Evaluate a strobeList expression in a scope where the local variable
% `p` is the supplied audit struct. Isolated from the caller's namespace.
v = eval(expr);
end


function refs = scanCodeRefs(filePath)
% Return a column cell array of unique code-name strings referenced as
% p.init.codes.<name> in the file.
txt = fileread(filePath);
tok = regexp(txt, 'p\.init\.codes\.([A-Za-z_][A-Za-z0-9_]*)', 'tokens');
if isempty(tok)
    refs = {};
    return
end
refs = cellfun(@(c) c{1}, tok, 'UniformOutput', false);
refs = unique(refs(:));
end


function cases = buildWorstCaseTrVars(p)
% Several synthetic trVars configurations exercising the strobe expression
% surface. Each case yields a (label, trVars) pair; the auditor evals
% every strobeList expression against each. Limits chosen at the
% encoding ceiling to catch *100 / *10 / +1800 scaling regressions.

base = p.trVarsInit;

cases(1).label  = 'defaults';
cases(1).trVars = base;

t = base;
t.pathAngleDeg     = 359.9;
t.pathCenterXDeg   = 320;          % radius * 100 = 32000 < 32767
t.pathCenterYDeg   = 0;
t.pathLengthDeg    = 327;          % * 100 = 32700
t.speedDegPerSec   = 327;
t.barWidthDeg      = 32;
t.barLengthDeg     = 327;
t.fixDegX          = 320;
t.fixDegY          = 0;
t.fixWinWidthDeg   = 320;
t.fixWinHeightDeg  = 320;
t.noiseCheckSizeDeg = 320;
t.rfLatencyMs      = 1000;
t.rfPosBinDeg      = 320;
t.rfRampCutoff     = 1.0;          % * 100 = 100
cases(2).label  = 'extreme-positive';
cases(2).trVars = t;

t = base;
t.pathAngleDeg   = -359.9;          % mod(., 360) keeps it in [0, 3600)
t.pathCenterXDeg = -100;
t.pathCenterYDeg = -100;            % atan2d -> -135 deg, *10+1800 = 450
t.fixDegX        = -10;
t.fixDegY        = -10;
cases(3).label  = 'extreme-negative';
cases(3).trVars = t;

t = base;
t.pathCenterXDeg = -10;
t.pathCenterYDeg = 0;               % atan2d(0, -10) = +180 -> 3600
t.fixDegX        = -10;
t.fixDegY        = 0;
cases(4).label  = 'theta-boundary-180';
cases(4).trVars = t;

filters = {'Ram-Lak', 'Hann', 'Shepp-Logan', 'Cosine'};
for kk = 1:numel(filters)
    t = base;
    t.rfRampFilter = filters{kk};
    cases(end + 1).label  = sprintf('filter-%s', filters{kk}); %#ok<AGROW>
    cases(end).trVars     = t;
end

end


function [errs, info] = checkRfmap12Overrides(p)
errs = 0;
info = struct();
sl   = p.init.strobeList;

hasCutoff = any(strcmp(sl(:, 1), 'barsweepRfRampCutoff_x100'));
hasFilter = any(strcmp(sl(:, 1), 'barsweepRfRampFilter'));
info.hasCutoffRow = hasCutoff;
info.hasFilterRow = hasFilter;

if ~hasCutoff
    errs = errs + 1;
    fprintf('[ERROR] Check 8: rfmap12 strobeList missing row "barsweepRfRampCutoff_x100".\n');
end
if ~hasFilter
    errs = errs + 1;
    fprintf('[ERROR] Check 8: rfmap12 strobeList missing row "barsweepRfRampFilter".\n');
end

rowIdx = find(strcmp(sl(:, 1), 'barsweepExptType'), 1);
if isempty(rowIdx)
    errs = errs + 1;
    fprintf('[ERROR] Check 8: rfmap12 strobeList missing row "barsweepExptType".\n');
    info.exptTypeValue = NaN;
else
    pAudit         = p;
    pAudit.trVars  = p.trVarsInit;
    pAudit.trData  = struct();
    pAudit.status  = struct('iTrial', 1);
    try
        v = evalExpr(sl{rowIdx, 2}, pAudit);
    catch me
        v = NaN;
        errs = errs + 1;
        fprintf('[ERROR] Check 8: rfmap12 barsweepExptType expression raised: %s\n', me.message);
    end
    info.exptTypeValue = v;
    if ~isequaln(v, 2)
        errs = errs + 1;
        fprintf('[ERROR] Check 8: rfmap12 barsweepExptType evaluated to %s, expected 2.\n', ...
            mat2str(v));
    end
end

if errs == 0
    fprintf('[OK]    Check 8: rfmap12 overrides present (exptType=2, two appended rows).\n');
end

end


function [errs, info] = checkCardinal4Shape(p)
errs = 0;
info = struct();
sl   = p.init.strobeList;

extras = {};
if any(strcmp(sl(:, 1), 'barsweepRfRampCutoff_x100'))
    extras{end + 1} = 'barsweepRfRampCutoff_x100'; %#ok<AGROW>
end
if any(strcmp(sl(:, 1), 'barsweepRfRampFilter'))
    extras{end + 1} = 'barsweepRfRampFilter'; %#ok<AGROW>
end
info.unexpectedRfmap12Rows = extras;

for ii = 1:numel(extras)
    errs = errs + 1;
    fprintf('[ERROR] Check 8: cardinal4 strobeList contains rfmap12-only row "%s".\n', ...
        extras{ii});
end

rowIdx = find(strcmp(sl(:, 1), 'barsweepExptType'), 1);
if isempty(rowIdx)
    errs = errs + 1;
    fprintf('[ERROR] Check 8: cardinal4 strobeList missing row "barsweepExptType".\n');
    info.exptTypeValue = NaN;
else
    pAudit         = p;
    pAudit.trVars  = p.trVarsInit;
    pAudit.trData  = struct();
    pAudit.status  = struct('iTrial', 1);
    try
        v = evalExpr(sl{rowIdx, 2}, pAudit);
    catch me
        v = NaN;
        errs = errs + 1;
        fprintf('[ERROR] Check 8: cardinal4 barsweepExptType expression raised: %s\n', me.message);
    end
    info.exptTypeValue = v;
    if ~isequaln(v, 1)
        errs = errs + 1;
        fprintf('[ERROR] Check 8: cardinal4 barsweepExptType evaluated to %s, expected 1.\n', ...
            mat2str(v));
    end
end

if errs == 0
    fprintf('[OK]    Check 8: cardinal4 strobeList shape correct (exptType=1, no rfmap12 rows).\n');
end

end
