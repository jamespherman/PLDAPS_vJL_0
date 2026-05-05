function plotSTA_checkerboard(figData, staAccum, ~, selectedChannel)
% plotSTA_checkerboard  Render online checkerboard STA + F1/F2 panel.
%
%   plotSTA_checkerboard(figData, staAccum, ~, selectedChannel)
%
%   Updates the kernel-trace and F1/F2-bar grids for the selected channel.
%   The third argument is the staSpikeCount that the dispatcher passes
%   for spatial modes; for checkerboard we read the per-condition spike
%   count from staAccum.spikeCountPerCondCh and ignore the dispatcher
%   field. Signature kept compatible so plotSTA.m can call uniformly.

if nargin < 4 || isempty(selectedChannel), selectedChannel = 1; end
if ~isvalid(figData.fig), return; end

ch = selectedChannel;

% --- Temporal kernels (normalize by spike count per cell) ---
maxAbsKern = 0;
for sz = 1:figData.nCheckSize
    for ct = 1:figData.nContrast
        nSpk = staAccum.spikeCountPerCondCh(sz, ct, ch);
        if nSpk > 0
            kern = staAccum.temporalKernel(:, sz, ct, ch) / nSpk;
        else
            kern = zeros(figData.nLags, 1);
        end
        set(figData.hKernLine(sz, ct), ...
            'XData', figData.lagTimesMs, ...
            'YData', kern);
        maxAbsKern = max(maxAbsKern, max(abs(kern)));
    end
end

% Use a single symmetric y-limit across all kernel panels so trace
% magnitudes are visually comparable across (size, contrast).
if maxAbsKern == 0, maxAbsKern = 1; end
for sz = 1:figData.nCheckSize
    for ct = 1:figData.nContrast
        ylim(figData.hKernAxes(sz, ct), ...
            [-maxAbsKern * 1.1, maxAbsKern * 1.1]);
    end
end

% --- F1/F2 bars (mean per-trial |z| -- average across trials) ---
maxBar = 0;
totalSpikesCh = 0;
modulNum = 0; modulDen = 0;
for sz = 1:figData.nCheckSize
    for ct = 1:figData.nContrast
        nTrial = staAccum.f1f2TrialCount(sz, ct);
        if nTrial > 0
            ampF1 = staAccum.f1f2AmpSum(1, sz, ct, ch) / nTrial;
            ampF2 = staAccum.f1f2AmpSum(2, sz, ct, ch) / nTrial;
        else
            ampF1 = 0; ampF2 = 0;
        end
        set(figData.hBars(sz, ct), 'YData', [ampF1, ampF2]);
        maxBar = max(maxBar, max(ampF1, ampF2));
        totalSpikesCh = totalSpikesCh + ...
            staAccum.spikeCountPerCondCh(sz, ct, ch);
        modulNum = modulNum + ampF1;
        modulDen = modulDen + ampF1 + ampF2;
    end
end
if maxBar == 0, maxBar = 1; end
for sz = 1:figData.nCheckSize
    for ct = 1:figData.nContrast
        ylim(figData.hBarAxes(sz, ct), [0, maxBar * 1.1]);
    end
end

% --- Info panel ---
set(figData.hChanText,  'String', sprintf('Channel: %d', ch));
set(figData.hSpikeText, 'String', ...
    sprintf('Spikes: %d (across all conditions, this channel)', ...
    totalSpikesCh));
if modulDen > 0
    miGlobal = modulNum / modulDen;
    set(figData.hModulText, 'String', ...
        sprintf('F1/(F1+F2) [pooled]: %.3f', miGlobal));
else
    set(figData.hModulText, 'String', 'F1/(F1+F2): --');
end
nTrialMin = min(staAccum.f1f2TrialCount(:));
nTrialMax = max(staAccum.f1f2TrialCount(:));
set(figData.hCondText, 'String', ...
    sprintf('Trials per cond: %d..%d', nTrialMin, nTrialMax));

drawnow;

end
