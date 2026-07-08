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

%% (0) Retrieve spike data from Ripple (or simulator under sim mode)
if isfield(p.trVars, 'useSimulatedSpikes') && p.trVars.useSimulatedSpikes
    % Simulation-mode validation harness: ground-truth LNP spikes from
    % p.init.simKernelBank instead of live Ripple. Field layout matches
    % pds.getRippleData (spikeTimes/spikeClusters/eventTimes/eventValues).
    p = simulateRippleData(p);
elseif isfield(p.rig, 'ripple') && isfield(p.rig.ripple, 'recChans') && ...
        p.rig.ripple.status && ~isempty(p.rig.ripple.recChans)
    p = pds.getRippleData(p);
end

%% (0b) Trim spikes to stimulus presentation window.
% The first pds.getRippleData call each session reads the entire Ripple
% spike buffer, which may contain thousands of pre-session threshold
% crossings. Inter-trial crossings also accumulate during ITIs. Discard
% everything outside the stimulus window so saved p.trData is clean and
% the per-spike accumulation loop is faster. The per-stim-type updateSTA
% function applies its own precise per-frame filter; this is a coarse
% upstream pass.
if ~isempty(p.trData.spikeTimes) && ~isempty(p.trData.eventValues)
    stimOnCode_ = p.init.codes.stimOn;
    evIdx_      = find(p.trData.eventValues == stimOnCode_, 1, 'last');
    if ~isempty(evIdx_)
        stimOnRipple_ = p.trData.eventTimes(evIdx_);
        trialDurS_    = p.trVars.nFramesThisTrial * p.trVars.noiseFrameDurS;
        inWindow_     = p.trData.spikeTimes >= stimOnRipple_ & ...
                        p.trData.spikeTimes <  stimOnRipple_ + trialDurS_;
        nDiscarded_   = numel(p.trData.spikeTimes) - nnz(inWindow_);
        if nDiscarded_ > 0
            fprintf('  Spike filter: kept %d of %d (discarded %d out-of-window).\n', ...
                nnz(inWindow_), numel(p.trData.spikeTimes), nDiscarded_);
            p.trData.spikeTimes    = p.trData.spikeTimes(inWindow_);
            p.trData.spikeClusters = p.trData.spikeClusters(inWindow_);
        end
    end
end

%% (1) Fill screen with background and flip
Screen('FillRect', p.draw.window, p.draw.color.background);
Screen('Flip', p.draw.window);

%% (2) Read buffered ADC and DIN data from DataPixx
p = pds.readDatapixxBuffers(p);

%% (3) Determine if trial should be repeated
p.trData.trialRepeatFlag = (p.trData.trialEndState > 10) & ...
    (p.trData.trialEndState < 20);

%% (4) Update playback / trial-array progress
if ~p.trData.trialRepeatFlag
    % Successful trial.
    p.status.iGoodTrial = p.status.iGoodTrial + 1;

    if strcmp(p.init.stimType, 'checkerboard')
        % Pop the row that nextParams peeked at, so it isn't shown
        % again. Aborted trials would have left the row in place,
        % causing it to re-present next trial.
        if ~isempty(p.status.trialsArrayRowsPossible)
            p.status.trialsArrayRowsPossible = ...
                p.status.trialsArrayRowsPossible(2:end);
        end
        % Mark this row's `completed` column.
        if isfield(p.trVars, 'checkerboardTrialRow')
            cols = p.init.trialArrayColumnNames;
            cIdx = find(strcmp(cols, 'completed'), 1);
            if ~isempty(cIdx)
                p.init.trialsArray(p.trVars.checkerboardTrialRow, cIdx) = 1;
            end
        end
    else
        % Noise-movie modes: advance playback index.
        p.init.noiseFrameIdx = p.trVars.trialEndFrame + 1;
    end

    % (4b) Accumulate STA from Ripple data (if enabled and data available)
    useSim = isfield(p.trVars, 'useSimulatedSpikes') && ...
        p.trVars.useSimulatedSpikes;
    if ((p.trVars.useRippleSTA && p.rig.ripple.status) || useSim) && ...
            ~isempty(p.trData.spikeTimes)
        p = accumulateSTA(p);

        % (4c) Per-channel RF center estimate (dva re fixation).
        % Cheap (argmax + centroid over ~nY x nX), runs every good
        % trial. Checkerboard returns all-NaN inside the helper.
        % Persisted on p.init so aborts/zero-spike trials inherit the
        % latest valid estimate when saved.
        p.init.lastRFCentersDeg = computeRFCenters(p);
    end
end

% Mirror the persistent estimate into trData so every saved trial file
% carries the most recent centers. Initialized to NaN in rfMap_init;
% updated above on successful trials with spikes.
if isfield(p.init, 'lastRFCentersDeg')
    p.trData.rfCentersDeg = p.init.lastRFCentersDeg;
end
% If trial was aborted: noise-movie modes re-present the same frames
% next trial; checkerboard leaves the row in trialsArrayRowsPossible
% so it gets retried.

%% (4d) Monitor spike threshold drift (passive rate tracking).
if ~p.trData.trialRepeatFlag && ...
        isfield(p.rig, 'ripple') && p.rig.ripple.status && ...
        ~(isfield(p.trVars, 'useSimulatedSpikes') && p.trVars.useSimulatedSpikes)
    p = pds.monitorSpikeThresholds(p);
end

%% (5) Strobe trial data
p = pds.strobeTrialData(p);

%% (5b) Strobe trialEnd (exactly once, after the paired info strobes,
% before any post-trial WaitSecs). Mirrors barsweep_finish.m:128-131.
p.trData.timing.trialEnd = GetSecs - p.trData.timing.trialStartPTB;
p.init.strb.strobeNow(p.init.codes.trialEnd);

% Add the list of strobes to trData to be saved
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
% p.init before saving. pds.saveP saves p.init on every trial; writing
% hundreds of MB per trial would be very slow. The RNG seed and
% generator parameters are saved, so the movie can be reconstructed
% offline.
%
% Chromatic mode no longer holds a session-level dklDriveTensor or
% noiseMovie: nextParams.m regenerates them per trial from per-trial
% seeds saved in the trial array. The per-trial fields live on
% p.trVars.* and are reset by _next on the next trial; we don't need
% to strip them here.
tempMovie    = p.init.noiseMovie;
tempStaAccum = p.init.staAccum;
tempStaFig   = [];
if isfield(p.init, 'staFigData')
    tempStaFig = p.init.staFigData;
    p.init.staFigData = [];
end
tempStaBrowser = [];
if isfield(p.init, 'staBrowser')
    tempStaBrowser = p.init.staBrowser;
    p.init.staBrowser = [];
end
p.init.noiseMovie = [];    % replaced by RNG seed for reconstruction
p.init.staAccum   = [];    % only saved at session end if needed
pds.saveP(p);
p.init.noiseMovie = tempMovie;
p.init.staAccum   = tempStaAccum;
if ~isempty(tempStaFig)
    p.init.staFigData = tempStaFig;
end
if ~isempty(tempStaBrowser)
    p.init.staBrowser = tempStaBrowser;
end

%% (9) Close PTB textures to free VRAM
% Per-frame textures generated each trial for the noise-movie modes
% must be closed. Checkerboard textures live on
% p.init.checkInfo.textures (persistent across trials), do NOT close
% them per trial.
if ~strcmp(p.init.stimType, 'checkerboard') && ...
        isfield(p.trVars, 'noiseTextures') && ...
        ~isempty(p.trVars.noiseTextures)
    validTex = p.trVars.noiseTextures(p.trVars.noiseTextures > 0);
    if ~isempty(validTex)
        Screen('Close', validTex);
    end
    p.trVars.noiseTextures = [];
end

%% (10) Update status variables for GUI display
if strcmp(p.init.stimType, 'checkerboard')
    % Movie-frame progress is meaningless for checkerboard (no movie);
    % use trial-array progress instead.
    nTotalCheckTrials = size(p.init.trialsArray, 1);
    nDoneCheckTrials  = nTotalCheckTrials - ...
        numel(p.status.trialsArrayRowsPossible);
    p.status.moviePctComplete = round( ...
        100 * nDoneCheckTrials / max(1, nTotalCheckTrials));
else
    p.status.moviePctComplete = round( ...
        100 * p.init.noiseFrameIdx / p.init.nNoiseFrames);
end
p.status.totalSpikesAccum = sum(p.init.staSpikeCount(:, 1));
p.status.iAbortedTrial    = p.status.iTrial - p.status.iGoodTrial;

if p.trData.trialEndState == p.state.fixBreak
    p.status.fixBreakCount = p.status.fixBreakCount + 1;
elseif p.trData.trialEndState == p.state.nonStart
    p.status.nonStartCount = p.status.nonStartCount + 1;
elseif p.trData.trialEndState == p.state.noiseComplete
    p.status.rewardCount = p.status.rewardCount + 1;
end

if p.trData.timing.stimOn > 0 && p.trData.timing.trialEnd > 0
    p.status.lastTrialDurS = p.trData.timing.trialEnd - p.trData.timing.stimOn;
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
% Uses event times from Ripple to find stimOn in Ripple clock,
% then feeds spike times through updateSTA.

% Find the stimOn event in Ripple's digital event stream
stimOnCode = p.init.codes.stimOn;
eventIdx = find(p.trData.eventValues == stimOnCode, 1, 'last');

if isempty(eventIdx)
    fprintf('  STA: stimOn event not found in Ripple data, skipping.\n');
    return;
end

stimOnTimeRipple = p.trData.eventTimes(eventIdx);

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

% Branch by stim type. The spatial modes go through the standard
% updateSTA dispatcher with a per-stim-type stimulus tensor;
% checkerboard has a distinct call signature (per-trial polarity
% sequence + condition + reversalHz) and a struct-shaped accumulator,
% so we call updateSTA_checkerboard directly rather than via the
% dispatcher.
if strcmp(p.init.stimType, 'checkerboard')
    p.init.staAccum = updateSTA_checkerboard( ...
        p.init.staAccum, spikeTimesPerChan, stimOnTimeRipple, ...
        p.trVars.noiseFrameDurS, ...
        p.trVars.checkPolaritySequence, ...
        [p.trVars.checkSizeIdx, p.trVars.contrastIdx], ...
        p.trVars.checkReversalHz, ...
        p.trVars.nSTALags);

    % Update the flat staSpikeCount per channel (used by the GUI
    % status display). Sum spikes across this trial within the trial
    % window.
    trialEndTime = stimOnTimeRipple + ...
        p.trVars.nFramesThisTrial * p.trVars.noiseFrameDurS;
    for ch = 1:p.trVars.nChannels
        spk = spikeTimesPerChan{ch};
        if ~isempty(spk)
            n = sum(spk >= stimOnTimeRipple & spk < trialEndTime);
            p.init.staSpikeCount(ch, :) = p.init.staSpikeCount(ch, :) + n;
        end
    end
else
    % Spatial-mode dispatcher path. For denseChromatic, STA is
    % accumulated against the per-trial DKL drive tensor (regenerated
    % in nextParams from the per-trial seed; lives on p.trVars). For
    % achromatic / sparse, the session-level pre-rendered movie on
    % p.init is the stimulus tensor directly.
    switch p.init.stimType
        case 'denseChromatic'
            stimTensor = p.trVars.thisTrialDklDrive;
            % Per-trial drive starts at frame 1 of its own tensor.
            stimStartFrame = 1;
        otherwise
            stimTensor     = p.init.noiseMovie;
            stimStartFrame = p.trVars.trialStartFrame;
    end

    [p.init.staAccum, p.init.staSpikeCount] = updateSTA( ...
        p.init.stimType, p.init.staAccum, p.init.staSpikeCount, ...
        spikeTimesPerChan, stimOnTimeRipple, ...
        p.trVars.noiseFrameDurS, stimTensor, ...
        stimStartFrame, p.trVars.nFramesThisTrial, ...
        p.trVars.nSTALags);

    % Zero the fixation-occluded checks: the clearing patch / fixation
    % point are drawn over the noise (rfMap_run.m), so the noise there was
    % never shown and its STA correlation is a spurious RF pinned at
    % fixation. Applied every trial so the live RF centres / maps stay
    % clean. (Cached mask; geometry is fixed within a session.)
    if ~isfield(p.init, 'occludedMask') || isempty(p.init.occludedMask)
        p.init.occludedMask = occludedCheckMask(p);
    end
    p.init.staAccum = applyOccludedMask(p.init.staAccum, p.init.occludedMask);
end

% Update online STA display via dispatcher, throttled per
% staPlotEveryNTrials. Accumulators update every successful trial;
% the plot only re-renders on schedule.
if isfield(p.init, 'staFigData') && ...
        mod(p.status.iGoodTrial, p.trVars.staPlotEveryNTrials) == 0
    plotSTA(p.init.stimType, p.init.staFigData, ...
        p.init.staAccum, p.init.staSpikeCount, 1);
    % Refresh the per-channel browser (separate uifigure, same cadence).
    % Dispatched by stimType: checkerboard uses an F1-amplitude image
    % per channel; everything else uses the spatial image + power-vs-lag
    % tile.
    if isfield(p.init, 'staBrowser') && ~isempty(p.init.staBrowser) && ...
            isfield(p.init.staBrowser, 'fig') && isvalid(p.init.staBrowser.fig)
        switch p.init.stimType
            case 'checkerboard'
                updateCheckerboardChannelBrowser(p.init.staBrowser, ...
                    p.init.staAccum);
            otherwise
                updateSTAChannelBrowser(p.init.staBrowser, ...
                    p.init.staAccum, p.init.staSpikeCount, ...
                    p.init.lastRFCentersDeg);
        end
    end
end

fprintf('  STA: %d total spikes accumulated\n', p.init.staSpikeCount(1, 1));

end
