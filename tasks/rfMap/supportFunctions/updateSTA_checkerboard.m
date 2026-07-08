function staAccum = updateSTA_checkerboard( ...
    staAccum, spikeTimesPerChan, stimOnTime, frameDurS, ...
    polaritySequence, condIdx, reversalHz, nLags)
% updateSTA_checkerboard  Accumulate temporal kernel + F1/F2 for one trial.
%
%   staAccum = updateSTA_checkerboard( ...
%       staAccum, spikeTimesPerChan, stimOnTime, frameDurS, ...
%       polaritySequence, condIdx, reversalHz, nLags)
%
%   Aggregates this trial's spike data into the running checkerboard
%   STA struct. Two analyses run in parallel:
%
%   (a) Temporal reverse-correlation. For each spike on each channel,
%       walk back nLags display frames and accumulate the polarity
%       (+/-1) at each lag into
%           temporalKernel(lag, checkSize, contrast, channel).
%       At plot time the kernel is normalized by the spike count for
%       that (checkSize, contrast, channel) cell.
%
%   (b) F1/F2 amplitude. computeF1F2 returns the per-trial complex
%       sum z = (z_F1, z_F2). We accumulate |z| (amplitude) into
%       f1f2AmpSum and increment the per-condition trial count. At
%       plot time amplitude = f1f2AmpSum / f1f2TrialCount (the plan
%       locks the cross-trial average as mean(|z|), no phase-locking
%       across trials).
%
%   Inputs:
%     staAccum          - struct with these accumulator fields:
%       .temporalKernel       [nLags, nCheckSize, nContrast, nCh]
%       .spikeCountPerCondCh  [nCheckSize, nContrast, nCh]
%       .f1f2AmpSum           [2, nCheckSize, nContrast, nCh]
%       .f1f2TrialCount       [nCheckSize, nContrast] -- trials per cond
%     spikeTimesPerChan - cell{nCh,1} of spike times in Ripple-clock
%                         seconds.
%     stimOnTime       - Ripple-clock time of stimOn for this trial.
%     frameDurS         - DISPLAY frame duration (1/refreshRate).
%                         Polarity-frame resolution; do NOT confuse
%                         with the noise-frame-hold of dense modes.
%     polaritySequence  - [1, nFramesTrial] vector of +/-1 recording the
%                         polarity at each display frame of the trial.
%     condIdx           - [checkSizeIdx, contrastIdx] for this trial.
%     reversalHz        - polarity FLIP rate (flips/s). The contrast
%                         fundamental is reversalHz/2; F1 is evaluated
%                         there and F2 at reversalHz.
%     nLags             - number of temporal lags (in display frames).
%
%   Output:
%     staAccum updated in place. spikeCountPerCondCh, temporalKernel,
%     and f1f2AmpSum are incremented; f1f2TrialCount(sz, ct) is
%     incremented by 1 for this trial regardless of spike count
%     (empty trials contribute z = 0 to the mean amplitude).

szIdx        = condIdx(1);
ctIdx        = condIdx(2);
nFramesTrial = numel(polaritySequence);
nCh          = numel(spikeTimesPerChan);

% Increment per-condition trial count once for this trial. F1/F2
% averages across all trials at this condition; trials with zero
% spikes contribute |z| = 0.
staAccum.f1f2TrialCount(szIdx, ctIdx) = ...
    staAccum.f1f2TrialCount(szIdx, ctIdx) + 1;

trialEndTime = stimOnTime + nFramesTrial * frameDurS;

for ch = 1:nCh
    spikes = spikeTimesPerChan{ch};
    if isempty(spikes), continue; end

    % Restrict to spikes within the trial window.
    spikes = spikes(spikes >= stimOnTime & spikes < trialEndTime);
    if isempty(spikes), continue; end

    % Spike times relative to stimOn (trial-aligned for F1/F2).
    spikesRel = spikes - stimOnTime;

    % --- (a) Temporal reverse-correlation ---
    spikeFrameIdx = floor(spikesRel / frameDurS) + 1;
    nSpikesInTrial = numel(spikeFrameIdx);

    staAccum.spikeCountPerCondCh(szIdx, ctIdx, ch) = ...
        staAccum.spikeCountPerCondCh(szIdx, ctIdx, ch) + nSpikesInTrial;

    for s = 1:nSpikesInTrial
        sf = spikeFrameIdx(s);
        for lag = 1:nLags
            stimIdx = sf - lag + 1;
            if stimIdx >= 1 && stimIdx <= nFramesTrial
                staAccum.temporalKernel(lag, szIdx, ctIdx, ch) = ...
                    staAccum.temporalKernel(lag, szIdx, ctIdx, ch) + ...
                    double(polaritySequence(stimIdx));
            end
        end
    end

    % --- (b) F1/F2 ---
    % reversalHz is the polarity FLIP rate (flips/s). One full +/- contrast
    % cycle takes TWO flips, so the stimulus fundamental is reversalHz/2:
    % the linear (X-like) response F1 lives at reversalHz/2 and the
    % frequency-doubled (Y-like) response F2 at reversalHz. computeF1F2
    % evaluates F1 at its argument and F2 at 2x, so pass the FUNDAMENTAL,
    % not the flip rate. (Passing reversalHz put F1 on an even harmonic
    % where a symmetric square-wave reversal has no linear power.)
    f1Hz = reversalHz / 2;
    z = computeF1F2(spikesRel, f1Hz);
    staAccum.f1f2AmpSum(:, szIdx, ctIdx, ch) = ...
        staAccum.f1f2AmpSum(:, szIdx, ctIdx, ch) + abs(z);
end

end
