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
% Updates the pkV, RT, and endpoint error plots by factor level.
% Each trial contributes data points to multiple factor levels based on
% which factors apply to that trial.
%
% Factor levels (x-positions):
%   1 = High Salience, 2 = Low Salience (bullseye trials only)
%   3 = High Reward, 4 = Low Reward (all trials)
%   5 = High Probability, 6 = Low Probability (all trials)
%   7 = Face, 8 = Non-Face (texture trials only)
%
% Location index mapping: targLocIdx 1 -> locIdx 1, targLocIdx 3 -> locIdx 2

% Check if metrics figure exists
if ~isfield(p.draw, 'metricsFig') || ~isvalid(p.draw.metricsFig)
    return
end

% Get current trial's target location index (1-4)
targLocIdx = p.trVars.targetLocIdx;

% Only process locations 1 and 3
if isempty(targLocIdx) || (targLocIdx ~= 1 && targLocIdx ~= 3)
    drawnow;
    return
end

% Map target location to storage index (loc 1 -> 1, loc 3 -> 2)
if targLocIdx == 1
    locIdx = 1;
else
    locIdx = 2;
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

% Get trial factors
stimType = p.trVars.stimType;     % 1=face, 2=non-face, 3-6=bullseye
salience = p.trVars.salience;     % 0=image, 1=high, 2=low
reward = p.trVars.reward;         % 1=high, 2=low
halfBlock = p.trVars.halfBlock;   % 1-4

% Determine probability level based on block and location
% Block 1 (halfBlocks 1-2): loc 1 = high-prob, loc 3 = low-prob
% Block 2 (halfBlocks 3-4): loc 1 = low-prob, loc 3 = high-prob
blockNum = ceil(halfBlock / 2);
if blockNum == 1
    isHighProb = (targLocIdx == 1);
else
    isHighProb = (targLocIdx == 3);
end

% Determine which factor levels this trial contributes to
factorLevels = [];

% Salience (only for bullseye trials, stimType 3-6)
if stimType >= 3 && stimType <= 6
    if salience == 1  % high salience
        factorLevels(end+1) = 1;
    elseif salience == 2  % low salience
        factorLevels(end+1) = 2;
    end
end

% Reward (all trials)
if reward == 1  % high reward
    factorLevels(end+1) = 3;
else  % low reward
    factorLevels(end+1) = 4;
end

% Probability (all trials)
if isHighProb
    factorLevels(end+1) = 5;
else
    factorLevels(end+1) = 6;
end

% Stimulus type (only for texture trials, stimType 1-2)
if stimType == 1  % face
    factorLevels(end+1) = 7;
elseif stimType == 2  % non-face
    factorLevels(end+1) = 8;
end

% Accumulate data for each applicable factor level
for iLevel = factorLevels
    p.status.onlineMetrics{iLevel, locIdx}.pkV(end+1) = pkV;
    p.status.onlineMetrics{iLevel, locIdx}.RT(end+1) = rt;
    p.status.onlineMetrics{iLevel, locIdx}.err(end+1) = err;
end

% Update all scatter plots and mean markers
jitterWidth = 0.12;
allPkV = [];
allRT = [];
allErr = [];

for iLevel = 1:8
    for iLoc = 1:2
        data = p.status.onlineMetrics{iLevel, iLoc};
        n = length(data.pkV);

        if n > 0
            % Generate jitter (offset loc3 slightly to the right of loc1)
            baseX = iLevel + (iLoc - 1.5) * 0.2;  % loc1 slightly left, loc3 slightly right
            jitter = (rand(1, n) - 0.5) * jitterWidth * 2;
            xData = baseX + jitter;

            % Update scatter plots
            set(p.draw.plotObs.pkVScatter{iLevel, iLoc}, 'XData', xData, 'YData', data.pkV);
            set(p.draw.plotObs.rtScatter{iLevel, iLoc}, 'XData', xData, 'YData', data.RT * 1000);
            set(p.draw.plotObs.errScatter{iLevel, iLoc}, 'XData', xData, 'YData', data.err);

            % Update mean markers
            set(p.draw.plotObs.pkVMean{iLevel, iLoc}, 'XData', baseX, 'YData', mean(data.pkV));
            set(p.draw.plotObs.rtMean{iLevel, iLoc}, 'XData', baseX, 'YData', mean(data.RT) * 1000);
            set(p.draw.plotObs.errMean{iLevel, iLoc}, 'XData', baseX, 'YData', mean(data.err));

            % Collect all data for axis scaling
            allPkV = [allPkV, data.pkV];
            allRT = [allRT, data.RT * 1000];
            allErr = [allErr, data.err];
        end
    end
end

% Dynamically adjust Y-axis limits based on data
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

% Count total trials for locations 1 and 3
nLoc1 = length(p.status.onlineMetrics{3, 1}.pkV) + length(p.status.onlineMetrics{4, 1}.pkV);
nLoc3 = length(p.status.onlineMetrics{3, 2}.pkV) + length(p.status.onlineMetrics{4, 2}.pkV);
nLoc1 = nLoc1 / 2;  % Divide by 2 since each trial is counted in both high/low reward
nLoc3 = nLoc3 / 2;

% Update title with trial counts
titleStr = sprintf('Saccade Peak Velocity by Factor (Loc1: %d, Loc3: %d trials)', round(nLoc1), round(nLoc3));
title(p.draw.pkVAxes, titleStr, 'FontSize', 12, 'FontWeight', 'bold');

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