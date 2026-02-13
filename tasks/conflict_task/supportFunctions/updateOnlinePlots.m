function p = updateOnlinePlots(p)
%   p = updateOnlinePlots(p)
%
% Updates the online visualization for the Conflict Task.
% 6-panel display (3 rows x 3 columns):
%   Panel 1: Phase 1 P(High Sal) by Hemifield
%   Panel 2: Phases 2-3 P(High Sal) Conflict vs Congruent
%   Panel 3: Phase 1 Median RT by Hemifield
%   Panel 4: Phases 2-3 Median RT Conflict vs Congruent
%   Panel 5: Choice Evolution Over Session
%   Panel 6: Session Information (right column)

% Update metrics based on current trial outcome
p = updateMetrics(p);

% Update all visualization panels
p = updateAllPanels(p);

% Update gaze/velocity plots if enabled
if p.trVars.wantOnlinePlots
    p = updateGazePlots(p);
end

end

%% -------------------- UPDATE METRICS --------------------
function p = updateMetrics(p)
% Updates the online metrics structures based on the current trial outcome.

% Get trial parameters
phaseNumber = p.trVars.phaseNumber;
deltaTIdx = p.trVars.deltaTIdx;
highSalSide = p.trVars.highSalienceSide;  % 1=left, 2=right
choseHighSal = p.trData.choseHighSalience;
isConflict = p.trVars.isConflict;
rt = p.trData.SRT;
isSingleStim = (p.trVars.singleStimSide ~= 0);

%% Route metrics to appropriate phase/category structure
if phaseNumber == 1
    if isSingleStim
        % Track single-stim trials separately (not in tachometric curves)
        p.status.nSingleStimTotal = p.status.nSingleStimTotal + 1;
        if choseHighSal
            p.status.nSingleStimCorrect = p.status.nSingleStimCorrect + 1;
        end
    else
        % Dual-stim Phase 1: categorize by high salience side
        if highSalSide == 1
            metricsCell = p.status.onlineMetrics.phase1.highSalLeft;
        else
            metricsCell = p.status.onlineMetrics.phase1.highSalRight;
        end

        % Update counts
        if choseHighSal
            metricsCell{deltaTIdx}.nChoseHighSal = ...
                metricsCell{deltaTIdx}.nChoseHighSal + 1;
            if ~isempty(rt) && ~isnan(rt)
                metricsCell{deltaTIdx}.rtHighSal(end+1) = rt * 1000;
            end
        else
            metricsCell{deltaTIdx}.nChoseLowSal = ...
                metricsCell{deltaTIdx}.nChoseLowSal + 1;
            if ~isempty(rt) && ~isnan(rt)
                metricsCell{deltaTIdx}.rtLowSal(end+1) = rt * 1000;
            end
        end

        % Store back
        if highSalSide == 1
            p.status.onlineMetrics.phase1.highSalLeft = metricsCell;
        else
            p.status.onlineMetrics.phase1.highSalRight = metricsCell;
        end
    end

elseif phaseNumber == 2
    % Phase 2: categorize by conflict vs congruent
    if isConflict
        metricsCell = p.status.onlineMetrics.phase2.conflict;
    else
        metricsCell = p.status.onlineMetrics.phase2.congruent;
    end

    % Update counts
    if choseHighSal
        metricsCell{deltaTIdx}.nChoseHighSal = ...
            metricsCell{deltaTIdx}.nChoseHighSal + 1;
        if ~isempty(rt) && ~isnan(rt)
            metricsCell{deltaTIdx}.rtHighSal(end+1) = rt * 1000;
        end
    else
        metricsCell{deltaTIdx}.nChoseLowSal = ...
            metricsCell{deltaTIdx}.nChoseLowSal + 1;
        if ~isempty(rt) && ~isnan(rt)
            metricsCell{deltaTIdx}.rtLowSal(end+1) = rt * 1000;
        end
    end

    % Store back
    if isConflict
        p.status.onlineMetrics.phase2.conflict = metricsCell;
    else
        p.status.onlineMetrics.phase2.congruent = metricsCell;
    end

elseif phaseNumber == 3
    % Phase 3: categorize by conflict vs congruent
    if isConflict
        metricsCell = p.status.onlineMetrics.phase3.conflict;
    else
        metricsCell = p.status.onlineMetrics.phase3.congruent;
    end

    % Update counts
    if choseHighSal
        metricsCell{deltaTIdx}.nChoseHighSal = ...
            metricsCell{deltaTIdx}.nChoseHighSal + 1;
        if ~isempty(rt) && ~isnan(rt)
            metricsCell{deltaTIdx}.rtHighSal(end+1) = rt * 1000;
        end
    else
        metricsCell{deltaTIdx}.nChoseLowSal = ...
            metricsCell{deltaTIdx}.nChoseLowSal + 1;
        if ~isempty(rt) && ~isnan(rt)
            metricsCell{deltaTIdx}.rtLowSal(end+1) = rt * 1000;
        end
    end

    % Store back
    if isConflict
        p.status.onlineMetrics.phase3.conflict = metricsCell;
    else
        p.status.onlineMetrics.phase3.congruent = metricsCell;
    end
end

%% Update cumulative tracking
cum = p.status.onlineMetrics.cumulative;
cum.trialNumbers(end+1) = p.status.iGoodTrial;
cum.choseHighSal(end+1) = choseHighSal;
cum.phase(end+1) = phaseNumber;
cum.highSalSide(end+1) = highSalSide;
cum.isConflict(end+1) = isConflict;
cum.isSingleStim(end+1) = isSingleStim;
p.status.onlineMetrics.cumulative = cum;

%% Update global outcome counters (dual-stim only)
if ~isSingleStim
    if choseHighSal
        p.status.nChoseHighSalience = p.status.nChoseHighSalience + 1;
    else
        p.status.nChoseLowSalience = p.status.nChoseLowSalience + 1;
    end
end

end

%% -------------------- UPDATE ALL PANELS --------------------
function p = updateAllPanels(p)
% Updates all 6 visualization panels.

% Check if visualization figure exists
if ~isfield(p.draw, 'vizFig') || ~isvalid(p.draw.vizFig)
    return
end

deltaTValues = p.status.deltaTValues;
nDeltaT = p.status.nDeltaT;

%% Panel 1: Phase 1 P(High Sal) by Hemifield
pHighSal_left = zeros(1, nDeltaT);
pHighSal_right = zeros(1, nDeltaT);

for iDT = 1:nDeltaT
    % High salience LEFT
    nHS = p.status.onlineMetrics.phase1.highSalLeft{iDT}.nChoseHighSal;
    nLS = p.status.onlineMetrics.phase1.highSalLeft{iDT}.nChoseLowSal;
    if (nHS + nLS) > 0
        pHighSal_left(iDT) = nHS / (nHS + nLS);
    else
        pHighSal_left(iDT) = NaN;
    end

    % High salience RIGHT
    nHS = p.status.onlineMetrics.phase1.highSalRight{iDT}.nChoseHighSal;
    nLS = p.status.onlineMetrics.phase1.highSalRight{iDT}.nChoseLowSal;
    if (nHS + nLS) > 0
        pHighSal_right(iDT) = nHS / (nHS + nLS);
    else
        pHighSal_right(iDT) = NaN;
    end
end

validLeft = ~isnan(pHighSal_left);
validRight = ~isnan(pHighSal_right);
if any(validLeft)
    set(p.draw.plotObs.p1_highSalLeft, ...
        'XData', deltaTValues(validLeft), 'YData', pHighSal_left(validLeft));
end
if any(validRight)
    set(p.draw.plotObs.p1_highSalRight, ...
        'XData', deltaTValues(validRight), 'YData', pHighSal_right(validRight));
end

%% Panel 2: Phases 2-3 P(High Sal) Conflict vs Congruent
pHighSal_conflict = zeros(1, nDeltaT);
pHighSal_congruent = zeros(1, nDeltaT);

for iDT = 1:nDeltaT
    % Conflict (combine phases 2 and 3)
    nHS = p.status.onlineMetrics.phase2.conflict{iDT}.nChoseHighSal + ...
          p.status.onlineMetrics.phase3.conflict{iDT}.nChoseHighSal;
    nLS = p.status.onlineMetrics.phase2.conflict{iDT}.nChoseLowSal + ...
          p.status.onlineMetrics.phase3.conflict{iDT}.nChoseLowSal;
    if (nHS + nLS) > 0
        pHighSal_conflict(iDT) = nHS / (nHS + nLS);
    else
        pHighSal_conflict(iDT) = NaN;
    end

    % Congruent (combine phases 2 and 3)
    nHS = p.status.onlineMetrics.phase2.congruent{iDT}.nChoseHighSal + ...
          p.status.onlineMetrics.phase3.congruent{iDT}.nChoseHighSal;
    nLS = p.status.onlineMetrics.phase2.congruent{iDT}.nChoseLowSal + ...
          p.status.onlineMetrics.phase3.congruent{iDT}.nChoseLowSal;
    if (nHS + nLS) > 0
        pHighSal_congruent(iDT) = nHS / (nHS + nLS);
    else
        pHighSal_congruent(iDT) = NaN;
    end
end

validConflict = ~isnan(pHighSal_conflict);
validCongruent = ~isnan(pHighSal_congruent);
if any(validConflict)
    set(p.draw.plotObs.p23_conflict, ...
        'XData', deltaTValues(validConflict), 'YData', pHighSal_conflict(validConflict));
end
if any(validCongruent)
    set(p.draw.plotObs.p23_congruent, ...
        'XData', deltaTValues(validCongruent), 'YData', pHighSal_congruent(validCongruent));
end

%% Panel 3: Phase 1 Median RT by Hemifield
medianRT_left = NaN(1, nDeltaT);
medianRT_right = NaN(1, nDeltaT);

for iDT = 1:nDeltaT
    % High salience LEFT: combine all RTs regardless of choice
    allRT = [p.status.onlineMetrics.phase1.highSalLeft{iDT}.rtHighSal, ...
             p.status.onlineMetrics.phase1.highSalLeft{iDT}.rtLowSal];
    if ~isempty(allRT)
        medianRT_left(iDT) = median(allRT);
    end

    % High salience RIGHT
    allRT = [p.status.onlineMetrics.phase1.highSalRight{iDT}.rtHighSal, ...
             p.status.onlineMetrics.phase1.highSalRight{iDT}.rtLowSal];
    if ~isempty(allRT)
        medianRT_right(iDT) = median(allRT);
    end
end

validLeft = ~isnan(medianRT_left);
validRight = ~isnan(medianRT_right);
if any(validLeft)
    set(p.draw.plotObs.rt_p1_highSalLeft, ...
        'XData', deltaTValues(validLeft), 'YData', medianRT_left(validLeft));
end
if any(validRight)
    set(p.draw.plotObs.rt_p1_highSalRight, ...
        'XData', deltaTValues(validRight), 'YData', medianRT_right(validRight));
end

%% Panel 4: Phases 2-3 Median RT Conflict vs Congruent
medianRT_conflict = NaN(1, nDeltaT);
medianRT_congruent = NaN(1, nDeltaT);

for iDT = 1:nDeltaT
    % Conflict (combine phases 2 and 3)
    allRT = [p.status.onlineMetrics.phase2.conflict{iDT}.rtHighSal, ...
             p.status.onlineMetrics.phase2.conflict{iDT}.rtLowSal, ...
             p.status.onlineMetrics.phase3.conflict{iDT}.rtHighSal, ...
             p.status.onlineMetrics.phase3.conflict{iDT}.rtLowSal];
    if ~isempty(allRT)
        medianRT_conflict(iDT) = median(allRT);
    end

    % Congruent (combine phases 2 and 3)
    allRT = [p.status.onlineMetrics.phase2.congruent{iDT}.rtHighSal, ...
             p.status.onlineMetrics.phase2.congruent{iDT}.rtLowSal, ...
             p.status.onlineMetrics.phase3.congruent{iDT}.rtHighSal, ...
             p.status.onlineMetrics.phase3.congruent{iDT}.rtLowSal];
    if ~isempty(allRT)
        medianRT_congruent(iDT) = median(allRT);
    end
end

validConflict = ~isnan(medianRT_conflict);
validCongruent = ~isnan(medianRT_congruent);
if any(validConflict)
    set(p.draw.plotObs.rt_p23_conflict, ...
        'XData', deltaTValues(validConflict), 'YData', medianRT_conflict(validConflict));
end
if any(validCongruent)
    set(p.draw.plotObs.rt_p23_congruent, ...
        'XData', deltaTValues(validCongruent), 'YData', medianRT_congruent(validCongruent));
end

%% Panel 5: Cumulative Evolution
cum = p.status.onlineMetrics.cumulative;

if ~isempty(cum.trialNumbers)
    % Phase 1: cumulative by hemifield (dual-stim only)
    p1_left_mask = (cum.phase == 1) & (cum.highSalSide == 1) & ~cum.isSingleStim;
    p1_right_mask = (cum.phase == 1) & (cum.highSalSide == 2) & ~cum.isSingleStim;

    if any(p1_left_mask)
        p1_left_trials = cum.trialNumbers(p1_left_mask);
        p1_left_choices = cum.choseHighSal(p1_left_mask);
        p1_left_cumsum = cumsum(p1_left_choices) ./ (1:length(p1_left_choices));
        set(p.draw.plotObs.cum_p1_left, 'XData', p1_left_trials, 'YData', p1_left_cumsum);
    end

    if any(p1_right_mask)
        p1_right_trials = cum.trialNumbers(p1_right_mask);
        p1_right_choices = cum.choseHighSal(p1_right_mask);
        p1_right_cumsum = cumsum(p1_right_choices) ./ (1:length(p1_right_choices));
        set(p.draw.plotObs.cum_p1_right, 'XData', p1_right_trials, 'YData', p1_right_cumsum);
    end

    % Phases 2-3: cumulative by conflict/congruent
    p23_conflict_mask = ((cum.phase == 2) | (cum.phase == 3)) & (cum.isConflict == 1);
    p23_congruent_mask = ((cum.phase == 2) | (cum.phase == 3)) & (cum.isConflict == 0);

    if any(p23_conflict_mask)
        p23_conflict_trials = cum.trialNumbers(p23_conflict_mask);
        p23_conflict_choices = cum.choseHighSal(p23_conflict_mask);
        p23_conflict_cumsum = cumsum(p23_conflict_choices) ./ (1:length(p23_conflict_choices));
        set(p.draw.plotObs.cum_p23_conflict, 'XData', p23_conflict_trials, 'YData', p23_conflict_cumsum);
    end

    if any(p23_congruent_mask)
        p23_congruent_trials = cum.trialNumbers(p23_congruent_mask);
        p23_congruent_choices = cum.choseHighSal(p23_congruent_mask);
        p23_congruent_cumsum = cumsum(p23_congruent_choices) ./ (1:length(p23_congruent_choices));
        set(p.draw.plotObs.cum_p23_congruent, 'XData', p23_congruent_trials, 'YData', p23_congruent_cumsum);
    end
end

%% Panel 6: Session Information
phaseStr = sprintf('Phase %d/3', p.status.currentPhase);
set(p.draw.phaseText, 'String', phaseStr);

trialsInThisPhase = p.init.trialsPerPhaseList(p.status.currentPhase);
trialStr = sprintf('Trial %d/%d in Phase', ...
    p.status.completedTrialsInPhase, trialsInThisPhase);
set(p.draw.trialText, 'String', trialStr);

totalStr = sprintf('Total: %d/%d', p.status.iGoodTrial, p.init.totalTrials);
set(p.draw.totalText, 'String', totalStr);

% Current reward info
if p.trVars.rewardBigSide == 1
    bigSideStr = 'LEFT';
else
    bigSideStr = 'RIGHT';
end
rewardInfoStr = sprintf('BigSide: %s | L:%dms R:%dms', ...
    bigSideStr, p.trVars.rewardDurationLeft, p.trVars.rewardDurationRight);
set(p.draw.rewardInfoText, 'String', rewardInfoStr);

% Outcome counts with breakdown
outcomeStr = {'--- Outcomes ---', ...
    sprintf('High Sal: %d | Low Sal: %d', p.status.nChoseHighSalience, p.status.nChoseLowSalience), ...
    sprintf('Fix Breaks: %d', p.status.nFixBreak), ...
    sprintf('No Response: %d', p.status.nNoResponse), ...
    sprintf('Inaccurate: %d', p.status.nInaccurate)};
set(p.draw.outcomeText, 'String', outcomeStr);

% Single-stim counter
if isfield(p.draw, 'singleStimText') && isvalid(p.draw.singleStimText)
    singleStimStr = sprintf('Single-Stim: %d/%d correct', ...
        p.status.nSingleStimCorrect, p.status.nSingleStimTotal);
    set(p.draw.singleStimText, 'String', singleStimStr);
end

% P(HighSal) summary
nTotal = p.status.nChoseHighSalience + p.status.nChoseLowSalience;
if nTotal > 0
    pHS_overall = p.status.nChoseHighSalience / nTotal;
    summaryStr = {'--- P(HighSal) ---', sprintf('Overall: %.2f (n=%d)', pHS_overall, nTotal)};
else
    summaryStr = {'--- P(HighSal) ---', 'Overall: - (n=0)'};
end
if isfield(p.draw, 'pHighSalSummaryText') && isvalid(p.draw.pHighSalSummaryText)
    set(p.draw.pHighSalSummaryText, 'String', summaryStr);
end

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
