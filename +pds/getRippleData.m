function p = getRippleData(p)
%
% p = getRippleData(p)
%

% Get spike times from 1st recording channel. Note these are returned as
% sample numbers based on a 30 kHz sample rate, so we divide by 30 kHz to
% convert to seconds:
try
    tempSpikeTimes{1} = [];
    while isempty(tempSpikeTimes{:})
        [~, tempSpikeTimes, ~, unitIdx] = xippmex('spike', ...
            p.rig.ripple.recChans(p.trVars.rippleChanSelect), 0);
    end

    % if there is an online sorted unit defined, use those spiketimes only,
    % otherwise use all spiketimes (threshold crossings).
    if any(unitIdx{1})
        p.trData.spikeTimes = tempSpikeTimes{unitIdx{1}} / 30000;
    else
        p.trData.spikeTimes = tempSpikeTimes{:} / 30000;
    end
catch me
    xippmex;
    tempSpikeTimes{1} = [];
    while isempty(tempSpikeTimes{:})
        [~, tempSpikeTimes, ~, unitIdx] = xippmex('spike', ...
            p.rig.ripple.recChans(p.trVars.rippleChanSelect), 0);
    end

    % if there is an online sorted unit defined, use those spiketimes only,
    % otherwise use all spiketimes (threshold crossings).
    if any(unitIdx{1})
        p.trData.spikeTimes = tempSpikeTimes{unitIdx{1}} / 30000;
    else
        p.trData.spikeTimes = tempSpikeTimes{:} / 30000;
    end
end

% why is this empty?!
if isempty(tempSpikeTimes{:})
    keyboard
end

% get strobed event values and event times from ripple (in ripple's clock).
[~, tempEventTimes, tempEventValues] = xippmex('digin');
tempEventValues = [tempEventValues.parallel];

% this is probably only for debugging while we're coding this up initially,
% but let's make sure we're only keeping one trial's worth of event value /
% time data. Note that we must also divide "eventTimes" by 30000 to convert
% from Ripple's sample clock (30 kHz sample rate) to seconds:
numInd = ...
    find(tempEventValues == p.init.codes.trialBegin, 1, 'last'):...
    length(tempEventValues);
p.trData.eventValues    = tempEventValues(numInd);
p.trData.eventTimes     = tempEventTimes(numInd)  / 30000;