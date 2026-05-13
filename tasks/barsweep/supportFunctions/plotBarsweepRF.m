function p = plotBarsweepRF(p)
% p = plotBarsweepRF(p)
%
% Refresh the online RF figure with the current accumulator state.
% Reads live values from p.trVars for the channel selector and
% reconstruction-only knobs (rfMapExtentDeg, rfRampFilter, rfRampCutoff)
% so mid-session GUI edits are honored without resetting the
% accumulator (see plan §1 "Mid-session parameter changes").
%
% Returns p so that lazy-created handles (zero contour, Gaussian-fit
% ellipse/marker) persist across calls -- the caller must capture the
% return value, otherwise each trial leaks a fresh set of overlay
% handles into the axes.

rf = p.init.barsweepRF;
if ~isstruct(rf) || ~isfield(rf, 'enabled') || ~rf.enabled
    return;
end
if ~isfield(rf, 'figData') || isempty(rf.figData) || ...
        ~isvalid(rf.figData.fig)
    return;
end
fd = rf.figData;

% Mirror live reconstruction-only knobs into the snapshot so
% reconstructBarsweepRF picks up GUI changes without an accumulator
% reset. Only the local copy is mutated; we never write back to
% p.init.barsweepRF here, since the accumulator state is unaffected.
rf.mapExtentDeg = p.trVars.rfMapExtentDeg;
rf.mapPixelDeg  = p.trVars.rfPosBinDeg;     % image resolution = bin width
rf.rampFilter   = p.trVars.rfRampFilter;
rf.rampCutoff   = p.trVars.rfRampCutoff;

% Reconstruction options; passed to reconstructBarsweepRF for both the
% detail panel and every grid tile.
reconOpts = struct('detectThresh', p.trVars.rfDetectThresh);

selCh = max(1, min(rf.nChannels, round(p.trVars.rfSelectedChannel)));

% Per-orientation forward/reverse balance (see §2 of plan).
balByPair = computePairBalance(rf);
worstBal  = min([balByPair, 1]);

% Title text for the detail panel.
trialN = p.status.iTrial;
spikesCh = rf.spikeCount(selCh);
banner = '';
if isfield(rf, 'bannerNextTrial') && ~isempty(rf.bannerNextTrial)
    banner = ['  ' rf.bannerNextTrial];
end

%% ---------- Detail panel ----------
switch rf.exptType
    case 'barsweep_rfmap12'
        out = reconstructBarsweepRF(rf, selCh, rf.exptType, reconOpts);
        cMax = max(abs(out.rfImage(:)));
        if cMax == 0, cMax = 1; end
        axisDispX = out.axisDeg + p.trVars.pathCenterXDeg;
        axisDispY = out.axisDeg + p.trVars.pathCenterYDeg;
        set(fd.detailImg, 'CData', out.rfImage, ...
            'XData', axisDispX, 'YData', axisDispY);
        set(fd.detailAx, 'CLim', [-cMax, cMax]);
        % Crosshair at sweep center.
        cx = p.trVars.pathCenterXDeg;
        cy = p.trVars.pathCenterYDeg;
        set(fd.detailCrosshairX, 'XData', [cx cx], ...
            'YData', [axisDispY(1) axisDispY(end)]);
        set(fd.detailCrosshairY, 'XData', [axisDispX(1) axisDispX(end)], ...
            'YData', [cy cy]);
        % Zero-isocontour to distinguish "no RF" from "ringing artifact".
        % Created lazily on the first refresh, then updated in place on
        % every subsequent call. hold on is required on creation:
        % contour() goes through newplot and would otherwise wipe the
        % cached detailImg / detailTitle / crosshair handles on the axes.
        if isempty(fd.detailZeroContour) || ~ishandle(fd.detailZeroContour)
            hold(fd.detailAx, 'on');
            [~, fd.detailZeroContour] = contour(fd.detailAx, ...
                axisDispX, axisDispY, out.rfImage, [0 0], ...
                'k', 'LineWidth', 0.5);
            hold(fd.detailAx, 'off');
            p.init.barsweepRF.figData.detailZeroContour = fd.detailZeroContour;
        end
        if any(out.rfImage(:) > 0) && any(out.rfImage(:) < 0)
            set(fd.detailZeroContour, ...
                'XData', axisDispX, 'YData', axisDispY, ...
                'ZData', out.rfImage, 'Visible', 'on');
        else
            set(fd.detailZeroContour, 'Visible', 'off');
        end
        % Gaussian-fit overlay: 1-sigma ellipse + centroid marker.
        % Drawn only when peakStats.detected (no point fitting noise).
        if ~isfield(fd, 'detailFitEllipse') || ...
                isempty(fd.detailFitEllipse) || ...
                ~ishandle(fd.detailFitEllipse)
            hold(fd.detailAx, 'on');
            fd.detailFitEllipse = plot(fd.detailAx, NaN, NaN, ...
                'm-', 'LineWidth', 1.5);
            fd.detailFitMarker  = plot(fd.detailAx, NaN, NaN, ...
                'm+', 'MarkerSize', 12, 'LineWidth', 1.5);
            hold(fd.detailAx, 'off');
            p.init.barsweepRF.figData.detailFitEllipse = fd.detailFitEllipse;
            p.init.barsweepRF.figData.detailFitMarker  = fd.detailFitMarker;
        end
        if out.peakStats.detected && ~isempty(out.gaussFit.ellipseX)
            set(fd.detailFitEllipse, ...
                'XData', out.gaussFit.ellipseX + p.trVars.pathCenterXDeg, ...
                'YData', out.gaussFit.ellipseY + p.trVars.pathCenterYDeg);
            set(fd.detailFitMarker, ...
                'XData', out.gaussFit.x0 + p.trVars.pathCenterXDeg, ...
                'YData', out.gaussFit.y0 + p.trVars.pathCenterYDeg);
        else
            set(fd.detailFitEllipse, 'XData', NaN, 'YData', NaN);
            set(fd.detailFitMarker,  'XData', NaN, 'YData', NaN);
        end
        % Title: encode SNR + detection state. RED title when undetected,
        % so the experimenter doesn't read off a noise-floor argmax as
        % a recovered RF center.
        if out.peakStats.detected
            titleStr = sprintf(['ch %d  spk=%d  tr=%d  bal=%.2f  ' ...
                'snr=%.1f  fit=(%.2f, %.2f)  fwhm=(%.2f, %.2f) dva (FBP)%s'], ...
                selCh, spikesCh, trialN, worstBal, out.peakStats.snr, ...
                out.gaussFit.x0 + p.trVars.pathCenterXDeg, ...
                out.gaussFit.y0 + p.trVars.pathCenterYDeg, ...
                out.gaussFit.fwhmX, out.gaussFit.fwhmY, banner);
            titleColor = [0 0 0];
            if worstBal < 0.5, titleColor = [0.7 0 0]; end
        else
            titleStr = sprintf(['ch %d  spk=%d  tr=%d  bal=%.2f  ' ...
                'snr=%.1f  NO RF DETECTED (thr=%.1f)%s'], ...
                selCh, spikesCh, trialN, worstBal, out.peakStats.snr, ...
                p.trVars.rfDetectThresh, banner);
            titleColor = [0.7 0 0];
        end
        set(fd.detailTitle, 'String', titleStr, 'Color', titleColor);

    case 'barsweep_cardinal4'
        out = reconstructBarsweepRF(rf, selCh, rf.exptType, reconOpts);
        % Convert path-center-relative axes to absolute display dva.
        axisDispX = out.axisX + p.trVars.pathCenterXDeg;
        axisDispY = out.axisY + p.trVars.pathCenterYDeg;
        xCenterAbs = out.xCenter + p.trVars.pathCenterXDeg;
        yCenterAbs = out.yCenter + p.trVars.pathCenterYDeg;

        % Rate vs x.
        set(fd.detailLineX, 'XData', axisDispX, 'YData', out.rateX);
        [~, ix] = max(out.rateX);
        if ~isempty(out.rateX)
            set(fd.detailMarkerX, 'XData', xCenterAbs, ...
                'YData', out.rateX(ix));
            ymax = max(out.rateX) * 1.1 + eps;
            set(fd.detailVlineX, 'XData', [p.trVars.pathCenterXDeg, p.trVars.pathCenterXDeg], ...
                'YData', [0, ymax]);
            ylim(fd.detailAxX, [0, ymax]);
            xlim(fd.detailAxX, [axisDispX(1), axisDispX(end)]);
        end

        % Rate vs y.
        set(fd.detailLineY, 'XData', axisDispY, 'YData', out.rateY);
        [~, iy] = max(out.rateY);
        if ~isempty(out.rateY)
            set(fd.detailMarkerY, 'XData', yCenterAbs, ...
                'YData', out.rateY(iy));
            ymax = max(out.rateY) * 1.1 + eps;
            set(fd.detailVlineY, 'XData', [p.trVars.pathCenterYDeg, p.trVars.pathCenterYDeg], ...
                'YData', [0, ymax]);
            ylim(fd.detailAxY, [0, ymax]);
            xlim(fd.detailAxY, [axisDispY(1), axisDispY(end)]);
        end

        % Separable 2D outer product.
        set(fd.detailSepImg, 'CData', out.separable2D, ...
            'XData', axisDispX, 'YData', axisDispY);
        set(fd.detailAxSep, 'CLim', [0 1]);
        set(fd.detailSepCrossX, 'XData', [xCenterAbs xCenterAbs], ...
            'YData', [axisDispY(1) axisDispY(end)]);
        set(fd.detailSepCrossY, 'XData', [axisDispX(1) axisDispX(end)], ...
            'YData', [yCenterAbs yCenterAbs]);

        % Gaussian-fit ellipse on the separable thumbnail. Only when the
        % SNR-based detector says we have a real peak on both axes.
        if ~isfield(fd, 'detailSepFitEllipse') || ...
                isempty(fd.detailSepFitEllipse) || ...
                ~ishandle(fd.detailSepFitEllipse)
            hold(fd.detailAxSep, 'on');
            fd.detailSepFitEllipse = plot(fd.detailAxSep, NaN, NaN, ...
                'm-', 'LineWidth', 1.5);
            fd.detailSepFitMarker  = plot(fd.detailAxSep, NaN, NaN, ...
                'm+', 'MarkerSize', 12, 'LineWidth', 1.5);
            hold(fd.detailAxSep, 'off');
            p.init.barsweepRF.figData.detailSepFitEllipse = fd.detailSepFitEllipse;
            p.init.barsweepRF.figData.detailSepFitMarker  = fd.detailSepFitMarker;
        end
        if out.peakStats.detected && ~isempty(out.gaussFit.ellipseX)
            set(fd.detailSepFitEllipse, ...
                'XData', out.gaussFit.ellipseX + p.trVars.pathCenterXDeg, ...
                'YData', out.gaussFit.ellipseY + p.trVars.pathCenterYDeg);
            set(fd.detailSepFitMarker, ...
                'XData', out.gaussFit.x0 + p.trVars.pathCenterXDeg, ...
                'YData', out.gaussFit.y0 + p.trVars.pathCenterYDeg);
        else
            set(fd.detailSepFitEllipse, 'XData', NaN, 'YData', NaN);
            set(fd.detailSepFitMarker,  'XData', NaN, 'YData', NaN);
        end

        % Update axis-X title with summary; axY/Sep keep their static labels.
        if numel(balByPair) >= 2
            balXY = sprintf('[%.2f, %.2f]', balByPair(1), balByPair(2));
        else
            balXY = sprintf('[%.2f]', worstBal);
        end
        if out.peakStats.detected
            titleStr = sprintf(['ch %d  spk=%d  tr=%d  bal=%s  ' ...
                'snrXY=[%.1f, %.1f]  fit=(%.2f, %.2f)  fwhm=(%.2f, %.2f) dva%s'], ...
                selCh, spikesCh, trialN, balXY, ...
                out.peakStats.snrX, out.peakStats.snrY, ...
                out.gaussFit.x0 + p.trVars.pathCenterXDeg, ...
                out.gaussFit.y0 + p.trVars.pathCenterYDeg, ...
                out.gaussFit.fwhmX, out.gaussFit.fwhmY, banner);
            titleColor = [0 0 0];
            if worstBal < 0.5, titleColor = [0.7 0 0]; end
        else
            titleStr = sprintf(['ch %d  spk=%d  tr=%d  bal=%s  ' ...
                'snrXY=[%.1f, %.1f]  NO RF DETECTED (thr=%.1f)%s'], ...
                selCh, spikesCh, trialN, balXY, ...
                out.peakStats.snrX, out.peakStats.snrY, ...
                p.trVars.rfDetectThresh, banner);
            titleColor = [0.7 0 0];
        end
        title(fd.detailAxX, titleStr, 'Color', titleColor, ...
            'Interpreter', 'none');
end

%% ---------- All-channels browser ----------
% The cross-channel grid lives in a separate uifigure browser created
% by initBarsweepChannelBrowser. Refresh it here so it shares the
% per-trial cadence of the detail panel.
if isfield(rf, 'browser') && ~isempty(rf.browser) && ...
        isfield(rf.browser, 'fig') && isvalid(rf.browser.fig)
    axisOffset = [p.trVars.pathCenterXDeg, p.trVars.pathCenterYDeg];
    updateBarsweepChannelBrowser(rf.browser, rf, reconOpts, axisOffset);
end

% Clear the banner after one refresh.
if ~isempty(banner)
    p.init.barsweepRF.bannerNextTrial = '';
end

drawnow limitrate;

end

%% --- helpers ---

function bal = computePairBalance(rf)
% For each opposite-direction pair (theta, theta+180), compute
% min(forward, reverse) / max(forward, reverse) from trialsByDirection.
% Returns a vector of pair balance ratios; empty if no pairs.

nDir = numel(rf.directionsRad);
counted = false(1, nDir);
bal = [];
for i = 1:nDir
    if counted(i), continue; end
    ai = rf.directionsRad(i);
    target = mod(ai + pi, 2*pi);
    j = find(~counted & abs(mod(rf.directionsRad - target, 2*pi)) < 1e-3, 1);
    if isempty(j) || j == i
        counted(i) = true;
        continue;
    end
    counted([i, j]) = true;
    a = rf.trialsByDirection(i);
    b = rf.trialsByDirection(j);
    if max(a, b) > 0
        bal(end+1) = min(a, b) / max(a, b); %#ok<AGROW>
    end
end

end
