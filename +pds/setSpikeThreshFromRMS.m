function p = setSpikeThreshFromRMS(p, chans, mult)
% pds.setSpikeThreshFromRMS  Set spike thresholds to a multiple of robust RMS.
%
% p = pds.setSpikeThreshFromRMS(p, chans, mult)
%
% Emulates Trellis's "Global Thresholding -> Multiple of RMS (Median)" mode
% using xippmex. Sets each channel's lower spike threshold to -mult*sigma,
% where sigma is the noise standard deviation in Ripple's spike-band stream
% (the same stream Trellis itself thresholds against).
%
% Inputs:
%   p     - PLDAPS struct. Requires p.rig.ripple.status==true; uses
%           p.rig.ripple.recChans as the default channel list.
%   chans - 1-indexed electrode IDs (optional, default p.rig.ripple.recChans).
%   mult  - RMS multiplier; threshold = -mult*sigma (optional, default 4).
%
% Output:
%   p.rig.ripple.spikeThresh - struct logging chans, sigma, lowThresh, mult,
%                              nWaveforms, and a NIP timestamp.
%
% How it works:
%   xippmex's 'cont' command can only retrieve raw/lfp/hi-res continuous data
%   -- the spike-band stream that Trellis computes RMS-Median on is not
%   exposed as a continuous stream. Filtering 'raw' ourselves does not give a
%   matching signal: in practice it yields a sigma estimate ~3x larger than
%   Trellis's, because raw and the spike stream are on different amplitude
%   scales (different quantization, possibly different gains/CMR in the NIP's
%   DSP). What IS exposed are the 52-sample waveform snippets that get
%   captured whenever a channel crosses its current threshold ('spike'
%   command). Those snippets ARE the spike-band stream.
%
%   So the algorithm here:
%     1. Save the current spike-thresh values.
%     2. Set a permissive test threshold (-3 uV) on each channel so that
%        every channel produces many noise-driven threshold crossings.
%     3. Flush any leftover spike packets from before the threshold change.
%     4. Wait briefly for new noise-crossing waveforms to accumulate.
%     5. Pull the waveforms with xippmex('spike',...).
%     6. Estimate sigma per channel as std of pooled pre-trigger baseline
%        samples (first nBaselinePre samples of each waveform). Trellis's
%        documented formula is MAD/0.6745 (i.e. scaled by 1.482), which for
%        Gaussian noise equals std exactly. We use std instead of MAD here
%        because the waveforms xippmex returns are quantized at 0.2 uV --
%        too coarse a grid for MAD to discriminate channels with sigma in
%        the 2-3 uV range. std averages over ~2500 baseline samples per
%        channel and stays well-behaved through the quantization.
%     7. Apply final thresholds at -mult * sigma. If a channel produced no
%        waveforms (dead/very quiet), its prior threshold is restored.
%
% Notes:
%   - Should be called during _init.m before recording starts. The brief
%     -3 uV test interval will produce a burst of spike packets that gets
%     transmitted/saved if recording is active.
%   - Does not touch the 'raw' stream, design any filters, or assume
%     anything about the NIP's filter chain -- it just uses what Ripple
%     emits as the spike stream.

% ---- arg defaults
if nargin < 3 || isempty(mult);  mult  = 4;                       end
if nargin < 2 || isempty(chans); chans = p.rig.ripple.recChans;   end

% ---- guards
if ~isfield(p, 'rig') || ~isfield(p.rig, 'ripple') || ...
        ~isfield(p.rig.ripple, 'status') || ~p.rig.ripple.status
    warning('pds:setSpikeThreshFromRMS:noRipple', ...
        'Ripple/NIP not connected; skipping spike-thresh setting.');
    return;
end
if isempty(chans)
    warning('pds:setSpikeThreshFromRMS:noChans', ...
        'No recording channels supplied; skipping spike-thresh setting.');
    return;
end
chans = chans(:)';

% ---- configuration
testThresh      = -3;     % uV: low enough to elicit many noise crossings
                          % on any reasonable channel (sigma 1-10 uV)
testDurSec      = 0.5;    % how long to accumulate noise crossings
nBaselinePre    = 10;     % samples 1..10 of each 52-sample waveform are
                          % pre-trigger -- pure baseline noise

% ---- save prior thresholds so we can restore them on failure or for
% channels that yield no waveforms
priorThresh = pds.xippmex('spike-thresh', chans);
priorThresh = priorThresh(:)';

restored = false;
try
    % Apply test threshold uniformly across channels
    pds.xippmex('spike-thresh', chans, testThresh * ones(1, numel(chans)));

    % Flush whatever was already buffered (events from prior thresholds)
    pds.xippmex('spike', chans, 0);

    % Accumulate noise crossings under the new test threshold
    WaitSecs(testDurSec);

    % Pull spike packets and extract waveforms
    [~, ~, waves, ~] = pds.xippmex('spike', chans, 0);

    % Estimate sigma per channel as std of pooled pre-trigger baseline
    % samples. The Trellis manual specifies MAD/0.6745 ("scaled by 1.482"),
    % which is the same as std for Gaussian noise -- but the waveforms
    % xippmex returns are quantized at 0.2 uV, and MAD on that quantized
    % grid is too coarse to discriminate channels with sigma in the 2-3 uV
    % range (every channel lands in the same MAD bin). std averages over
    % the ~2500 baseline samples per channel and stays well-behaved.
    sigma     = nan(numel(chans), 1);
    nWavesPer = zeros(numel(chans), 1);
    for c = 1:numel(chans)
        w = waves{c};
        if isempty(w);                              continue; end
        w = double(w);
        if size(w, 2) < nBaselinePre;               continue; end
        b = w(:, 1:nBaselinePre);
        sigma(c)     = std(b(:));
        nWavesPer(c) = size(w, 1);
    end

    valid = ~isnan(sigma) & sigma > 0;
    if ~any(valid)
        % Nothing crossed -- restore prior thresholds and bail
        pds.xippmex('spike-thresh', chans, priorThresh);
        restored = true;
        warning('pds:setSpikeThreshFromRMS:noCrossings', ...
            ['No noise crossings on any channel at test threshold ' ...
             '%g uV. Thresholds left at prior values.'], testThresh);
        return;
    end

    % Apply final thresholds. Channels without crossings keep prior values.
    lowThresh = priorThresh;
    lowThresh(valid) = -mult * sigma(valid)';
    pds.xippmex('spike-thresh', chans, lowThresh);
    restored = true;

catch ME
    if ~restored
        pds.xippmex('spike-thresh', chans, priorThresh);
    end
    rethrow(ME);
end

% ---- sanity check warning
if max(sigma(valid)) > 30
    warning('pds:setSpikeThreshFromRMS:sigmaSuspect', ...
        ['Estimated noise sigma exceeds 30 uV on at least one channel ' ...
         '(max %.1f uV, median %.1f uV). Typical spike-band noise is ' ...
         '1-5 uV; verify recording quality.'], ...
        max(sigma(valid)), median(sigma(valid)));
end

% ---- log into p
p.rig.ripple.spikeThresh = struct( ...
    'chans',       chans, ...
    'mult',        mult, ...
    'sigma',       sigma(:)', ...
    'lowThresh',   lowThresh, ...
    'nWaveforms',  nWavesPer(:)', ...
    'testThresh',  testThresh, ...
    'testDurSec',  testDurSec, ...
    'nipTime',     pds.xippmex('time'));

fprintf(['pds.setSpikeThreshFromRMS: set lower thresholds on %d/%d ' ...
         'channels (mult=%.2f, sigma %.2f-%.2f uV from %d-%d ' ...
         'noise-crossing waveforms per channel)\n'], ...
        sum(valid), numel(chans), mult, ...
        min(sigma(valid)), max(sigma(valid)), ...
        min(nWavesPer(valid)), max(nWavesPer(valid)));

end
