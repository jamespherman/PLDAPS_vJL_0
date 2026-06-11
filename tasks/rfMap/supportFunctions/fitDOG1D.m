function [x0, fitParams, gof] = fitDOG1D(xAxis, rate, opts)
% fitDOG1D  Fit 1-D difference-of-Gaussians to a rate-vs-position profile.
%
%   [x0, fitParams, gof] = fitDOG1D(xAxis, rate)
%   [x0, fitParams, gof] = fitDOG1D(xAxis, rate, opts)
%
%   Model:
%     f(x) = b + A*[exp(-(x-x0)^2/(2*sc^2)) - w*exp(-(x-x0)^2/(2*ss^2))]
%
%   The DOG center x0 is the RF center estimate. A may be positive
%   (ON-center peak) or negative (OFF-center trough).
%
%   Inputs:
%     xAxis  - [N x 1] position bin centers (dva)
%     rate   - [N x 1] firing rate at each position (spk/s)
%     opts   - struct: .maxIter (default 2000)
%
%   Outputs:
%     x0        - RF center position (dva)
%     fitParams - struct with A, x0, sc, ss, w, b
%     gof       - struct with rmse, r2, yFit

if nargin < 3, opts = struct(); end
maxIter = 2000;
if isfield(opts, 'maxIter'), maxIter = opts.maxIter; end

xAxis = xAxis(:)';
rate  = rate(:)';
valid = isfinite(rate) & isfinite(xAxis);
x = xAxis(valid);
y = rate(valid);
N = numel(y);

nanP = struct('A',NaN,'x0',NaN,'sc',NaN,'ss',NaN,'w',NaN,'b',NaN);
nanG = struct('rmse',NaN,'r2',NaN,'yFit',nan(size(xAxis)));
if N < 6
    x0 = NaN; fitParams = nanP; gof = nanG;
    return;
end

% --- Initialise from data ---
nFlank = max(1, round(N * 0.1));
b0 = median([y(1:nFlank), y(end-nFlank+1:end)]);

[peakVal, peakIdx] = max(y);
[troughVal, troughIdx] = min(y);
if (peakVal - b0) >= (b0 - troughVal)
    A0 = peakVal - b0;
    x0i = x(peakIdx);
else
    A0 = troughVal - b0;
    x0i = x(troughIdx);
end
if abs(A0) < eps, A0 = 1; end

binW = median(diff(x));
hw = find(y > b0 + abs(A0)/2);
if numel(hw) >= 2
    sc0 = max((x(hw(end)) - x(hw(1))) / 2.35, binW);
else
    sc0 = max((x(end) - x(1)) / 10, binW);
end
ss0 = sc0 * 4;
w0  = 0.3;

p0 = [A0, x0i, sc0, ss0, w0, b0];

% --- DOG model ---
dog = @(p, xv) p(6) + p(1) * (exp(-(xv - p(2)).^2 / (2*p(3)^2)) - ...
    p(5) * exp(-(xv - p(2)).^2 / (2*p(4)^2)));

% --- Least-squares with soft constraints ---
cost = @(p) sum((y - dog(p, x)).^2) + ...
    1e4 * (max(0, -abs(p(3)))^2 + max(0, abs(p(3)) - 20)^2 + ...
           max(0, -abs(p(4)))^2 + max(0, abs(p(4)) - 50)^2 + ...
           max(0, -p(5))^2      + max(0, p(5) - 1.5)^2);

fmsOpt = optimset('MaxIter', maxIter, 'MaxFunEvals', maxIter * 6, ...
    'TolFun', 1e-8, 'TolX', 1e-6, 'Display', 'off');
pF = fminsearch(cost, p0, fmsOpt);

x0 = pF(2);
fitParams = struct('A', pF(1), 'x0', pF(2), ...
    'sc', abs(pF(3)), 'ss', abs(pF(4)), ...
    'w', max(0, min(1.5, pF(5))), 'b', pF(6));

yFit  = dog(pF, xAxis);
yFitV = dog(pF, x);
ssRes = sum((y - yFitV).^2);
ssTot = sum((y - mean(y)).^2);
gof = struct('rmse', sqrt(ssRes / N), ...
    'r2', 1 - ssRes / max(ssTot, eps), ...
    'yFit', yFit);

end
