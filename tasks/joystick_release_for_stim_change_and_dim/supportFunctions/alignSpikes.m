function p = alignSpikes(p)

%
% p = alignSpikes(p)
%
% Here we simply check if there are events that we want to align spike
% times to. If any of those events has occurred, we align all the spike
% times we have in our buffer to that event and store the aligned spike
% times in the "UserData" field of the relevant plot object:

% for each of our 11 PSTHs, we want to check whether conditions are met
% (e.g. event occurred in the last trial) such that we should add the spike
% times to the across-trials list of spike times for the condition. Let's
% make a big list of conditionals to handle that:

% (1) Fixation onset
% (2) Stimulus onset (location 1)
% (3) Stimulus onset (location 2)
% (4) stimulus onset (location 3)
% (5) Stimulus onset (location 4)
% (6) Stimulus change (location 1)
% (7) Stimulus change (location 2)
% (8) Stimulus change (location 3)
% (9) Stimulus change (location 4)
% (10) Reward
% (11) Free reward
% (12) no free reward
% (13) Multiple stimulus onset (location 1)
% (14) Multiple stimulus onset (location 2)
% (15) Multiple stimulus onset (location 3)
% (16) Multiple stimulus onset (location 4)
% (17) Multiple stimulus change (location 1)
% (18) Multiple stimulus change (location 2)
% (19) Multiple stimulus change (location 3)
% (20) Multiple stimulus change (location 4)

try
% fixation onset:
if any(p.trData.eventValues == p.init.codes.fixOn)

    % time to align to; only use the last one.
    alignTime = ...
        p.trData.eventTimes(p.trData.eventValues == p.init.codes.fixOn);

    % add the previous trial's spike times to the list of spike times we'll
    % use to construct the PSTH:
    p.draw.onlinePlotObj(1).UserData.spTimes = ...
        [p.draw.onlinePlotObj(1).UserData.spTimes; ...
        p.trData.spikeTimes(:) - alignTime(end)];

    % iterate the total trial count for this plot object:
    p.draw.onlinePlotObj(1).UserData.trialCount = ...
        p.draw.onlinePlotObj(1).UserData.trialCount + 1;
end

% SINGLE stimulus onset (all locations):
if any(p.trData.eventValues == p.init.codes.stimOn) && ...
        length(p.trVars.stimOnList) == 1

    % At which location did the SINGLE stimulus onset occur? We use that
    % information to define a plot index ("plotInd") that refers to an
    % element of p.draw.onlinePlotObj where we store the aligned spikes and
    % trial counts:
    plotInd = p.trVars.stimOnList + 1;

    % time to align to; only use the last one.
    alignTime = ...
        p.trData.eventTimes(p.trData.eventValues == p.init.codes.stimOn);

    % add the previous trial's spike times to the list of spike times we'll
    % use to construct the PSTH:
    p.draw.onlinePlotObj(plotInd).UserData.spTimes = ...
        [p.draw.onlinePlotObj(plotInd).UserData.spTimes; ...
        p.trData.spikeTimes(:) - alignTime(end)];

    % iterate the total trial count for this plot object:
    p.draw.onlinePlotObj(plotInd).UserData.trialCount = ...
        p.draw.onlinePlotObj(plotInd).UserData.trialCount + 1;
end

% stimulus change (all locations) with a SINGLE stimulus present:
if any(p.trData.eventValues == p.init.codes.stimChange) && ...
        length(p.trVars.stimOnList) == 1

    % At which location did the stimulus change occur? We use that
    % information to define a plot index ("plotInd") that refers to an
    % element of p.draw.onlinePlotObj where we store the aligned spikes and
    % trial counts:
    plotInd = p.trVars.stimOnList + 5;

    % time to align to; only use the last one.
    alignTime = ...
        p.trData.eventTimes(p.trData.eventValues == ...
        p.init.codes.stimChange);

    % add the previous trial's spike times to the list of spike times we'll
    % use to construct the PSTH:
    p.draw.onlinePlotObj(plotInd).UserData.spTimes = ...
        [p.draw.onlinePlotObj(plotInd).UserData.spTimes; ...
        p.trData.spikeTimes(:) - alignTime(end)];

    % iterate the total trial count for this plot object:
    p.draw.onlinePlotObj(plotInd).UserData.trialCount = ...
        p.draw.onlinePlotObj(plotInd).UserData.trialCount + 1;
end

% reward:
if any(p.trData.eventValues == p.init.codes.reward)

    % time to align to; only use the last one.
    alignTime = ...
        p.trData.eventTimes(p.trData.eventValues == p.init.codes.reward);

    % add the previous trial's spike times to the list of spike times we'll
    % use to construct the PSTH:
    p.draw.onlinePlotObj(10).UserData.spTimes = ...
        [p.draw.onlinePlotObj(10).UserData.spTimes; ...
        p.trData.spikeTimes(:) - alignTime(end)];

    % iterate the total trial count for this plot object:
    p.draw.onlinePlotObj(10).UserData.trialCount = ...
        p.draw.onlinePlotObj(10).UserData.trialCount + 1;
end

% free reward:
if any(p.trData.eventValues == p.init.codes.freeReward)

    % time to align to; only use the last one.
    alignTime = ...
        p.trData.eventTimes(p.trData.eventValues == ...
        p.init.codes.freeReward);

    % add the previous trial's spike times to the list of spike times we'll
    % use to construct the PSTH:
    p.draw.onlinePlotObj(11).UserData.spTimes = ...
        [p.draw.onlinePlotObj(11).UserData.spTimes; ...
        p.trData.spikeTimes(:) - alignTime(end)];

    % iterate the total trial count for this plot object:
    p.draw.onlinePlotObj(11).UserData.trialCount = ...
        p.draw.onlinePlotObj(11).UserData.trialCount + 1;
end

% no free reward:
if any(p.trData.eventValues == p.init.codes.noFreeReward)

    % time to align to; only use the last one.
    alignTime = ...
        p.trData.eventTimes(p.trData.eventValues == ...
        p.init.codes.noFreeReward);

    % add the previous trial's spike times to the list of spike times we'll
    % use to construct the PSTH:
    p.draw.onlinePlotObj(12).UserData.spTimes = ...
        [p.draw.onlinePlotObj(12).UserData.spTimes; ...
        p.trData.spikeTimes(:) - alignTime(end)];

    % iterate the total trial count for this plot object:
    p.draw.onlinePlotObj(12).UserData.trialCount = ...
        p.draw.onlinePlotObj(12).UserData.trialCount + 1;
end

% MULTIPLE stimulus onset (all locations):
if any(p.trData.eventValues == p.init.codes.stimOn) && ...
        length(p.trVars.stimOnList) > 1

    % At which location did the CUED stimulus onset occur? We use that
    % information to define a plot index ("plotInd") that refers to an
    % element of p.draw.onlinePlotObj where we store the aligned spikes and
    % trial counts:
    plotInd = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
        strcmp(p.init.trialArrayColumnNames, 'cue loc')) + 12;

    % time to align to; only use the last one.
    alignTime = ...
        p.trData.eventTimes(p.trData.eventValues == p.init.codes.stimOn);

    % add the previous trial's spike times to the list of spike times we'll
    % use to construct the PSTH:
    p.draw.onlinePlotObj(plotInd).UserData.spTimes = ...
        [p.draw.onlinePlotObj(plotInd).UserData.spTimes; ...
        p.trData.spikeTimes(:) - alignTime(end)];

    % iterate the total trial count for this plot object:
    p.draw.onlinePlotObj(plotInd).UserData.trialCount = ...
        p.draw.onlinePlotObj(plotInd).UserData.trialCount + 1;
end

% stimulus change (all locations) with MULTIPLE stimuli present:
if any(p.trData.eventValues == p.init.codes.stimChange) && ...
        length(p.trVars.stimOnList) > 1

    % At which location did the stimulus change occur? We use that
    % information to define a plot index ("plotInd") that refers to an
    % element of p.draw.onlinePlotObj where we store the aligned spikes and
    % trial counts:
    plotInd = p.init.trialsArray(p.trVars.currentTrialsArrayRow, ...
        strcmp(p.init.trialArrayColumnNames, 'cue loc')) + 16;

    % time to align to; only use the last one.
    alignTime = ...
        p.trData.eventTimes(p.trData.eventValues == ...
        p.init.codes.stimChange);

    % add the previous trial's spike times to the list of spike times we'll
    % use to construct the PSTH:
    p.draw.onlinePlotObj(plotInd).UserData.spTimes = ...
        [p.draw.onlinePlotObj(plotInd).UserData.spTimes; ...
        p.trData.spikeTimes(:) - alignTime(end)];

    % iterate the total trial count for this plot object:
    p.draw.onlinePlotObj(plotInd).UserData.trialCount = ...
        p.draw.onlinePlotObj(plotInd).UserData.trialCount + 1;
end

catch me
    keyboard
end

end