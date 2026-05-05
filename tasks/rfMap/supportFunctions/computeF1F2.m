function z = computeF1F2(spikeTimesRel, reversalHz)
% computeF1F2  Per-trial complex F1/F2 sums for a spike train.
%
%   z = computeF1F2(spikeTimesRel, reversalHz)
%
%   Inputs:
%     spikeTimesRel - column vector of spike times in seconds, with
%                     t = 0 at trial start (i.e., relative to noiseOn).
%                     Spikes outside the analysis window should already
%                     have been excluded by the caller.
%     reversalHz    - polarity reversal frequency f_rev (Hz). F1 is
%                     evaluated at f_rev; F2 at 2 * f_rev.
%
%   Output:
%     z             - 2-vector of complex sums:
%                       z(1) = sum_t [cos(2 pi f_rev t) + i sin(2 pi f_rev t)]
%                       z(2) = sum_t [cos(4 pi f_rev t) + i sin(4 pi f_rev t)]
%                     Magnitudes |z(1)|, |z(2)| are F1, F2 amplitudes;
%                     phase(z) is the per-trial phase. The plan locks
%                     the cross-trial average as mean(|z|) (no phase-
%                     locking across trials), so this function returns
%                     per-trial z; the caller accumulates magnitudes
%                     across trials.

if isempty(spikeTimesRel)
    z = [0 + 0i; 0 + 0i];
    return
end

t = spikeTimesRel(:);
omega1 = 2 * pi * reversalHz;
omega2 = 2 * pi * 2 * reversalHz;

z = [sum(exp(1i * omega1 * t)); ...
     sum(exp(1i * omega2 * t))];

end
