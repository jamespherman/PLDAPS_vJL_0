function [kernel, spatialKernel, temporalKernel, params] = buildGroundTruthRF(params)
% buildGroundTruthRF  Construct a parameterized LGN-like spatiotemporal RF.
%
%   [kernel, spatialKernel, temporalKernel, params] = buildGroundTruthRF(params)
%
%   Spatial component: difference of Gaussians (center-surround).
%   Temporal component: biphasic kernel (difference of alpha functions).
%   Full kernel is space-time separable: K(x,y,tau) = K_spatial(x,y) * K_temporal(tau).
%
%   params fields (all optional, with defaults):
%     .nChecksX          - grid width in checks (40)
%     .nChecksY          - grid height in checks (30)
%     .checkSizeDeg      - check size in degrees (0.5)
%     .rfCenterDeg       - [x, y] RF center in degrees ([5, 3])
%     .rfSigmaCenterDeg  - center Gaussian sigma in degrees (0.8)
%     .rfSigmaSurrDeg    - surround Gaussian sigma in degrees (2.5)
%     .rfSurrWeight      - surround weight relative to center (0.5)
%     .rfExcPeakMs       - excitatory peak latency in ms (30)
%     .rfInhPeakMs       - inhibitory peak latency in ms (60)
%     .rfInhWeight       - inhibitory temporal weight (0.5)
%     .nSTALags          - number of temporal lags (8)
%     .noiseFrameDurMs   - noise frame duration in ms (30)
%
%   Returns:
%     kernel          - [nChecksY, nChecksX, nSTALags] full stRF kernel
%     spatialKernel   - [nChecksY, nChecksX] spatial component (normalized)
%     temporalKernel  - [nSTALags, 1] temporal component (normalized)
%     params          - input params with defaults filled in

if nargin < 1, params = struct(); end

% Set defaults
if ~isfield(params, 'nChecksX'),         params.nChecksX = 40; end
if ~isfield(params, 'nChecksY'),         params.nChecksY = 30; end
if ~isfield(params, 'checkSizeDeg'),     params.checkSizeDeg = 0.5; end
if ~isfield(params, 'rfCenterDeg'),      params.rfCenterDeg = [5, 3]; end
if ~isfield(params, 'rfSigmaCenterDeg'), params.rfSigmaCenterDeg = 0.8; end
if ~isfield(params, 'rfSigmaSurrDeg'),   params.rfSigmaSurrDeg = 2.5; end
if ~isfield(params, 'rfSurrWeight'),     params.rfSurrWeight = 0.5; end
if ~isfield(params, 'rfExcPeakMs'),      params.rfExcPeakMs = 30; end
if ~isfield(params, 'rfInhPeakMs'),      params.rfInhPeakMs = 60; end
if ~isfield(params, 'rfInhWeight'),      params.rfInhWeight = 0.5; end
if ~isfield(params, 'nSTALags'),         params.nSTALags = 8; end
if ~isfield(params, 'noiseFrameDurMs'),  params.noiseFrameDurMs = 30; end

%% Spatial kernel: difference of Gaussians
% Check center positions in degrees (origin at top-left corner of grid)
xDeg = ((1:params.nChecksX) - 0.5) * params.checkSizeDeg;
yDeg = ((1:params.nChecksY) - 0.5) * params.checkSizeDeg;
[xGrid, yGrid] = meshgrid(xDeg, yDeg);

% Squared distance from RF center
dx = xGrid - params.rfCenterDeg(1);
dy = yGrid - params.rfCenterDeg(2);
r2 = dx.^2 + dy.^2;

% Center and surround Gaussians
centerGauss   = exp(-r2 / (2 * params.rfSigmaCenterDeg^2));
surroundGauss = exp(-r2 / (2 * params.rfSigmaSurrDeg^2));
spatialKernel = centerGauss - params.rfSurrWeight * surroundGauss;

% Normalize to peak absolute value = 1
spatialKernel = spatialKernel / max(abs(spatialKernel(:)));

%% Temporal kernel: biphasic (difference of alpha functions)
% Lag times in ms: lag index k corresponds to (k-1) frames of delay.
%   k=1 -> 0 ms,  k=2 -> 30 ms,  k=3 -> 60 ms, ...
lagMs = ((1:params.nSTALags) - 1) * params.noiseFrameDurMs;

% Alpha function shape parameter
n = 5;

% Excitatory component peaks at rfExcPeakMs
t1 = params.rfExcPeakMs;
excitatory = zeros(1, params.nSTALags);
valid = lagMs > 0;
excitatory(valid) = (lagMs(valid)/t1).^n .* exp(-n*(lagMs(valid)/t1 - 1));

% Inhibitory component peaks at rfInhPeakMs
t2 = params.rfInhPeakMs;
inhibitory = zeros(1, params.nSTALags);
inhibitory(valid) = (lagMs(valid)/t2).^n .* exp(-n*(lagMs(valid)/t2 - 1));

temporalKernel = excitatory - params.rfInhWeight * inhibitory;

% Normalize to peak absolute value = 1
temporalKernel = temporalKernel(:) / max(abs(temporalKernel));

%% Full separable kernel: K(x,y,tau) = K_spatial(x,y) * K_temporal(tau)
kernel = zeros(params.nChecksY, params.nChecksX, params.nSTALags);
for k = 1:params.nSTALags
    kernel(:,:,k) = spatialKernel * temporalKernel(k);
end

end
