function stats = srs_compute_statistics(T, meta, options)
%SRS_COMPUTE_STATISTICS Compute SRS behavioral statistics.
%
% Analyses are separated into two levels:
%   1. Description of every saved trial, including passEye debug trials.
%
%   2. Behavioral inference restricted to RealEyeChoice trials.
%
% Exact binomial tests, Wilson intervals, and permutation tests use base
% MATLAB. Advanced multivariable logistic regression is added only when
% fitglm is available.
%

if nargin < 3
    options = struct();
end
options = fillDefaultOptions(options);

rng(options.randomSeed, 'twister');

stats = struct();
stats.options = options;
stats.meta = meta;

%% Main masks
allGoodChoice = T.GoodChoice;
realGoodChoice = T.RealEyeChoice;
allGood = T.GoodTrial;

%% General summary
summaryRows = repmat(emptySummaryRow(), 0, 1);
summaryRows(end + 1) = summaryRow('Saved attempts', ...
    height(T), 'trials', 'One trialXXXX.mat file per saved attempt.');
summaryRows(end + 1) = summaryRow('Successful trials', ...
    sum(T.GoodTrial), 'trials', 'trialEndState = 455 / GoodTrial = 1.');
summaryRows(end + 1) = summaryRow('Completion rate', ...
    safeMean(double(T.GoodTrial)), 'proportion', 'Successful trials / saved attempts.');
summaryRows(end + 1) = summaryRow('Successful instruction trials', ...
    sum(T.GoodTrial & T.IsInstruction), 'trials', 'Single-target trials.');
summaryRows(end + 1) = summaryRow('Successful two-target choices', ...
    sum(allGoodChoice), 'trials', 'All acquisition modes combined.');
summaryRows(end + 1) = summaryRow('Real eye-controlled choices', ...
    sum(realGoodChoice), 'trials', 'passEye=0 and mouseEyeSim=0.');
summaryRows(end + 1) = summaryRow('Fraction passEye', ...
    safeMean(double(T.PassEye ~= 0)), 'proportion', ...
    'passEye forces a programmed choice in this task.');
summaryRows(end + 1) = summaryRow('Fraction passJoy', ...
    safeMean(double(T.PassJoy ~= 0)), 'proportion', ...
    'Joystick bypass.');
summaryRows(end + 1) = summaryRow('Valid reaction times', ...
    sum(isfinite(T.ReactionTimeMs)), 'trials', ...
    'saccadeOnset strictly after fixOff.');
summaryRows(end + 1) = summaryRow('Valid fixation-acquisition latencies', ...
    sum(isfinite(T.FixAcquisitionLatencyMs)), 'trials', ...
    'fixAq strictly after fixOn.');
summaryRows(end + 1) = summaryRow('Session duration', ...
    meta.sessionDurationMin, 'minutes', 'Estimated from PTB timestamps.');
summaryRows(end + 1) = summaryRow('Missed frames', ...
    sum(T.MissedFrames, 'omitnan'), 'frames', 'Sum across saved attempts.');
summaryRows(end + 1) = summaryRow('Identity-side mapping errors', ...
    sum(T.GoodChoice & ~T.ChoiceMappingValid), 'trials', ...
    'The recorded chosen side does not match the side of the chosen target.');
stats.summaryTable = struct2table(summaryRows);

%% Experimental-design quality and counterbalancing
balanceRows = repmat(emptyProbabilityRow(), 0, 1);
completedChoices = T.GoodTrial & T.IsChoice;
completedInstructions = T.GoodTrial & T.IsInstruction;

balanceRows(end + 1) = probabilityRow( ...
    'T1 presented on the right', T.T1Side == 1, completedChoices, ...
    completedChoices, 'Spatial counterbalancing of target identity.');
balanceRows(end + 1) = probabilityRow( ...
    'Rich target on the right', T.RichSide == 1, completedChoices, ...
    completedChoices, 'Reward value should be independent of side.');
balanceRows(end + 1) = probabilityRow( ...
    'High-salience target on the right', T.HighSalienceSide == 1, ...
    completedChoices, completedChoices, ...
    'Salience should be independent of side.');
balanceRows(end + 1) = probabilityRow( ...
    'Congruent trial', T.IsCongruent, completedChoices, ...
    completedChoices, 'Congruent/conflict balance.');
balanceRows(end + 1) = probabilityRow( ...
    'T1 instruction trial', T.SingleTargetID == 1, completedInstructions, ...
    completedInstructions, 'Identity balance in instruction trials.');
stats.balanceTable = struct2table(balanceRows);

%% Biases and sequential dependencies
% NAll/ProportionAll describe all files. Inferential p-values and
% confidence intervals use RealEyeChoice trials only.
biasRows = repmat(emptyBiasRow(), 0, 1);

biasRows(end + 1) = biasRow('Spatial', 'Choose right', ...
    T.ChoseRight, allGoodChoice, realGoodChoice, ...
    'Absolute right/left bias.');
biasRows(end + 1) = biasRow('Identity', 'Choose T1', ...
    T.ChoseT1, allGoodChoice, realGoodChoice, ...
    'Absolute T1/T2 bias.');
biasRows(end + 1) = biasRow('Reward', 'Choose rich target', ...
    T.ChoseRich, allGoodChoice, realGoodChoice, ...
    'Choice based on the blockwise reward contingency.');
biasRows(end + 1) = biasRow('Salience', 'Choose high-salience target', ...
    T.ChoseHighSalience, allGoodChoice, realGoodChoice, ...
    'Choice guided by visual salience.');

allTransitionTarget = allGoodChoice & isfinite(T.StayedTarget);
realTransitionTarget = realGoodChoice & isfinite(T.StayedTarget);
allTransitionSide = allGoodChoice & isfinite(T.StayedSide);
realTransitionSide = realGoodChoice & isfinite(T.StayedSide);

biasRows(end + 1) = biasRow('Perseveration', 'Repeat target identity', ...
    T.StayedTarget, allTransitionTarget, realTransitionTarget, ...
    'Current choice compared with the previous two-target choice.');
biasRows(end + 1) = biasRow('Perseveration', 'Repeat side', ...
    T.StayedSide, allTransitionSide, realTransitionSide, ...
    'Current choice compared with the previous two-target choice.');
stats.biasTable = struct2table(biasRows);

%% Explicit comparison of candidate strategies
stats.strategyTable = computeStrategyTable(T);

% Exact conditional associations help distinguish spatial influence from
% identity, reward, and salience when the design is counterbalanced.
%
stats.associationTable = computeAssociationTable(T);

% Early-to-late evolution of major choice policies.
stats.choiceEvolutionTable = computeChoiceEvolutionTable(T, options);

% Descriptive psychometric bins for continuous salience evidence.
%
stats.psychometricTable = computePsychometricTable(T);
stats.psychometricFit = computePsychometricFit(T);

%% Statistical reconstruction of online plots
onlineRows = repmat(emptyBiasRow(), 0, 1);

onlineRows(end + 1) = biasRow('Online plot', ...
    'P(high salience) - conflict', T.ChoseHighSalience, ...
    allGoodChoice & T.IsConflict, realGoodChoice & T.IsConflict, ...
    'Offline equivalent of pHighSalConflict.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(high salience) - congruent', T.ChoseHighSalience, ...
    allGoodChoice & T.IsCongruent, realGoodChoice & T.IsCongruent, ...
    'Offline equivalent of pHighSalCongruent.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(high reward) - conflict', T.ChoseRich, ...
    allGoodChoice & T.IsConflict, realGoodChoice & T.IsConflict, ...
    'Offline equivalent of pHighRewardConflict.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(high reward) - congruent', T.ChoseRich, ...
    allGoodChoice & T.IsCongruent, realGoodChoice & T.IsCongruent, ...
    'Offline equivalent of pHighRewardCongruent.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(right) - conflict', T.ChoseRight, ...
    allGoodChoice & T.IsConflict, realGoodChoice & T.IsConflict, ...
    'Additional spatial control.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(right) - congruent', T.ChoseRight, ...
    allGoodChoice & T.IsCongruent, realGoodChoice & T.IsCongruent, ...
    'Additional spatial control.');
stats.onlineChoiceTable = struct2table(onlineRows);
stats.onlineConditionComparisonTable = ...
    computeOnlineConditionComparisonTable(T);

% Descriptive summaries and temporal trends for online traces and
% operational engagement measures.
stats.timeSeriesTable = computeTimeSeriesTable(T, options);

%% Reaction time and conflict-congruent comparison
rtRows = repmat(emptyRtRow(), 0, 1);
rtRows(end + 1) = rtRow('All choices', ...
    T.ReactionTimeMs(allGoodChoice), ...
    T.ReactionTimeMs(realGoodChoice));
rtRows(end + 1) = rtRow('Congruent', ...
    T.ReactionTimeMs(allGoodChoice & T.IsCongruent), ...
    T.ReactionTimeMs(realGoodChoice & T.IsCongruent));
rtRows(end + 1) = rtRow('Conflict', ...
    T.ReactionTimeMs(allGoodChoice & T.IsConflict), ...
    T.ReactionTimeMs(realGoodChoice & T.IsConflict));
stats.rtTable = struct2table(rtRows);

rtConflict = T.ReactionTimeMs(realGoodChoice & T.IsConflict);
rtCongruent = T.ReactionTimeMs(realGoodChoice & T.IsCongruent);
[rtDifference, rtP] = permutationDifference( ...
    rtConflict, rtCongruent, options.nPermutations, 'median');
stats.rtConflictMinusCongruentMs = rtDifference;
stats.rtConflictVsCongruentP = rtP;

%% Exploration: previous reward and identity switching
stats.exploration = computeExploration(T, options);

%% Outcome and error types
stats.outcomeTable = computeOutcomeTable(T);

%% Completion of each block
stats.blockTable = computeBlockTable(T);

%% Operational engagement and conservative late-change detection
stats.engagement = computeEngagement(T, options, meta);
stats.engagementTable = stats.engagement.earlyLateTable;

%% Multivariable models when the Statistics Toolbox is available
stats.modelTable = computeOptionalChoiceModels(T);

% Add Benjamini-Hochberg false-discovery-rate corrections within each
% family of related exploratory tests. Figures use these q-values for stars.
stats = applyFDRCorrections(stats);

%% Synthetic measures for the report
stats.interpretation = computeInterpretation(stats, T, meta);

end

%% ========================================================================
% Strategies candidates
% ========================================================================

function strategyTable = computeStrategyTable(T)
choiceRows = find(T.GoodChoice);
C = T(choiceRows, :);

if isempty(C)
    strategyTable = table();
    return;
end

names = [ ...
    "Always T1"; ...
    "Always T2"; ...
    "Choose rich target"; ...
    "Choose low-reward target"; ...
    "Choose high-salience target"; ...
    "Choose low-salience target"; ...
    "Repeat previous identity"; ...
    "Switch identity"; ...
    "Always right"; ...
    "Always left"; ...
    "Choose rich side"; ...
    "Choose low-reward side"; ...
    "Choose high-salience side"; ...
    "Choose low-salience side"; ...
    "Repeat previous side"; ...
    "Switch side"];

domains = [repmat("Identity", 8, 1); repmat("Spatial", 8, 1)];

nStrategies = numel(names);
predictions = nan(height(C), nStrategies);

% Identity predictions: 1=T1, 2=T2.
predictions(:, 1) = 1;
predictions(:, 2) = 2;
predictions(:, 3) = C.RichTarget;
predictions(:, 4) = 3 - C.RichTarget;
predictions(:, 5) = C.HighSalienceTarget;
predictions(:, 6) = 3 - C.HighSalienceTarget;
predictions(:, 7) = C.PreviousChosenTarget;
predictions(:, 8) = 3 - C.PreviousChosenTarget;

% Spatial predictions: 1=right, 2=left.
predictions(:, 9) = 1;
predictions(:, 10) = 2;
predictions(:, 11) = C.RichSide;
predictions(:, 12) = 3 - C.RichSide;
predictions(:, 13) = C.HighSalienceSide;
predictions(:, 14) = 3 - C.HighSalienceSide;
predictions(:, 15) = C.PreviousChosenSide;
predictions(:, 16) = 3 - C.PreviousChosenSide;

rows = repmat(emptyStrategyRow(), nStrategies, 1);

for iStrategy = 1:nStrategies
    if domains(iStrategy) == "Identity"
        observed = C.ChosenTarget;
    else
        observed = C.ChosenSide;
    end

    valid = ismember(predictions(:, iStrategy), [1 2]) & ...
        ismember(observed, [1 2]);
    correct = observed(valid) == predictions(valid, iStrategy);

    realValid = valid & C.RealEyeChoice;
    realCorrect = observed(realValid) == predictions(realValid, iStrategy);

    rows(iStrategy).Domain = domains(iStrategy);
    rows(iStrategy).Strategy = names(iStrategy);
    rows(iStrategy).NAll = sum(valid);
    rows(iStrategy).CorrectAll = sum(correct);
    rows(iStrategy).AccuracyAll = safeMean(double(correct));
    rows(iStrategy).NReal = sum(realValid);
    rows(iStrategy).CorrectReal = sum(realCorrect);
    rows(iStrategy).AccuracyReal = safeMean(double(realCorrect));

    [rows(iStrategy).CI95LowReal, rows(iStrategy).CI95HighReal] = ...
        wilsonInterval(rows(iStrategy).CorrectReal, rows(iStrategy).NReal);
    rows(iStrategy).PExactVsChanceReal = exactBinomialP( ...
        rows(iStrategy).CorrectReal, rows(iStrategy).NReal, 0.5);
end

% Identify strategies that make exactly the same predictions in this
% dataset. This prevents confusing, for example, always T2 with choosing
% the rich target in a T2-rich block.
for iStrategy = 1:nStrategies
    sameNames = strings(0, 1);
    for jStrategy = 1:nStrategies
        if iStrategy == jStrategy || domains(iStrategy) ~= domains(jStrategy)
            continue;
        end
        if isequaln(predictions(:, iStrategy), predictions(:, jStrategy))
            sameNames(end + 1, 1) = names(jStrategy); %#ok<AGROW>
        end
    end
    if isempty(sameNames)
        rows(iStrategy).IndistinguishableFrom = "None";
    else
        rows(iStrategy).IndistinguishableFrom = strjoin(sameNames, ' ; ');
    end
end

strategyTable = struct2table(rows);

end


%% ========================================================================
% Conditional associations, evolution, and psychometrics
% ========================================================================

function associationTable = computeAssociationTable(T)
% Build 2x2 tables for real choices and use two-sided Fisher exact tests.
% The All columns remain descriptive for passEye diagnostics.
%

C = T(T.GoodChoice, :);
if isempty(C)
    associationTable = table();
    return;
end

previousRight = nan(height(C), 1);
validPreviousSide = ismember(C.PreviousChosenSide, [1 2]);
previousRight(validPreviousSide) = double( ...
    C.PreviousChosenSide(validPreviousSide) == 1);

previousT1 = nan(height(C), 1);
validPreviousTarget = ismember(C.PreviousChosenTarget, [1 2]);
previousT1(validPreviousTarget) = double( ...
    C.PreviousChosenTarget(validPreviousTarget) == 1);

rows = repmat(emptyAssociationRow(), 0, 1);
rows(end + 1) = associationRow('Spatial', 'Choose right', ...
    'Rich target on the right', C.ChoseRight, C.RichOnRight, C.RealEyeChoice, ...
    'Effect of reward on chosen side.');
rows(end + 1) = associationRow('Spatial', 'Choose right', ...
    'High-salience target on the right', C.ChoseRight, ...
    C.HighSalienceOnRight, C.RealEyeChoice, ...
    'Effect of salience on chosen side.');
rows(end + 1) = associationRow('Spatial/identity', 'Choose right', ...
    'T1 on the right', C.ChoseRight, C.T1OnRight, C.RealEyeChoice, ...
    'A T1 preference produces a positive association; T2 produces a negative association.');
rows(end + 1) = associationRow('Spatial perseveration', 'Choose right', ...
    'Previous choice on the right', C.ChoseRight, previousRight, ...
    C.RealEyeChoice, 'Dependence on the side selected previously.');

rows(end + 1) = associationRow('Reward', 'Choose T1', ...
    'T1 is rich', C.ChoseT1, C.T1IsRich, C.RealEyeChoice, ...
    'Reward effect independent of T1 side.');
rows(end + 1) = associationRow('Salience', 'Choose T1', ...
    'T1 is high salience', C.ChoseT1, C.T1IsHighSalience, ...
    C.RealEyeChoice, 'Effect of salience on identity choice.');
rows(end + 1) = associationRow('Identity/spatial', 'Choose T1', ...
    'T1 on the right', C.ChoseT1, C.T1OnRight, C.RealEyeChoice, ...
    'An always-right policy produces a positive association.');
rows(end + 1) = associationRow('Identity perseveration', 'Choose T1', ...
    'Previous choice was T1', C.ChoseT1, previousT1, C.RealEyeChoice, ...
    'Dependence on the previously selected identity.');

associationTable = struct2table(rows);
end

function r = associationRow(domain, responseLabel, predictorLabel, ...
        response, predictor, realMask, notes)
r = emptyAssociationRow();

validAll = isfinite(response) & isfinite(predictor) & ...
    ismember(response, [0 1]) & ismember(predictor, [0 1]);
validReal = validAll & logical(realMask);

r.Domain = string(domain);
r.Response = string(responseLabel);
r.Predictor = string(predictorLabel);
r.Notes = string(notes);

[r.NAll, r.PResponseWhen0All, r.PResponseWhen1All, ...
    r.DifferenceAll, r.OddsRatioAll] = ...
    summarizeBinaryAssociation(response(validAll), predictor(validAll));

[r.NReal, r.PResponseWhen0Real, r.PResponseWhen1Real, ...
    r.DifferenceReal, r.OddsRatioReal, countsReal] = ...
    summarizeBinaryAssociation(response(validReal), predictor(validReal));
r.FisherPReal = fisherExactTwoSided(countsReal);
end

function [n, p0, p1, difference, oddsRatio, counts] = ...
        summarizeBinaryAssociation(response, predictor)
% counts = [x0y0 x0y1; x1y0 x1y1]. A Haldane-Anscombe correction
% (+0.5 per cell) yields a finite odds ratio under separation.

n = numel(response);
p0 = NaN;
p1 = NaN;
difference = NaN;
oddsRatio = NaN;
counts = nan(2, 2);

if n == 0
    return;
end

counts = [ ...
    sum(predictor == 0 & response == 0), ...
    sum(predictor == 0 & response == 1); ...
    sum(predictor == 1 & response == 0), ...
    sum(predictor == 1 & response == 1)];

if sum(counts(1, :)) > 0
    p0 = counts(1, 2) / sum(counts(1, :));
end
if sum(counts(2, :)) > 0
    p1 = counts(2, 2) / sum(counts(2, :));
end
if isfinite(p0) && isfinite(p1)
    difference = p1 - p0;
end

corrected = counts + 0.5;
oddsRatio = (corrected(2, 2) * corrected(1, 1)) / ...
    (corrected(2, 1) * corrected(1, 2));
end

function pValue = fisherExactTwoSided(counts)
% Two-sided Fisher exact test with fixed margins. Degenerate tables
% cannot estimate an association and return NaN.

pValue = NaN;
if any(~isfinite(counts(:))) || any(counts(:) < 0)
    return;
end
counts = round(counts);

x0 = sum(counts(1, :));
x1 = sum(counts(2, :));
y0 = sum(counts(:, 1));
y1 = sum(counts(:, 2));
n = sum(counts(:));

if n == 0 || x0 == 0 || x1 == 0 || y0 == 0 || y1 == 0
    return;
end

% a represents the predictor=1, response=1 cell.
aObserved = counts(2, 2);
aMin = max(0, x1 - y0);
aMax = min(x1, y1);
aValues = (aMin:aMax)';

logP = logChoose(y1, aValues) + ...
    logChoose(y0, x1 - aValues) - logChoose(n, x1);
observedIdx = find(aValues == aObserved, 1, 'first');
if isempty(observedIdx)
    return;
end
selected = logP <= logP(observedIdx) + 1e-12;
pValue = min(1, sum(exp(logP(selected))));
end

function value = logChoose(n, k)
value = -Inf(size(k));
valid = k >= 0 & k <= n & isfinite(k);
value(valid) = gammaln(n + 1) - gammaln(k(valid) + 1) - ...
    gammaln(n - k(valid) + 1);
end

function evolutionTable = computeChoiceEvolutionTable(T, options)
% Compare the first and final thirds of choices to detect policy changes.
%

C = T(T.GoodChoice, :);
if isempty(C)
    evolutionTable = table();
    return;
end

metricNames = [ ...
    "P(choose right)"; ...
    "P(choose T1)"; ...
    "P(choose rich target)"; ...
    "P(choose high-salience target)"; ...
    "P(repeat identity)"; ...
    "P(repeat side)"];
metricValues = {C.ChoseRight; C.ChoseT1; C.ChoseRich; ...
    C.ChoseHighSalience; C.StayedTarget; C.StayedSide};

rows = repmat(emptyChoiceEvolutionRow(), numel(metricNames), 1);
for iMetric = 1:numel(metricNames)
    values = metricValues{iMetric};
    rows(iMetric) = choiceEvolutionRow(metricNames(iMetric), ...
        values, C.RealEyeChoice, options.nPermutations);
end

evolutionTable = struct2table(rows);
end

function r = choiceEvolutionRow(metric, values, realMask, nPerm)
r = emptyChoiceEvolutionRow();
r.Metric = string(metric);

validAll = find(isfinite(values));
[earlyAll, lateAll] = firstLastThird(validAll);
r.NEarlyAll = numel(earlyAll);
r.NLateAll = numel(lateAll);
r.EarlyAll = safeMean(values(earlyAll));
r.LateAll = safeMean(values(lateAll));
r.LateMinusEarlyAll = r.LateAll - r.EarlyAll;

validReal = find(isfinite(values) & logical(realMask));
[earlyReal, lateReal] = firstLastThird(validReal);
r.NEarlyReal = numel(earlyReal);
r.NLateReal = numel(lateReal);
r.EarlyReal = safeMean(values(earlyReal));
r.LateReal = safeMean(values(lateReal));
[r.LateMinusEarlyReal, r.PermutationPReal] = permutationDifference( ...
    values(lateReal), values(earlyReal), nPerm, 'mean');
end

function [earlyIdx, lateIdx] = firstLastThird(validIdx)
if isempty(validIdx)
    earlyIdx = zeros(0, 1);
    lateIdx = zeros(0, 1);
    return;
end
n = numel(validIdx);
third = max(1, floor(n / 3));
earlyIdx = validIdx(1:third);
lateIdx = validIdx((n - third + 1):n);
end

function psychometricTable = computePsychometricTable(T)
% Bin signed salience evidence. Positive values mean T1 is more salient
% than T2, so the response is P(choose T1).

C = T(T.GoodChoice, :);
if isempty(C)
    psychometricTable = table();
    return;
end

nHue = sum(isfinite(C.HueContrastDifferenceT1MinusT2Deg));
nLum = sum(isfinite(C.MeasuredLuminanceDifferenceT1MinusT2CdM2));
if nHue >= nLum && nHue > 0
    evidence = C.HueContrastDifferenceT1MinusT2Deg;
    evidenceType = "T1 - T2 hue contrast (deg)";
elseif nLum > 0
    evidence = C.MeasuredLuminanceDifferenceT1MinusT2CdM2;
    evidenceType = "T1 - T2 luminance (cd/m2)";
else
    psychometricTable = table();
    return;
end

valid = isfinite(evidence) & isfinite(C.ChoseT1);
if ~any(valid)
    psychometricTable = table();
    return;
end

x = evidence(valid);
y = C.ChoseT1(valid);
real = C.RealEyeChoice(valid);

if min(x) == max(x)
    edges = [min(x) - 0.5, max(x) + 0.5];
else
    nBins = min(7, max(3, round(sqrt(numel(x)))));
    edges = linspace(min(x), max(x), nBins + 1);
end

nBins = numel(edges) - 1;
rows = repmat(emptyPsychometricRow(), 0, 1);
for iBin = 1:nBins
    if iBin < nBins
        inBin = x >= edges(iBin) & x < edges(iBin + 1);
    else
        inBin = x >= edges(iBin) & x <= edges(iBin + 1);
    end
    if ~any(inBin)
        continue;
    end

    row = emptyPsychometricRow();
    row.EvidenceType = evidenceType;
    row.Bin = iBin;
    row.EvidenceMin = min(x(inBin));
    row.EvidenceMean = mean(x(inBin));
    row.EvidenceMax = max(x(inBin));
    row.NAll = sum(inBin);
    row.CountT1All = sum(y(inBin));
    row.PChooseT1All = row.CountT1All / row.NAll;
    [row.CI95LowAll, row.CI95HighAll] = ...
        wilsonInterval(row.CountT1All, row.NAll);

    inBinReal = inBin & real;
    row.NReal = sum(inBinReal);
    row.CountT1Real = sum(y(inBinReal));
    row.PChooseT1Real = safeMean(y(inBinReal));
    [row.CI95LowReal, row.CI95HighReal] = ...
        wilsonInterval(row.CountT1Real, row.NReal);
    rows(end + 1, 1) = row; %#ok<AGROW>
end

if isempty(rows)
    psychometricTable = table();
else
    psychometricTable = struct2table(rows);
end
end

function comparisonTable = computeOnlineConditionComparisonTable(T)
% Compare conflict and congruent trials directly using two-sided Fisher
% exact tests. These tests answer a different question from the one-sample
% binomial tests shown for each individual bar.

C = T(T.RealEyeChoice, :);
rows = repmat(emptyConditionComparisonRow(), 0, 1);
if isempty(C)
    comparisonTable = table();
    return;
end

rows(end + 1) = conditionComparisonRow( ...
    'Choose high-salience target', C.ChoseHighSalience, ...
    C.IsConflict, C.IsCongruent, ...
    'Tests whether salience-guided choices differ between conditions.');
rows(end + 1) = conditionComparisonRow( ...
    'Choose high-reward target', C.ChoseRich, ...
    C.IsConflict, C.IsCongruent, ...
    'Tests whether reward-guided choices differ between conditions.');
rows(end + 1) = conditionComparisonRow( ...
    'Choose right', C.ChoseRight, C.IsConflict, C.IsCongruent, ...
    'Spatial control comparing conflict and congruent trials.');
comparisonTable = struct2table(rows);
end

function row = conditionComparisonRow(outcomeLabel, response, ...
        conflictMask, congruentMask, notes)
row = emptyConditionComparisonRow();
valid = isfinite(response) & ismember(response, [0 1]) & ...
    (logical(conflictMask) | logical(congruentMask));
response = response(valid);
condition = double(logical(congruentMask(valid))); % 0=conflict, 1=congruent

[row.NTotal, row.PConflict, row.PCongruent, row.Difference, ...
    row.OddsRatio, counts] = summarizeBinaryAssociation(response, condition);
row.NConflict = sum(condition == 0);
row.NCongruent = sum(condition == 1);
row.CountConflict = sum(response(condition == 0));
row.CountCongruent = sum(response(condition == 1));
[row.CI95LowConflict, row.CI95HighConflict] = ...
    wilsonInterval(row.CountConflict, row.NConflict);
[row.CI95LowCongruent, row.CI95HighCongruent] = ...
    wilsonInterval(row.CountCongruent, row.NCongruent);
row.FisherP = fisherExactTwoSided(counts);
row.Outcome = string(outcomeLabel);
row.Notes = string(notes);
end

function fit = computePsychometricFit(T)
% Fit P(choose T1) as a logistic function of signed visual salience.
% The predictor is standardized, so the odds ratio is reported per one
% standard deviation increase in T1-minus-T2 evidence. The implementation
% uses iteratively reweighted least squares and requires base MATLAB only.

fit = struct('EvidenceType', "", 'N', 0, 'EvidenceMean', NaN, ...
    'EvidenceSD', NaN, 'Intercept', NaN, 'InterceptSE', NaN, ...
    'SlopePerSD', NaN, 'SlopeSE', NaN, 'OddsRatioPerSD', NaN, ...
    'WaldP', NaN, 'LikelihoodRatioP', NaN, 'Converged', false, ...
    'XGrid', nan(0,1), 'PGrid', nan(0,1), ...
    'Note', "Not estimable.");

C = T(T.RealEyeChoice, :);
if isempty(C)
    fit.Note = "No real eye-controlled choices.";
    return;
end

nHue = sum(isfinite(C.HueContrastDifferenceT1MinusT2Deg));
nLum = sum(isfinite(C.MeasuredLuminanceDifferenceT1MinusT2CdM2));
if nHue >= nLum && nHue > 0
    evidence = C.HueContrastDifferenceT1MinusT2Deg;
    fit.EvidenceType = "T1 - T2 hue contrast (deg)";
elseif nLum > 0
    evidence = C.MeasuredLuminanceDifferenceT1MinusT2CdM2;
    fit.EvidenceType = "T1 - T2 luminance (cd/m2)";
else
    fit.Note = "No continuous salience evidence was saved.";
    return;
end

y = C.ChoseT1;
valid = isfinite(evidence) & isfinite(y) & ismember(y, [0 1]);
x = evidence(valid);
y = y(valid);
fit.N = numel(y);
if fit.N < 20 || numel(unique(y)) < 2 || std(x) <= 0
    fit.Note = "At least 20 variable choices and non-constant evidence are required.";
    return;
end

fit.EvidenceMean = mean(x);
fit.EvidenceSD = std(x);
z = (x - fit.EvidenceMean) ./ fit.EvidenceSD;
X = [ones(fit.N, 1), z];
[beta, covariance, converged, logLikelihood] = logisticIRLS(X, y);
fit.Converged = converged;
if ~converged || any(~isfinite(beta)) || any(~isfinite(covariance(:)))
    fit.Note = "The logistic fit did not converge; inspect possible separation.";
    return;
end

se = sqrt(max(0, diag(covariance)));
fit.Intercept = beta(1);
fit.InterceptSE = se(1);
fit.SlopePerSD = beta(2);
fit.SlopeSE = se(2);
fit.OddsRatioPerSD = exp(beta(2));
if se(2) > 0
    fit.WaldP = erfc(abs(beta(2) / se(2)) / sqrt(2));
end

pNull = min(max(mean(y), eps), 1 - eps);
logLikelihoodNull = sum(y .* log(pNull) + (1 - y) .* log(1 - pNull));
lrStatistic = max(0, 2 * (logLikelihood - logLikelihoodNull));
fit.LikelihoodRatioP = gammainc(lrStatistic / 2, 0.5, 'upper');
fit.XGrid = linspace(min(x), max(x), 200)';
zGrid = (fit.XGrid - fit.EvidenceMean) ./ fit.EvidenceSD;
fit.PGrid = logisticFunction(beta(1) + beta(2) .* zGrid);
fit.Note = "Slope tests whether signed salience predicts T1 choice.";
end

function [beta, covariance, converged, logLikelihood] = logisticIRLS(X, y)
% Numerically stable two-parameter logistic regression.
maxIterations = 100;
tolerance = 1e-9;
ridge = 1e-8;
beta = zeros(size(X, 2), 1);
converged = false;

for iIteration = 1:maxIterations
    eta = X * beta;
    mu = logisticFunction(eta);
    weights = max(mu .* (1 - mu), 1e-9);
    workingResponse = eta + (y - mu) ./ weights;
    information = X' * (weights .* X) + ridge * eye(size(X, 2));
    betaNew = information \ (X' * (weights .* workingResponse));
    if any(~isfinite(betaNew))
        break;
    end
    if max(abs(betaNew - beta)) < tolerance
        beta = betaNew;
        converged = true;
        break;
    end
    beta = betaNew;
end

eta = X * beta;
mu = logisticFunction(eta);
weights = max(mu .* (1 - mu), 1e-9);
information = X' * (weights .* X) + ridge * eye(size(X, 2));
covariance = pinv(information);
mu = min(max(mu, eps), 1 - eps);
logLikelihood = sum(y .* log(mu) + (1 - y) .* log(1 - mu));
end

function p = logisticFunction(eta)
eta = max(min(eta, 35), -35);
p = 1 ./ (1 + exp(-eta));
end

function timeSeriesTable = computeTimeSeriesTable(T, options)
% Summarize continuous traces and test simple monotonic trends with
% attempt number using a permutation test of Pearson correlation.

rows = repmat(emptyTimeSeriesRow(), 0, 1);

rewardDiff = T.RewardDifferenceT1MinusT2Ms;
rewardDiff(~T.GoodTrial) = NaN;
rows(end + 1) = timeSeriesRow('T1 - T2 reward difference (ms)', ...
    rewardDiff, T.Attempt, options.nPermutations, ...
    'Design variable; not necessarily known before the choice.');

hueDiff = T.HueContrastDifferenceT1MinusT2Deg;
hueDiff(~T.GoodTrial) = NaN;
rows(end + 1) = timeSeriesRow('T1 - T2 hue contrast difference (deg)', ...
    hueDiff, T.Attempt, options.nPermutations, ...
    'Signed visual-salience evidence.');

lumDiff = T.MeasuredLuminanceDifferenceT1MinusT2CdM2;
lumDiff(~T.GoodTrial) = NaN;
rows(end + 1) = timeSeriesRow('T1 - T2 luminance difference (cd/m2)', ...
    lumDiff, T.Attempt, options.nPermutations, ...
    'Used when the session manipulates luminance.');

rows(end + 1) = timeSeriesRow('Pre-trial interval (s)', ...
    T.PreTrialIntervalSec, T.Attempt, options.nPermutations, ...
    'A late increase can indicate slower task initiation.');
rows(end + 1) = timeSeriesRow('Fixation acquisition latency (ms)', ...
    T.FixAcquisitionLatencyMs, T.Attempt, options.nPermutations, ...
    'Operational engagement measure before the saccadic response.');

rt = T.ReactionTimeMs;
rt(~T.GoodChoice) = NaN;
rows(end + 1) = timeSeriesRow('Reaction time (ms)', ...
    rt, T.Attempt, options.nPermutations, ...
    'fixOff to saccadeOnset.');

rows(end + 1) = timeSeriesRow('Attempt duration (s)', ...
    T.TrialDurationSec, T.Attempt, options.nPermutations, ...
    'Includes completed and aborted attempts.');
rows(end + 1) = timeSeriesRow('Missed frames', ...
    T.MissedFrames, T.Attempt, options.nPermutations, ...
    'Technical display-quality control.');

timeSeriesTable = struct2table(rows);
end

function r = timeSeriesRow(metric, values, attempt, nPerm, notes)
r = emptyTimeSeriesRow();
valid = isfinite(values) & isfinite(attempt);
x = values(valid);
t = attempt(valid);

r.Metric = string(metric);
r.N = numel(x);
r.Mean = safeMean(x);
r.SD = safeStd(x);
r.Median = safeMedian(x);
r.IQR = safeIQR(x);
if ~isempty(x)
    r.Minimum = min(x);
    r.Maximum = max(x);
end
[r.CorrelationWithAttempt, r.PermutationP] = ...
    permutationCorrelation(t, x, nPerm);
r.Notes = string(notes);
end

%% ========================================================================
% Exploration
% ========================================================================

function exploration = computeExploration(T, options)
allMask = T.GoodChoice & isfinite(T.PreviousRewardMs) & ...
    isfinite(T.SwitchedTarget);
realMask = T.RealEyeChoice & isfinite(T.PreviousRewardMs) & ...
    isfinite(T.SwitchedTarget);

exploration = struct();
exploration.nAll = sum(allMask);
exploration.pSwitchAll = safeMean(T.SwitchedTarget(allMask));
exploration.nReal = sum(realMask);
exploration.pSwitchReal = safeMean(T.SwitchedTarget(realMask));

nSwitchReal = sum(T.SwitchedTarget(realMask));
[exploration.ciLowReal, exploration.ciHighReal] = ...
    wilsonInterval(nSwitchReal, exploration.nReal);
exploration.pExactVsChanceReal = exactBinomialP( ...
    nSwitchReal, exploration.nReal, 0.5);

x = T.PreviousRewardMs(realMask);
y = T.SwitchedTarget(realMask);
[exploration.rewardSwitchCorrelation, ...
    exploration.rewardSwitchPermutationP] = ...
    permutationCorrelation(x, y, options.nPermutations);

% Descriptive binning consistent with the online plot.
allX = T.PreviousRewardMs(allMask);
allY = T.SwitchedTarget(allMask);
[exploration.binCenters, exploration.binPSwitch, exploration.binN] = ...
    binBinaryRelationship(allX, allY, 6);

end

%% ========================================================================
% Outcomes and blocks
% ========================================================================

function outcomeTable = computeOutcomeTable(T)
labels = strings(height(T), 1);
for iTrial = 1:height(T)
    state = T.TrialEndState(iTrial);
    switch state
        case 455
            labels(iTrial) = "Success";
        case 453
            labels(iTrial) = "No response";
        case 454
            labels(iTrial) = "Inaccurate saccade";
        case 11
            labels(iTrial) = "Fixation/target break";
        case 12
            labels(iTrial) = "Joystick break";
        case 13
            labels(iTrial) = "Non-start";
        otherwise
            if strlength(T.Outcome(iTrial)) > 0
                labels(iTrial) = T.Outcome(iTrial);
            else
                labels(iTrial) = sprintf('State %g', state);
            end
    end
end

uniqueLabels = unique(labels, 'stable');
rows = repmat(struct('Outcome', "", 'Count', NaN, 'Proportion', NaN), ...
    numel(uniqueLabels), 1);
for iLabel = 1:numel(uniqueLabels)
    rows(iLabel).Outcome = uniqueLabels(iLabel);
    rows(iLabel).Count = sum(labels == uniqueLabels(iLabel));
    rows(iLabel).Proportion = rows(iLabel).Count / height(T);
end
outcomeTable = struct2table(rows);
end

function blockTable = computeBlockTable(T)
blocks = unique(T.BlockUID, 'stable');
rows = repmat(emptyBlockRow(), numel(blocks), 1);

for iBlock = 1:numel(blocks)
    mask = T.BlockUID == blocks(iBlock);
    firstIdx = find(mask, 1, 'first');

    expected = finiteMax(T.ExpectedTrialsInBlock(mask));
    goodCount = sum(T.GoodTrial(mask));

    rows(iBlock).SessionID = T.SessionID(firstIdx);
    rows(iBlock).BlockUID = blocks(iBlock);
    rows(iBlock).Block = T.Block(firstIdx);
    rows(iBlock).RichTarget = T.RichTarget(firstIdx);
    rows(iBlock).Attempts = sum(mask);
    rows(iBlock).GoodTrials = goodCount;
    rows(iBlock).GoodChoices = sum(T.GoodChoice(mask));
    rows(iBlock).RealEyeChoices = sum(T.RealEyeChoice(mask));
    rows(iBlock).ExpectedTrials = expected;
    rows(iBlock).TrialsMissing = max(0, expected - goodCount);

    if isfinite(expected) && expected > 0
        rows(iBlock).CompletionFraction = goodCount / expected;
        rows(iBlock).Incomplete = goodCount < expected;
    else
        rows(iBlock).CompletionFraction = NaN;
        rows(iBlock).Incomplete = false;
    end
end

blockTable = struct2table(rows);
end

%% ========================================================================
% Engagement and late changes
% ========================================================================

function engagement = computeEngagement(T, options, meta)
n = height(T);
window = min(options.rollingWindow, max(3, n));

engagement = struct();
engagement.window = window;
engagement.attempt = T.Attempt;
engagement.rollingCompletionRate = ...
    trailingMean(double(T.GoodTrial), window);
engagement.rollingPreTrialIntervalSec = ...
    trailingMedian(T.PreTrialIntervalSec, window);
engagement.rollingReactionTimeMs = ...
    trailingMedian(T.ReactionTimeMs, window);
engagement.rollingFixAcquisitionLatencyMs = ...
    trailingMedian(T.FixAcquisitionLatencyMs, window);
engagement.rollingTrialDurationSec = ...
    trailingMedian(T.TrialDurationSec, window);
engagement.rollingRightChoiceEntropy = ...
    trailingBinaryEntropy(T.ChoseRight, window);

% Compare the first and final thirds of the session.
third = max(1, floor(n / 3));
early = false(n, 1);
late = false(n, 1);
early(1:third) = true;
late((n - third + 1):n) = true;

rows = repmat(emptyEarlyLateRow(), 0, 1);

[diffCompletion, pCompletion] = permutationDifference( ...
    double(T.GoodTrial(late)), double(T.GoodTrial(early)), ...
    options.nPermutations, 'mean');
rows(end + 1) = earlyLateRow('Completion rate', ...
    safeMean(double(T.GoodTrial(early))), ...
    safeMean(double(T.GoodTrial(late))), ...
    diffCompletion, pCompletion, sum(early), sum(late));

[diffInterval, pInterval] = permutationDifference( ...
    T.PreTrialIntervalSec(late), T.PreTrialIntervalSec(early), ...
    options.nPermutations, 'median');
rows(end + 1) = earlyLateRow('Median pre-trial interval (s)', ...
    safeMedian(T.PreTrialIntervalSec(early)), ...
    safeMedian(T.PreTrialIntervalSec(late)), ...
    diffInterval, pInterval, ...
    sum(isfinite(T.PreTrialIntervalSec(early))), ...
    sum(isfinite(T.PreTrialIntervalSec(late))));

[diffRT, pRT] = permutationDifference( ...
    T.ReactionTimeMs(late), T.ReactionTimeMs(early), ...
    options.nPermutations, 'median');
rows(end + 1) = earlyLateRow('Median reaction time (ms)', ...
    safeMedian(T.ReactionTimeMs(early)), ...
    safeMedian(T.ReactionTimeMs(late)), ...
    diffRT, pRT, ...
    sum(isfinite(T.ReactionTimeMs(early))), ...
    sum(isfinite(T.ReactionTimeMs(late))));

[diffFix, pFix] = permutationDifference( ...
    T.FixAcquisitionLatencyMs(late), ...
    T.FixAcquisitionLatencyMs(early), ...
    options.nPermutations, 'median');
rows(end + 1) = earlyLateRow('Median fixation acquisition latency (ms)', ...
    safeMedian(T.FixAcquisitionLatencyMs(early)), ...
    safeMedian(T.FixAcquisitionLatencyMs(late)), ...
    diffFix, pFix, ...
    sum(isfinite(T.FixAcquisitionLatencyMs(early))), ...
    sum(isfinite(T.FixAcquisitionLatencyMs(late))));

rows(end + 1) = earlyLateRow('Mean missed frames', ...
    safeMean(T.MissedFrames(early)), ...
    safeMean(T.MissedFrames(late)), ...
    safeMean(T.MissedFrames(late)) - safeMean(T.MissedFrames(early)), ...
    NaN, sum(early), sum(late));

engagement.earlyLateTable = struct2table(rows);

% Search for the strongest increase while permutation-correcting the scan
% over candidate split points. Disengagement is operational and does not
% measure subjective boredom.
minSegment = max(10, floor(n / 6));
nChangePerm = min(options.nPermutations, 2000);

[failSplit, failEffect, failP] = bestIncreaseChangePoint( ...
    double(~T.GoodTrial), minSegment, nChangePerm, 'mean');
[intervalSplit, intervalEffect, intervalP] = bestIncreaseChangePoint( ...
    log1p(T.PreTrialIntervalSec), minSegment, nChangePerm, 'median');
[rtSplit, rtEffect, rtP] = bestIncreaseChangePoint( ...
    log1p(T.ReactionTimeMs), minSegment, nChangePerm, 'median');
[fixSplit, fixEffect, fixP] = bestIncreaseChangePoint( ...
    log1p(T.FixAcquisitionLatencyMs), minSegment, ...
    nChangePerm, 'median');

engagement.failureChangeAttempt = splitToAttempt(T, failSplit);
engagement.failureChangeEffect = failEffect;
engagement.failureChangeP = failP;
engagement.intervalChangeAttempt = splitToAttempt(T, intervalSplit);
engagement.intervalChangeEffectLog = intervalEffect;
engagement.intervalChangeP = intervalP;
engagement.rtChangeAttempt = splitToAttempt(T, rtSplit);
engagement.rtChangeEffectLog = rtEffect;
engagement.rtChangeP = rtP;
engagement.fixChangeAttempt = splitToAttempt(T, fixSplit);
engagement.fixChangeEffectLog = fixEffect;
engagement.fixChangeP = fixP;

runOnset = firstFailureRun(T.GoodTrial, 3);
engagement.failureRunOnsetAttempt = splitToAttempt(T, runOnset);

significantAttempts = [];
labels = strings(0, 1);
if isfinite(failP) && failP < 0.05 && failEffect > 0
    significantAttempts(end + 1) = engagement.failureChangeAttempt; %#ok<AGROW>
    labels(end + 1) = "increased failure rate"; %#ok<AGROW>
end
if isfinite(intervalP) && intervalP < 0.05 && intervalEffect > 0
    significantAttempts(end + 1) = engagement.intervalChangeAttempt; %#ok<AGROW>
    labels(end + 1) = "longer pre-trial intervals"; %#ok<AGROW>
end
if isfinite(rtP) && rtP < 0.05 && rtEffect > 0
    significantAttempts(end + 1) = engagement.rtChangeAttempt; %#ok<AGROW>
    labels(end + 1) = "longer reaction times"; %#ok<AGROW>
end
if isfinite(fixP) && fixP < 0.05 && fixEffect > 0
    significantAttempts(end + 1) = engagement.fixChangeAttempt; %#ok<AGROW>
    labels(end + 1) = "slower fixation acquisition"; %#ok<AGROW>
end
if isfinite(engagement.failureRunOnsetAttempt)
    significantAttempts(end + 1) = engagement.failureRunOnsetAttempt; %#ok<AGROW>
    labels(end + 1) = "at least three consecutive failures"; %#ok<AGROW>
end

% A strong operational conclusion requires two convergent indicators,
% except for an explicit run of three consecutive failures.
hasFailureRun = isfinite(engagement.failureRunOnsetAttempt);
if numel(significantAttempts) >= 2 || hasFailureRun
    engagement.estimatedDisengagementAttempt = min(significantAttempts);
    engagement.evidence = strjoin(labels, ' ; ');
elseif numel(significantAttempts) == 1
    engagement.estimatedDisengagementAttempt = NaN;
    engagement.evidence = "Only one indicator changed: " + labels(1) + ...
        ". Evidence is insufficient to date operational disengagement.";
else
    engagement.estimatedDisengagementAttempt = NaN;
    engagement.evidence = ...
        "No convergent late change was detected.";
end

if meta.dataLikelySimulated
    % Never retain a behavioral disengagement point for generated choices.
    % Technical change-point fields remain available for debugging.

    engagement.estimatedDisengagementAttempt = NaN;
    engagement.evidence = engagement.evidence + ...
        " passEye/simulation session: no behavioral conclusion " + ...
        "about boredom is possible.";
end

end

%% ========================================================================
% Optional logistic regression
% ========================================================================

function modelTable = computeOptionalChoiceModels(T)
% fitglm belongs to the Statistics and Machine Learning Toolbox. This
% guarded section never blocks the base-MATLAB analyses.

if exist('fitglm', 'file') ~= 2
    modelTable = table("All models", "Not run", NaN, NaN, NaN, ...
        NaN, 0, "fitglm unavailable; exact and permutation analyses were retained.", ...
        'VariableNames', {'Model', 'Term', 'Estimate', 'SE', 'PValue', ...
        'OddsRatio', 'N', 'Note'});
    return;
end

C = T(T.RealEyeChoice, :);
if height(C) < 20
    modelTable = table("All models", "Not run", NaN, NaN, NaN, ...
        NaN, height(C), "Fewer than 20 real eye-controlled choices.", ...
        'VariableNames', {'Model', 'Term', 'Estimate', 'SE', 'PValue', ...
        'OddsRatio', 'N', 'Note'});
    return;
end

allRows = repmat(emptyModelRow(), 0, 1);

% Spatial model: the intercept captures right/left bias; T1OnRight turns
% an identity preference into a spatial prediction.
previousRight = double(C.PreviousChosenSide == 1);
previousRight(~isfinite(C.PreviousChosenSide)) = NaN;
progress = standardizeFinite(C.ChoiceInBlock);
Xspatial = [C.RichOnRight, C.HighSalienceOnRight, C.T1OnRight, ...
    previousRight, progress];
spatialNames = {'RichOnRight', 'HighSalienceOnRight', 'T1OnRight', ...
    'PreviousRight', 'ChoiceProgress'};
spatialRows = fitOneLogisticModel('Choose right', Xspatial, ...
    C.ChoseRight, spatialNames);
allRows = [allRows; spatialRows]; %#ok<AGROW>

% Identity model: the intercept captures T1/T2 bias; T1OnRight detects
% spatial preference independently of identity.
previousT1 = double(C.PreviousChosenTarget == 1);
previousT1(~isfinite(C.PreviousChosenTarget)) = NaN;
Xidentity = [C.T1IsRich, C.T1IsHighSalience, C.T1OnRight, ...
    previousT1, progress];
identityNames = {'T1IsRich', 'T1IsHighSalience', 'T1OnRight', ...
    'PreviousT1', 'ChoiceProgress'};
identityRows = fitOneLogisticModel('Choose T1', Xidentity, ...
    C.ChoseT1, identityNames);
allRows = [allRows; identityRows]; %#ok<AGROW>

if isempty(allRows)
    modelTable = table("All models", "Not run", NaN, NaN, NaN, ...
        NaN, height(C), "Constant response or non-estimable predictors.", ...
        'VariableNames', {'Model', 'Term', 'Estimate', 'SE', 'PValue', ...
        'OddsRatio', 'N', 'Note'});
else
    modelTable = struct2table(allRows);
end

end

function rows = fitOneLogisticModel(modelName, X, y, predictorNames)
rows = repmat(emptyModelRow(), 0, 1);

valid = isfinite(y) & all(isfinite(X), 2);
X = X(valid, :);
y = y(valid);

if numel(y) < 20 || numel(unique(y)) < 2
    return;
end

% Remove constant columns and then rank-redundant columns to avoid errors
% caused by perfect confounds within a block.
%
keep = false(1, size(X, 2));
currentX = zeros(size(X, 1), 0);
for iPredictor = 1:size(X, 2)
    candidate = X(:, iPredictor);
    if max(candidate) == min(candidate)
        continue;
    end
    if rank([ones(size(X, 1), 1), currentX, candidate]) > ...
            rank([ones(size(X, 1), 1), currentX])
        keep(iPredictor) = true;
        currentX = [currentX, candidate]; %#ok<AGROW>
    end
end

X = X(:, keep);
predictorNames = predictorNames(keep);
if isempty(X)
    return;
end

dataTable = array2table(X, 'VariableNames', predictorNames);
dataTable.Response = y;
formula = ['Response ~ 1 + ' strjoin(predictorNames, ' + ')];

try
    mdl = fitglm(dataTable, formula, ...
        'Distribution', 'binomial', 'Link', 'logit');
    C = mdl.Coefficients;

    for iTerm = 1:height(C)
        row = emptyModelRow();
        row.Model = string(modelName);
        row.Term = string(C.Properties.RowNames{iTerm});
        row.Estimate = C.Estimate(iTerm);
        row.SE = C.SE(iTerm);
        row.PValue = C.pValue(iTerm);
        row.OddsRatio = exp(C.Estimate(iTerm));
        row.N = numel(y);
        if abs(row.Estimate) > 10
            row.Note = "Extreme coefficient; probable separation.";
        else
            row.Note = "";
        end
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
catch ME
    row = emptyModelRow();
    row.Model = string(modelName);
    row.Term = "Model failure";
    row.N = numel(y);
    row.Note = string(ME.message);
    rows(end + 1, 1) = row;
end

end

%% ========================================================================
% Multiple-comparison correction
% ========================================================================

function stats = applyFDRCorrections(stats)
% Correct related exploratory tests within each analysis family. Raw
% p-values are retained; q-values are added as new table columns.

stats = addQColumn(stats, 'balanceTable', 'PExactVsHalf');
stats = addQColumn(stats, 'biasTable', 'PExactVsHalfReal');
stats = addQColumn(stats, 'strategyTable', 'PExactVsChanceReal');
stats = addQColumn(stats, 'associationTable', 'FisherPReal');
stats = addQColumn(stats, 'choiceEvolutionTable', 'PermutationPReal');
stats = addQColumn(stats, 'onlineChoiceTable', 'PExactVsHalfReal');
stats = addQColumn(stats, 'timeSeriesTable', 'PermutationP');
stats = addQColumn(stats, 'engagementTable', 'PermutationP');
stats = addQColumn(stats, 'onlineConditionComparisonTable', 'FisherP');
stats = addQColumn(stats, 'modelTable', 'PValue');
end

function stats = addQColumn(stats, tableField, pField)
if ~isfield(stats, tableField) || ~istable(stats.(tableField))
    return;
end
T = stats.(tableField);
if ~any(strcmp(T.Properties.VariableNames, pField))
    return;
end
T.QFDR = benjaminiHochberg(T.(pField));
stats.(tableField) = T;
end

function qValues = benjaminiHochberg(pValues)
% Benjamini-Hochberg FDR adjustment while preserving NaN positions.
pValues = pValues(:);
qValues = nan(size(pValues));
valid = isfinite(pValues) & pValues >= 0 & pValues <= 1;
if ~any(valid)
    return;
end
p = pValues(valid);
[sortedP, order] = sort(p);
m = numel(sortedP);
adjusted = sortedP .* m ./ (1:m)';
for i = m-1:-1:1
    adjusted(i) = min(adjusted(i), adjusted(i + 1));
end
adjusted = min(adjusted, 1);
restored = nan(m, 1);
restored(order) = adjusted;
qValues(valid) = restored;
end

%% ========================================================================
% Synthetic interpretation
% ========================================================================

function interpretation = computeInterpretation(stats, T, meta)
interpretation = struct();

choiceMask = T.GoodChoice;
interpretation.pRightAll = safeMean(T.ChoseRight(choiceMask));
interpretation.pT1All = safeMean(T.ChoseT1(choiceMask));
interpretation.pRichAll = safeMean(T.ChoseRich(choiceMask));
interpretation.pHighSalienceAll = ...
    safeMean(T.ChoseHighSalience(choiceMask));

interpretation.spatialBiasMagnitude = ...
    abs(interpretation.pRightAll - 0.5) * 2;
interpretation.identityBiasMagnitude = ...
    abs(interpretation.pT1All - 0.5) * 2;
interpretation.rewardBiasMagnitude = ...
    abs(interpretation.pRichAll - 0.5) * 2;
interpretation.salienceBiasMagnitude = ...
    abs(interpretation.pHighSalienceAll - 0.5) * 2;

if isempty(stats.strategyTable)
    interpretation.bestStrategyAll = "None";
    interpretation.bestStrategyAccuracyAll = NaN;
else
    [bestAccuracy, idx] = max(stats.strategyTable.AccuracyAll);
    interpretation.bestStrategyAll = stats.strategyTable.Strategy(idx);
    interpretation.bestStrategyAccuracyAll = bestAccuracy;
    interpretation.bestStrategyConfounds = ...
        stats.strategyTable.IndistinguishableFrom(idx);
end

interpretation.inferenceAllowed = meta.nRealEyeChoices > 0;
if ~interpretation.inferenceAllowed
    interpretation.mainCaveat = [ ...
        "Strategy results are descriptive only because no " + ...
        "real eye-controlled choice is available."];
else
    interpretation.mainCaveat = "";
end
end

%% ========================================================================
% Table-row constructors
% ========================================================================

function r = emptySummaryRow()
r = struct('Metric', "", 'Value', NaN, 'Unit', "", 'Notes', "");
end

function r = summaryRow(metric, value, unit, notes)
r = emptySummaryRow();
r.Metric = string(metric);
r.Value = value;
r.Unit = string(unit);
r.Notes = string(notes);
end

function r = emptyProbabilityRow()
r = struct('Metric', "", 'N', NaN, 'Count', NaN, ...
    'Proportion', NaN, 'CI95Low', NaN, 'CI95High', NaN, ...
    'PExactVsHalf', NaN, 'Notes', "");
end

function r = probabilityRow(metric, values, mask, inferenceMask, notes)
% Keep inferenceMask separate to make the tested population explicit,
% even when it equals mask for design checks.
r = emptyProbabilityRow();
valid = mask & isfinite(double(values));
validInference = inferenceMask & isfinite(double(values));

r.Metric = string(metric);
r.N = sum(valid);
r.Count = sum(double(values(valid)));
r.Proportion = safeMean(double(values(valid)));

nInference = sum(validInference);
xInference = sum(double(values(validInference)));
[r.CI95Low, r.CI95High] = wilsonInterval(xInference, nInference);
r.PExactVsHalf = exactBinomialP(xInference, nInference, 0.5);
r.Notes = string(notes);
end

function r = emptyBiasRow()
r = struct('Domain', "", 'Metric', "", ...
    'NAll', NaN, 'CountAll', NaN, 'ProportionAll', NaN, ...
    'NReal', NaN, 'CountReal', NaN, 'ProportionReal', NaN, ...
    'CI95LowReal', NaN, 'CI95HighReal', NaN, ...
    'PExactVsHalfReal', NaN, 'Notes', "");
end

function r = biasRow(domain, metric, values, allMask, realMask, notes)
r = emptyBiasRow();
validAll = allMask & isfinite(values);
validReal = realMask & isfinite(values);

r.Domain = string(domain);
r.Metric = string(metric);
r.NAll = sum(validAll);
r.CountAll = sum(values(validAll));
r.ProportionAll = safeMean(values(validAll));
r.NReal = sum(validReal);
r.CountReal = sum(values(validReal));
r.ProportionReal = safeMean(values(validReal));
[r.CI95LowReal, r.CI95HighReal] = ...
    wilsonInterval(r.CountReal, r.NReal);
r.PExactVsHalfReal = exactBinomialP(r.CountReal, r.NReal, 0.5);
r.Notes = string(notes);
end

function r = emptyStrategyRow()
r = struct('Domain', "", 'Strategy', "", ...
    'NAll', NaN, 'CorrectAll', NaN, 'AccuracyAll', NaN, ...
    'NReal', NaN, 'CorrectReal', NaN, 'AccuracyReal', NaN, ...
    'CI95LowReal', NaN, 'CI95HighReal', NaN, ...
    'PExactVsChanceReal', NaN, 'IndistinguishableFrom', "");
end

function r = emptyAssociationRow()
r = struct('Domain', "", 'Response', "", 'Predictor', "", ...
    'NAll', NaN, 'PResponseWhen0All', NaN, ...
    'PResponseWhen1All', NaN, 'DifferenceAll', NaN, ...
    'OddsRatioAll', NaN, 'NReal', NaN, ...
    'PResponseWhen0Real', NaN, 'PResponseWhen1Real', NaN, ...
    'DifferenceReal', NaN, 'OddsRatioReal', NaN, ...
    'FisherPReal', NaN, 'Notes', "");
end

function r = emptyConditionComparisonRow()
r = struct('Outcome', "", 'NTotal', NaN, ...
    'NConflict', NaN, 'CountConflict', NaN, 'PConflict', NaN, ...
    'CI95LowConflict', NaN, 'CI95HighConflict', NaN, ...
    'NCongruent', NaN, 'CountCongruent', NaN, 'PCongruent', NaN, ...
    'CI95LowCongruent', NaN, 'CI95HighCongruent', NaN, ...
    'Difference', NaN, 'OddsRatio', NaN, 'FisherP', NaN, ...
    'QFDR', NaN, 'Notes', "");
end

function r = emptyChoiceEvolutionRow()
r = struct('Metric', "", ...
    'NEarlyAll', NaN, 'NLateAll', NaN, ...
    'EarlyAll', NaN, 'LateAll', NaN, 'LateMinusEarlyAll', NaN, ...
    'NEarlyReal', NaN, 'NLateReal', NaN, ...
    'EarlyReal', NaN, 'LateReal', NaN, ...
    'LateMinusEarlyReal', NaN, 'PermutationPReal', NaN);
end

function r = emptyPsychometricRow()
r = struct('EvidenceType', "", 'Bin', NaN, ...
    'EvidenceMin', NaN, 'EvidenceMean', NaN, 'EvidenceMax', NaN, ...
    'NAll', NaN, 'CountT1All', NaN, 'PChooseT1All', NaN, ...
    'CI95LowAll', NaN, 'CI95HighAll', NaN, ...
    'NReal', NaN, 'CountT1Real', NaN, 'PChooseT1Real', NaN, ...
    'CI95LowReal', NaN, 'CI95HighReal', NaN);
end

function r = emptyTimeSeriesRow()
r = struct('Metric', "", 'N', NaN, 'Mean', NaN, 'SD', NaN, ...
    'Median', NaN, 'IQR', NaN, 'Minimum', NaN, 'Maximum', NaN, ...
    'CorrelationWithAttempt', NaN, 'PermutationP', NaN, 'Notes', "");
end

function r = emptyRtRow()
r = struct('Condition', "", ...
    'NAll', NaN, 'MedianAllMs', NaN, 'IQRAllMs', NaN, ...
    'NReal', NaN, 'MedianRealMs', NaN, 'IQRRealMs', NaN);
end

function r = rtRow(condition, allValues, realValues)
r = emptyRtRow();
allValues = allValues(isfinite(allValues));
realValues = realValues(isfinite(realValues));
r.Condition = string(condition);
r.NAll = numel(allValues);
r.MedianAllMs = safeMedian(allValues);
r.IQRAllMs = safeIQR(allValues);
r.NReal = numel(realValues);
r.MedianRealMs = safeMedian(realValues);
r.IQRRealMs = safeIQR(realValues);
end

function r = emptyBlockRow()
r = struct('SessionID', "", 'BlockUID', "", 'Block', NaN, ...
    'RichTarget', NaN, 'Attempts', NaN, 'GoodTrials', NaN, ...
    'GoodChoices', NaN, 'RealEyeChoices', NaN, ...
    'ExpectedTrials', NaN, 'TrialsMissing', NaN, ...
    'CompletionFraction', NaN, 'Incomplete', false);
end

function r = emptyEarlyLateRow()
r = struct('Metric', "", 'EarlyValue', NaN, 'LateValue', NaN, ...
    'LateMinusEarly', NaN, 'PermutationP', NaN, ...
    'NEarly', NaN, 'NLate', NaN);
end

function r = earlyLateRow(metric, earlyValue, lateValue, difference, ...
        pValue, nEarly, nLate)
r = emptyEarlyLateRow();
r.Metric = string(metric);
r.EarlyValue = earlyValue;
r.LateValue = lateValue;
r.LateMinusEarly = difference;
r.PermutationP = pValue;
r.NEarly = nEarly;
r.NLate = nLate;
end

function r = emptyModelRow()
r = struct('Model', "", 'Term', "", 'Estimate', NaN, ...
    'SE', NaN, 'PValue', NaN, 'OddsRatio', NaN, 'N', NaN, 'Note', "");
end

%% ========================================================================
% Base-MATLAB statistical utilities
% ========================================================================

function [low, high] = wilsonInterval(x, n)
if n <= 0 || ~isfinite(n) || ~isfinite(x)
    low = NaN;
    high = NaN;
    return;
end
z = 1.95996398454005;
p = x / n;
den = 1 + z^2 / n;
center = (p + z^2 / (2 * n)) / den;
halfWidth = z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den;
low = max(0, center - halfWidth);
high = min(1, center + halfWidth);
end

function pValue = exactBinomialP(x, n, p0)
% Two-sided exact binomial test by probability ordering: sum outcomes
% whose H0 probability is no greater than the observed outcome.
if n <= 0 || ~isfinite(n) || ~isfinite(x)
    pValue = NaN;
    return;
end
x = round(x);
n = round(n);
k = (0:n)';
logProb = gammaln(n + 1) - gammaln(k + 1) - gammaln(n - k + 1) + ...
    k .* log(p0) + (n - k) .* log(1 - p0);
observedLogProb = logProb(x + 1);
selected = logProb <= observedLogProb + 1e-12;
pValue = min(1, sum(exp(logProb(selected))));
end

function [difference, pValue] = permutationDifference(a, b, nPerm, statistic)
a = a(isfinite(a));
b = b(isfinite(b));
if isempty(a) || isempty(b)
    difference = NaN;
    pValue = NaN;
    return;
end

switch lower(statistic)
    case 'mean'
        fun = @mean;
    otherwise
        fun = @median;
end

difference = fun(a) - fun(b);
combined = [a(:); b(:)];
nA = numel(a);

extremeCount = 0;
for iPerm = 1:nPerm
    order = randperm(numel(combined));
    permA = combined(order(1:nA));
    permB = combined(order((nA + 1):end));
    permDifference = fun(permA) - fun(permB);
    if abs(permDifference) >= abs(difference)
        extremeCount = extremeCount + 1;
    end
end
pValue = (extremeCount + 1) / (nPerm + 1);
end

function [rObserved, pValue] = permutationCorrelation(x, y, nPerm)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if numel(x) < 5 || numel(unique(x)) < 2 || numel(unique(y)) < 2
    rObserved = NaN;
    pValue = NaN;
    return;
end
rMatrix = corrcoef(x, y);
rObserved = rMatrix(1, 2);
extremeCount = 0;
for iPerm = 1:nPerm
    yPerm = y(randperm(numel(y)));
    rPermMatrix = corrcoef(x, yPerm);
    rPerm = rPermMatrix(1, 2);
    if abs(rPerm) >= abs(rObserved)
        extremeCount = extremeCount + 1;
    end
end
pValue = (extremeCount + 1) / (nPerm + 1);
end

function [splitIndex, effect, pValue] = bestIncreaseChangePoint( ...
        x, minSegment, nPerm, statistic)
x = x(:);
n = numel(x);
splitIndex = NaN;
effect = NaN;
pValue = NaN;

if n < 2 * minSegment
    return;
end

[observedMax, observedSplit] = scanBestIncrease(x, minSegment, statistic);
if ~isfinite(observedMax)
    return;
end

maxPermuted = nan(nPerm, 1);
for iPerm = 1:nPerm
    xPerm = x(randperm(n));
    maxPermuted(iPerm) = scanBestIncrease(xPerm, minSegment, statistic);
end
validPerm = isfinite(maxPermuted);
if ~any(validPerm)
    return;
end

splitIndex = observedSplit;
effect = observedMax;
pValue = (1 + sum(maxPermuted(validPerm) >= observedMax)) / ...
    (1 + sum(validPerm));
end

function [bestEffect, bestSplit] = scanBestIncrease(x, minSegment, statistic)
n = numel(x);
bestEffect = -Inf;
bestSplit = NaN;
for split = minSegment:(n - minSegment)
    before = x(1:split);
    after = x((split + 1):end);
    before = before(isfinite(before));
    after = after(isfinite(after));
    if numel(before) < max(3, floor(minSegment / 2)) || ...
            numel(after) < max(3, floor(minSegment / 2))
        continue;
    end
    if strcmpi(statistic, 'mean')
        candidate = mean(after) - mean(before);
    else
        candidate = median(after) - median(before);
    end
    if candidate > bestEffect
        bestEffect = candidate;
        bestSplit = split;
    end
end
if isinf(bestEffect)
    bestEffect = NaN;
end
end

%% ========================================================================
% Rolling series and small utility functions
% ========================================================================

function y = trailingMean(x, window)
y = nan(size(x));
for i = 1:numel(x)
    startIdx = max(1, i - window + 1);
    values = x(startIdx:i);
    values = values(isfinite(values));
    if ~isempty(values)
        y(i) = mean(values);
    end
end
end

function y = trailingMedian(x, window)
y = nan(size(x));
for i = 1:numel(x)
    startIdx = max(1, i - window + 1);
    values = x(startIdx:i);
    values = values(isfinite(values));
    if ~isempty(values)
        y(i) = median(values);
    end
end
end

function y = trailingBinaryEntropy(x, window)
y = nan(size(x));
for i = 1:numel(x)
    startIdx = max(1, i - window + 1);
    values = x(startIdx:i);
    values = values(isfinite(values));
    if numel(values) < 3
        continue;
    end
    p = mean(values);
    if p == 0 || p == 1
        y(i) = 0;
    else
        y(i) = -(p * log2(p) + (1 - p) * log2(1 - p));
    end
end
end

function [centers, pBinary, counts] = binBinaryRelationship(x, y, nBins)
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);
if isempty(x)
    centers = NaN;
    pBinary = NaN;
    counts = 0;
    return;
end
if min(x) == max(x)
    centers = mean(x);
    pBinary = mean(y);
    counts = numel(y);
    return;
end
edges = linspace(min(x), max(x), nBins + 1);
centers = nan(nBins, 1);
pBinary = nan(nBins, 1);
counts = zeros(nBins, 1);
for iBin = 1:nBins
    if iBin < nBins
        inBin = x >= edges(iBin) & x < edges(iBin + 1);
    else
        inBin = x >= edges(iBin) & x <= edges(iBin + 1);
    end
    if any(inBin)
        centers(iBin) = mean(x(inBin));
        pBinary(iBin) = mean(y(inBin));
        counts(iBin) = sum(inBin);
    end
end
keep = counts > 0;
centers = centers(keep);
pBinary = pBinary(keep);
counts = counts(keep);
end

function onsetIndex = firstFailureRun(goodTrial, runLength)
failure = ~logical(goodTrial(:));
onsetIndex = NaN;
if numel(failure) < runLength
    return;
end
for i = 1:(numel(failure) - runLength + 1)
    if all(failure(i:(i + runLength - 1)))
        onsetIndex = i;
        return;
    end
end
end

function attempt = splitToAttempt(T, splitIndex)
if isfinite(splitIndex) && splitIndex >= 1 && splitIndex <= height(T)
    attempt = T.Attempt(round(splitIndex));
else
    attempt = NaN;
end
end

function value = safeMean(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = mean(x);
end
end

function value = safeMedian(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = median(x);
end
end

function value = safeStd(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
elseif numel(x) == 1
    value = 0;
else
    value = std(x);
end
end

function value = safeIQR(x)
x = sort(x(isfinite(x)));
if isempty(x)
    value = NaN;
else
    value = percentileLinear(x, 75) - percentileLinear(x, 25);
end
end

function value = percentileLinear(sortedX, percentile)
n = numel(sortedX);
if n == 1
    value = sortedX(1);
    return;
end
position = 1 + (n - 1) * percentile / 100;
lowerIdx = floor(position);
upperIdx = ceil(position);
if lowerIdx == upperIdx
    value = sortedX(lowerIdx);
else
    weight = position - lowerIdx;
    value = sortedX(lowerIdx) * (1 - weight) + ...
        sortedX(upperIdx) * weight;
end
end

function value = finiteMax(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = max(x);
end
end

function z = standardizeFinite(x)
z = nan(size(x));
valid = isfinite(x);
if sum(valid) < 2
    return;
end
mu = mean(x(valid));
sigma = std(x(valid));
if sigma == 0
    z(valid) = 0;
else
    z(valid) = (x(valid) - mu) / sigma;
end
end

function options = fillDefaultOptions(options)
defaults = struct( ...
    'rollingWindow', 20, ...
    'nPermutations', 5000, ...
    'randomSeed', 1, ...
    'makeFigures', true, ...
    'saveFigures', true, ...
    'saveMatlabFigures', true, ...
    'outputRoot', '', ...
    'verbose', true);
fields = fieldnames(defaults);
for iField = 1:numel(fields)
    name = fields{iField};
    if ~isfield(options, name) || isempty(options.(name))
        options.(name) = defaults.(name);
    end
end
end
