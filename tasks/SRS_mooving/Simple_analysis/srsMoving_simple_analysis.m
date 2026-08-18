function results = srsMoving_simple_analysis(sessionFolder, excludeForcedCorrectionRepeats)
%SRSMOVING_SIMPLE_ANALYSIS Simple identity-versus-space analysis for SRS_mooving.
%
% RESULTS = srsMoving_simple_analysis(SESSIONFOLDER)
%
% The main figure asks whether choices are better described by target
% identity/value or by screen geometry. Crucially, absolute hemifield metrics
% are conditioned on availability:
%   P(right hemifield) uses ONLY trials with one target left and one right.
% A trial with two left targets is therefore excluded from that denominator.
% It is still included in P(rightmost target), because one of the two left
% targets is farther right than the other. The same distinction is used for
% upper/lower versus uppermost/lowermost.
%
% Forced correction repeats are excluded from the primary strategy analysis
% by default because their condition is deliberately repeated. A second CSV
% including correction repeats is always exported for supervision.
%
% Core analysis uses base MATLAB only.

if nargin < 1 || isempty(sessionFolder)
    error('SRS_mooving:AnalysisMissingFolder', ...
        'Provide the session folder containing trialXXXX.mat files.');
end
if nargin < 2 || isempty(excludeForcedCorrectionRepeats)
    excludeForcedCorrectionRepeats = true;
end
if isstring(sessionFolder)
    sessionFolder = char(sessionFolder);
end
if ~isfolder(sessionFolder)
    error('SRS_mooving:AnalysisFolderNotFound', ...
        'Session folder not found: %s', sessionFolder);
end

files = dir(fullfile(sessionFolder, 'trial*.mat'));
if isempty(files)
    error('SRS_mooving:AnalysisNoTrials', ...
        'No trialXXXX.mat files found in %s', sessionFolder);
end

% Numeric file order.
trialNumber = nan(numel(files),1);
for i = 1:numel(files)
    tok = regexp(files(i).name, 'trial(\d+)\.mat', 'tokens', 'once');
    if ~isempty(tok)
        trialNumber(i) = str2double(tok{1});
    end
end
[~, order] = sort(trialNumber);
files = files(order);
trialNumber = trialNumber(order);

rows = repmat(emptyRow(), numel(files), 1);
for i = 1:numel(files)
    S = load(fullfile(sessionFolder, files(i).name), ...
        'trVars', 'trData', 'status', 'init');
    if ~isfield(S,'trVars') || ~isfield(S,'trData') || ~isfield(S,'status')
        error('SRS_mooving:AnalysisBadTrialFile', ...
            '%s does not contain trVars/trData/status.', files(i).name);
    end
    rows(i) = readTrial(S, files(i).name, trialNumber(i));
end

T = struct2table(rows);

% Recompute previous-identity variables on the analysis-eligible sequence so
% correction-repeat exclusion does not create artificial transitions.
baseChoice = T.RealEyeChoice;
if excludeForcedCorrectionRepeats
    baseChoice = baseChoice & ~T.CorrectionRepeat;
end
T.PrimaryChoice = baseChoice;
T.PreviousChosenTargetPrimary(:) = NaN;
T.RepeatIdentityPrimary(:) = NaN;
lastTarget = NaN;
for i = 1:height(T)
    if ~baseChoice(i)
        continue
    end
    if any(lastTarget == [1 2])
        T.PreviousChosenTargetPrimary(i) = lastTarget;
        T.RepeatIdentityPrimary(i) = double(T.ChosenTarget(i) == lastTarget);
    end
    lastTarget = T.ChosenTarget(i);
end

strategyPrimary = computeStrategies(T, baseChoice, true);
strategyAll = computeStrategies(T, T.RealEyeChoice, false);
summary = computeSummary(T, baseChoice);
angular = computeAngularSelection(T, baseChoice, 8);

[analysisRoot, ~, ~] = fileparts(mfilename('fullpath'));
[~, sessionName] = fileparts(sessionFolder);
resultsFolder = fullfile(analysisRoot, 'results', sessionName);
figuresFolder = fullfile(analysisRoot, 'figures', sessionName);
if ~isfolder(resultsFolder), mkdir(resultsFolder); end
if ~isfolder(figuresFolder), mkdir(figuresFolder); end

writetable(T, fullfile(resultsFolder, 'trial_table_moving.csv'));
writetable(strategyPrimary, fullfile(resultsFolder, 'strategy_summary_primary.csv'));
writetable(strategyAll, fullfile(resultsFolder, 'strategy_summary_all_completed.csv'));
writetable(summary, fullfile(resultsFolder, 'moving_choice_summary.csv'));
writetable(angular, fullfile(resultsFolder, 'angular_selection_bias.csv'));

fig = makeFigure(strategyPrimary, summary, angular, sessionName);
savefig(fig, fullfile(figuresFolder, 'simple_moving_strategy_analysis.fig'));
print(fig, fullfile(figuresFolder, 'simple_moving_strategy_analysis.png'), ...
    '-dpng', '-r160');
try
    print(fig, fullfile(figuresFolder, 'simple_moving_strategy_analysis.pdf'), ...
        '-dpdf', '-bestfit');
catch
    print(fig, fullfile(figuresFolder, 'simple_moving_strategy_analysis.pdf'), ...
        '-dpdf');
end

results = struct();
results.trials = T;
results.strategyPrimary = strategyPrimary;
results.strategyAllCompleted = strategyAll;
results.summary = summary;
results.angularSelection = angular;
results.figure = fig;
results.resultsFolder = resultsFolder;
results.figuresFolder = figuresFolder;

fprintf('\nSRS_mooving simple analysis: %s\n', sessionName);
fprintf('  Real two-target eye choices: %d\n', sum(T.RealEyeChoice));
fprintf('  Primary choices used: %d\n', sum(baseChoice));
fprintf('  Forced correction repeats excluded from primary: %d\n', ...
    sum(T.RealEyeChoice & T.CorrectionRepeat & excludeForcedCorrectionRepeats));
printMetric(summary, 'P(high reward identity)');
printMetric(summary, 'P(T1 identity)');
printMetric(summary, 'P(right hemi | L/R available)');
printMetric(summary, 'P(rightmost target)');
printMetric(summary, 'P(upper hemi | U/D available)');
printMetric(summary, 'P(uppermost target)');
fprintf('  Results: %s\n', resultsFolder);

end

function r = readTrial(S, fileName, fileTrialIndex)
tv = S.trVars;
td = S.trData;
st = S.status;
r = emptyRow();

r.FileName = string(fileName);
r.FileTrialIndex = fileTrialIndex;
r.Attempt = getScalar(st, 'iTrial', fileTrialIndex);
r.Block = getScalar(st, 'CurrentBlockNumber', NaN);
r.TrialType = getScalar(st, 'ActualTrialType', NaN);
r.NStim = getScalar(tv, 'nStim', getScalar(td, 'nStim', NaN));
r.ChosenTarget = getScalar(td, 'chosenTargetID', 0);
r.RichTarget = getScalar(st, 'highRewardTargetID', ...
    getScalar(st, 'CurrentBlockType', NaN));
r.HighSalienceTarget = getScalar(st, 'highSalienceTargetID', NaN);
r.PassEye = getScalar(tv, 'passEye', 0);
r.MouseEyeSim = getScalar(tv, 'mouseEyeSim', 0);
r.CorrectionRepeat = getLogicalScalar(td, 'correctionTrialActive', ...
    getLogicalScalar(tv, 'correctionTrialActive', false));

r.T1X = getScalar(tv, 'T1_locDegX', getScalar(td, 'T1_locDegX', NaN));
r.T1Y = getScalar(tv, 'T1_locDegY', getScalar(td, 'T1_locDegY', NaN));
r.T2X = getScalar(tv, 'T2_locDegX', getScalar(td, 'T2_locDegX', NaN));
r.T2Y = getScalar(tv, 'T2_locDegY', getScalar(td, 'T2_locDegY', NaN));
r.FixX = getScalar(tv, 'fixDegX', 0);
r.FixY = getScalar(tv, 'fixDegY', 0);

r.T1Angle = getScalar(tv, 'movingT1AngleDeg', ...
    mod(atan2d(r.T1Y-r.FixY, r.T1X-r.FixX), 360));
r.T2Angle = getScalar(tv, 'movingT2AngleDeg', ...
    mod(atan2d(r.T2Y-r.FixY, r.T2X-r.FixX), 360));

r.GoodTrial = getLogicalScalar(td, 'GoodTrial', ...
    getScalar(td, 'trialEndState', NaN) == 455);
r.RealEyeChoice = r.GoodTrial && r.NStim == 2 && ...
    any(r.ChosenTarget == [1 2]) && r.PassEye == 0 && r.MouseEyeSim == 0;

% Re-derive geometry from saved coordinates rather than trusting labels.
tol = 1e-9;
r.T1HorizontalSide = horizontalSide(r.T1X, r.FixX, tol);
r.T2HorizontalSide = horizontalSide(r.T2X, r.FixX, tol);
r.T1VerticalSide = verticalSide(r.T1Y, r.FixY, tol);
r.T2VerticalSide = verticalSide(r.T2Y, r.FixY, tol);
r.StraddlesLR = (r.T1HorizontalSide == 1 && r.T2HorizontalSide == 2) || ...
    (r.T1HorizontalSide == 2 && r.T2HorizontalSide == 1);
r.StraddlesUD = (r.T1VerticalSide == 1 && r.T2VerticalSide == 2) || ...
    (r.T1VerticalSide == 2 && r.T2VerticalSide == 1);

[r.RightmostTarget, r.LeftmostTarget] = rankPair(r.T1X, r.T2X, tol);
[r.UppermostTarget, r.LowermostTarget] = rankPair(r.T1Y, r.T2Y, tol);

if r.ChosenTarget == 1
    r.ChosenX = r.T1X;
    r.ChosenY = r.T1Y;
    r.ChosenAngle = r.T1Angle;
    r.ChosenHorizontalSide = r.T1HorizontalSide;
    r.ChosenVerticalSide = r.T1VerticalSide;
elseif r.ChosenTarget == 2
    r.ChosenX = r.T2X;
    r.ChosenY = r.T2Y;
    r.ChosenAngle = r.T2Angle;
    r.ChosenHorizontalSide = r.T2HorizontalSide;
    r.ChosenVerticalSide = r.T2VerticalSide;
else
    r.ChosenX = NaN;
    r.ChosenY = NaN;
    r.ChosenAngle = NaN;
    r.ChosenHorizontalSide = 0;
    r.ChosenVerticalSide = 0;
end

r.ChoseRich = double(r.RealEyeChoice && any(r.RichTarget == [1 2]) && ...
    r.ChosenTarget == r.RichTarget);
r.ChoseHighSalience = double(r.RealEyeChoice && ...
    any(r.HighSalienceTarget == [1 2]) && ...
    r.ChosenTarget == r.HighSalienceTarget);
r.ChoseRightmost = binaryTargetChoice(r, r.RightmostTarget);
r.ChoseUppermost = binaryTargetChoice(r, r.UppermostTarget);

end

function Tstrategy = computeStrategies(T, choiceMask, usePrimaryPrevious)
labels = { ...
    'Choose high reward identity'; ...
    'Choose high salience identity'; ...
    'Always T1'; ...
    'Always T2'; ...
    'Repeat previous identity'; ...
    'Choose rightmost target'; ...
    'Choose leftmost target'; ...
    'Choose uppermost target'; ...
    'Choose lowermost target'; ...
    'Choose right hemifield'; ...
    'Choose left hemifield'; ...
    'Choose upper hemifield'; ...
    'Choose lower hemifield'};
classes = { ...
    'identity/value'; 'identity/salience'; 'identity'; 'identity'; ...
    'identity/history'; 'spatial/relative'; 'spatial/relative'; ...
    'spatial/relative'; 'spatial/relative'; 'spatial/absolute'; ...
    'spatial/absolute'; 'spatial/absolute'; 'spatial/absolute'};

nS = numel(labels);
accuracy = nan(nS,1);
nEligible = zeros(nS,1);
ciLow = nan(nS,1);
ciHigh = nan(nS,1);

pred = cell(nS,1);
elig = cell(nS,1);

validRich = choiceMask & ismember(T.RichTarget,[1 2]);
pred{1} = T.RichTarget; elig{1} = validRich;
validSal = choiceMask & ismember(T.HighSalienceTarget,[1 2]);
pred{2} = T.HighSalienceTarget; elig{2} = validSal;
pred{3} = ones(height(T),1); elig{3} = choiceMask;
pred{4} = 2*ones(height(T),1); elig{4} = choiceMask;

if usePrimaryPrevious
    prev = T.PreviousChosenTargetPrimary;
else
    prev = previousChoiceTarget(T, choiceMask);
end
pred{5} = prev;
elig{5} = choiceMask & ismember(prev,[1 2]);

pred{6} = T.RightmostTarget;
elig{6} = choiceMask & ismember(T.RightmostTarget,[1 2]);
pred{7} = T.LeftmostTarget;
elig{7} = choiceMask & ismember(T.LeftmostTarget,[1 2]);
pred{8} = T.UppermostTarget;
elig{8} = choiceMask & ismember(T.UppermostTarget,[1 2]);
pred{9} = T.LowermostTarget;
elig{9} = choiceMask & ismember(T.LowermostTarget,[1 2]);

rightTarget = nan(height(T),1);
leftTarget = nan(height(T),1);
rightTarget(T.StraddlesLR & T.T1HorizontalSide==1) = 1;
rightTarget(T.StraddlesLR & T.T2HorizontalSide==1) = 2;
leftTarget(T.StraddlesLR & T.T1HorizontalSide==2) = 1;
leftTarget(T.StraddlesLR & T.T2HorizontalSide==2) = 2;
pred{10} = rightTarget; elig{10} = choiceMask & T.StraddlesLR;
pred{11} = leftTarget; elig{11} = choiceMask & T.StraddlesLR;

upperTarget = nan(height(T),1);
lowerTarget = nan(height(T),1);
upperTarget(T.StraddlesUD & T.T1VerticalSide==1) = 1;
upperTarget(T.StraddlesUD & T.T2VerticalSide==1) = 2;
lowerTarget(T.StraddlesUD & T.T1VerticalSide==2) = 1;
lowerTarget(T.StraddlesUD & T.T2VerticalSide==2) = 2;
pred{12} = upperTarget; elig{12} = choiceMask & T.StraddlesUD;
pred{13} = lowerTarget; elig{13} = choiceMask & T.StraddlesUD;

for s = 1:nS
    m = elig{s} & ismember(pred{s},[1 2]);
    nEligible(s) = sum(m);
    if nEligible(s) > 0
        k = sum(T.ChosenTarget(m) == pred{s}(m));
        accuracy(s) = k / nEligible(s);
        [ciLow(s), ciHigh(s)] = wilsonCI(k, nEligible(s));
    end
end

Tstrategy = table(string(labels), string(classes), accuracy, nEligible, ...
    ciLow, ciHigh, 'VariableNames', ...
    {'Strategy','Class','Accuracy','N','WilsonLow','WilsonHigh'});
Tstrategy = sortrows(Tstrategy, 'Accuracy', 'descend');
end

function summary = computeSummary(T, choiceMask)
metrics = {};
values = [];
counts = [];

[metrics,values,counts] = addMetric(metrics,values,counts, ...
    'P(high reward identity)', T.ChosenTarget == T.RichTarget, ...
    choiceMask & ismember(T.RichTarget,[1 2]));
[metrics,values,counts] = addMetric(metrics,values,counts, ...
    'P(high salience identity)', T.ChosenTarget == T.HighSalienceTarget, ...
    choiceMask & ismember(T.HighSalienceTarget,[1 2]));
[metrics,values,counts] = addMetric(metrics,values,counts, ...
    'P(T1 identity)', T.ChosenTarget == 1, choiceMask);
[metrics,values,counts] = addMetric(metrics,values,counts, ...
    'P(right hemi | L/R available)', T.ChosenHorizontalSide == 1, ...
    choiceMask & T.StraddlesLR);
[metrics,values,counts] = addMetric(metrics,values,counts, ...
    'P(rightmost target)', T.ChosenTarget == T.RightmostTarget, ...
    choiceMask & ismember(T.RightmostTarget,[1 2]));
[metrics,values,counts] = addMetric(metrics,values,counts, ...
    'P(upper hemi | U/D available)', T.ChosenVerticalSide == 1, ...
    choiceMask & T.StraddlesUD);
[metrics,values,counts] = addMetric(metrics,values,counts, ...
    'P(uppermost target)', T.ChosenTarget == T.UppermostTarget, ...
    choiceMask & ismember(T.UppermostTarget,[1 2]));

summary = table(string(metrics(:)), values(:), counts(:), ...
    'VariableNames', {'Metric','Value','N'});
end

function angular = computeAngularSelection(T, choiceMask, nBins)
edges = linspace(0,360,nBins+1);
centers = edges(1:end-1) + diff(edges)/2;
available = zeros(nBins,1);
chosen = zeros(nBins,1);

idx = find(choiceMask);
for ii = 1:numel(idx)
    i = idx(ii);
    a1 = mod(T.T1Angle(i),360);
    a2 = mod(T.T2Angle(i),360);
    ac = mod(T.ChosenAngle(i),360);
    b1 = angleBin(a1, edges);
    b2 = angleBin(a2, edges);
    bc = angleBin(ac, edges);
    if b1>0, available(b1)=available(b1)+1; end
    if b2>0, available(b2)=available(b2)+1; end
    if bc>0, chosen(bc)=chosen(bc)+1; end
end
rate = chosen ./ available;
rate(available==0) = NaN;
angular = table((1:nBins)', centers(:), available, chosen, rate, ...
    'VariableNames', {'Bin','CenterDeg','AvailableTargets','ChosenTargets','SelectionRate'});
end

function fig = makeFigure(strategy, summary, angular, sessionName)
fig = figure('Name','SRS moving simple analysis', ...
    'Color','w','Position',[60 60 1500 850]);

% 1. Candidate strategies
subplot(2,2,1);
nShow = height(strategy);
b = bar(1:nShow, strategy.Accuracy);
hold on;
errorbar(1:nShow, strategy.Accuracy, ...
    strategy.Accuracy-strategy.WilsonLow, ...
    strategy.WilsonHigh-strategy.Accuracy, ...
    '.','Color',[0 0 0],'LineWidth',1);
plot([0 nShow+1],[0.5 0.5],'--','Color',[0.3 0.3 0.3]);
set(gca,'XTick',1:nShow,'XTickLabel',cellstr(strategy.Strategy));
xtickangle(45);
ylim([0 1]); xlim([0 nShow+1]);
ylabel('Prediction accuracy');
title('Identity/value vs spatial candidate strategies');
grid on;
for i=1:nShow
    text(i, min(0.98,strategy.Accuracy(i)+0.045), sprintf('n=%d',strategy.N(i)), ...
        'HorizontalAlignment','center','FontSize',7,'Rotation',90);
end
if isempty(b), drawnow; end

% 2. Availability-normalized angular selection
subplot(2,2,2);
bar(angular.CenterDeg, angular.SelectionRate, 1);
hold on;
plot([0 360],[0.5 0.5],'--','Color',[0.3 0.3 0.3]);
xlim([0 360]); ylim([0 1]);
set(gca,'XTick',0:45:360);
xlabel('Target polar angle (deg; 0=right, 90=up)');
ylabel('Chosen / available');
title('Spatial selection bias corrected for target availability');
grid on;

% 3. Identity/value summary
subplot(2,2,3);
identityNames = {'P(high reward identity)','P(high salience identity)','P(T1 identity)'};
[v,n] = summaryValues(summary, identityNames);
bar(1:numel(v),v); hold on;
plot([0 numel(v)+1],[0.5 0.5],'--','Color',[0.3 0.3 0.3]);
set(gca,'XTick',1:numel(v),'XTickLabel',identityNames);
xtickangle(20); ylim([0 1]); xlim([0 numel(v)+1]);
ylabel('Choice probability'); title('Identity / value choices'); grid on;
for i=1:numel(v)
    text(i,min(0.97,v(i)+0.05),sprintf('n=%d',n(i)), ...
        'HorizontalAlignment','center','FontSize',8);
end

% 4. Spatial summary
subplot(2,2,4);
spatialNames = {'P(right hemi | L/R available)','P(rightmost target)', ...
    'P(upper hemi | U/D available)','P(uppermost target)'};
[v,n] = summaryValues(summary, spatialNames);
bar(1:numel(v),v); hold on;
plot([0 numel(v)+1],[0.5 0.5],'--','Color',[0.3 0.3 0.3]);
set(gca,'XTick',1:numel(v),'XTickLabel',spatialNames);
xtickangle(20); ylim([0 1]); xlim([0 numel(v)+1]);
ylabel('Choice probability'); title('Absolute and relative spatial biases'); grid on;
for i=1:numel(v)
    text(i,min(0.97,v(i)+0.05),sprintf('n=%d',n(i)), ...
        'HorizontalAlignment','center','FontSize',8);
end

sgtitle(sprintf('%s | SRS moving strategy diagnostics', sessionName), ...
    'Interpreter','none');

% One explicit interpretation note in the figure.
annotation(fig,'textbox',[0.02 0.005 0.96 0.035], ...
    'String',['Hemifield probabilities use only trials where both hemifields were available. ', ...
    'Rightmost/uppermost probabilities include same-hemifield target pairs. ', ...
    'Primary analysis excludes forced correction repeats.'], ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',9);
end

function [v,n] = summaryValues(summary,names)
v = nan(numel(names),1); n = zeros(numel(names),1);
for i=1:numel(names)
    idx = find(summary.Metric == string(names{i}),1);
    if ~isempty(idx)
        v(i)=summary.Value(idx); n(i)=summary.N(idx);
    end
end
end

function [metrics,values,counts] = addMetric(metrics,values,counts,name,x,mask)
mask = logical(mask) & isfinite(double(x));
metrics{end+1,1}=name;
counts(end+1,1)=sum(mask);
if any(mask)
    values(end+1,1)=mean(double(x(mask)));
else
    values(end+1,1)=NaN;
end
end

function prev = previousChoiceTarget(T, choiceMask)
prev = nan(height(T),1);
last = NaN;
for i=1:height(T)
    if ~choiceMask(i), continue; end
    prev(i)=last;
    last=T.ChosenTarget(i);
end
end

function x = binaryTargetChoice(r,targetID)
if r.RealEyeChoice && any(targetID==[1 2])
    x=double(r.ChosenTarget==targetID);
else
    x=NaN;
end
end

function [highID,lowID] = rankPair(a,b,tol)
if ~isfinite(a) || ~isfinite(b)
    highID=0; lowID=0;
elseif a>b+tol
    highID=1; lowID=2;
elseif a<b-tol
    highID=2; lowID=1;
else
    highID=0; lowID=0;
end
end

function side = horizontalSide(x,fixX,tol)
if ~isfinite(x)
    side=0;
elseif x>fixX+tol
    side=1;
elseif x<fixX-tol
    side=2;
else
    side=0;
end
end

function side = verticalSide(y,fixY,tol)
if ~isfinite(y)
    side=0;
elseif y>fixY+tol
    side=1;
elseif y<fixY-tol
    side=2;
else
    side=0;
end
end

function bin = angleBin(angleDeg,edges)
bin=0;
if ~isfinite(angleDeg), return; end
angleDeg=mod(angleDeg,360);
for i=1:numel(edges)-1
    if angleDeg>=edges(i) && angleDeg<edges(i+1)
        bin=i; return
    end
end
if angleDeg==360, bin=numel(edges)-1; end
end

function [low,high] = wilsonCI(k,n)
if n<=0
    low=NaN; high=NaN; return
end
z=1.95996398454005;
p=k/n;
den=1+z^2/n;
center=(p+z^2/(2*n))/den;
half=z*sqrt(p*(1-p)/n+z^2/(4*n^2))/den;
low=max(0,center-half); high=min(1,center+half);
end

function printMetric(summary,name)
idx=find(summary.Metric==string(name),1);
if isempty(idx), return; end
fprintf('  %-34s = %.3f (n=%d)\n',name,summary.Value(idx),summary.N(idx));
end

function value = getLogicalScalar(s,name,defaultValue)
value = logical(defaultValue);
if isstruct(s) && isfield(s,name)
    candidate = s.(name);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = logical(double(candidate) ~= 0);
    end
end
end

function value = getScalar(s,name,defaultValue)
value=defaultValue;
if isstruct(s) && isfield(s,name)
    x=s.(name);
    if (isnumeric(x)||islogical(x)) && isscalar(x) && isfinite(double(x))
        value=double(x);
    end
end
end

function r = emptyRow()
r = struct( ...
    'FileName',string(""),'FileTrialIndex',NaN,'Attempt',NaN,'Block',NaN, ...
    'TrialType',NaN,'NStim',NaN,'ChosenTarget',NaN,'RichTarget',NaN, ...
    'HighSalienceTarget',NaN,'PassEye',NaN,'MouseEyeSim',NaN, ...
    'CorrectionRepeat',false,'GoodTrial',false,'RealEyeChoice',false, ...
    'PrimaryChoice',false,'T1X',NaN,'T1Y',NaN,'T2X',NaN,'T2Y',NaN, ...
    'FixX',NaN,'FixY',NaN,'T1Angle',NaN,'T2Angle',NaN, ...
    'T1HorizontalSide',0,'T2HorizontalSide',0,'T1VerticalSide',0, ...
    'T2VerticalSide',0,'StraddlesLR',false,'StraddlesUD',false, ...
    'RightmostTarget',0,'LeftmostTarget',0,'UppermostTarget',0, ...
    'LowermostTarget',0,'ChosenX',NaN,'ChosenY',NaN,'ChosenAngle',NaN, ...
    'ChosenHorizontalSide',0,'ChosenVerticalSide',0,'ChoseRich',NaN, ...
    'ChoseHighSalience',NaN,'ChoseRightmost',NaN,'ChoseUppermost',NaN, ...
    'PreviousChosenTargetPrimary',NaN,'RepeatIdentityPrimary',NaN);
end
