function p               = updateOnlinePlots(p)

% get eye X & Y data, and time data relative to fixation offset:
% samples:
eyeX = 4 * p.trData.eyeX;
eyeY = 4 * p.trData.eyeY;
eyeT = p.trData.eyeT - p.trData.timing.trialStartDP + ...
    - p.trData.timing.fixAq;

% compute total velocity using "smoothdiff"
eyeV = ((1000*smoothdiff(eyeX)).^2 + (1000*smoothdiff(eyeY)).^2).^0.5;

% get min & max of gaze x / y so we know how much y-range to plot event
% markers over:
yMin = min(eyeV);
yMax = max(eyeV);

% construct target plot. Check if p.trData.timing.targetOff is > 0. If it
% isn't, set it to Inf for plotting purposes:
if p.trData.timing.targetOff < 0
    p.trData.timing.targetOff = Inf;
end
nSamples = length(eyeT);
targY = zeros(1, nSamples);
targY(eyeT > (p.trData.timing.targetOn - p.trData.timing.fixAq) & eyeT < ...
    p.trData.timing.targetOff) = 1;
if ~p.trVars.isVisSac
    targY(eyeT > p.trData.timing.targetReillum) = 1;
end
targY = targY + 2;

% construct fixation plot:
fixY = zeros(1, nSamples);
fixY(eyeT > p.trData.timing.fixOn & eyeT < p.trData.timing.fixOff) = 1;

% assign values to plot objects:
set(p.draw.plotObs.xGaze, 'XData', eyeT, 'YData', eyeX);
set(p.draw.plotObs.yGaze, 'XData', eyeT, 'YData', eyeY);
set(p.draw.plotObs.tgt, 'XData', eyeT, 'YData', targY);
set(p.draw.plotObs.fix, 'XData', eyeT', 'YData', fixY);
set(p.draw.plotObs.sacOn, ...
    'XData', ...
    (p.trData.timing.saccadeOnset - p.trData.timing.fixAq) * [1 1], ...
    'YData', [yMin yMax]);
set(p.draw.plotObs.sacOff, ...
    'XData', ...
    (p.trData.timing.saccadeOffset - p.trData.timing.fixAq) * [1 1], ...
    'YData', [yMin yMax]);
set(p.draw.plotObs.eyeVel, 'XData', eyeT, 'YData', eyeV);
set(p.draw.plotObs.vThresh, ...
    'XData', [min(eyeT), max(eyeT)], ...
    'YData', p.trVars.eyeVelThresh * [1 1]);

% update figure windows:
drawnow;

end

function y = smoothdiff(x)

% define filter & filter coefficients
b           = zeros(29,1);
b(1)        =  -4.3353241e-04 * 2*pi;
b(2)        =  -4.3492899e-04 * 2*pi;
b(3)        =  -4.8506188e-04 * 2*pi;
b(4)        =  -3.6747546e-04 * 2*pi;
b(5)        =  -2.0984645e-05 * 2*pi;
b(6)        =   5.7162272e-04 * 2*pi;
b(7)        =   1.3669190e-03 * 2*pi;
b(8)        =   2.2557429e-03 * 2*pi;
b(9)        =   3.0795928e-03 * 2*pi;
b(10)       =   3.6592020e-03 * 2*pi;
b(11)       =   3.8369002e-03 * 2*pi;
b(12)       =   3.5162346e-03 * 2*pi;
b(13)       =   2.6923104e-03 * 2*pi;
b(14)       =   1.4608032e-03 * 2*pi;
b(15)       =   0.0;
b(16:29)    = -b(14:-1:1);

% make x a column vector
x = x(:);

% apply filter to "x"
y = filter(b, 1, x);

% get rid of leading and trailing edges of y (these will be noisy due to
% filter length).
y = [y(15:length(x), :); zeros(14, 1)]';

end