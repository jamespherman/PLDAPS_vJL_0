function staAccum = applyOccludedMask(staAccum, mask)
% applyOccludedMask  Zero the fixation-occluded spatial checks in a spatial
% STA accumulator so downstream RF detection / SNR / maps ignore them.
%
%   staAccum = applyOccludedMask(staAccum, mask)
%
%   staAccum : cell{nCh} of [nY, nX, nLags] (achromatic/sparse) or
%              [nY, nX, 3, nLags] (denseChromatic) accumulators.
%   mask     : logical [nY, nX] of occluded checks (from occludedCheckMask).
%
%   The occluded checks were painted over with mean luminance on the
%   subject display, so they carry no valid stimulus-response correlation;
%   zeroing them removes the spurious fixation-pinned RF artifact. Safe to
%   call every trial (idempotent on already-zeroed checks). No-op if mask
%   is empty or all-false.

if isempty(mask) || ~any(mask(:)), return; end
for ch = 1:numel(staAccum)
    a = staAccum{ch};
    if isempty(a), continue; end
    sz = size(a);
    if ndims(a) == 3            % [nY, nX, nLags]
        a(repmat(mask, 1, 1, sz(3))) = 0;
    else                        % [nY, nX, 3, nLags]
        a(repmat(mask, 1, 1, sz(3), sz(4))) = 0;
    end
    staAccum{ch} = a;
end
end
