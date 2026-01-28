function p = updateOnlinePlots(p)
%   p = updateOnlinePlots(p)
%
% Updates the online visualization for the Conflict Task.
% Primary display: Tachometric curve (P(goal-directed) vs delta-t)

% Update tachometric curve plot
p = updateTachometricCurve(p);

% Update gaze/velocity plots if enabled
if p.trVars.wantOnlinePlots
    p = updateGazePlots(p);
end

end

%% -------------------- UPDATE TACHOMETRIC CURVE --------------------
function p = updateTachometricCurve(p)
% Updates the tachometric curve showing P(goal-directed) vs delta-t
% for both Conflict and Congruent trials.

% Check if tachometric figure exists
if ~isfield(p.draw, 'tachFig') || ~isvalid(p.draw.tachFig)
    return
end

% Get trial parameters
trialType = p.trVars.trialType;  % 1=CONFLICT, 2=CONGRUENT
deltaTIdx = p.trVars.deltaTIdx;
outcome = p.trData.outcome;
rt = p.trData.SRT;

% Determine which metrics structure to update
if trialType == 1
    metricsCell = p.status.onlineMetrics.conflict;
else
    metricsCell = p.status.onlineMetrics.congruent;
end

% Update counts based on outcome
if strcmp(outcome, 'GOAL_DIRECTED')
    metricsCell{deltaTIdx}.nGoalDirected = ...
        metricsCell{deltaTIdx}.nGoalDirected + 1;
    if ~isnan(rt)
        metricsCell{deltaTIdx}.rtGoalDirected(end+1) = rt * 1000;  % Convert to ms
    end
elseif strcmp(outcome, 'CAPTURE')
    metricsCell{deltaTIdx}.nCapture = ...
        metricsCell{deltaTIdx}.nCapture + 1;
    if ~isnan(rt)
        metricsCell{deltaTIdx}.rtCapture(end+1) = rt * 1000;
    end
end

% Store updated metrics
if trialType == 1
    p.status.onlineMetrics.conflict = metricsCell;
else
    p.status.onlineMetrics.congruent = metricsCell;
end

% Update outcome counters
p.status.nGoalDirected = p.status.nGoalDirected + strcmp(outcome, 'GOAL_DIRECTED');
p.status.nCapture = p.status.nCapture + strcmp(outcome, 'CAPTURE');

%% Compute P(goal-directed) for each delta-t
deltaTValues = p.status.deltaTValues;
nDeltaT = p.status.nDeltaT;

pGoalConflict = zeros(1, nDeltaT);
pGoalCongruent = zeros(1, nDeltaT);
nConflict = zeros(1, nDeltaT);
nCongruent = zeros(1, nDeltaT);

for iDT = 1:nDeltaT
    % Conflict trials
    nG = p.status.onlineMetrics.conflict{iDT}.nGoalDirected;
    nC = p.status.onlineMetrics.conflict{iDT}.nCapture;
    nConflict(iDT) = nG + nC;
    if nConflict(iDT) > 0
        pGoalConflict(iDT) = nG / nConflict(iDT);
    else
        pGoalConflict(iDT) = NaN;
    end

    % Congruent trials
    nG = p.status.onlineMetrics.congruent{iDT}.nGoalDirected;
    nC = p.status.onlineMetrics.congruent{iDT}.nCapture;
    nCongruent(iDT) = nG + nC;
    if nCongruent(iDT) > 0
        pGoalCongruent(iDT) = nG / nCongruent(iDT);
    else
        pGoalCongruent(iDT) = NaN;
    end
end

%% Update tachometric curve plot
set(p.draw.plotObs.tachConflict, 'XData', deltaTValues, 'YData', pGoalConflict);
set(p.draw.plotObs.tachCongruent, 'XData', deltaTValues, 'YData', pGoalCongruent);

% Update scatter points for Conflict trials
validConflict = ~isnan(pGoalConflict);
if any(validConflict)
    set(p.draw.plotObs.tachConflictPts, ...
        'XData', deltaTValues(validConflict), ...
        'YData', pGoalConflict(validConflict));
end

% Update scatter points for Congruent trials
validCongruent = ~isnan(pGoalCongruent);
if any(validCongruent)
    set(p.draw.plotObs.tachCongruentPts, ...
        'XData', deltaTValues(validCongruent), ...
        'YData', pGoalCongruent(validCongruent));
end

% Update title with trial counts
totalConflict = sum(nConflict);
totalCongruent = sum(nCongruent);
titleStr = sprintf('Tachometric Curve (Conflict: %d, Congruent: %d trials)', ...
    totalConflict, totalCongruent);
title(p.draw.tachAxes, titleStr, 'FontSize', 12, 'FontWeight', 'bold');

%% Update RT plot
% Collect all RTs for goal-directed and capture outcomes
allRtGoal = [];
allRtCapture = [];

for iDT = 1:nDeltaT
    allRtGoal = [allRtGoal, p.status.onlineMetrics.conflict{iDT}.rtGoalDirected, ...
                           p.status.onlineMetrics.congruent{iDT}.rtGoalDirected];
    allRtCapture = [allRtCapture, p.status.onlineMetrics.conflict{iDT}.rtCapture, ...
                                 p.status.onlineMetrics.congruent{iDT}.rtCapture];
end

% Update RT histogram or summary
if ~isempty(allRtGoal) || ~isempty(allRtCapture)
    % Compute mean RTs
    meanRtGoal = mean(allRtGoal, 'omitnan');
    meanRtCapture = mean(allRtCapture, 'omitnan');

    % Update bar plot
    set(p.draw.plotObs.rtBarGoal, 'YData', meanRtGoal);
    set(p.draw.plotObs.rtBarCapture, 'YData', meanRtCapture);

    % Update axis limits
    maxRT = max([allRtGoal, allRtCapture]);
    if ~isempty(maxRT) && maxRT > 0
        set(p.draw.rtAxes, 'YLim', [0, maxRT * 1.2]);
    end

    % Update title with counts and means
    rtTitleStr = sprintf('Mean RT: Goal=%.0fms (n=%d), Capture=%.0fms (n=%d)', ...
        meanRtGoal, length(allRtGoal), meanRtCapture, length(allRtCapture));
    title(p.draw.rtAxes, rtTitleStr, 'FontSize', 11);
end

%% Update block progress indicator
blockStr = sprintf('Block %d/6 | Trial %d/60', ...
    p.status.iBlock, p.status.iTrialInBlock);
set(p.draw.blockText, 'String', blockStr);

drawnow;

end

%% -------------------- UPDATE GAZE PLOTS --------------------
function p = updateGazePlots(p)
% Updates the gaze position and velocity plots for the current trial.

% Check if gaze figure exists
if ~isfield(p.draw, 'gazeVsTimeFig') || ~isvalid(p.draw.gazeVsTimeFig)
    return
end

% Get eye X & Y data, and time data relative to fixation offset:
eyeX = 4 * p.trData.eyeX;
eyeY = 4 * p.trData.eyeY;
eyeT = p.trData.eyeT - p.trData.timing.trialStartDP - p.trData.timing.fixAq;

% Compute total velocity using "smoothdiff"
eyeV = ((1000*smoothdiff(eyeX)).^2 + (1000*smoothdiff(eyeY)).^2).^0.5;

% Get min & max of gaze for plotting
yMin = min(eyeV);
yMax = max(eyeV);

% Construct stimulus plot
nSamples = length(eyeT);
stimY = zeros(1, nSamples);
stimOnsetTime = p.trData.timing.stimOn - p.trData.timing.fixAq;
if stimOnsetTime > 0
    stimY(eyeT > stimOnsetTime) = 1;
end
stimY = stimY + 2;

% Construct fixation plot
fixY = zeros(1, nSamples);
fixOffTime = p.trData.timing.fixOff - p.trData.timing.fixAq;
fixY(eyeT < fixOffTime) = 1;

% Assign values to plot objects
set(p.draw.plotObs.xGaze, 'XData', eyeT, 'YData', eyeX);
set(p.draw.plotObs.yGaze, 'XData', eyeT, 'YData', eyeY);
set(p.draw.plotObs.tgt, 'XData', eyeT, 'YData', stimY);
set(p.draw.plotObs.fix, 'XData', eyeT', 'YData', fixY);
set(p.draw.plotObs.sacOn, ...
    'XData', (p.trData.timing.saccadeOnset - p.trData.timing.fixAq) * [1 1], ...
    'YData', [yMin yMax]);
set(p.draw.plotObs.sacOff, ...
    'XData', (p.trData.timing.saccadeOffset - p.trData.timing.fixAq) * [1 1], ...
    'YData', [yMin yMax]);
set(p.draw.plotObs.eyeVel, 'XData', eyeT, 'YData', eyeV);
set(p.draw.plotObs.vThresh, ...
    'XData', [min(eyeT), max(eyeT)], ...
    'YData', p.trVars.eyeVelThresh * [1 1]);

end

%% -------------------- SMOOTHED DIFFERENTIATION FILTER --------------------
function y = smoothdiff(x)
% Applies a smoothed differentiation filter to compute velocity.

b = zeros(29,1);
b(1)  = -4.3353241e-04 * 2*pi;
b(2)  = -4.3492899e-04 * 2*pi;
b(3)  = -4.8506188e-04 * 2*pi;
b(4)  = -3.6747546e-04 * 2*pi;
b(5)  = -2.0984645e-05 * 2*pi;
b(6)  =  5.7162272e-04 * 2*pi;
b(7)  =  1.3669190e-03 * 2*pi;
b(8)  =  2.2557429e-03 * 2*pi;
b(9)  =  3.0795928e-03 * 2*pi;
b(10) =  3.6592020e-03 * 2*pi;
b(11) =  3.8369002e-03 * 2*pi;
b(12) =  3.5162346e-03 * 2*pi;
b(13) =  2.6923104e-03 * 2*pi;
b(14) =  1.4608032e-03 * 2*pi;
b(15) =  0.0;
b(16:29) = -b(14:-1:1);

x = x(:);
y = filter(b, 1, x);
y = [y(15:length(x), :); zeros(14, 1)]';

end
