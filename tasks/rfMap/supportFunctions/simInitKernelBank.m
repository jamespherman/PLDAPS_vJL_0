function p = simInitKernelBank(p)
% simInitKernelBank  Build per-channel ground-truth kernel bank for sim mode.
%
%   p = simInitKernelBank(p)
%
%   Populates p.init.simKernelBank with a struct holding per-channel
%   spatiotemporal kernels (or temporal kernel + gain table for
%   checkerboard), per-channel base/peak firing rates, and a pre-computed
%   analytic gStd used to keep the LNP sigmoid in its quasi-linear regime
%   without per-trial recomputation.
%
%   Coordinate-frame convention (CRITICAL):
%     Templates are specified in fixation-relative dva (+x right, +y up,
%     PTB visual convention). buildGroundTruthRF places its spatial
%     Gaussian using a grid-frame coordinate where the origin sits at the
%     TOP-LEFT corner of the [nY x nX] check grid. The rfMap grid is
%     centered on screen at middleXY, with row 1 at the top. To put a
%     template at fix-frame (xFix, yFix), the grid-frame center is:
%       xGrid =  xFix + nX * checkSizeDeg / 2
%       yGrid = -yFix + nY * checkSizeDeg / 2   (Y flipped)
%     This mirrors the inverse mapping in computeRFCenters.m; getting it
%     wrong mirrors recovered RFs across the X axis.
%
%   Defaults (chosen per user guidance, see SIM_MODE_PLAN.md "Open
%   questions"):
%     - 8 templates x 4 channels = 32 simulated channels (the remaining
%       channels stay empty / silent).
%     - Mixed DKL weighting for chromatic: half L-M, quarter achromatic,
%       quarter mixed/S.
%     - Checkerboard: temporal kernel + per-(checkSize, contrast) gain
%       table only (no spatial gating).
%     - Per-(channel, trial) reproducible seeds derived from baseSeed.

if ~isfield(p.trVarsInit, 'simBaseSeed'), p.trVarsInit.simBaseSeed = 42; end

stimType = p.init.stimType;
nTotalCh = p.trVarsInit.nChannels;
nLags    = p.trVarsInit.nSTALags;

% 8 templates scattered across the visual field (fix-frame dva, +y up).
templateCenters = [-3 2; 3 2; 0 3; -3 -2; 3 -2; 0 -2; -5 0; 5 0];
nTemplates    = size(templateCenters, 1);
chPerTemplate = 4;
nSimCh        = min(nTemplates * chPerTemplate, nTotalCh);

% Deterministic RNG for kernel-bank construction (per-channel jitter).
rs = RandStream('mt19937ar', 'Seed', uint32(p.trVarsInit.simBaseSeed));

bank = struct( ...
    'nChannels',  nTotalCh, ...
    'nSimulated', nSimCh, ...
    'baseSeed',   double(p.trVarsInit.simBaseSeed), ...
    'stimType',   stimType, ...
    'kernels',    {cell(nTotalCh, 1)}, ...
    'templateCenters', templateCenters);

switch stimType
    case {'denseAchromatic', 'sparse', 'denseChromatic'}
        nY = p.init.noiseGridSize(1);
        nX = p.init.noiseGridSize(2);
        checkSizeDeg    = p.trVarsInit.checkSizeDeg;
        noiseFrameDurMs = p.trVarsInit.noiseFrameHold * p.rig.frameDuration * 1000;

        isChrom = strcmp(stimType, 'denseChromatic');

        % Grid center offset from fixation in dva. For hemifield
        % restriction the grid is no longer centered on fixation;
        % template coordinates must account for this shift.
        fixPxX = p.draw.middleXY(1) + pds.deg2pix(p.trVarsInit.fixDegX, p);
        fixPxY = p.draw.middleXY(2) - pds.deg2pix(p.trVarsInit.fixDegY, p);
        gridCenterDegX = pds.pix2deg( ...
            p.init.noiseGridCenterPix(1) - fixPxX, p);
        gridCenterDegY = pds.pix2deg( ...
            fixPxY - p.init.noiseGridCenterPix(2), p);

        % Per-axis contrast magnitude vector (1=L-M, 2=S, 3=Achro). Used
        % both for DKL projection and for analytic gStd.
        if isChrom
            contrastVec = zeros(1, 3);
            dklAxes = p.trVarsInit.dklAxes;
            if isscalar(p.trVarsInit.dklContrasts)
                contrastVec(dklAxes) = p.trVarsInit.dklContrasts;
            else
                contrastVec(dklAxes) = p.trVarsInit.dklContrasts(:)';
            end
        else
            contrastVec = [];
        end

        for tmplIdx = 1:nTemplates
            cFix = templateCenters(tmplIdx, :);
            % Convert from fixation frame (+y up) to grid frame (+y
            % down, origin at top-left of grid). Accounts for hemifield
            % offset via gridCenterDeg.
            cGrid = [ cFix(1) - gridCenterDegX + nX * checkSizeDeg / 2, ...
                     -(cFix(2) - gridCenterDegY) + nY * checkSizeDeg / 2 ];

            for repIdx = 1:chPerTemplate
                ch = (tmplIdx - 1) * chPerTemplate + repIdx;
                if ch > nSimCh, break; end

                % sigmaC narrowed from plan's 0.6-1.0 to 0.3-0.5 dva so
                % that, at production rfMap geometry (checkSizeDeg = 2,
                % grid 15 x 24), the spatial kernel is effectively a
                % delta (peak concentrated in 1 check). With a coarse
                % 360-pixel grid and ~360 frames per 20-trial session,
                % the STA noise floor (std = sqrt(stimVar / N_frames))
                % is dominated by the FRAME count, not the spike count
                % -- spikes that share a frame see the same stimulus.
                % Concentrating the signal in one pixel keeps the
                % per-pixel signal magnitude above max-of-noise within
                % the 20-trial budget. At finer (LGN-scale 0.5 dva)
                % grids, the kernel still spans 1-2 pixels and recovery
                % degrades; that case needs longer sessions.
                sigmaC   = 0.3 + 0.2 * rand(rs);              % 0.3-0.5 dva
                % Excitatory temporal peak: scale to the actual noise
                % frame duration so the biphasic kernel has nontrivial
                % support across the nLags=8 lag axis. A fixed 25-45 ms
                % range (plan default) lands far before lag 2 at
                % production noiseFrameHold (~80-100 ms/frame at 10-12
                % Hz), making the kernel effectively zero at every lag
                % and killing all simulated signal. 1.0-2.5 frames puts
                % the peak between lag 2 and lag 3.
                excPeak  = noiseFrameDurMs * (1.0 + 1.5 * rand(rs));
                polarity = (rand(rs) > 0.5) * 2 - 1;          % ON / OFF

                % Weak surround + weak inhibitory lobe. The plan's
                % full-strength DoG (sw=0.5) and biphasic kernel
                % (inhWeight=0.5) make the kernel temporally bimodal
                % (positive lobe followed by negative lobe of similar
                % magnitude). On the per-channel browser that's fine,
                % but for peak-lag selection in computeRFCenters, the
                % two lobes can compete: noise can push the wrong lobe
                % to higher energy. Weakening both (sw=0.15,
                % inhWeight=0.25) keeps the kernel recognizable but
                % gives the positive lobe a clear advantage.
                rfp = struct( ...
                    'nChecksX',         nX, ...
                    'nChecksY',         nY, ...
                    'checkSizeDeg',     checkSizeDeg, ...
                    'rfCenterDeg',      cGrid, ...
                    'rfSigmaCenterDeg', sigmaC, ...
                    'rfSigmaSurrDeg',   sigmaC * 1.5, ...
                    'rfSurrWeight',     0.15, ...
                    'rfExcPeakMs',      excPeak, ...
                    'rfInhPeakMs',      excPeak * 2, ...
                    'rfInhWeight',      0.25, ...
                    'nSTALags',         nLags, ...
                    'noiseFrameDurMs',  noiseFrameDurMs);
                [~, spatialKernel, temporalKernel] = buildGroundTruthRF(rfp);
                temporalKernel = polarity * temporalKernel;

                % DKL axis weights: cycle through canonical mixes so the
                % bank spans L-M, S, Achro, and a mixed cell.
                if isChrom
                    mixIdx = mod(tmplIdx - 1, 4) + 1;
                    switch mixIdx
                        case 1, wDKL = [1.0  0.0  0.0];   % L-M
                        case 2, wDKL = [0.0  0.0  1.0];   % achromatic
                        case 3, wDKL = [0.7  0.0  0.5];   % L-M + A mix
                        case 4, wDKL = [0.0  1.0  0.0];   % S (one in four)
                    end
                    % Mask off axes not actually presented this session.
                    wDKL(contrastVec == 0) = 0;
                    wn = norm(wDKL);
                    if wn > 0, wDKL = wDKL / wn; end
                else
                    wDKL = [];
                end

                % Per-channel base/peak rate (jittered +/-20%).
                % Calibrated to real LGN threshold-crossing statistics
                % (2026-06-01 64ch probe): ~3-7 spk/s per channel,
                % ~5-10 spk/ch/trial at 1.5s trial duration.
                baseRate = 2  * (1 + 0.4 * (rand(rs) - 0.5));
                peakRate = 20 * (1 + 0.4 * (rand(rs) - 0.5));

                % Analytic gStd. Variance of the generator g(t) is
                %   var(g) = sum(K_t.^2) * var(proj(t))
                %   var(proj) = sum(K_s.^2) * stimVar
                % For chromatic, stimVar = sum_c (wDKL_c * contrast_c)^2.
                % For achromatic binary +/-0.5, stimVar = 0.25. Pre-
                % compute here (not per-trial) so the first trial isn't
                % saturated by a noisy ~18-sample std estimate.
                spatialEnergy = sum(spatialKernel(:).^2);
                tempEnergy    = sum(temporalKernel(:).^2);
                if isChrom
                    stimVar = sum( (wDKL .* contrastVec).^2 );
                    if stimVar <= 0, stimVar = 0.25; end
                elseif strcmp(stimType, 'sparse')
                    % Balanced sparse: each pixel takes +/-1 with prob
                    % nSpots/(2*nPos) each, 0 otherwise. Per-pixel
                    % variance = nSpots/nPos. Treating pixels as
                    % approximately independent (the balance constraint
                    % adds a small negative correlation).
                    nPos = nY * nX;
                    nSpots = 6;
                    if isfield(p.trVarsInit, 'nSparseSpots')
                        nSpots = p.trVarsInit.nSparseSpots;
                    end
                    stimVar = nSpots / max(1, nPos);
                else
                    stimVar = 0.25;   % +/-0.5 dense binary
                end
                gStd = sqrt(spatialEnergy * tempEnergy * stimVar);
                if ~(gStd > 0), gStd = 1; end

                bank.kernels{ch} = struct( ...
                    'spatialKernel',     spatialKernel, ...
                    'temporalKernel',    temporalKernel, ...
                    'wDKL',              wDKL, ...
                    'baseRate',          baseRate, ...
                    'peakRate',          peakRate, ...
                    'gStd',              gStd, ...
                    'polarity',          polarity, ...
                    'rfCenterFixFrame',  cFix, ...
                    'rfCenterGridFrame', cGrid, ...
                    'templateIdx',       tmplIdx);
            end
        end

    case 'checkerboard'
        displayFrameMs = p.rig.frameDuration * 1000;
        nSize = numel(p.trVarsInit.checkSizesDva);
        nCt   = numel(p.trVarsInit.checkContrasts);

        for tmplIdx = 1:nTemplates
            excPeakBase = 25 + 20 * rand(rs);                  % 25-45 ms
            polarity    = (rand(rs) > 0.5) * 2 - 1;

            for repIdx = 1:chPerTemplate
                ch = (tmplIdx - 1) * chPerTemplate + repIdx;
                if ch > nSimCh, break; end

                excPeak = excPeakBase + 5 * (rand(rs) - 0.5);
                rfp = struct( ...
                    'nSTALags',        nLags, ...
                    'noiseFrameDurMs', displayFrameMs, ...
                    'rfExcPeakMs',     excPeak, ...
                    'rfInhPeakMs',     excPeak * 2);
                [~, ~, temporalKernel] = buildGroundTruthRF(rfp);
                temporalKernel = polarity * temporalKernel;

                % Per-(checkSize, contrast) gain. Plan proposal:
                %   gain(sz, ct) = (1 - 0.5 * sizeIdx_norm) * contrast
                % so small checks get higher gain than large checks, and
                % gain scales linearly with Michelson contrast. The
                % browser then shows contrast tuning (rows differ across
                % ct columns) and a mild size preference.
                gainTable = zeros(nSize, nCt);
                for sz = 1:nSize
                    sizeNorm = (sz - 1) / max(1, nSize - 1);
                    for ct = 1:nCt
                        gainTable(sz, ct) = (1 - 0.5 * sizeNorm) * ...
                            p.trVarsInit.checkContrasts(ct);
                    end
                end

                baseRate = 2  * (1 + 0.4 * (rand(rs) - 0.5));
                peakRate = 20 * (1 + 0.4 * (rand(rs) - 0.5));

                % gStd: polarity sequence has unit amplitude. Normalize
                % by the *max* gain across conditions so the highest
                % (sz,ct) condition sits with g ~ 1 std in the sigmoid;
                % weaker conditions ride lower, producing visible
                % contrast/size tuning in the recovered F1/F2 plot.
                tempEnergy = sum(temporalKernel(:).^2);
                gStd = max(gainTable(:)) * sqrt(tempEnergy);
                if ~(gStd > 0), gStd = 1; end

                bank.kernels{ch} = struct( ...
                    'temporalKernel', temporalKernel, ...
                    'gainTable',      gainTable, ...
                    'baseRate',       baseRate, ...
                    'peakRate',       peakRate, ...
                    'gStd',           gStd, ...
                    'polarity',       polarity, ...
                    'templateIdx',    tmplIdx);
            end
        end

    otherwise
        error('simInitKernelBank:badStimType', ...
            ['Unrecognized p.init.stimType = ''%s''. Expected one of: ' ...
             'denseAchromatic, denseChromatic, sparse, checkerboard.'], stimType);
end

% Noise channels: all remaining channels beyond nSimCh fire at a low
% spontaneous rate with no stimulus drive, matching the observation that
% ~46/64 real probe channels show threshold crossings but most have no RF.
nNoiseCh = 0;
for ch = (nSimCh + 1):nTotalCh
    noiseRate = 2 + 2 * rand(rs);   % 2-4 spk/s uniform
    bank.kernels{ch} = struct('isNoise', true, ...
        'baseRate', noiseRate, 'peakRate', 0);
    nNoiseCh = nNoiseCh + 1;
end
bank.nNoiseChannels = nNoiseCh;

p.init.simKernelBank = bank;

fprintf(['simInitKernelBank: %d RF + %d noise / %d total channels ' ...
         '(stimType=%s, baseSeed=%d)\n'], ...
    nSimCh, nNoiseCh, nTotalCh, stimType, bank.baseSeed);

end
