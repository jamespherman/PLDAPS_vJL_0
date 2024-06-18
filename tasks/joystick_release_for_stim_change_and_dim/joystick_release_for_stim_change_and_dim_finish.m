function p = joystick_release_for_stim_change_and_dim_finish(p)
%
%   p = joystick_release_for_stim_change_and_dim_finish(p)
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

% (0) get buffered spike times and event times from ripple (this might seem
% like an odd time to do this but before you go changing it ask jph), then
% align spikes to events for later plotting. This is currently a hack
% because we drop the first trial's events - figure out a way around this.
if p.rig.ripple.status
    p = pds.getRippleData(p);
end
p = alignSpikes(p);

% (1) fill screen with background color (if we're not playing a movie)
if ~isfield(p.draw, 'movie')
    Screen('FillRect', p.draw.window, p.draw.color.background);
    Screen('Flip', p.draw.window);
end

% read buffered ADC and DIN data from DATAPixx
p           = pds.readDatapixxBuffers(p);

% Was the previous trial aborted?
p.trData.trialRepeatFlag = (p.trData.trialEndState > 10) & ...
    (p.trData.trialEndState < 20);                                                       

%% strobes:
% strobe trial data:
p           = pds.strobeTrialData(p);
% save strobed codes:
p.trData.strobed = p.init.strb.strobedList;

% flush strobe "veto" & "strobed" list
p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

% wait for joystick release
% p           = pds.waitForJoystickRelease(p);

% if a "time-out" is desired, make it happen here. Note: the way this works
% at present is: we only advance from here if the desired interval of time
% has elapsed since the end of the previous trial. This means that if the
% monkey has held the joystick down for a "long time" since the end of the
% last trial, the "time-out" window has passed and there won't be an
% ADDITIONAL time out.
postTrialTimeOut(p);

% Wait a randomized duration after the reward in the last trial, or if
% there was no reward wait that same duration after the end of the last
% trial. First define which of those two event's we're waiting relative to:
if p.trData.timing.reward > 0
    relTime = p.trData.timing.reward + p.trVars.rewardScheduleDur;
else
    relTime = p.trData.timing.trialEnd;
end

% Wait "p.trVars.postRewardDuration" seconds after the relevant event
% defined above:
timeNow = GetSecs - p.trData.timing.trialStartPTB;
WaitSecs(relTime + p.trVars.postRewardDuration - timeNow);

% If this trial has a free inter-trial-interval reward available and didn't
% end in "repeatFlag", give a free reward:
if p.trVars.freeRewardProbability > 0 && ...
        p.status.freeRewardsAvailable(p.trVars.currentTrialsArrayRow) ...
        && ~p.trData.trialRepeatFlag

    % deliver free reward
    p = pds.freeReward(p);

    % update count of total free rewards given:
    p.status.freeRwdTotal = p.status.freeRwdTotal + 1;

    % update last trial in which free reward was given:
    p.status.freeRwdLast  = p.status.iTrial;
else

    % strobe time of no free reward
    p.init.strb.strobeNow(p.init.codes.noFreeReward);

    % wait same duration as reward schedule;
    % WaitSecs(p.trVars.rewardScheduleDur);
end

% store missed frames count
p.trData.missedFrameCount = nnz(diff(p.trData.timing.flipTime) > ...
    p.rig.frameDuration * 1.5);
p.status.missedFrames = p.status.missedFrames + p.trData.missedFrameCount;

% (5) auto save backup
pds.saveP(p);

% (6) if we're using QUEST, compute the posterior and update the parameter
% estimates here
p           = updateQuest(p);

% (8) update trials list
p           = updateTrialsList(p);

% (7) update status variables
p           = updateStatusVariables(p);

% (8) if we're using online plots, update them now:
if isfield(p.trVars, 'wantOnlinePlots') && p.trVars.wantOnlinePlots
    p       = updateOnlinePlots(p);
end

end