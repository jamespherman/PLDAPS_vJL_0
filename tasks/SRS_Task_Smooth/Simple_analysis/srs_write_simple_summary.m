function summaryFile = srs_write_simple_summary(T, stats, meta, resultFolder)
%SRS_WRITE_SIMPLE_SUMMARY Write a concise recap of the seven simple plots.

if ~isfolder(resultFolder)
    mkdir(resultFolder);
end
summaryFile = fullfile(resultFolder, 'simple_analysis_summary.txt');
fid = fopen(summaryFile, 'w');
if fid < 0
    error('Could not create summary file: %s', summaryFile);
end
cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'SRS TASK SMOOTH - SIMPLE BEHAVIORAL ANALYSIS\n');
fprintf(fid, '============================================\n\n');
fprintf(fid, 'Session          : %s\n', char(meta.sessionID));
fprintf(fid, 'Source folder    : %s\n', char(meta.sessionFolder));
fprintf(fid, 'Analyzed blocks  : %s\n', mat2str(meta.analyzedBlocks));
fprintf(fid, 'Generated        : %s\n\n', datestr(now));

fprintf(fid, 'INFERENCE RULES\n');
fprintf(fid, '---------------\n');
fprintf(fid, ['Behavioral inference uses only real eye-controlled successful ', ...
    'two-target choices (passEye=0 and mouseEyeSim=0).\n']);
fprintf(fid, 'Single-target instruction trials are excluded from choice analyses.\n');
fprintf(fid, ['ns: p/q >= 0.05; *: <0.05; **: <0.01; ***: <0.001. ', ...
    'Related exploratory tests use Benjamini-Hochberg FDR correction.\n\n']);

fprintf(fid, '1. DATA RECAP\n');
fprintf(fid, '-------------\n');
fprintf(fid, 'Saved attempts                  : %d\n', height(T));
fprintf(fid, 'Successful trials               : %d\n', sum(T.GoodTrial));
fprintf(fid, 'Successful single-target trials : %d\n', ...
    sum(T.GoodTrial & T.IsInstruction));
fprintf(fid, 'Successful two-target choices   : %d\n', sum(T.GoodChoice));
fprintf(fid, 'Real eye-controlled choices     : %d\n', sum(T.RealEyeChoice));
fprintf(fid, 'Valid reaction times            : %d\n', ...
    sum(T.RealEyeChoice & isfinite(T.ReactionTimeMs)));
fprintf(fid, 'Identity-side mapping errors    : %d\n', ...
    sum(T.GoodChoice & ~T.ChoiceMappingValid));
fprintf(fid, 'Missed frames                   : %.0f\n\n', ...
    sum(T.MissedFrames, 'omitnan'));

fprintf(fid, '2. CHOICE BY TASK CONDITION\n');
fprintf(fid, '---------------------------\n');
S = stats.onlineChoiceTable;
for i = 1:min(4, height(S))
    fprintf(fid, '%-31s : %d/%d = %s, 95%% CI [%s, %s], q=%s %s\n', ...
        char(S.Metric(i)), round(S.CountReal(i)), round(S.NReal(i)), ...
        numberText(S.ProportionReal(i)), numberText(S.CI95LowReal(i)), ...
        numberText(S.CI95HighReal(i)), qText(S, i), ...
        starText(qValue(S, i)));
end
fprintf(fid, '\n');

fprintf(fid, '3. CONFLICT VERSUS CONGRUENT\n');
fprintf(fid, '----------------------------\n');
C = stats.onlineConditionComparisonTable;
if isempty(C)
    fprintf(fid, 'Not estimable.\n\n');
else
    for i = 1:height(C)
        fprintf(fid, ['%-28s | conflict %d/%d=%s; congruent %d/%d=%s; ', ...
            'delta=%s; Fisher p=%s; q=%s %s\n'], ...
            char(C.Outcome(i)), round(C.CountConflict(i)), ...
            round(C.NConflict(i)), numberText(C.PConflict(i)), ...
            round(C.CountCongruent(i)), round(C.NCongruent(i)), ...
            numberText(C.PCongruent(i)), numberText(C.Difference(i)), ...
            pText(C.FisherP(i)), qText(C, i), starText(qValue(C, i)));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '4. CANDIDATE STRATEGIES\n');
fprintf(fid, '-----------------------\n');
R = stats.strategyTable;
if isempty(R)
    fprintf(fid, 'Not estimable.\n\n');
else
    score = R.AccuracyReal;
    score(~isfinite(score)) = -Inf;
    [~, order] = sort(score, 'descend');
    nToPrint = min(8, numel(order));
    for rankIndex = 1:nToPrint
        i = order(rankIndex);
        if ~isfinite(R.AccuracyReal(i))
            continue;
        end
        fprintf(fid, '%2d. %-32s accuracy=%s, N=%d, q=%s %s', ...
            rankIndex, char(R.Strategy(i)), ...
            numberText(R.AccuracyReal(i)), round(R.NReal(i)), ...
            qText(R, i), starText(qValue(R, i)));
        if R.IndistinguishableFrom(i) ~= "None"
            fprintf(fid, ' | identical predictions: %s', ...
                char(R.IndistinguishableFrom(i)));
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, ['Accuracy cannot identify a unique policy when multiple ', ...
        'strategies make the same predictions under the analyzed block design.\n\n']);
end

fprintf(fid, '5. CONDITIONAL ASSOCIATIONS\n');
fprintf(fid, '---------------------------\n');
A = stats.associationTable;
if isempty(A)
    fprintf(fid, 'Not estimable.\n\n');
else
    for i = 1:height(A)
        fprintf(fid, ['%-29s -> %-17s | delta=%s; OR=%s; N=%d; ', ...
            'Fisher p=%s; q=%s %s\n'], ...
            char(A.Predictor(i)), char(A.Response(i)), ...
            numberText(A.DifferenceReal(i)), ...
            numberText(A.OddsRatioReal(i)), round(A.NReal(i)), ...
            pText(A.FisherPReal(i)), qText(A, i), ...
            starText(qValue(A, i)));
    end
    fprintf(fid, ['Delta is P(response=1|predictor=1) minus ', ...
        'P(response=1|predictor=0).\n\n']);
end

fprintf(fid, '6. PREVIOUS REWARD AND IDENTITY SWITCHING\n');
fprintf(fid, '-----------------------------------------\n');
X = stats.exploration;
fprintf(fid, 'P(identity switch)          : %s, N=%d\n', ...
    numberText(X.pSwitchReal), X.nReal);
fprintf(fid, 'Previous reward vs switch   : r=%s, permutation p=%s %s\n\n', ...
    numberText(X.rewardSwitchCorrelation), ...
    pText(X.rewardSwitchPermutationP), ...
    starText(X.rewardSwitchPermutationP));

fprintf(fid, '7. REACTION TIME\n');
fprintf(fid, '----------------\n');
RT = stats.rtTable;
for i = 1:height(RT)
    fprintf(fid, '%-16s : N=%d, median=%s ms, IQR=%s ms\n', ...
        char(RT.Condition(i)), round(RT.NReal(i)), ...
        numberText(RT.MedianRealMs(i)), numberText(RT.IQRRealMs(i)));
end
fprintf(fid, ['Conflict minus congruent median = %s ms; ', ...
    'permutation p=%s %s\n\n'], ...
    numberText(stats.rtConflictMinusCongruentMs), ...
    pText(stats.rtConflictVsCongruentP), ...
    starText(stats.rtConflictVsCongruentP));

fprintf(fid, '8. COMPACT INTERPRETATION\n');
fprintf(fid, '-------------------------\n');
printCoreMetric(fid, stats.biasTable, 'Choose rich target');
printCoreMetric(fid, stats.biasTable, 'Choose high-salience target');
printCoreMetric(fid, stats.biasTable, 'Choose right');
printCoreMetric(fid, stats.biasTable, 'Repeat side');

if ~isempty(R)
    valid = R.NReal > 0 & isfinite(R.AccuracyReal);
    if any(valid)
        validRows = find(valid);
        [bestAccuracy, localIndex] = max(R.AccuracyReal(validRows));
        bestRow = validRows(localIndex);
        fprintf(fid, 'Highest candidate accuracy : %s (%s, q=%s %s).\n', ...
            char(R.Strategy(bestRow)), numberText(bestAccuracy), ...
            qText(R, bestRow), starText(qValue(R, bestRow)));
    end
end

significantCondition = false;
if ~isempty(C)
    for i = 1:height(C)
        if isfinite(qValue(C, i)) && qValue(C, i) < 0.05
            significantCondition = true;
            fprintf(fid, ['Conflict/congruent difference: %s is significant ', ...
                '(delta=%s, q=%s %s).\n'], char(C.Outcome(i)), ...
                numberText(C.Difference(i)), qText(C, i), ...
                starText(qValue(C, i)));
        end
    end
end
if ~significantCondition
    fprintf(fid, 'No conflict/congruent choice comparison survives FDR correction.\n');
end

if isfinite(X.rewardSwitchPermutationP) && ...
        X.rewardSwitchPermutationP < 0.05
    fprintf(fid, ['Previous reward predicts identity switching ', ...
        '(r=%s, p=%s).\n'], numberText(X.rewardSwitchCorrelation), ...
        pText(X.rewardSwitchPermutationP));
else
    fprintf(fid, ['No detectable previous-reward effect on identity ', ...
        'switching (r=%s, p=%s).\n'], ...
        numberText(X.rewardSwitchCorrelation), ...
        pText(X.rewardSwitchPermutationP));
end

if isfinite(stats.rtConflictVsCongruentP) && ...
        stats.rtConflictVsCongruentP < 0.05
    fprintf(fid, ['Conflict and congruent reaction-time medians differ ', ...
        '(conflict-congruent=%s ms, p=%s).\n'], ...
        numberText(stats.rtConflictMinusCongruentMs), ...
        pText(stats.rtConflictVsCongruentP));
else
    fprintf(fid, ['No detectable conflict-related reaction-time cost ', ...
        '(conflict-congruent=%s ms, p=%s).\n'], ...
        numberText(stats.rtConflictMinusCongruentMs), ...
        pText(stats.rtConflictVsCongruentP));
end

fprintf(fid, ['\nInterpretation constraint: these are exploratory within-session ', ...
    'analyses. Repeated trials are not independent subjects, and candidate ', ...
    'strategies can remain confounded when block reversals or side ', ...
    'counterbalancing are insufficient.\n']);
end

function printCoreMetric(fid, B, metricName)
row = find(B.Metric == string(metricName), 1, 'first');
if isempty(row)
    return;
end
fprintf(fid, '%-27s: %d/%d=%s, 95%% CI [%s, %s], q=%s %s.\n', ...
    metricName, round(B.CountReal(row)), round(B.NReal(row)), ...
    numberText(B.ProportionReal(row)), numberText(B.CI95LowReal(row)), ...
    numberText(B.CI95HighReal(row)), qText(B, row), ...
    starText(qValue(B, row)));
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
elseif abs(value) >= 100
    textValue = sprintf('%.1f', value);
else
    textValue = sprintf('%.3f', value);
end
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
