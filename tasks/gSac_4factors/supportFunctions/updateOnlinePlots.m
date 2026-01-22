function p               = updateOnlinePlots(p)

% Update gaze/velocity plots if enabled
if p.trVars.wantOnlinePlots
    p = updateGazePlots(p);
end

% Always update saccade metrics plots (pkV, RT, err by target location)
p = updateMetricsPlots(p);

end

%% -------------------- UPDATE GAZE PLOTS --------------------
function p = updateGazePlots(p)
% Updates the gaze position and velocity plots for the current trial.

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

end

%% -------------------- UPDATE METRICS PLOTS --------------------
function p = updateMetricsPlots(p)
% Updates the pkV, RT, and endpoint error plots by target location.
% Accumulates data across trials and updates scatter plots with means.

% Check if metrics figure exists
if ~isfield(p.draw, 'metricsFig') || ~isvalid(p.draw.metricsFig)
    return
end

% Get current trial's target location index (1-4)
targLocIdx = p.trVars.targetLocIdx;

% Validate target location index
if isempty(targLocIdx) || targLocIdx < 1 || targLocIdx > 4
    return
end

% Get saccade metrics from this trial
pkV = p.trData.peakVel;           % peak velocity (deg/s)
rt = p.trData.SRT;                % reaction time (s)

% Calculate endpoint error (Euclidean distance from target to landing position)
if ~isempty(p.trData.postSacXY) && ~any(isnan(p.trData.postSacXY))
    targX = p.trVars.targDegX;
    targY = p.trVars.targDegY;
    postX = p.trData.postSacXY(1);
    postY = p.trData.postSacXY(2);
    err = sqrt((postX - targX)^2 + (postY - targY)^2);  % endpoint error (deg)
else
    err = NaN;
end

% Skip if any metric is invalid
if isnan(pkV) || isnan(rt) || isnan(err)
    drawnow;
    return
end

% Accumulate data in p.status arrays
p.status.onlinePkV{targLocIdx}(end+1) = pkV;
p.status.onlineRT{targLocIdx}(end+1) = rt;
p.status.onlineErr{targLocIdx}(end+1) = err;

% Update scatter plots for locations 1 and 3
% Location 1 is plotted at x=1, Location 3 is plotted at x=2

% Get data for locations 1 and 3
pkV1 = p.status.onlinePkV{1};
pkV3 = p.status.onlinePkV{3};
rt1 = p.status.onlineRT{1};
rt3 = p.status.onlineRT{3};
err1 = p.status.onlineErr{1};
err3 = p.status.onlineErr{3};

% Add horizontal jitter for visibility
jitterWidth = 0.15;
n1 = length(pkV1);
n3 = length(pkV3);
jitter1 = (rand(1, n1) - 0.5) * jitterWidth * 2;
jitter3 = (rand(1, n3) - 0.5) * jitterWidth * 2;

% Update Peak Velocity scatter plots
set(p.draw.plotObs.pkVLoc1, 'XData', ones(1, n1) + jitter1, 'YData', pkV1);
set(p.draw.plotObs.pkVLoc3, 'XData', 2*ones(1, n3) + jitter3, 'YData', pkV3);

% Update RT scatter plots (convert to ms for display)
set(p.draw.plotObs.rtLoc1, 'XData', ones(1, n1) + jitter1, 'YData', rt1 * 1000);
set(p.draw.plotObs.rtLoc3, 'XData', 2*ones(1, n3) + jitter3, 'YData', rt3 * 1000);

% Update Error scatter plots
set(p.draw.plotObs.errLoc1, 'XData', ones(1, n1) + jitter1, 'YData', err1);
set(p.draw.plotObs.errLoc3, 'XData', 2*ones(1, n3) + jitter3, 'YData', err3);

% Update mean markers
if ~isempty(pkV1)
    set(p.draw.plotObs.pkVMeanLoc1, 'XData', 1, 'YData', mean(pkV1));
    set(p.draw.plotObs.rtMeanLoc1, 'XData', 1, 'YData', mean(rt1) * 1000);
    set(p.draw.plotObs.errMeanLoc1, 'XData', 1, 'YData', mean(err1));
end
if ~isempty(pkV3)
    set(p.draw.plotObs.pkVMeanLoc3, 'XData', 2, 'YData', mean(pkV3));
    set(p.draw.plotObs.rtMeanLoc3, 'XData', 2, 'YData', mean(rt3) * 1000);
    set(p.draw.plotObs.errMeanLoc3, 'XData', 2, 'YData', mean(err3));
end

% Dynamically adjust Y-axis limits based on data
allPkV = [pkV1, pkV3];
allRT = [rt1, rt3] * 1000;  % convert to ms
allErr = [err1, err3];

if ~isempty(allPkV)
    pkVRange = [min(allPkV) * 0.9, max(allPkV) * 1.1];
    if pkVRange(1) < pkVRange(2)
        set(p.draw.pkVAxes, 'YLim', pkVRange);
    end
end

if ~isempty(allRT)
    rtRange = [min(allRT) * 0.9, max(allRT) * 1.1];
    if rtRange(1) < rtRange(2)
        set(p.draw.rtAxes, 'YLim', rtRange);
    end
end

if ~isempty(allErr)
    errRange = [0, max(allErr) * 1.2];
    if errRange(2) > 0
        set(p.draw.errAxes, 'YLim', errRange);
    end
end

% Update title with trial counts
titleStr = sprintf('Saccade Peak Velocity (n1=%d, n3=%d)', n1, n3);
title(p.draw.pkVAxes, titleStr, 'FontSize', 14, 'FontWeight', 'bold');

% Refresh figure
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