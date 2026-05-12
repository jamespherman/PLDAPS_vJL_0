function trials = decodeRippleEvents(eventValues, eventTimes, codes)
% trials = decodeRippleEvents(eventValues, eventTimes, codes)
%
% Pure decoder for a barsweep Ripple event stream. Accepts the raw
% (codeNumeric, time) arrays already on p.trData.eventValues /
% p.trData.eventTimes (or read from a .nev file by openNEV) plus the
% pds.initCodes struct, and returns a struct array of per-trial decoded
% records.
%
% This decoder is shared between the offline validator (validateBarsweep
% Session) and any post-hoc RF analysis: every consumer needs the same
% (events, params, outcome) view of a trial.
%
% Inputs:
%   eventValues  numeric vector, codeNumeric per strobe.
%   eventTimes   numeric vector, Ripple-clock seconds per strobe (must
%                be the same length as eventValues, monotonically
%                non-decreasing within a trial).
%   codes        struct from pds.initCodes; must contain fields
%                trialBegin, trialEnd, trialRunDone, fixOn, fixAq,
%                stimOn, stimOff, fixBreak, nonStart, plus every code
%                referenced by a barsweep strobeList row.
%
% Output:
%   trials  1xN struct array. Empty if no trialBegin/trialEnd pair found.
%   Fields per element:
%     iTrial          decoded from trialCount strobe (NaN if missing)
%     startTime       Ripple-clock seconds, time of trialBegin
%     endTime         Ripple-clock seconds, time of trialEnd
%     events          table: codeName, codeValue, time. Only the canonical
%                     event strobes (fixOn/fixAq/stimOn/stimOff/fixBreak/
%                     nonStart/trialBegin/trialRunDone/trialEnd) appear
%                     here -- the param batch is parsed separately into
%                     `params`.
%     params          struct keyed by codeName -> raw (encoded) value
%     paramsDecoded   struct keyed by codeName -> physically meaningful
%                     value (degrees, dva, ms, ...). For barsweepExptType
%                     and barsweepRfRampFilter, paramsDecoded contains the
%                     canonical string ('barsweep_cardinal4', 'Hann', ...).
%     outcome         'trialComplete' | 'fixBreak' | 'nonStart' | 'unknown'
%     exptType        'barsweep_cardinal4' | 'barsweep_rfmap12' | ''
%     rfLatencyMs     decoded barsweepRfLatency (NaN if absent)
%     rfPosBinDeg     decoded barsweepRfPosBin_x100 / 100 (NaN if absent)
%     rfRampFilter    rfmap12 only: canonical string (or '' if absent)
%     rfRampCutoff    rfmap12 only: decoded scalar (NaN if absent)
%     diagnostics     struct of soft warnings: missingTrialEnd,
%                     paramBatchOddLength, unknownParamCodes (cell array),
%                     paramExpectedCount, paramActualCount.
%
% The decoder also asserts intra-session consistency: every trial that
% carries a non-empty exptType must agree, and the rfmap12-only fields
% (rfRampFilter, rfRampCutoff) must be present iff exptType is rfmap12.

if nargin < 3 || ~isstruct(codes)
    error('decodeRippleEvents:badInput', ...
        'codes (3rd arg) must be the pds.initCodes() struct.');
end

eventValues = eventValues(:);
eventTimes  = eventTimes(:);
if numel(eventValues) ~= numel(eventTimes)
    error('decodeRippleEvents:lengthMismatch', ...
        'eventValues and eventTimes must be the same length (%d vs %d).', ...
        numel(eventValues), numel(eventTimes));
end

% Reverse name lookup: codeNumeric -> field name.
[name2val, val2name] = buildCodeMaps(codes);

% Required canonical event codes; assert presence so downstream segmentation
% and outcome inference are unambiguous. `reward` is included because
% pds.deliverReward strobes 8000 from the trialComplete state (see
% barsweep_run.m); the validator's aborted-trial sanity check needs to
% see this strobe in the decoded events stream to verify it's absent on
% fixBreak / nonStart trials.
requiredEvts = {'trialBegin', 'trialEnd', 'trialRunDone', 'fixOn', ...
                'fixAq', 'stimOn', 'stimOff', 'fixBreak', 'nonStart', ...
                'reward'};
for ii = 1:numel(requiredEvts)
    nm = requiredEvts{ii};
    assert(isfield(name2val, nm), ...
        'decodeRippleEvents: codes.%s missing from pds.initCodes().', nm);
end

% Locate trial brackets. trialBegin opens, trialEnd closes; an unmatched
% trialBegin (no following trialEnd) is recorded but flagged.
beginIdx = find(eventValues == name2val.trialBegin);
endIdx   = find(eventValues == name2val.trialEnd);
nB = numel(beginIdx);
nE = numel(endIdx);

if nB == 0
    trials = struct([]);
    return
end

trials = repmat(makeEmptyTrial(), 1, nB);

sessionExptType = '';   % first non-empty exptType wins; subsequent must match.

for tt = 1:nB
    bi = beginIdx(tt);
    % First trialEnd strictly after this trialBegin and strictly before
    % the next trialBegin.
    if tt < nB
        nextBi = beginIdx(tt + 1);
    else
        nextBi = numel(eventValues) + 1;
    end
    eiCandidates = endIdx(endIdx > bi & endIdx < nextBi);
    if isempty(eiCandidates)
        ei = NaN;
    else
        ei = eiCandidates(1);
    end

    tr = makeEmptyTrial();
    tr.startTime = eventTimes(bi);
    if ~isnan(ei)
        tr.endTime = eventTimes(ei);
        spanIdx    = bi:ei;
    else
        tr.endTime = NaN;
        tr.diagnostics.missingTrialEnd = true;
        spanIdx    = bi:(nextBi - 1);
    end

    spanVals = eventValues(spanIdx);
    spanTime = eventTimes(spanIdx);

    % --- Event timeline (canonical events only). --------------------------
    % CRITICAL: restrict event extraction to the trial BODY (trialBegin
    % through trialRunDone, inclusive). The param batch between
    % trialRunDone and trialEnd contains arbitrary integer values that
    % can numerically collide with event-code numerics — e.g. the
    % default barLengthDeg=80 yields barsweepLength_x100=8000, which
    % matches the reward code (8000) and would otherwise produce a
    % spurious reward strobe in the events table on every trial. The
    % param batch is parsed separately as paired (code, value) below.
    rdLocal = find(spanVals == name2val.trialRunDone, 1, 'last');
    if isempty(rdLocal)
        bodyEnd = numel(spanVals);
    else
        bodyEnd = rdLocal;
    end
    bodyVals = spanVals(1:bodyEnd);
    bodyTime = spanTime(1:bodyEnd);
    canonicalEventCodes = [name2val.trialBegin, name2val.fixOn, ...
        name2val.fixAq, name2val.stimOn, name2val.stimOff, ...
        name2val.fixBreak, name2val.nonStart, name2val.trialRunDone, ...
        name2val.trialEnd, name2val.reward];
    evtMask = ismember(bodyVals, canonicalEventCodes);
    eVals   = bodyVals(evtMask);
    eTimes  = bodyTime(evtMask);
    % Append trialEnd separately if present (it lives after the param batch).
    if ~isnan(ei)
        eVals  = [eVals;  eventValues(ei)];
        eTimes = [eTimes; eventTimes(ei)];
    end
    eNames  = cell(numel(eVals), 1);
    for kk = 1:numel(eVals)
        eNames{kk} = val2name(eVals(kk));
    end
    tr.events = table(eNames, eVals, eTimes, ...
        'VariableNames', {'codeName', 'codeValue', 'time'});

    % --- Outcome inference. ----------------------------------------------
    hasFixBreak = any(eVals == name2val.fixBreak);
    hasFixAq    = any(eVals == name2val.fixAq);
    hasNonStart = any(eVals == name2val.nonStart);
    if hasFixBreak
        tr.outcome = 'fixBreak';
    elseif hasNonStart || ~hasFixAq
        tr.outcome = 'nonStart';
    else
        tr.outcome = 'trialComplete';
    end

    % --- Param batch. ----------------------------------------------------
    % The batch lives between trialRunDone (exclusive) and trialEnd
    % (exclusive). All entries are paired: (codeNumeric, value).
    rdIdxLocal = find(spanVals == name2val.trialRunDone, 1, 'last');
    if isnan(ei) || isempty(rdIdxLocal)
        paramRange = [];
    else
        paramRange = (rdIdxLocal + 1):(numel(spanVals) - 1);
    end
    paramVals = spanVals(paramRange);
    nP = numel(paramVals);
    tr.diagnostics.paramActualCount = nP;
    if mod(nP, 2) ~= 0
        tr.diagnostics.paramBatchOddLength = true;
    end

    unknownCodes = [];
    for ii = 1:2:(nP - 1)
        codeNum = paramVals(ii);
        valNum  = paramVals(ii + 1);
        if isKey(val2name, codeNum)
            nm = val2name(codeNum);
            tr.params.(nm)        = valNum;
            tr.paramsDecoded.(nm) = decodeParam(nm, valNum);
        else
            unknownCodes(end + 1) = codeNum; %#ok<AGROW>
        end
    end
    tr.diagnostics.unknownParamCodes = unknownCodes;

    % --- Decoded scalar conveniences (NaN/'' if absent). -----------------
    if isfield(tr.paramsDecoded, 'barsweepExptType')
        tr.exptType = tr.paramsDecoded.barsweepExptType;
    end
    if isfield(tr.paramsDecoded, 'barsweepRfLatency')
        tr.rfLatencyMs = tr.paramsDecoded.barsweepRfLatency;
    end
    if isfield(tr.paramsDecoded, 'barsweepRfPosBin_x100')
        tr.rfPosBinDeg = tr.paramsDecoded.barsweepRfPosBin_x100;
    end
    if isfield(tr.paramsDecoded, 'barsweepRfRampFilter')
        tr.rfRampFilter = tr.paramsDecoded.barsweepRfRampFilter;
    end
    if isfield(tr.paramsDecoded, 'barsweepRfRampCutoff_x100')
        tr.rfRampCutoff = tr.paramsDecoded.barsweepRfRampCutoff_x100;
    end
    if isfield(tr.params, 'trialCount')
        tr.iTrial = tr.params.trialCount;
    end

    % --- Expected param batch size (regime-driven). ----------------------
    switch tr.exptType
        case 'barsweep_cardinal4'
            tr.diagnostics.paramExpectedCount = 25 * 2;
        case 'barsweep_rfmap12'
            tr.diagnostics.paramExpectedCount = 27 * 2;
        otherwise
            tr.diagnostics.paramExpectedCount = NaN;
    end

    % Track session-wide exptType for the cross-trial assertion below.
    if ~isempty(tr.exptType)
        if isempty(sessionExptType)
            sessionExptType = tr.exptType;
        elseif ~strcmp(sessionExptType, tr.exptType)
            error('decodeRippleEvents:exptTypeChanged', ...
                ['Trial %d decoded exptType "%s" but earlier trials in this ' ...
                 'session decoded "%s". A regime change mid-session is a ' ...
                 'programmer error.'], ...
                tt, tr.exptType, sessionExptType);
        end
    end

    % --- Cross-field consistency for rfmap12-only params. ---------------
    if strcmp(tr.exptType, 'barsweep_rfmap12')
        assert(~isempty(tr.rfRampFilter), ...
            ['decodeRippleEvents: trial %d has exptType=rfmap12 but no ' ...
             'barsweepRfRampFilter strobe was decoded.'], tt);
        assert(~isnan(tr.rfRampCutoff), ...
            ['decodeRippleEvents: trial %d has exptType=rfmap12 but no ' ...
             'barsweepRfRampCutoff_x100 strobe was decoded.'], tt);
    elseif strcmp(tr.exptType, 'barsweep_cardinal4')
        if isfield(tr.params, 'barsweepRfRampFilter') || ...
                isfield(tr.params, 'barsweepRfRampCutoff_x100')
            error('decodeRippleEvents:cardinalUnexpectedRfmap12Param', ...
                ['Trial %d decoded exptType=cardinal4 but the rfmap12-only ' ...
                 'params (barsweepRfRampFilter, barsweepRfRampCutoff_x100) ' ...
                 'are present in the strobe stream.'], tt);
        end
    end

    trials(tt) = tr;
end

end


%% -------------------- helpers --------------------

function [name2val, val2name] = buildCodeMaps(codes)
% Forward (struct) and reverse (containers.Map) lookups over pds.initCodes.
flds = fieldnames(codes);
name2val = struct();
keysCell = {};
valsCell = {};
for ii = 1:numel(flds)
    v = codes.(flds{ii});
    if isnumeric(v) && isscalar(v)
        name2val.(flds{ii}) = v;
        keysCell{end + 1} = v; %#ok<AGROW>
        valsCell{end + 1} = flds{ii}; %#ok<AGROW>
    end
end
% Reverse map: numeric -> name. If multiple names share a value we keep the
% first; the strobe stream is decoded by code numeric so the chosen alias
% is cosmetic, but we still warn.
[~, uniqIdx] = unique(cell2mat(keysCell), 'first');
val2name = containers.Map(keysCell(uniqIdx), valsCell(uniqIdx));
end


function tr = makeEmptyTrial()
tr = struct( ...
    'iTrial',         NaN, ...
    'startTime',      NaN, ...
    'endTime',        NaN, ...
    'events',         table('Size', [0 3], ...
                            'VariableTypes', {'cell', 'double', 'double'}, ...
                            'VariableNames', {'codeName', 'codeValue', 'time'}), ...
    'params',         struct(), ...
    'paramsDecoded',  struct(), ...
    'outcome',        'unknown', ...
    'exptType',       '', ...
    'rfLatencyMs',    NaN, ...
    'rfPosBinDeg',    NaN, ...
    'rfRampFilter',   '', ...
    'rfRampCutoff',   NaN, ...
    'diagnostics',    struct( ...
        'missingTrialEnd',      false, ...
        'paramBatchOddLength',  false, ...
        'unknownParamCodes',    [], ...
        'paramExpectedCount',   NaN, ...
        'paramActualCount',     NaN));
end


function decoded = decodeParam(codeName, raw)
% Invert the encoding documented in plan §1c. Pure: takes the encoded
% integer and returns a physical scalar (or canonical string).

switch codeName
    case {'barsweepCenterTheta_x10', 'barsweepFixTheta_x10'}
        decoded = (double(raw) - 1800) / 10;            % [-180, 180] degrees
    case 'barsweepAngle_x10'
        decoded = double(raw) / 10;                      % [0, 360) degrees
    case {'barsweepCenterRadius_x100', 'barsweepPathLength_x100', ...
          'barsweepSpeed_x100', 'barsweepWidth_x100', ...
          'barsweepLength_x100', 'barsweepFixRadius_x100', ...
          'barsweepFixWinWidth_x100', 'barsweepFixWinHeight_x100', ...
          'barsweepNoiseGrain_x100', 'barsweepRfPosBin_x100', ...
          'barsweepRfRampCutoff_x100'}
        decoded = double(raw) / 100;
    case 'barsweepExptType'
        switch raw
            case 1, decoded = 'barsweep_cardinal4';
            case 2, decoded = 'barsweep_rfmap12';
            otherwise
                error('decodeRippleEvents:badExptType', ...
                    'barsweepExptType strobed value %s; expected 1 or 2.', ...
                    mat2str(raw));
        end
    case 'barsweepRfRampFilter'
        switch raw
            case 1, decoded = 'Ram-Lak';
            case 2, decoded = 'Hann';
            case 3, decoded = 'Shepp-Logan';
            case 4, decoded = 'Cosine';
            otherwise
                error('decodeRippleEvents:badRampFilter', ...
                    'barsweepRfRampFilter strobed value %s; expected 1..4.', ...
                    mat2str(raw));
        end
    otherwise
        % Identity decode for unscaled params (taskCode, date_*, time_*,
        % trialCount, lum indices, stim mode, rfLatency).
        decoded = double(raw);
end
end
