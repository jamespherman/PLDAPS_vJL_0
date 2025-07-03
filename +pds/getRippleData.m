function p = getRippleData(p)
% Get spike times from all recording channels
[~, tempSpikeTimes, ~, unitIdx] = pds.xippmex('spike', ...
    p.rig.ripple.recChans, 0);

% how many channels?
nChannels = length(tempSpikeTimes);

% Initialize spike counters
totalSpikes = 0;
p.trData.spikeTimes = [];

% Convert and store spike data for current trial
for iChan = 1:nChannels
    if ~isempty(tempSpikeTimes{iChan})
        nSpikesThisChan = length(tempSpikeTimes{iChan});
        totalSpikes = totalSpikes + nSpikesThisChan;
        
        if p.trVars.useOnlineSort
            validSpikes = logical(unitIdx{iChan});
            p.trData.spikeTimes = [p.trData.spikeTimes; ...
                (tempSpikeTimes{iChan}(validSpikes) / 30000)'];
            p.trData.spikeClusters = [p.trData.spikeClusters; ...
                unitIdx{iChan}(validSpikes)'];
        else
            p.trData.spikeTimes = [p.trData.spikeTimes; ...
                (tempSpikeTimes{iChan} / 30000)'];
            p.trData.spikeClusters = [p.trData.spikeClusters; ...
                zeros(nSpikesThisChan, 1)+iChan];
        end
    end
end

disp(['Received ' num2str(totalSpikes) ' spikes from ' ...
    num2str(nChannels) ' channels']);

% get strobed event values and event times from ripple
[~, tempEventTimes, tempEventValues] = pds.xippmex('digin');
tempEventValues = [tempEventValues.parallel];

% store event values and event times
p.trData.eventValues = tempEventValues(:);
p.trData.eventTimes = (tempEventTimes / 30000)';

end