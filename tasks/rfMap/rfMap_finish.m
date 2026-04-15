function p = rfMap_finish(p)
%   p = rfMap_finish(p)
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% Post-trial processing: retrieve Ripple data, accumulate STA on
% successful trials, update display, strobe data, save, close textures.

%% (0) Retrieve spike data from Ripple
if isfield(p.rig, 'ripple') && isfield(p.rig.ripple, 'recChans') && ...
        p.rig.ripple.status && ~isempty(p.rig.ripple.recChans)
    p = pds.getRippleData(p);
end

%% (1) Fill screen with background and flip
Screen('FillRect', p.draw.window, p.draw.color.background);
Screen('Flip', p.draw.window);

%% (2) Read buffered ADC and DIN data from DataPixx
p = pds.readDatapixxBuffers(p);

%% (3) Determine if trial should be repeated
p.trData.trialRepeatFlag = (p.trData.trialEndState > 10) & ...
    (p.trData.trialEndState < 20);

%% (4) Update noise movie playback position
if ~p.trData.trialRepeatFlag
    % Successful trial: advance movie index
    p.init.noiseFrameIdx = p.trVars.trialEndFrame + 1;
    p.status.iGoodTrial  = p.status.iGoodTrial + 1;

    % (4b) Accumulate STA from Ripple data (if enabled and data available)
    if p.trVars.useRippleSTA && p.rig.ripple.status && ...
            ~isempty(p.trData.spikeTimes)
        p = accumulateSTA(p);
    end
end
% If trial was aborted, noiseFrameIdx stays the same (re-present frames)

%% (5) Strobe trial data
p = pds.strobeTrialData(p);
p.trData.strobed = p.init.strb.strobedList;

% Flush strobe veto & strobed lists
p.init.strb.flushVetoList;
p.init.strb.flushStrobedList;

%% (6) Post-trial timeout (for fixation breaks)
if p.trData.trialRepeatFlag
    WaitSecs(p.trVars.timeoutAfterFixBreak);
end

%% (7) Store missed frames count
p.trData.missedFrameCount = nnz(diff(p.trData.timing.flipTime) > ...
    p.rig.frameDuration * 1.5);
p.status.missedFrames = p.status.missedFrames + p.trData.missedFrameCount;

%% (8) Auto save
% Temporarily remove the large noise movie and STA accumulators from
% p.init before saving. pds.saveP saves p.init on every trial, and the
% noise movie alone is ~237 MB -- writing that per trial is very slow.
% The RNG seed is saved, so the movie can be reconstructed offline.
tempMovie    = p.init.noiseMovie;
tempStaAccum = p.init.staAccum;
tempStaFig   = [];
if isfield(p.init, 'staFigData')
    tempStaFig = p.init.staFigData;
    p.init.staFigData = [];
end
p.init.noiseMovie = [];    % replaced by RNG seed for reconstruction
p.init.staAccum   = [];    % only saved at session end if needed
pds.saveP(p);
p.init.noiseMovie = tempMovie;
p.init.staAccum   = tempStaAccum;
if ~isempty(tempStaFig)
    p.init.staFigData = tempStaFig;
end

%% (9) Close PTB textures to free VRAM
if isfield(p.trVars, 'noiseTextures') && ~isempty(p.trVars.noiseTextures)
    validTex = p.trVars.noiseTextures(p.trVars.noiseTextures > 0);
    if ~isempty(validTex)
        Screen('Close', validTex);
    end
    p.trVars.noiseTextures = [];
end

%% (10) Update status variables for GUI display
p.status.moviePctComplete = round(100 * p.init.noiseFrameIdx / p.init.nNoiseFrames);
p.status.totalSpikesAccum = sum(p.init.staSpikeCount);
p.status.iAbortedTrial    = p.status.iTrial - p.status.iGoodTrial;

if p.trData.trialEndState == p.state.fixBreak
    p.status.fixBreakCount = p.status.fixBreakCount + 1;
elseif p.trData.trialEndState == p.state.nonStart
    p.status.nonStartCount = p.status.nonStartCount + 1;
elseif p.trData.trialEndState == p.state.noiseComplete
    p.status.rewardCount = p.status.rewardCount + 1;
end

if p.trData.timing.noiseOn > 0 && p.trData.timing.trialEnd > 0
    p.status.lastTrialDurS = p.trData.timing.trialEnd - p.trData.timing.noiseOn;
end
if p.status.iGoodTrial > 0
    p.status.meanFixHoldS = round(100 * p.status.rewardCount * ...
        p.trVars.trialDurationS / max(1, p.status.iTrial)) / 100;
end

%% (11) Print trial summary
if p.trData.trialRepeatFlag
    outcomeStr = 'ABORT';
else
    outcomeStr = 'GOOD';
end
fprintf('Trial %d: %s | %d good | movie %.1f%% | missed: %d\n', ...
    p.status.iTrial, outcomeStr, p.status.iGoodTrial, ...
    p.status.moviePctComplete, p.trData.missedFrameCount);

end

%% ---- Local functions ----

function p = accumulateSTA(p)
% Accumulate STA from this trial's Ripple spike data.
%
% Uses event times from Ripple to find noiseOn in Ripple clock,
% then feeds spike times through updateSTA.

% Find the noiseOn event in Ripple's digital event stream
noiseOnCode = p.init.codes.noiseOn;
eventIdx = find(p.trData.eventValues == noiseOnCode, 1, 'last');

if isempty(eventIdx)
    fprintf('  STA: noiseOn event not found in Ripple data, skipping.\n');
    return;
end

noiseOnTimeRipple = p.trData.eventTimes(eventIdx);

% Organize spike times by channel
spikeTimesPerChan = cell(p.trVars.nChannels, 1);
if isfield(p.trData, 'spikeClusters') && ~isempty(p.trData.spikeClusters)
    for ch = 1:p.trVars.nChannels
        chanMask = p.trData.spikeClusters == ch;
        spikeTimesPerChan{ch} = p.trData.spikeTimes(chanMask);
    end
else
    % All spikes go to channel 1
    spikeTimesPerChan{1} = p.trData.spikeTimes;
end

% Call the core STA accumulation function
[p.init.staAccum, p.init.staSpikeCount] = updateSTA( ...
    p.init.staAccum, p.init.staSpikeCount, ...
    spikeTimesPerChan, noiseOnTimeRipple, ...
    p.trVars.noiseFrameDurS, p.init.noiseMovie, ...
    p.trVars.trialStartFrame, p.trVars.nFramesThisTrial, ...
    p.trVars.nSTALags);

% Update online STA display
if isfield(p.init, 'staFigData')
    plotSTA(p.init.staFigData, p.init.staAccum, p.init.staSpikeCount, 1);
end

fprintf('  STA: %d total spikes accumulated\n', p.init.staSpikeCount(1));

end
