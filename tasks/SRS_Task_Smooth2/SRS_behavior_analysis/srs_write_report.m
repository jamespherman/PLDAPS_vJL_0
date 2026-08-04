function reportFile = srs_write_report(T, stats, meta, outputFolder)
%SRS_WRITE_REPORT Ecrire un rapport texte lisible sans ouvrir MATLAB tables.
%
% Le rapport distingue volontairement description et inference. Une session
% passEye peut produire des choix parfaitement structures, mais ces choix sont
% generes par le code et ne renseignent pas sur la strategie de l'animal.

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

reportFile = fullfile(outputFolder, 'analysis_report.txt');
fid = fopen(reportFile, 'w');
if fid < 0
    error('Impossible de creer le rapport : %s', reportFile);
end
cleanupObject = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, 'ANALYSE COMPORTEMENTALE SRS_TASK_SMOOTH\n');
fprintf(fid, '=======================================\n\n');
fprintf(fid, 'Session / ensemble : %s\n', meta.sessionID);
if isfield(meta, 'sessionFolder')
    fprintf(fid, 'Dossier source      : %s\n', meta.sessionFolder);
end
if isfield(meta, 'blockRangeRequested') && ...
        ~isempty(meta.blockRangeRequested)
    fprintf(fid, 'Plage de blocs      : %g a %g\n', ...
        meta.blockRangeRequested(1), meta.blockRangeRequested(2));
end
fprintf(fid, 'Date de generation  : %s\n\n', datestr(now));

%% Validite
fprintf(fid, '1. VALIDITE DES DONNEES\n');
fprintf(fid, '-----------------------\n');
if isfield(meta, 'warnings') && ~isempty(meta.warnings)
    for iWarning = 1:numel(meta.warnings)
        fprintf(fid, 'ATTENTION : %s\n', char(meta.warnings(iWarning)));
    end
else
    fprintf(fid, 'Aucun mode de simulation/contournement detecte.\n');
end

fprintf(fid, '\nChoix a deux cibles enregistres : %d\n', sum(T.GoodChoice));
fprintf(fid, 'Choix eligibles pour inference : %d\n', sum(T.RealEyeChoice));
fprintf(fid, 'Fraction passEye               : %.3f\n', ...
    mean(double(T.PassEye ~= 0)));
fprintf(fid, 'Fraction passJoy               : %.3f\n', ...
    mean(double(T.PassJoy ~= 0)));
fprintf(fid, 'RT valides                     : %d\n', ...
    sum(isfinite(T.ReactionTimeMs)));
fprintf(fid, 'Latences fixation valides      : %d\n\n', ...
    sum(isfinite(T.FixAcquisitionLatencyMs)));

%% Resume
fprintf(fid, '2. RESUME DE SESSION\n');
fprintf(fid, '--------------------\n');
for iRow = 1:height(stats.summaryTable)
    fprintf(fid, '%-36s : %s %s\n', ...
        char(stats.summaryTable.Metric(iRow)), ...
        numberText(stats.summaryTable.Value(iRow)), ...
        char(stats.summaryTable.Unit(iRow)));
end
fprintf(fid, '\n');

%% Blocs et arret
fprintf(fid, '3. BLOCS ET POINT D''ARRET\n');
fprintf(fid, '-------------------------\n');
for iBlock = 1:height(stats.blockTable)
    B = stats.blockTable(iBlock, :);
    fprintf(fid, ['%s : T%d riche, %d tentatives, %d essais reussis, ', ...
        '%d choix, attendu=%s, completion=%s, manquants=%s.\n'], ...
        char(B.BlockUID), round(B.RichTarget), round(B.Attempts), ...
        round(B.GoodTrials), round(B.GoodChoices), ...
        numberText(B.ExpectedTrials), numberText(B.CompletionFraction), ...
        numberText(B.TrialsMissing));
end
fprintf(fid, ['\nUn bloc incomplet indique ou la session s''est arretee, mais ne ', ...
    'prouve pas que l''animal s''ennuyait. L''ennui est un etat subjectif; ', ...
    'les analyses ci-dessous recherchent seulement des signes operationnels ', ...
    'de desengagement.\n\n']);

%% Contrebalancement
fprintf(fid, '4. CONTREBALANCEMENT DU PLAN\n');
fprintf(fid, '----------------------------\n');
for iRow = 1:height(stats.balanceTable)
    R = stats.balanceTable(iRow, :);
    fprintf(fid, '%-34s : %d/%d = %s, p exact vs 0.5 = %s\n', ...
        char(R.Metric), round(R.Count), round(R.N), ...
        numberText(R.Proportion), pText(R.PExactVsHalf));
end
fprintf(fid, '\n');

%% Biais
fprintf(fid, '5. BIAIS SPATIAL, IDENTITAIRE, REWARD ET SAILLANCE\n');
fprintf(fid, '--------------------------------------------------\n');
for iRow = 1:height(stats.biasTable)
    R = stats.biasTable(iRow, :);
    fprintf(fid, '%-31s | tout: %d/%d = %s', ...
        char(R.Metric), round(R.CountAll), round(R.NAll), ...
        numberText(R.ProportionAll));
    if R.NReal > 0
        fprintf(fid, [' | reel: %d/%d = %s, IC95 [%s, %s], ', ...
            'p exact = %s'], ...
            round(R.CountReal), round(R.NReal), ...
            numberText(R.ProportionReal), ...
            numberText(R.CI95LowReal), ...
            numberText(R.CI95HighReal), ...
            pText(R.PExactVsHalfReal));
    else
        fprintf(fid, ' | reel: non estimable');
    end
    fprintf(fid, '\n');
end

fprintf(fid, '\nIndice descriptif de biais (0=aucun, 1=absolu) :\n');
fprintf(fid, '  Spatial droite/gauche : %s\n', ...
    numberText(stats.interpretation.spatialBiasMagnitude));
fprintf(fid, '  Identitaire T1/T2     : %s\n', ...
    numberText(stats.interpretation.identityBiasMagnitude));
fprintf(fid, '  Cible riche/pauvre    : %s\n', ...
    numberText(stats.interpretation.rewardBiasMagnitude));
fprintf(fid, '  Haute/faible saillance: %s\n\n', ...
    numberText(stats.interpretation.salienceBiasMagnitude));

%% Strategies
fprintf(fid, '6. STRATEGIES CANDIDATES\n');
fprintf(fid, '------------------------\n');
if isempty(stats.strategyTable)
    fprintf(fid, 'Aucune strategie calculable.\n\n');
else
    strategyTable = stats.strategyTable;
    if any(strategyTable.NReal > 0)
        sortValues = strategyTable.AccuracyReal;
        dataLabel = 'reel';
    else
        sortValues = strategyTable.AccuracyAll;
        dataLabel = 'descriptif debug';
    end
    sortValues(~isfinite(sortValues)) = -Inf;
    [~, order] = sort(sortValues, 'descend');

    fprintf(fid, 'Classement (%s) :\n', dataLabel);
    for iRank = 1:min(12, numel(order))
        R = strategyTable(order(iRank), :);
        if strcmp(dataLabel, 'reel')
            accuracy = R.AccuracyReal;
            nValue = R.NReal;
            pValue = R.PExactVsChanceReal;
        else
            accuracy = R.AccuracyAll;
            nValue = R.NAll;
            pValue = NaN;
        end
        fprintf(fid, '  %2d. %-37s accuracy=%s, N=%d', ...
            iRank, char(R.Strategy), numberText(accuracy), round(nValue));
        if isfinite(pValue)
            fprintf(fid, ', p=%s', pText(pValue));
        end
        fprintf(fid, '\n');
        if R.IndistinguishableFrom ~= "Aucune"
            fprintf(fid, '      Meme prediction que : %s\n', ...
                char(R.IndistinguishableFrom));
        end
    end

    fprintf(fid, '\nMeilleure strategie descriptive : %s, accuracy=%s.\n', ...
        char(stats.interpretation.bestStrategyAll), ...
        numberText(stats.interpretation.bestStrategyAccuracyAll));
    fprintf(fid, 'Strategies confondues avec elle : %s.\n\n', ...
        char(stats.interpretation.bestStrategyConfounds));
end

%% Associations conditionnelles
fprintf(fid, '7. ASSOCIATIONS CONDITIONNELLES\n');
fprintf(fid, '--------------------------------\n');
if isempty(stats.associationTable)
    fprintf(fid, 'Aucune association calculable.\n\n');
else
    for iRow = 1:height(stats.associationTable)
        R = stats.associationTable(iRow, :);
        fprintf(fid, '%-27s <- %-32s | tout: delta=%s, ORcorr=%s, N=%d', ...
            char(R.Response), char(R.Predictor), ...
            numberText(R.DifferenceAll), numberText(R.OddsRatioAll), ...
            round(R.NAll));
        if R.NReal > 0
            fprintf(fid, ' | reel: delta=%s, ORcorr=%s, Fisher p=%s, N=%d', ...
                numberText(R.DifferenceReal), ...
                numberText(R.OddsRatioReal), ...
                pText(R.FisherPReal), round(R.NReal));
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, ['\nLe delta est P(reponse=1|predicteur=1) moins ', ...
        'P(reponse=1|predicteur=0). ORcorr utilise une correction de ', ...
        'Haldane-Anscombe de 0.5 par cellule.\n\n']);
end

%% Evolution et psychometrie
fprintf(fid, '8. EVOLUTION DE LA STRATEGIE ET PSYCHOMETRIE\n');
fprintf(fid, '---------------------------------------------\n');
if ~isempty(stats.choiceEvolutionTable)
    fprintf(fid, 'Premier tiers versus dernier tiers des choix :\n');
    for iRow = 1:height(stats.choiceEvolutionTable)
        R = stats.choiceEvolutionTable(iRow, :);
        fprintf(fid, '  %-29s | tout: %s -> %s, delta=%s', ...
            char(R.Metric), numberText(R.EarlyAll), ...
            numberText(R.LateAll), numberText(R.LateMinusEarlyAll));
        if R.NEarlyReal > 0 && R.NLateReal > 0
            fprintf(fid, ' | reel: %s -> %s, delta=%s, p=%s', ...
                numberText(R.EarlyReal), numberText(R.LateReal), ...
                numberText(R.LateMinusEarlyReal), ...
                pText(R.PermutationPReal));
        end
        fprintf(fid, '\n');
    end
end

if isempty(stats.psychometricTable)
    fprintf(fid, '\nAucune psychometrie continue calculable.\n\n');
else
    P = stats.psychometricTable;
    fprintf(fid, '\nPsychometrie : %s, %d bins.\n', ...
        char(P.EvidenceType(1)), height(P));
    for iRow = 1:height(P)
        fprintf(fid, '  bin %d, evidence=%s, P(T1) tout=%s (N=%d)', ...
            round(P.Bin(iRow)), numberText(P.EvidenceMean(iRow)), ...
            numberText(P.PChooseT1All(iRow)), round(P.NAll(iRow)));
        if P.NReal(iRow) > 0
            fprintf(fid, ', P(T1) reel=%s (N=%d)', ...
                numberText(P.PChooseT1Real(iRow)), round(P.NReal(iRow)));
        end
        fprintf(fid, '\n');
    end
    fprintf(fid, '\n');
end

%% Online plots
fprintf(fid, '9. STATISTIQUES DES ONLINE PLOTS\n');
fprintf(fid, '--------------------------------\n');
for iRow = 1:height(stats.onlineChoiceTable)
    R = stats.onlineChoiceTable(iRow, :);
    fprintf(fid, '%-38s : tout=%s (N=%d)', ...
        char(R.Metric), numberText(R.ProportionAll), round(R.NAll));
    if R.NReal > 0
        fprintf(fid, ', reel=%s, IC95 [%s, %s], p=%s', ...
            numberText(R.ProportionReal), ...
            numberText(R.CI95LowReal), ...
            numberText(R.CI95HighReal), ...
            pText(R.PExactVsHalfReal));
    end
    fprintf(fid, '\n');
end

fprintf(fid, '\nTemps de reaction :\n');
for iRow = 1:height(stats.rtTable)
    R = stats.rtTable(iRow, :);
    fprintf(fid, '  %-12s : median tout=%s ms (N=%d), reel=%s ms (N=%d)\n', ...
        char(R.Condition), numberText(R.MedianAllMs), round(R.NAll), ...
        numberText(R.MedianRealMs), round(R.NReal));
end
fprintf(fid, '  Difference conflit - congruent = %s ms, p permutation = %s\n', ...
    numberText(stats.rtConflictMinusCongruentMs), ...
    pText(stats.rtConflictVsCongruentP));

fprintf(fid, '\nExploration / changement d''identite :\n');
fprintf(fid, '  P(switch) tout = %s (N=%d)\n', ...
    numberText(stats.exploration.pSwitchAll), stats.exploration.nAll);
fprintf(fid, '  P(switch) reel = %s (N=%d), p exact=%s\n', ...
    numberText(stats.exploration.pSwitchReal), ...
    stats.exploration.nReal, ...
    pText(stats.exploration.pExactVsChanceReal));
fprintf(fid, '  Correlation reward precedente / switch = %s, p permutation=%s\n\n', ...
    numberText(stats.exploration.rewardSwitchCorrelation), ...
    pText(stats.exploration.rewardSwitchPermutationP));

fprintf(fid, 'Series temporelles et tendances avec la tentative :\n');
for iRow = 1:height(stats.timeSeriesTable)
    R = stats.timeSeriesTable(iRow, :);
    fprintf(fid, '  %-43s : mediane=%s, IQR=%s, r=%s, pperm=%s, N=%d\n', ...
        char(R.Metric), numberText(R.Median), numberText(R.IQR), ...
        numberText(R.CorrelationWithAttempt), ...
        pText(R.PermutationP), round(R.N));
end
fprintf(fid, '\n');

%% Engagement
fprintf(fid, '10. ENGAGEMENT ET CHANGEMENT TARDIF\n');
fprintf(fid, '-----------------------------------\n');
for iRow = 1:height(stats.engagementTable)
    R = stats.engagementTable(iRow, :);
    fprintf(fid, '%-34s : debut=%s, fin=%s, delta=%s, p=%s\n', ...
        char(R.Metric), numberText(R.EarlyValue), ...
        numberText(R.LateValue), numberText(R.LateMinusEarly), ...
        pText(R.PermutationP));
end
fprintf(fid, '\nPoint de changement des echecs     : %s, p=%s\n', ...
    numberText(stats.engagement.failureChangeAttempt), ...
    pText(stats.engagement.failureChangeP));
fprintf(fid, 'Point de changement des intervalles: %s, p=%s\n', ...
    numberText(stats.engagement.intervalChangeAttempt), ...
    pText(stats.engagement.intervalChangeP));
fprintf(fid, 'Point de changement des RT          : %s, p=%s\n', ...
    numberText(stats.engagement.rtChangeAttempt), ...
    pText(stats.engagement.rtChangeP));
fprintf(fid, 'Point de changement fixation        : %s, p=%s\n', ...
    numberText(stats.engagement.fixChangeAttempt), ...
    pText(stats.engagement.fixChangeP));
fprintf(fid, 'Estimation conservatrice retenue    : %s\n', ...
    numberText(stats.engagement.estimatedDisengagementAttempt));
fprintf(fid, 'Interpretation                      : %s\n\n', ...
    char(stats.engagement.evidence));

%% Modeles
fprintf(fid, '11. MODELES LOGISTIQUES MULTIVARIES\n');
fprintf(fid, '----------------------------------\n');
for iRow = 1:height(stats.modelTable)
    R = stats.modelTable(iRow, :);
    fprintf(fid, '%-14s | %-22s | beta=%s | OR=%s | p=%s | N=%d | %s\n', ...
        char(R.Model), char(R.Term), numberText(R.Estimate), ...
        numberText(R.OddsRatio), pText(R.PValue), round(R.N), ...
        char(R.Note));
end

%% Methodes et prudence
fprintf(fid, '\n12. METHODES ET LIMITES\n');
fprintf(fid, '-----------------------\n');
fprintf(fid, ['- Les biais binaires sont testes contre 0.5 avec un test ', ...
    'binomial exact bilateral et un intervalle de Wilson a 95 %%.\n']);
fprintf(fid, ['- Les associations binaires conditionnelles utilisent un ', ...
    'test exact bilateral de Fisher et un odds ratio corrige de 0.5.\n']);
fprintf(fid, ['- Les differences de RT et d''engagement sont testees par ', ...
    'permutation, sans hypothese de normalite.\n']);
fprintf(fid, ['- La detection de desengagement recherche une augmentation ', ...
    'des echecs, des intervalles, des RT ou de la latence de fixation. ', ...
    'Elle ne mesure pas directement l''ennui.\n']);
fprintf(fid, ['- Les p-values sont exploratoires et ne sont pas corrigees ', ...
    'pour l ensemble des comparaisons. Une conclusion confirmatoire ', ...
    'demande une hypothese definie a l avance ou une correction adaptee.\n']);
fprintf(fid, ['- Les recompenses trial-by-trial sont tirees avec du bruit. ', ...
    'L''animal ne connait pas la valeur tiree avant son choix; la variable ', ...
    'causale pertinente est surtout l''identite riche apprise dans le bloc.\n']);
fprintf(fid, ['- Pour dissocier cible riche et preference T1/T2, il faut ', ...
    'plusieurs blocs avec alternance de l''identite riche.\n']);
if strlength(stats.interpretation.mainCaveat) > 0
    fprintf(fid, '- LIMITATION PRINCIPALE : %s\n', ...
        char(stats.interpretation.mainCaveat));
end

end

%% Utilitaires de mise en forme

function textValue = numberText(value)
if ~isfinite(value)
    textValue = 'NA';
elseif abs(value) >= 1000
    textValue = sprintf('%.1f', value);
elseif abs(value) >= 10
    textValue = sprintf('%.3f', value);
else
    textValue = sprintf('%.4f', value);
end
end

function textValue = pText(value)
if ~isfinite(value)
    textValue = 'NA';
elseif value < 1e-4
    textValue = sprintf('%.2e', value);
else
    textValue = sprintf('%.4f', value);
end
end
