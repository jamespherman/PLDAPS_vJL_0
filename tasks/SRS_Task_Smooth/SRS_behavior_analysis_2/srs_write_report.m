function reportFile = srs_write_report(T, stats, meta, outputFolder)
%SRS_WRITE_REPORT Write a detailed English behavioral-analysis report.
%
% The report separates descriptive summaries from behavioral inference.
% Exact p-values and FDR-adjusted q-values are included wherever available.

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end
reportFile = fullfile(outputFolder, 'analysis_report.txt');
fid = fopen(reportFile, 'w');
if fid < 0
    error('Could not create report: %s', reportFile);
end
cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'SRS_TASK_SMOOTH BEHAVIORAL ANALYSIS\n');
fprintf(fid, '===================================\n\n');
fprintf(fid, 'Session or dataset : %s\n', meta.sessionID);
if isfield(meta, 'sessionFolder')
    fprintf(fid, 'Source folder      : %s\n', meta.sessionFolder);
end
fprintf(fid, 'Generated          : %s\n\n', datestr(now));

fprintf(fid, 'STATISTICAL SYMBOLS\n');
fprintf(fid, '-------------------\n');
fprintf(fid, 'ns: p/q >= 0.05; *: <0.05; **: <0.01; ***: <0.001.\n');
fprintf(fid, ['Families of related exploratory tests are corrected with the ', ...
    'Benjamini-Hochberg false-discovery-rate procedure. Figures use q-values ', ...
    'for stars whenever a corrected family is available. Single tests such ', ...
    'as the conflict-congruent RT permutation test and psychometric slope ', ...
    'test use their raw p-values.\n\n']);

%% Data validity
fprintf(fid, '1. DATA VALIDITY\n');
fprintf(fid, '----------------\n');
if isfield(meta, 'warnings') && ~isempty(meta.warnings)
    for i = 1:numel(meta.warnings)
        fprintf(fid, 'WARNING: %s\n', char(meta.warnings(i)));
    end
else
    fprintf(fid, 'No simulation or bypass warning was detected.\n');
end
fprintf(fid, '\nSaved two-target choices : %d\n', sum(T.GoodChoice));
fprintf(fid, 'Choices eligible for inference: %d\n', sum(T.RealEyeChoice));
fprintf(fid, 'passEye fraction          : %.3f\n', mean(double(T.PassEye ~= 0)));
fprintf(fid, 'passJoy fraction          : %.3f\n', mean(double(T.PassJoy ~= 0)));
fprintf(fid, 'Valid reaction times      : %d\n', sum(isfinite(T.ReactionTimeMs)));
fprintf(fid, 'Valid fixation latencies  : %d\n\n', ...
    sum(isfinite(T.FixAcquisitionLatencyMs)));

%% General summary
fprintf(fid, '2. SESSION SUMMARY\n');
fprintf(fid, '------------------\n');
printMetricTable(fid, stats.summaryTable, 'Value', 'Unit');
fprintf(fid, '\n');

%% Design balance
fprintf(fid, '3. DESIGN BALANCE\n');
fprintf(fid, '-----------------\n');
B = stats.balanceTable;
for i = 1:height(B)
    fprintf(fid, '%-34s: %d/%d = %s; exact p=%s; FDR q=%s %s\n', ...
        char(B.Metric(i)), round(B.Count(i)), round(B.N(i)), ...
        numberText(B.Proportion(i)), pText(B.PExactVsHalf(i)), ...
        qText(B, i), starText(qValue(B, i)));
end
fprintf(fid, ['\nA significant balance test indicates that the corresponding ', ...
    'design factor departed from 0.5. This may confound behavioral ', ...
    'interpretation if it is also associated with the animal''s choices.\n\n']);

%% Core choice biases
fprintf(fid, '4. CORE CHOICE BIASES AND PERSEVERATION\n');
fprintf(fid, '---------------------------------------\n');
B = stats.biasTable;
for i = 1:height(B)
    fprintf(fid, '%-30s | all: %d/%d = %s', char(B.Metric(i)), ...
        round(B.CountAll(i)), round(B.NAll(i)), numberText(B.ProportionAll(i)));
    if B.NReal(i) > 0
        fprintf(fid, [' | real: %d/%d = %s, 95%% Wilson CI [%s, %s], ', ...
            'exact p=%s, FDR q=%s %s'], ...
            round(B.CountReal(i)), round(B.NReal(i)), ...
            numberText(B.ProportionReal(i)), ...
            numberText(B.CI95LowReal(i)), numberText(B.CI95HighReal(i)), ...
            pText(B.PExactVsHalfReal(i)), qText(B, i), ...
            starText(qValue(B, i)));
    else
        fprintf(fid, ' | real: not estimable');
    end
    fprintf(fid, '\n');
end
fprintf(fid, '\n');

%% Direct condition comparisons
fprintf(fid, '5. CONFLICT VERSUS CONGRUENT CHOICE COMPARISONS\n');
fprintf(fid, '------------------------------------------------\n');
if isempty(stats.onlineConditionComparisonTable)
    fprintf(fid, 'Not estimable because no real eye-controlled choices were available.\n\n');
else
    C = stats.onlineConditionComparisonTable;
    for i = 1:height(C)
        fprintf(fid, ['%-28s | conflict %d/%d=%s, congruent %d/%d=%s, ', ...
            'delta(congruent-conflict)=%s, OR=%s, Fisher p=%s, FDR q=%s %s\n'], ...
            char(C.Outcome(i)), round(C.CountConflict(i)), ...
            round(C.NConflict(i)), numberText(C.PConflict(i)), ...
            round(C.CountCongruent(i)), round(C.NCongruent(i)), ...
            numberText(C.PCongruent(i)), numberText(C.Difference(i)), ...
            numberText(C.OddsRatio(i)), pText(C.FisherP(i)), ...
            qText(C, i), starText(qValue(C, i)));
    end
    fprintf(fid, '\n');
end

%% Reaction times
fprintf(fid, '6. REACTION TIMES\n');
fprintf(fid, '-----------------\n');
R = stats.rtTable;
for i = 1:height(R)
    fprintf(fid, '%-16s | all N=%d median=%s ms IQR=%s', ...
        char(R.Condition(i)), round(R.NAll(i)), ...
        numberText(R.MedianAllMs(i)), numberText(R.IQRAllMs(i)));
    if R.NReal(i) > 0
        fprintf(fid, ' | real N=%d median=%s ms IQR=%s', ...
            round(R.NReal(i)), numberText(R.MedianRealMs(i)), ...
            numberText(R.IQRRealMs(i)));
    end
    fprintf(fid, '\n');
end
fprintf(fid, ['Conflict minus congruent median RT = %s ms; two-sided ', ...
    'permutation p=%s %s.\n\n'], ...
    numberText(stats.rtConflictMinusCongruentMs), ...
    pText(stats.rtConflictVsCongruentP), ...
    starText(stats.rtConflictVsCongruentP));

%% Candidate strategies
fprintf(fid, '7. CANDIDATE STRATEGIES\n');
fprintf(fid, '-----------------------\n');
S = stats.strategyTable;
if isempty(S)
    fprintf(fid, 'No strategy could be evaluated.\n\n');
else
    if any(S.NReal > 0)
        score = S.AccuracyReal;
        n = S.NReal;
        p = S.PExactVsChanceReal;
        source = 'real choices';
    else
        score = S.AccuracyAll;
        n = S.NAll;
        p = nan(height(S), 1);
        source = 'debug description';
    end
    scoreForSort = score;
    scoreForSort(~isfinite(scoreForSort)) = -Inf;
    [~, order] = sort(scoreForSort, 'descend');
    fprintf(fid, 'Ranking based on %s:\n', source);
    for rankIndex = 1:numel(order)
        i = order(rankIndex);
        if ~isfinite(score(i))
            continue;
        end
        fprintf(fid, '%2d. %-34s accuracy=%s, N=%d', rankIndex, ...
            char(S.Strategy(i)), numberText(score(i)), round(n(i)));
        if isfinite(p(i))
            fprintf(fid, ', exact p=%s, FDR q=%s %s', ...
                pText(p(i)), qText(S, i), starText(qValue(S, i)));
        end
        fprintf(fid, '\n');
        if S.IndistinguishableFrom(i) ~= "None"
            fprintf(fid, '    Identical predictions to: %s\n', ...
                char(S.IndistinguishableFrom(i)));
        end
    end
    fprintf(fid, ['\nAccuracy alone cannot identify a policy when two candidate ', ...
        'strategies make identical predictions under the current block ', ...
        'structure. Use multiple blocks with rich-target reversals.\n\n']);
end

%% Conditional associations
fprintf(fid, '8. CONDITIONAL ASSOCIATIONS\n');
fprintf(fid, '---------------------------\n');
A = stats.associationTable;
if isempty(A)
    fprintf(fid, 'No conditional association could be evaluated.\n\n');
else
    for i = 1:height(A)
        fprintf(fid, '%-28s -> %-18s | all delta=%s, OR=%s, N=%d', ...
            char(A.Predictor(i)), char(A.Response(i)), ...
            numberText(A.DifferenceAll(i)), numberText(A.OddsRatioAll(i)), ...
            round(A.NAll(i)));
        if A.NReal(i) > 0
            fprintf(fid, [' | real delta=%s, OR=%s, Fisher p=%s, ', ...
                'FDR q=%s %s, N=%d'], ...
                numberText(A.DifferenceReal(i)), ...
                numberText(A.OddsRatioReal(i)), ...
                pText(A.FisherPReal(i)), qText(A, i), ...
                starText(qValue(A, i)), round(A.NReal(i)));
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, ['\nDelta is P(response=1|predictor=1) minus ', ...
        'P(response=1|predictor=0). Odds ratios use a 0.5 ', ...
        'Haldane-Anscombe correction in each 2x2 cell.\n\n']);
end

%% Choice evolution
fprintf(fid, '9. EARLY VERSUS LATE CHOICE POLICY\n');
fprintf(fid, '----------------------------------\n');
E = stats.choiceEvolutionTable;
for i = 1:height(E)
    fprintf(fid, '%-30s | all %s -> %s, delta=%s', ...
        char(E.Metric(i)), numberText(E.EarlyAll(i)), ...
        numberText(E.LateAll(i)), numberText(E.LateMinusEarlyAll(i)));
    if E.NEarlyReal(i) > 0 && E.NLateReal(i) > 0
        fprintf(fid, [' | real %s -> %s, delta=%s, permutation p=%s, ', ...
            'FDR q=%s %s'], ...
            numberText(E.EarlyReal(i)), numberText(E.LateReal(i)), ...
            numberText(E.LateMinusEarlyReal(i)), ...
            pText(E.PermutationPReal(i)), qText(E, i), ...
            starText(qValue(E, i)));
    end
    fprintf(fid, '\n');
end
fprintf(fid, '\n');

%% Psychometric analysis
fprintf(fid, '10. SALIENCE PSYCHOMETRIC ANALYSIS\n');
fprintf(fid, '----------------------------------\n');
F = stats.psychometricFit;
if F.Converged
    fprintf(fid, 'Evidence variable        : %s\n', char(F.EvidenceType));
    fprintf(fid, 'N real choices           : %d\n', F.N);
    fprintf(fid, 'Slope per evidence SD    : %s (SE %s)\n', ...
        numberText(F.SlopePerSD), numberText(F.SlopeSE));
    fprintf(fid, 'Odds ratio per evidence SD: %s\n', ...
        numberText(F.OddsRatioPerSD));
    fprintf(fid, 'Wald p                   : %s\n', pText(F.WaldP));
    fprintf(fid, 'Likelihood-ratio p       : %s %s\n', ...
        pText(F.LikelihoodRatioP), starText(F.LikelihoodRatioP));
else
    fprintf(fid, 'Logistic fit not estimable: %s\n', char(F.Note));
end
fprintf(fid, ['The logistic regression uses unbinned choices. Binned ', ...
    'proportions and Wilson intervals are exported separately for ', ...
    'visualization.\n\n']);

%% Exploration and previous reward
fprintf(fid, '11. STAY/SWITCH AND PREVIOUS REWARD\n');
fprintf(fid, '-----------------------------------\n');
X = stats.exploration;
fprintf(fid, 'P(identity switch), all  : %s (N=%d)\n', ...
    numberText(X.pSwitchAll), X.nAll);
if X.nReal > 0
    fprintf(fid, ['P(identity switch), real : %s, 95%% CI [%s, %s], ', ...
        'exact p vs 0.5=%s\n'], ...
        numberText(X.pSwitchReal), numberText(X.ciLowReal), ...
        numberText(X.ciHighReal), pText(X.pExactVsChanceReal));
    fprintf(fid, ['Previous reward versus switch: r=%s, permutation p=%s ', ...
        '%s.\n'], numberText(X.rewardSwitchCorrelation), ...
        pText(X.rewardSwitchPermutationP), ...
        starText(X.rewardSwitchPermutationP));
end
fprintf(fid, '\n');

%% Engagement
fprintf(fid, '12. OPERATIONAL ENGAGEMENT\n');
fprintf(fid, '--------------------------\n');
G = stats.engagementTable;
for i = 1:height(G)
    fprintf(fid, ['%-34s early=%s, late=%s, delta=%s, permutation p=%s, ', ...
        'FDR q=%s %s\n'], ...
        char(G.Metric(i)), numberText(G.EarlyValue(i)), ...
        numberText(G.LateValue(i)), numberText(G.LateMinusEarly(i)), ...
        pText(G.PermutationP(i)), qText(G, i), ...
        starText(qValue(G, i)));
end
fprintf(fid, '\nChange-point tests corrected by permutation over candidate splits:\n');
fprintf(fid, '  Failures          : attempt %s, effect=%s, p=%s\n', ...
    numberText(stats.engagement.failureChangeAttempt), ...
    numberText(stats.engagement.failureChangeEffect), ...
    pText(stats.engagement.failureChangeP));
fprintf(fid, '  Pre-trial interval: attempt %s, log effect=%s, p=%s\n', ...
    numberText(stats.engagement.intervalChangeAttempt), ...
    numberText(stats.engagement.intervalChangeEffectLog), ...
    pText(stats.engagement.intervalChangeP));
fprintf(fid, '  Reaction time     : attempt %s, log effect=%s, p=%s\n', ...
    numberText(stats.engagement.rtChangeAttempt), ...
    numberText(stats.engagement.rtChangeEffectLog), ...
    pText(stats.engagement.rtChangeP));
fprintf(fid, '  Fixation latency  : attempt %s, log effect=%s, p=%s\n', ...
    numberText(stats.engagement.fixChangeAttempt), ...
    numberText(stats.engagement.fixChangeEffectLog), ...
    pText(stats.engagement.fixChangeP));
fprintf(fid, '\nOperational interpretation: %s\n', ...
    char(stats.engagement.evidence));
fprintf(fid, ['This is not a direct measure of boredom. It only detects ', ...
    'changes in observable task engagement.\n\n']);

%% Blocks
fprintf(fid, '13. BLOCK COMPLETION\n');
fprintf(fid, '--------------------\n');
B = stats.blockTable;
for i = 1:height(B)
    fprintf(fid, ['%s: rich target T%d, attempts=%d, successful trials=%d, ', ...
        'two-target choices=%d, expected=%s, completion=%s, missing=%s.\n'], ...
        char(B.BlockUID(i)), round(B.RichTarget(i)), round(B.Attempts(i)), ...
        round(B.GoodTrials(i)), round(B.GoodChoices(i)), ...
        numberText(B.ExpectedTrials(i)), numberText(B.CompletionFraction(i)), ...
        numberText(B.TrialsMissing(i)));
end
fprintf(fid, '\n');

%% Multivariable models
fprintf(fid, '14. MULTIVARIABLE LOGISTIC MODELS\n');
fprintf(fid, '---------------------------------\n');
M = stats.modelTable;
if isempty(M)
    fprintf(fid, 'No model output.\n');
else
    for i = 1:height(M)
        fprintf(fid, ['%-14s | %-20s beta=%s, SE=%s, OR=%s, p=%s, ', ...
            'FDR q=%s %s, N=%d, %s\n'], ...
            char(M.Model(i)), char(M.Term(i)), numberText(M.Estimate(i)), ...
            numberText(M.SE(i)), numberText(M.OddsRatio(i)), ...
            pText(M.PValue(i)), qText(M, i), ...
            starText(qValue(M, i)), round(M.N(i)), char(M.Note(i)));
    end
end
fprintf(fid, '\n');

%% Figure guide
fprintf(fid, '15. FIGURE GUIDE\n');
fprintf(fid, '----------------\n');
fprintf(fid, ['Figure 1 reconstructs the online plots and adds confidence ', ...
    'intervals, exact choice tests, direct condition comparisons, RT ', ...
    'statistics, and the previous-reward stay/switch analysis.\n']);
fprintf(fid, ['Figure 2 distinguishes spatial, identity, reward, salience, ', ...
    'and perseverative strategies using candidate accuracy, trial-by-trial ', ...
    'sequences, conditional choice probabilities, block summaries, and ', ...
    'spatial entropy.\n']);
fprintf(fid, ['Figure 3 describes operational engagement and technical ', ...
    'quality. Red lines are shown only when the predefined operational ', ...
    'criterion retains a candidate disengagement point.\n']);
fprintf(fid, ['Figure 4 contains the psychometric fit, early-late policy ', ...
    'changes, conditional effect sizes, and temporal trends.\n']);
fprintf(fid, ['Figure 5 provides a compact inferential summary, including ', ...
    'core biases, conflict-congruent comparisons, multivariable models, ', ...
    'and numerical engagement statistics.\n\n']);

fprintf(fid, 'INTERPRETATION CAUTION\n');
fprintf(fid, '----------------------\n');
fprintf(fid, ['These analyses are exploratory. A confirmatory conclusion ', ...
    'should be based on a prespecified hypothesis, adequate counterbalancing, ', ...
    'replication across sessions, and an analysis plan that accounts for ', ...
    'repeated observations within the same animal.\n']);
end

%% Helper functions

function printMetricTable(fid, T, valueField, unitField)
for i = 1:height(T)
    fprintf(fid, '%-38s: %s %s\n', char(T.Metric(i)), ...
        numberText(T.(valueField)(i)), char(T.(unitField)(i)));
end
end

function value = qValue(T, row)
if any(strcmp(T.Properties.VariableNames, 'QFDR'))
    value = T.QFDR(row);
else
    value = NaN;
end
end

function textValue = qText(T, row)
textValue = pText(qValue(T, row));
end

function textValue = starText(value)
if ~isfinite(value)
    textValue = 'n/a';
elseif value < 0.001
    textValue = '***';
elseif value < 0.01
    textValue = '**';
elseif value < 0.05
    textValue = '*';
else
    textValue = 'ns';
end
end

function textValue = pText(value)
if ~isfinite(value)
    textValue = 'n/a';
elseif value < 0.001
    textValue = '<0.001';
else
    textValue = sprintf('%.4f', value);
end
end

function textValue = numberText(value)
if ~isfinite(value)
    textValue = 'n/a';
elseif abs(value) >= 1000
    textValue = sprintf('%.0f', value);
elseif abs(value) >= 100
    textValue = sprintf('%.1f', value);
else
    textValue = sprintf('%.4f', value);
end
end
