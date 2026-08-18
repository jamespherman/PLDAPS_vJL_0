function p = srsSmooth_finish(p)
%   p = srsSmooth_finish(p)
%
% Part of the quintet of pldpas functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% finish function runs at the end of every trial and is usually used to 
% save data, update online plots, set stimulus for next trial, etc.


%% In this function:
% (1) Clear "Screen".
% (2) Strobe current trial's information (stimulus params, etc) to ephys
%     system.
% (3) Pause ephys.
% (4) Store data in PDS structure (eye position traces, spike times, etc.).
% (5) Auto save backup (if desired).
% (6) Update status variables.
% (7) Update trials list (shuffle back in trials to be repeated, take care
%     of transitions between blocks, etc.).
% (8) Update online plots.


%% Photometer / i1 measurement mode
% These actions are launched through the GUI but do not create a behavioral
% trial. Skip the normal finish pipeline when a measurement has completed.
measurementFlags = {'i1RampMeasurementDone', 'i1ScanMeasurementDone', ...
    'i1GrayBgMeasurementDone'};
measurementDone = false;
if isfield(p, 'status')
    for iFlag = 1:numel(measurementFlags)
        if isfield(p.status, measurementFlags{iFlag}) && ...
                p.status.(measurementFlags{iFlag})
            measurementDone = true;
            p.status.(measurementFlags{iFlag}) = false;
        end
    end
end
if measurementDone
    disp('Skipping normal srsSmooth_finish after i1 measurement.');
    return
end

% (1) fill screen with background color (if we're not playing a movie)
if ~isfield(p.draw, 'movie')
    Screen('FillRect', p.draw.window, p.draw.color.background);
    Screen('Flip', p.draw.window);
end

% read buffered ADC and DIN data from DATAPixx
p           = pds.readDatapixxBuffers(p);

% Was the previous trial completed?
% True (1) if 455 ; False if not 455
p.trData.GoodTrial = p.trData.trialEndState == p.state.sacComplete;
p.trData.trialRepeatFlag = ~p.trData.GoodTrial;

% Apply any correction-control changes made during the trial before
% strobing and deciding whether a correction sequence should start/stop.
p = readCorrectionControlWindow(p);

%% strobes:
% strobe trial data:
p           = pds.strobeTrialData(p);

% strobe and mark end of trial:
timeNow = GetSecs - p.trData.timing.trialStartPTB; % timeNow is relative to trial Start
p.trData.timing.trialEnd   = timeNow;
p.init.strb.strobeNow(p.init.codes.trialEnd);

% (3) mark end time in PTB & DP time:
[p.trData.timing.trialEndPTB, p.trData.timing.trialEndDP] = pds.getTimes;

% save strobed codes:
p.trData.strobed = p.init.strb.strobedList;

% flush strobe "veto" & "strobed" list
p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

% (3) pause ephys
pds.stopOmniPlex;

% wait for joystick release
% p           = pds.waitForJoystickRelease(p);

% if a "time-out" is desired, make it happen here. Note: the way this works
% at present is: we only advance from here if the desired interval of time
% has elapsed since the end of the previous trial. This means that if the
% monkey has held the joystick down for a "long time" since the end of the
% last trial, the "time-out" window has passed and there won't be an
% ADDITIONAL time out.
postTrialTimeOut(p);

% retreive data from omniplex PC if desired.
if p.rig.connectToOmniplex
    p = pds.getOmniplexData(p);
end

% % % p.trData.spikeAndStrobeTimes(p.trData.spikeAndStrobeTimes(:,1)==4, 3)
% % % 
% % % keyboard

% store missed frames count
p.trData.missedFrameCount = nnz(diff(p.trData.timing.flipTime) > ...
    p.rig.frameDuration * 1.5);
p.status.missedFrames = p.status.missedFrames + p.trData.missedFrameCount;

% (5) auto save backup
pds.saveP(p);

% (6) if we're using QUEST, compute the posterior and update the parameter
% estimates here
p           = updateQuest(p);

% (7) update the block schedule. Successful rows are removed;
% unsuccessful rows remain eligible for later repetition.
p           = updateTrialsList(p);

% (8) update status variables and behavioral outcome counters.
p           = updateStatusVariables(p);

% Print one standardized, human-readable result for every attempt. This is
% intentionally centralized here so success and every abort state are
% reported even when the state machine itself did not print a message.
printSrsTrialOutcome(p);

% disp(p.trData.timing.saccadeOnset)
% disp(p.trData.timing.fixOff)

% (8) if we're using online plots, update them now:
if isfield(p.trVars, 'wantOnlinePlots') && p.trVars.wantOnlinePlots
    p       = updateOnlinePlots(p);
end

% Keep the dedicated control window synchronized with correction state and
% the continuously updated right-choice probability.
p = updateCorrectionControlWindow(p);

end

function printSrsTrialOutcome(p)
%PRINTSRSTRIALOUTCOME Print exactly one final outcome line per attempt.

attempt = getScalarField(p.status, 'iTrial', NaN);
nStim = getScalarField(p.trData, 'nStim', ...
    getScalarField(p.trVars, 'nStim', NaN));
trialType = getScalarField(p.status, 'ActualTrialType', NaN);
goodTrial = isfield(p.trData, 'GoodTrial') && logical(p.trData.GoodTrial);

correctionText = '';
wasForcedCorrection = logical(getScalarField( ...
    p.trData, 'correctionTrialActive', 0));
if wasForcedCorrection
    rep = getScalarField(p.trData, 'correctionTrialRepetition', 0);
    correctionText = sprintf(' | correction repeat %d', round(rep));
elseif isfield(p.status, 'correctionTrialActive') && ...
        logical(p.status.correctionTrialActive) && ...
        getScalarField(p.status, 'correctionTrialRepetition', 0) == 0
    correctionText = ' | correction triggered';
end

if goodTrial
    chosenTarget = getScalarField(p.trData, 'chosenTargetID', NaN);
    chosenSide = getScalarField(p.trData, 'chosenSide', NaN);
    highRewardTarget = getScalarField(p.status, 'highRewardTargetID', NaN);

    if nStim == 1
        decisionText = 'single target';
    elseif chosenTarget == highRewardTarget
        decisionText = 'HIGH REWARD choice';
    else
        decisionText = 'LOW REWARD choice';
    end

    fprintf('[SRS trial %s] saccadeMade: choice T%s/%s | %s | %s%s\n', ...
        integerText(attempt), integerText(chosenTarget), ...
        sideText(chosenSide), trialTypeText(nStim, trialType), ...
        decisionText, correctionText);
else
    reason = getTextField(p.trData, 'failureReason', '');
    reasonText = canonicalFailureText(reason, p);
    fprintf('[SRS trial %s] %s%s\n', ...
        integerText(attempt), reasonText, correctionText);
end

end

function text = canonicalFailureText(reason, p)
key = lower(regexprep(char(string(reason)), '[^a-zA-Z]', ''));
switch key
    case 'fixationnotacquired'
        text = 'no fix';
    case 'fixbreakbeforetargeton'
        text = 'breakfix';
    case 'fixbreakduringdelay'
        text = 'breakfixduringdelay';
    case 'noresponse'
        text = 'no response';
    case 'targetholdbreak'
        text = 'breakfix: target hold';
    case 'landingoutsidetargetwindows'
        text = 'inaccurate: landing outside target windows';
    case 'saccadedurationexceeded'
        text = 'inaccurate: saccade duration exceeded';
    case 'blinkduringsaccade'
        text = 'blink during saccade';
    case 'miss'
        text = 'miss';
    case 'fixbreak'
        text = 'breakfix';
    otherwise
        text = inferFailureFromEndState(p);
        if strcmp(text, 'trial aborted') && ~isempty(strtrim(char(string(reason))))
            text = char(string(reason));
        end
end
end

function text = inferFailureFromEndState(p)
text = 'trial aborted';
if ~isfield(p.trData, 'trialEndState') || ~isfield(p, 'state')
    return
end
state = p.trData.trialEndState;
if isfield(p.state, 'nonStart') && state == p.state.nonStart
    text = 'no fix';
elseif isfield(p.state, 'noResponse') && state == p.state.noResponse
    text = 'no response';
elseif isfield(p.state, 'fixBreak') && state == p.state.fixBreak
    text = 'breakfix';
elseif isfield(p.state, 'inaccurate') && state == p.state.inaccurate
    text = 'inaccurate';
elseif isfield(p.state, 'miss') && state == p.state.miss
    text = 'miss';
end
end

function text = trialTypeText(nStim, trialType)
if nStim == 1
    text = 'single-target';
elseif trialType == 1
    text = 'congruent';
elseif trialType == 2
    text = 'conflict';
else
    text = 'unknown trial type';
end
end

function text = sideText(side)
if side == 1
    text = 'right';
elseif side == 2
    text = 'left';
else
    text = 'unknown side';
end
end

function text = integerText(value)
if isfinite(value)
    text = sprintf('%.0f', value);
else
    text = '?';
end
end

function value = getScalarField(s, name, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, name)
    candidate = s.(name);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end

function value = getTextField(s, name, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, name)
    candidate = s.(name);
    if ischar(candidate)
        value = candidate;
    elseif isstring(candidate) && isscalar(candidate)
        value = char(candidate);
    end
end
end

