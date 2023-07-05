function p = getRippleData(p)
%
% p = getRippleData(p)
%
% get spike times, event values, and event times stored in NIP's buffer,
% and append them to p.trData fields. We append so we can call multiple
% times 

% Get spike times from 1st recording channel. Note these are returned as
% sample numbers based on a 30 kHz sample rate, so we divide by 30 kHz to
% convert to seconds:
[~, tempSpikeTimes, ~, unitIdx] = pds.xippmex('spike', ...
    p.rig.ripple.recChans(p.trVars.rippleChanSelect), 0);

% if we're using online sorting, use those spike times only,
% otherwise use all spiketimes (threshold crossings).
if p.trVars.useOnlineSort
    p.trData.spikeTimes = [p.trData.spikeTimes, ...
        tempSpikeTimes{1}(logical(unitIdx{1})) / 30000];
else
    p.trData.spikeTimes = [p.trData.spikeTimes, ...
        tempSpikeTimes{:} / 30000];
end

% get strobed event values and event times from ripple (in ripple's clock).
[~, tempEventTimes, tempEventValues] = pds.xippmex('digin');
tempEventValues = [tempEventValues.parallel];

% store event values and event times:
p.trData.eventValues    = [p.trData.eventValues, tempEventValues];
p.trData.eventTimes     = [p.trData.eventTimes, tempEventTimes / 30000];
