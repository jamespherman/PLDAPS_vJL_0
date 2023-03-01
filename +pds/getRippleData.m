function p = getRippleData(p)
%
% p = getRippleData(p)
%

% get spike times from 1st recording channel:
try
    [~, tempSpikeTimes] = xippmex('spike', ...
        p.rig.ripple.recChans(1), 0);
    p.trData.spikeTimes = tempSpikeTimes{:};
catch me
    xippmex;
    [~, tempSpikeTimes] = xippmex('spike', ...
        p.rig.ripple.recChans(1), 0);
    p.trData.spikeTimes = tempSpikeTimes{:};
end

% get strobed event values and event times from ripple (in ripple's clock).
[~, p.trData.eventTimes, tempEventValues] = xippmex('digin');
p.trData.eventValues = [tempEventValues.parallel];