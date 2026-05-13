function p = setSpikeThreshFromRMS(p, chans, mult)
% pds.setSpikeThreshFromRMS  Set spike thresholds to a multiple of median-based RMS.
%
% p = pds.setSpikeThreshFromRMS(p, chans, mult)
%
% Emulates Trellis's "Global Thresholding -> Multiple of RMS (Median)" mode
% using only xippmex. For each channel in chans, retrieves ~2 s of raw
% continuous data, applies the same bandpass filter the NIP uses for spike
% detection, computes a robust noise estimate
%
%     sigma_n = median(|x|) / 0.6745     (Quian Quiroga et al., 2004)
%
% and sets the lower spike threshold to -mult * sigma_n via
% xippmex('spike-thresh', ...).
%
% Inputs:
%   p     - PLDAPS struct. Requires p.rig.ripple.status==true; uses
%           p.rig.ripple.recChans as the default channel list.
%   chans - 1-indexed electrode IDs (optional, default p.rig.ripple.recChans).
%   mult  - RMS multiplier; threshold = -mult*sigma_n (optional, default 4).
%
% Output:
%   p.rig.ripple.spikeThresh - struct logging chans, sigma, lowThresh, mult,
%                              filter label, durMs, and a NIP timestamp.
%
% Notes:
%   - The 'raw' stream is enabled for these channels for the duration of the
%     measurement and restored to its prior state afterwards (raw at 30 kHz
%     across many channels is expensive on the NIP->PC link).
%   - The spike-band filter is queried from the NIP and used directly (SOS
%     coefficients), so the noise statistic is computed on a signal whose
%     bandwidth matches the stream the NIP actually thresholds.
%   - Intended to be called from a task's _init.m after pds.initRipple, on a
%     quiet period (no visual stim driving units, no electrical stim, no
%     opto). The default 2 s window with 32-64 channels easily fits in the
%     5 s circular buffer.

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
chans = chans(:)';   % row vector for xippmex

% ---- configuration
durMs = 2000;     % length of background snippet (ms); ring buffer holds 5 s
fsRaw = 30000;    % 'raw' stream sample rate (Hz), per Xippmex manual

% ---- query the spike-band cutoffs from the NIP, then design our own
% 4th-order Butterworth bandpass at those cutoffs. The SOS matrix that
% xippmex returns from filter('list',...) for built-in slots isn't always
% usable directly with filtfilt (column convention not guaranteed to match
% MATLAB's [b0 b1 b2 a0 a1 a2]), and an SOS that silently behaves as a
% near-passthrough yields LFP-dominated noise estimates orders of magnitude
% too large. Re-designing at the queried cutoffs keeps the noise band
% matched to what the NIP actually thresholds on.
[sel, filt] = pds.xippmex('filter', 'list', chans(1), 'spike');
lo = filt(sel).lowCutoff;
hi = filt(sel).highCutoff;
if ~(isfinite(lo) && isfinite(hi) && lo > 0 && hi > lo && hi < fsRaw/2)
    % Cutoffs are missing or nonsensical; use a sensible default spike band.
    lo = 300;  hi = 5000;
    fLabel = sprintf('%s -> default %g-%g Hz Butterworth-4', ...
                     filt(sel).label, lo, hi);
else
    fLabel = sprintf('%s -> %g-%g Hz Butterworth-4', filt(sel).label, lo, hi);
end
[zz, pp, kk] = butter(4, [lo hi] / (fsRaw/2), 'bandpass');
sos = zp2sos(zz, pp, kk);

% ---- save prior raw-stream enable state; enable any channels that are off.
% 'raw' is enabled on a per-FrontEnd basis (manual p.8), so xippmex rejects
% per-channel array values for this stream -- pass scalars to channel subsets.
priorRawState = double(pds.xippmex('signal', chans, 'raw'));
priorRawState = priorRawState(:)';
offChans = chans(priorRawState == 0);
if ~isempty(offChans)
    pds.xippmex('signal', offChans, 'raw', 1);
    % only need a long wait if we just enabled streaming
    WaitSecs(durMs/1000 + 0.3);
else
    % already streaming; ring buffer is full -- short settle is enough
    WaitSecs(0.1);
end

% ---- pull background snippet, [nChan x nSamp], microvolts
data = pds.xippmex('cont', chans, durMs, 'raw');
data = double(data);

% ---- bandpass to the spike band, then robust sigma per channel
xbp       = filtfilt(sos, 1, data')';        % filtfilt operates on columns
sigma     = median(abs(xbp), 2) / 0.6745;    % [nChan x 1], microvolts
lowThresh = -mult * sigma;                   % microvolts, negative

% ---- sanity check: spike-band sigma is typically a few uV. If it's much
% larger, the filter probably isn't doing its job (e.g. LFP leaking through)
% and the thresholds are about to be set absurdly large. Warn loudly.
if max(sigma) > 30
    warning('pds:setSpikeThreshFromRMS:sigmaSuspect', ...
        ['Estimated noise sigma exceeds 30 uV on at least one channel ' ...
         '(max %.1f uV, median %.1f uV). Typical spike-band noise is ' ...
         '2-8 uV; this usually means the bandpass filter isn''t working ' ...
         'as intended (LFP leaking through). Thresholds were set anyway.'], ...
        max(sigma), median(sigma));
end

% ---- apply lower thresholds (upper left untouched)
pds.xippmex('spike-thresh', chans, lowThresh(:)');

% ---- restore prior raw-stream enable state (only disable channels we turned on)
if ~isempty(offChans)
    pds.xippmex('signal', offChans, 'raw', 0);
end

% ---- log into p for the saved data file
p.rig.ripple.spikeThresh = struct( ...
    'chans',       chans, ...
    'mult',        mult, ...
    'sigma',       sigma(:)', ...
    'lowThresh',   lowThresh(:)', ...
    'filterLabel', fLabel, ...
    'durMs',       durMs, ...
    'nipTime',     pds.xippmex('time'));

fprintf(['pds.setSpikeThreshFromRMS: set lower thresholds on %d channels ' ...
         '(median|x|/0.6745, mult=%.2f, filter=%s; ', ...
         'sigma range %.1f-%.1f uV)\n'], ...
        numel(chans), mult, fLabel, min(sigma), max(sigma));

end
