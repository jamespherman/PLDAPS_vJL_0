function p = rfMap_denseChromatic_settings
%   p = rfMap_denseChromatic_settings
%
% Settings file for rfMap dense chromatic (DKL) noise mode. Tri-noise:
% each check, each frame, draws an independent +/- contrast on every
% active DKL axis. STA is accumulated against the per-check DKL drive
% vector (not RGB), producing a [nY, nX, 3, nLags] map per channel
% where the 3rd dim is DKL axes (1=L-M, 2=S, 3=Achromatic).
%
% Loads via the PLDAPS GUI: Browse  ->  this file  ->  Initialize  ->  Run.

%% pin stim type FIRST
p = struct;
p.init.stimType = 'denseChromatic';

%% common configuration
p = rfMap_commonSettings(p);

%% chromatic-specific overrides
% Active DKL axes for tri-noise. [1 2 3] = all three axes vary
% independently each frame (typical). Subset with [1 2] for chromatic-
% only, [3] for achromatic-only (functionally equivalent to
% denseAchromatic but using the DKL pipeline).
p.trVarsInit.dklAxes      = [1 2 3];

% Per-axis DKL contrast. Scalar broadcasts to all active axes; pass a
% vector for per-axis control (in axis order [LM, S, Achro], with
% inactive axes ignored).
%
% The 8 tri-noise corners sit at (+/-c_LM, +/-c_S, +/-c_Achro). For
% typical VPixx primaries the +/-0.5 cube pokes past the gamut wall on
% one corner -- dkl2rgb clips it to bgRGB and two states collapse to
% the same color (initClut catches this and errors). The principled
% way to pick the largest in-gamut contrast for a given rig is to call
%
%   gamutMaxContrasts(dklAxes, axisRatios)
%
% which solves for the maximum scaling of axisRatios that keeps all 8
% corners in [0,255] linear RGB. For the rig1/rig2 LUTs shipped here,
% gamutMaxContrasts([1 2 3], [1 1 1]) = 0.4738; with a 5% safety
% margin against fp roundoff and LUT quantization that's 0.45.
%
% A per-axis vector lets you trade contrast across axes (e.g.,
% [c_LM, c_S, c_Achro] = [0.32 0.32 0.64] biases toward achromatic).
% Caveat: with non-uniform per-axis contrasts the recovered STA
% amplitude scales by c_axis, so cross-axis tuning comparisons must
% renormalize by p.init.dklDriveVariancePerAxis (saved at session
% init) before treating |sta(:,:,1,k)| vs |sta(:,:,2,k)| as a meaningful
% "more L-M-tuned vs more S-tuned" test.
p.trVarsInit.dklContrasts = 0.45;

% Calibration source flag.
%   'measured_primaries+measured_gamma' (preferred; rig LUT files)
%   'vendor_primaries+measured_gamma'
% Per-rig LUT_VPIXX_rig{N}.{xyY,r,g,b} files in supportFunctions/ are
% on-rig measurements; initClut.m loads them via initmon based on
% p.init.pcName. Override here only if running with vendor primaries.
p.init.dklCalibrationSource = 'measured_primaries+measured_gamma';

% Slow the noise rate for chromatic. Chromatic LGN responses are
% bandlimited below typical luminance responses, and per-axis STA SNR
% benefits from longer per-check dwell because chromatic tri-noise
% spreads spikes across 8 corner states per check rather than 2.
% rfMap_init turns this into noiseFrameHold = round(refreshRate / 10);
% at 120 Hz that is 12 (~83 ms / check), matching the Phase-2 design.
p.trVarsInit.noiseTargetUpdateHz = 10;

%% Pre-compute integer strobe values (eval'd at strobe time only sees p).
% rfMapDklAxisIdx enum: 1=L-M, 2=S, 3=achromatic, 4=mixed (tri-noise).
if isscalar(p.trVarsInit.dklAxes)
    p.init.dklAxisIdxStrobe = double(p.trVarsInit.dklAxes);
else
    p.init.dklAxisIdxStrobe = 4;
end
% rfMapDklCalibSource enum: 1=measured_primaries, 2=vendor_primaries,
% 0=other/unknown.
if strncmp(p.init.dklCalibrationSource, 'measured_primaries', 18)
    p.init.dklCalibSourceStrobe = 1;
elseif strncmp(p.init.dklCalibrationSource, 'vendor_primaries', 16)
    p.init.dklCalibSourceStrobe = 2;
else
    p.init.dklCalibSourceStrobe = 0;
end

%% strobe additions specific to chromatic mode
p.init.strobeList = [p.init.strobeList; { ...
    'rfMapDklAxisIdx',       'p.init.dklAxisIdxStrobe'; ...
    'rfMapDklContrast_x100', 'round(max(p.trVarsInit.dklContrasts(:)) * 100)'; ...
    'rfMapDklCalibSource',   'p.init.dklCalibSourceStrobe'; ...
    }];

%% finalize gui-comm mirror
p.trVarsGuiComm = p.trVarsInit;

end
