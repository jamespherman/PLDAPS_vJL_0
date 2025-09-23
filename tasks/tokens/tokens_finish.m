function p = tokens_finish(p)
%
% Part of the quintet of pldaps functions. This function runs at the end
% of every trial to handle data saving, plot updates, and trial logic.

% Clear the screen by filling it with the background color
if ~isfield(p.draw, 'movie')
    Screen('FillRect', p.draw.window, p.draw.color.background);
    Screen('Flip', p.draw.window);
end

% Read any buffered ADC and DIN data from the DataPixx
p = pds.readDatapixxBuffers(p);

% Determine if the trial should be repeated based on the end state
p.trData.trialRepeatFlag = (p.trData.trialEndState > 10) && ...
    (p.trData.trialEndState < 20);
if p.trData.trialRepeatFlag
    p.status.repeatLast = true;
    p.status.lastTrialRow = p.trVars.currentTrialsArrayRow;
else
    p.status.repeatLast = false;
end

%% Strobes and Timestamps
% Strobe trial data summary (you will handle adding rewardAmt to this)
p = pds.strobeTrialData(p);

% Mark and strobe the final end of the trial
timeNow = GetSecs - p.trData.timing.trialStartPTB;
p.trData.timing.trialEnd   = timeNow;
p.init.strb.strobeNow(p.init.codes.trialEnd);

% Mark final end time in PTB & DP time
[p.trData.timing.trialEndPTB, p.trData.timing.trialEndDP] = pds.getTimes;

% Save the list of all strobed values for this trial
p.trData.strobed = p.init.strb.strobedList;

% Flush strobe lists for the next trial
p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

% Pause ephys recording
pds.stopOmniPlex;

% Retrieve data from Omniplex PC if desired
if p.rig.connectToOmniplex
    p = pds.getOmniplexData(p);
end

% Store frame rate information
p.trData.missedFrameCount = nnz(diff(p.trData.timing.flipTime) > ...
    p.rig.frameDuration * 1.5);
p.status.missedFrames = p.status.missedFrames + p.trData.missedFrameCount;

% Auto save a backup of the PDS structure
pds.saveP(p);

% Update trials list to handle repetition logic
p = updateTrialsList(p);

% Update status variables (e.g., performance metrics)
p = updateStatusVariables(p);

% Update online plots if they are enabled
if isfield(p.trVars, 'wantOnlinePlots') && p.trVars.wantOnlinePlots
    p = updateOnlinePlots(p);
end

end