function stats = srs_compute_statistics(T, meta, options)
%SRS_COMPUTE_STATISTICS Calculer les analyses comportementales SRS.
%
% Les analyses sont separees en deux niveaux :
%   1. Descriptif de tout ce qui a ete enregistre, y compris les essais en
%      mode debug passEye.
%   2. Inference comportementale sur les essais RealEyeChoice uniquement.
%
% Les tests de base (binomial exact, intervalles de Wilson, permutations)
% sont implementes ici et ne demandent pas la Statistics Toolbox. Une
% regression logistique plus avancee est ajoutee uniquement si fitglm est
% disponible.

if nargin < 3
    options = struct();
end
options = fillDefaultOptions(options);

rng(options.randomSeed, 'twister');

stats = struct();
stats.options = options;
stats.meta = meta;

%% Masques principaux
allGoodChoice = T.GoodChoice;
realGoodChoice = T.RealEyeChoice;
allGood = T.GoodTrial;

%% Resume general
summaryRows = repmat(emptySummaryRow(), 0, 1);
summaryRows(end + 1) = summaryRow('Tentatives enregistrees', ...
    height(T), 'essais', 'Un fichier trialXXXX.mat par tentative.');
summaryRows(end + 1) = summaryRow('Essais termines avec succes', ...
    sum(T.GoodTrial), 'essais', 'trialEndState = 455 / GoodTrial = 1.');
summaryRows(end + 1) = summaryRow('Taux de completion', ...
    safeMean(double(T.GoodTrial)), 'proportion', 'Succes / tentatives.');
summaryRows(end + 1) = summaryRow('Essais instruction reussis', ...
    sum(T.GoodTrial & T.IsInstruction), 'essais', 'Essais a une cible.');
summaryRows(end + 1) = summaryRow('Choix a deux cibles reussis', ...
    sum(allGoodChoice), 'essais', 'Tous modes confondus.');
summaryRows(end + 1) = summaryRow('Choix avec controle oculaire reel', ...
    sum(realGoodChoice), 'essais', 'passEye=0 et mouseEyeSim=0.');
summaryRows(end + 1) = summaryRow('Fraction passEye', ...
    safeMean(double(T.PassEye ~= 0)), 'proportion', ...
    'passEye force un choix dans cette tache.');
summaryRows(end + 1) = summaryRow('Fraction passJoy', ...
    safeMean(double(T.PassJoy ~= 0)), 'proportion', ...
    'Contournement du joystick.');
summaryRows(end + 1) = summaryRow('RT valides', ...
    sum(isfinite(T.ReactionTimeMs)), 'essais', ...
    'saccadeOnset strictement apres fixOff.');
summaryRows(end + 1) = summaryRow('Latences de fixation valides', ...
    sum(isfinite(T.FixAcquisitionLatencyMs)), 'essais', ...
    'fixAq strictement apres fixOn.');
summaryRows(end + 1) = summaryRow('Duree de session', ...
    meta.sessionDurationMin, 'minutes', 'Estimee avec les timestamps PTB.');
summaryRows(end + 1) = summaryRow('Frames manquees', ...
    sum(T.MissedFrames, 'omitnan'), 'frames', 'Somme sur les tentatives.');
summaryRows(end + 1) = summaryRow('Erreurs mapping identite/cote', ...
    sum(T.GoodChoice & ~T.ChoiceMappingValid), 'essais', ...
    'Le cote choisi ne correspond pas au cote de la cible choisie.');
stats.summaryTable = struct2table(summaryRows);

%% Qualite du plan experimental et contrebalancement
balanceRows = repmat(emptyProbabilityRow(), 0, 1);
completedChoices = T.GoodTrial & T.IsChoice;
completedInstructions = T.GoodTrial & T.IsInstruction;

balanceRows(end + 1) = probabilityRow( ...
    'T1 presentee a droite', T.T1Side == 1, completedChoices, ...
    completedChoices, 'Contrebalancement spatial des identites.');
balanceRows(end + 1) = probabilityRow( ...
    'Cible riche a droite', T.RichSide == 1, completedChoices, ...
    completedChoices, 'La valeur doit etre independante du cote.');
balanceRows(end + 1) = probabilityRow( ...
    'Cible tres saillante a droite', T.HighSalienceSide == 1, ...
    completedChoices, completedChoices, ...
    'La saillance doit etre independante du cote.');
balanceRows(end + 1) = probabilityRow( ...
    'Essai congruent', T.IsCongruent, completedChoices, ...
    completedChoices, 'Equilibre congruent/conflit.');
balanceRows(end + 1) = probabilityRow( ...
    'Instruction T1', T.SingleTargetID == 1, completedInstructions, ...
    completedInstructions, 'Equilibre des deux identites en instruction.');
stats.balanceTable = struct2table(balanceRows);

%% Biais et dependances sequentielles
% Les colonnes NAll/ProportionAll decrivent tous les fichiers. Les p-values
% et intervalles inferentiels utilisent uniquement les choix RealEyeChoice.
biasRows = repmat(emptyBiasRow(), 0, 1);

biasRows(end + 1) = biasRow('Spatial', 'Choisit droite', ...
    T.ChoseRight, allGoodChoice, realGoodChoice, ...
    'Biais absolu droite/gauche.');
biasRows(end + 1) = biasRow('Identite', 'Choisit T1', ...
    T.ChoseT1, allGoodChoice, realGoodChoice, ...
    'Biais absolu T1/T2.');
biasRows(end + 1) = biasRow('Valeur', 'Choisit la cible riche', ...
    T.ChoseRich, allGoodChoice, realGoodChoice, ...
    'Strategie basee sur la valeur moyenne du bloc.');
biasRows(end + 1) = biasRow('Saillance', 'Choisit la cible tres saillante', ...
    T.ChoseHighSalience, allGoodChoice, realGoodChoice, ...
    'Strategie guidee par la saillance.');

allTransitionTarget = allGoodChoice & isfinite(T.StayedTarget);
realTransitionTarget = realGoodChoice & isfinite(T.StayedTarget);
allTransitionSide = allGoodChoice & isfinite(T.StayedSide);
realTransitionSide = realGoodChoice & isfinite(T.StayedSide);

biasRows(end + 1) = biasRow('Perseveration', 'Repete la meme identite', ...
    T.StayedTarget, allTransitionTarget, realTransitionTarget, ...
    'Choix courant compare au choix a deux cibles precedent.');
biasRows(end + 1) = biasRow('Perseveration', 'Repete le meme cote', ...
    T.StayedSide, allTransitionSide, realTransitionSide, ...
    'Choix courant compare au choix a deux cibles precedent.');
stats.biasTable = struct2table(biasRows);

%% Comparaison explicite de strategies candidates
stats.strategyTable = computeStrategyTable(T);

% Associations conditionnelles exactes. Elles permettent de distinguer,
% lorsque le plan est correctement contrebalance, une influence spatiale
% d'une preference identitaire, de la valeur ou de la saillance.
stats.associationTable = computeAssociationTable(T);

% Evolution debut-fin des principales politiques de choix.
stats.choiceEvolutionTable = computeChoiceEvolutionTable(T, options);

% Psychometrie descriptive de la saillance continue, lorsque la tache a
% sauvegarde une difference de contraste de teinte ou de luminance.
stats.psychometricTable = computePsychometricTable(T);

%% Reproduction statistique des online plots
onlineRows = repmat(emptyBiasRow(), 0, 1);

onlineRows(end + 1) = biasRow('Online plot', ...
    'P(haute saillance) - conflit', T.ChoseHighSalience, ...
    allGoodChoice & T.IsConflict, realGoodChoice & T.IsConflict, ...
    'Equivalent de pHighSalConflict.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(haute saillance) - congruent', T.ChoseHighSalience, ...
    allGoodChoice & T.IsCongruent, realGoodChoice & T.IsCongruent, ...
    'Equivalent de pHighSalCongruent.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(haute recompense) - conflit', T.ChoseRich, ...
    allGoodChoice & T.IsConflict, realGoodChoice & T.IsConflict, ...
    'Equivalent de pHighRewardConflict.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(haute recompense) - congruent', T.ChoseRich, ...
    allGoodChoice & T.IsCongruent, realGoodChoice & T.IsCongruent, ...
    'Equivalent de pHighRewardCongruent.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(droite) - conflit', T.ChoseRight, ...
    allGoodChoice & T.IsConflict, realGoodChoice & T.IsConflict, ...
    'Controle spatial supplementaire.');
onlineRows(end + 1) = biasRow('Online plot', ...
    'P(droite) - congruent', T.ChoseRight, ...
    allGoodChoice & T.IsCongruent, realGoodChoice & T.IsCongruent, ...
    'Controle spatial supplementaire.');
stats.onlineChoiceTable = struct2table(onlineRows);

% Statistiques descriptives et tendances temporelles des traces qui
% apparaissent dans les online plots, plus quelques indices d'engagement.
stats.timeSeriesTable = computeTimeSeriesTable(T, options);

%% Temps de reaction et comparaison conflit/congruent
rtRows = repmat(emptyRtRow(), 0, 1);
rtRows(end + 1) = rtRow('Tous les choix', ...
    T.ReactionTimeMs(allGoodChoice), ...
    T.ReactionTimeMs(realGoodChoice));
rtRows(end + 1) = rtRow('Congruent', ...
    T.ReactionTimeMs(allGoodChoice & T.IsCongruent), ...
    T.ReactionTimeMs(realGoodChoice & T.IsCongruent));
rtRows(end + 1) = rtRow('Conflit', ...
    T.ReactionTimeMs(allGoodChoice & T.IsConflict), ...
    T.ReactionTimeMs(realGoodChoice & T.IsConflict));
stats.rtTable = struct2table(rtRows);

rtConflict = T.ReactionTimeMs(realGoodChoice & T.IsConflict);
rtCongruent = T.ReactionTimeMs(realGoodChoice & T.IsCongruent);
[rtDifference, rtP] = permutationDifference( ...
    rtConflict, rtCongruent, options.nPermutations, 'median');
stats.rtConflictMinusCongruentMs = rtDifference;
stats.rtConflictVsCongruentP = rtP;

%% Exploration : recompense precedente et changement d'identite
stats.exploration = computeExploration(T, options);

%% Types d'issues et erreurs
stats.outcomeTable = computeOutcomeTable(T);

%% Completion de chaque bloc
stats.blockTable = computeBlockTable(T);

%% Engagement, arrets et detection prudente d'un changement tardif
stats.engagement = computeEngagement(T, options, meta);
stats.engagementTable = stats.engagement.earlyLateTable;

%% Modeles multivaries si la Statistics Toolbox est disponible
stats.modelTable = computeOptionalChoiceModels(T);

%% Mesures synthetiques pour le rapport
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
    "Toujours T1"; ...
    "Toujours T2"; ...
    "Choisit la cible riche"; ...
    "Choisit la cible pauvre"; ...
    "Choisit la cible tres saillante"; ...
    "Choisit la cible peu saillante"; ...
    "Repete l'identite precedente"; ...
    "Change d'identite"; ...
    "Toujours droite"; ...
    "Toujours gauche"; ...
    "Choisit le cote riche"; ...
    "Choisit le cote pauvre"; ...
    "Choisit le cote tres saillant"; ...
    "Choisit le cote peu saillant"; ...
    "Repete le cote precedent"; ...
    "Change de cote"];

domains = [repmat("Identite", 8, 1); repmat("Spatial", 8, 1)];

nStrategies = numel(names);
predictions = nan(height(C), nStrategies);

% Predictions en identite : 1=T1, 2=T2.
predictions(:, 1) = 1;
predictions(:, 2) = 2;
predictions(:, 3) = C.RichTarget;
predictions(:, 4) = 3 - C.RichTarget;
predictions(:, 5) = C.HighSalienceTarget;
predictions(:, 6) = 3 - C.HighSalienceTarget;
predictions(:, 7) = C.PreviousChosenTarget;
predictions(:, 8) = 3 - C.PreviousChosenTarget;

% Predictions spatiales : 1=droite, 2=gauche.
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
    if domains(iStrategy) == "Identite"
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

% Identifier les strategies qui font exactement les memes predictions dans
% ce jeu de donnees. C'est essentiel pour ne pas confondre, par exemple,
% "toujours T2" avec "choisit la cible riche" dans un bloc T2-rich.
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
        rows(iStrategy).IndistinguishableFrom = "Aucune";
    else
        rows(iStrategy).IndistinguishableFrom = strjoin(sameNames, ' ; ');
    end
end

strategyTable = struct2table(rows);

end


%% ========================================================================
% Associations conditionnelles, evolution et psychometrie
% ========================================================================

function associationTable = computeAssociationTable(T)
% Construire des tableaux 2 x 2 sur les choix reels. Un test de Fisher exact
% bilateral est utilise, sans Statistics Toolbox. La partie "All" reste
% descriptive, ce qui permet aussi de diagnostiquer une session passEye.

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
rows(end + 1) = associationRow('Spatial', 'Choix droite', ...
    'Cible riche a droite', C.ChoseRight, C.RichOnRight, C.RealEyeChoice, ...
    'Effet de la valeur sur le cote choisi.');
rows(end + 1) = associationRow('Spatial', 'Choix droite', ...
    'Cible tres saillante a droite', C.ChoseRight, ...
    C.HighSalienceOnRight, C.RealEyeChoice, ...
    'Effet de la saillance sur le cote choisi.');
rows(end + 1) = associationRow('Spatial/identite', 'Choix droite', ...
    'T1 a droite', C.ChoseRight, C.T1OnRight, C.RealEyeChoice, ...
    'Une preference T1 produit une association positive; T2, negative.');
rows(end + 1) = associationRow('Perseveration spatiale', 'Choix droite', ...
    'Choix precedent a droite', C.ChoseRight, previousRight, ...
    C.RealEyeChoice, 'Dependance au cote du choix precedent.');

rows(end + 1) = associationRow('Valeur', 'Choix T1', ...
    'T1 est riche', C.ChoseT1, C.T1IsRich, C.RealEyeChoice, ...
    'Effet de la valeur, independamment du cote de T1.');
rows(end + 1) = associationRow('Saillance', 'Choix T1', ...
    'T1 est tres saillante', C.ChoseT1, C.T1IsHighSalience, ...
    C.RealEyeChoice, 'Effet de la saillance sur le choix identitaire.');
rows(end + 1) = associationRow('Identite/spatial', 'Choix T1', ...
    'T1 a droite', C.ChoseT1, C.T1OnRight, C.RealEyeChoice, ...
    'Une strategie toujours droite produit une association positive.');
rows(end + 1) = associationRow('Perseveration identitaire', 'Choix T1', ...
    'Choix precedent T1', C.ChoseT1, previousT1, C.RealEyeChoice, ...
    'Dependance a l identite du choix precedent.');

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
% counts = [x0y0 x0y1; x1y0 x1y1]. Une correction de Haldane-Anscombe
% (+0.5 dans chaque cellule) donne un odds ratio fini en cas de separation.

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
% Test exact bilateral de Fisher avec marges fixees. Les tables degeneres
% ne permettent pas d'estimer une association et renvoient NaN.

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

% a represente la cellule predictor=1, response=1.
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
% Comparer le premier et le dernier tiers des choix. Cette analyse indique
% si une politique apparait, disparait ou se rigidifie pendant la session.

C = T(T.GoodChoice, :);
if isempty(C)
    evolutionTable = table();
    return;
end

metricNames = [ ...
    "P(choix droite)"; ...
    "P(choix T1)"; ...
    "P(choix cible riche)"; ...
    "P(choix haute saillance)"; ...
    "P(repetition identite)"; ...
    "P(repetition cote)"];
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
% Binner l'evidence de saillance signee. Une valeur positive signifie que
% T1 est plus saillante que T2. Le choix analyse est donc P(T1).

C = T(T.GoodChoice, :);
if isempty(C)
    psychometricTable = table();
    return;
end

nHue = sum(isfinite(C.HueContrastDifferenceT1MinusT2Deg));
nLum = sum(isfinite(C.MeasuredLuminanceDifferenceT1MinusT2CdM2));
if nHue >= nLum && nHue > 0
    evidence = C.HueContrastDifferenceT1MinusT2Deg;
    evidenceType = "Contraste de teinte T1-T2 (deg)";
elseif nLum > 0
    evidence = C.MeasuredLuminanceDifferenceT1MinusT2CdM2;
    evidenceType = "Luminance T1-T2 (cd/m2)";
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

function timeSeriesTable = computeTimeSeriesTable(T, options)
% Resumer les traces continues et tester une tendance monotone simple avec
% la tentative. Le test est une permutation de la correlation de Pearson.

rows = repmat(emptyTimeSeriesRow(), 0, 1);

rewardDiff = T.RewardDifferenceT1MinusT2Ms;
rewardDiff(~T.GoodTrial) = NaN;
rows(end + 1) = timeSeriesRow('Difference reward T1-T2 (ms)', ...
    rewardDiff, T.Attempt, options.nPermutations, ...
    'Variable de plan; pas une valeur connue avant le choix.');

hueDiff = T.HueContrastDifferenceT1MinusT2Deg;
hueDiff(~T.GoodTrial) = NaN;
rows(end + 1) = timeSeriesRow('Difference contraste teinte T1-T2 (deg)', ...
    hueDiff, T.Attempt, options.nPermutations, ...
    'Evidence visuelle signee de saillance.');

lumDiff = T.MeasuredLuminanceDifferenceT1MinusT2CdM2;
lumDiff(~T.GoodTrial) = NaN;
rows(end + 1) = timeSeriesRow('Difference luminance T1-T2 (cd/m2)', ...
    lumDiff, T.Attempt, options.nPermutations, ...
    'Utilise lorsque la session varie la luminance.');

rows(end + 1) = timeSeriesRow('Intervalle pre-essai (s)', ...
    T.PreTrialIntervalSec, T.Attempt, options.nPermutations, ...
    'Un allongement tardif peut signaler un ralentissement.');
rows(end + 1) = timeSeriesRow('Latence acquisition fixation (ms)', ...
    T.FixAcquisitionLatencyMs, T.Attempt, options.nPermutations, ...
    'Indice d engagement avant la reponse saccadique.');

rt = T.ReactionTimeMs;
rt(~T.GoodChoice) = NaN;
rows(end + 1) = timeSeriesRow('Temps de reaction (ms)', ...
    rt, T.Attempt, options.nPermutations, ...
    'fixOff vers saccadeOnset.');

rows(end + 1) = timeSeriesRow('Duree de tentative (s)', ...
    T.TrialDurationSec, T.Attempt, options.nPermutations, ...
    'Inclut les essais termines et interrompus.');
rows(end + 1) = timeSeriesRow('Frames manquees', ...
    T.MissedFrames, T.Attempt, options.nPermutations, ...
    'Controle technique de presentation.');

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

% Binning descriptif identique dans l'esprit au online plot.
allX = T.PreviousRewardMs(allMask);
allY = T.SwitchedTarget(allMask);
[exploration.binCenters, exploration.binPSwitch, exploration.binN] = ...
    binBinaryRelationship(allX, allY, 6);

end

%% ========================================================================
% Issues et blocs
% ========================================================================

function outcomeTable = computeOutcomeTable(T)
labels = strings(height(T), 1);
for iTrial = 1:height(T)
    state = T.TrialEndState(iTrial);
    switch state
        case 455
            labels(iTrial) = "Succes";
        case 453
            labels(iTrial) = "Pas de reponse";
        case 454
            labels(iTrial) = "Saccade imprecise";
        case 11
            labels(iTrial) = "Rupture de fixation/cible";
        case 12
            labels(iTrial) = "Rupture joystick";
        case 13
            labels(iTrial) = "Non-start";
        otherwise
            if strlength(T.Outcome(iTrial)) > 0
                labels(iTrial) = T.Outcome(iTrial);
            else
                labels(iTrial) = sprintf('Etat %g', state);
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
% Engagement et changement tardif
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

% Comparaison du premier et du dernier tiers de la session.
third = max(1, floor(n / 3));
early = false(n, 1);
late = false(n, 1);
early(1:third) = true;
late((n - third + 1):n) = true;

rows = repmat(emptyEarlyLateRow(), 0, 1);

[diffCompletion, pCompletion] = permutationDifference( ...
    double(T.GoodTrial(late)), double(T.GoodTrial(early)), ...
    options.nPermutations, 'mean');
rows(end + 1) = earlyLateRow('Taux de completion', ...
    safeMean(double(T.GoodTrial(early))), ...
    safeMean(double(T.GoodTrial(late))), ...
    diffCompletion, pCompletion, sum(early), sum(late));

[diffInterval, pInterval] = permutationDifference( ...
    T.PreTrialIntervalSec(late), T.PreTrialIntervalSec(early), ...
    options.nPermutations, 'median');
rows(end + 1) = earlyLateRow('Intervalle pre-essai median (s)', ...
    safeMedian(T.PreTrialIntervalSec(early)), ...
    safeMedian(T.PreTrialIntervalSec(late)), ...
    diffInterval, pInterval, ...
    sum(isfinite(T.PreTrialIntervalSec(early))), ...
    sum(isfinite(T.PreTrialIntervalSec(late))));

[diffRT, pRT] = permutationDifference( ...
    T.ReactionTimeMs(late), T.ReactionTimeMs(early), ...
    options.nPermutations, 'median');
rows(end + 1) = earlyLateRow('RT median (ms)', ...
    safeMedian(T.ReactionTimeMs(early)), ...
    safeMedian(T.ReactionTimeMs(late)), ...
    diffRT, pRT, ...
    sum(isfinite(T.ReactionTimeMs(early))), ...
    sum(isfinite(T.ReactionTimeMs(late))));

[diffFix, pFix] = permutationDifference( ...
    T.FixAcquisitionLatencyMs(late), ...
    T.FixAcquisitionLatencyMs(early), ...
    options.nPermutations, 'median');
rows(end + 1) = earlyLateRow('Latence fixation mediane (ms)', ...
    safeMedian(T.FixAcquisitionLatencyMs(early)), ...
    safeMedian(T.FixAcquisitionLatencyMs(late)), ...
    diffFix, pFix, ...
    sum(isfinite(T.FixAcquisitionLatencyMs(early))), ...
    sum(isfinite(T.FixAcquisitionLatencyMs(late))));

rows(end + 1) = earlyLateRow('Frames manquees moyens', ...
    safeMean(T.MissedFrames(early)), ...
    safeMean(T.MissedFrames(late)), ...
    safeMean(T.MissedFrames(late)) - safeMean(T.MissedFrames(early)), ...
    NaN, sum(early), sum(late));

engagement.earlyLateTable = struct2table(rows);

% Recherche de changement avec controle par permutation du meilleur point
% de coupure. Le terme "desengagement" est operationnel : le code ne peut
% pas mesurer l'etat subjectif d'ennui.
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
    labels(end + 1) = "augmentation des echecs"; %#ok<AGROW>
end
if isfinite(intervalP) && intervalP < 0.05 && intervalEffect > 0
    significantAttempts(end + 1) = engagement.intervalChangeAttempt; %#ok<AGROW>
    labels(end + 1) = "augmentation des intervalles"; %#ok<AGROW>
end
if isfinite(rtP) && rtP < 0.05 && rtEffect > 0
    significantAttempts(end + 1) = engagement.rtChangeAttempt; %#ok<AGROW>
    labels(end + 1) = "augmentation des RT"; %#ok<AGROW>
end
if isfinite(fixP) && fixP < 0.05 && fixEffect > 0
    significantAttempts(end + 1) = engagement.fixChangeAttempt; %#ok<AGROW>
    labels(end + 1) = "fixation plus lente"; %#ok<AGROW>
end
if isfinite(engagement.failureRunOnsetAttempt)
    significantAttempts(end + 1) = engagement.failureRunOnsetAttempt; %#ok<AGROW>
    labels(end + 1) = "au moins trois echecs consecutifs"; %#ok<AGROW>
end

% Une conclusion forte exige deux indicateurs concordants, sauf une serie
% explicite de trois echecs consecutifs.
hasFailureRun = isfinite(engagement.failureRunOnsetAttempt);
if numel(significantAttempts) >= 2 || hasFailureRun
    engagement.estimatedDisengagementAttempt = min(significantAttempts);
    engagement.evidence = strjoin(labels, ' ; ');
elseif numel(significantAttempts) == 1
    engagement.estimatedDisengagementAttempt = NaN;
    engagement.evidence = "Un seul indice change : " + labels(1) + ...
        ". Evidence insuffisante pour dater un desengagement.";
else
    engagement.estimatedDisengagementAttempt = NaN;
    engagement.evidence = ...
        "Aucun changement tardif convergent detecte.";
end

if meta.dataLikelySimulated
    % Ne jamais afficher un point d'ennui sur des choix generes par le code.
    % Les points de changement restent disponibles dans les champs detailles
    % pour le diagnostic technique, mais aucune estimation finale n'est gardee.
    engagement.estimatedDisengagementAttempt = NaN;
    engagement.evidence = engagement.evidence + ...
        " Session en mode passEye/simulation : aucune conclusion " + ...
        "comportementale sur l'ennui n'est possible.";
end

end

%% ========================================================================
% Regression logistique optionnelle
% ========================================================================

function modelTable = computeOptionalChoiceModels(T)
% fitglm appartient a la Statistics and Machine Learning Toolbox. Toute
% cette section est protegee : son absence ne bloque jamais le reste.

if exist('fitglm', 'file') ~= 2
    modelTable = table("Tous modeles", "Non execute", NaN, NaN, NaN, ...
        NaN, 0, "fitglm indisponible; analyses exactes conservees.", ...
        'VariableNames', {'Model', 'Term', 'Estimate', 'SE', 'PValue', ...
        'OddsRatio', 'N', 'Note'});
    return;
end

C = T(T.RealEyeChoice, :);
if height(C) < 20
    modelTable = table("Tous modeles", "Non execute", NaN, NaN, NaN, ...
        NaN, height(C), "Moins de 20 choix avec controle oculaire reel.", ...
        'VariableNames', {'Model', 'Term', 'Estimate', 'SE', 'PValue', ...
        'OddsRatio', 'N', 'Note'});
    return;
end

allRows = repmat(emptyModelRow(), 0, 1);

% Modele spatial. L'intercept capture un biais droite/gauche. T1OnRight
% transforme une preference identitaire T1 en prediction spatiale.
previousRight = double(C.PreviousChosenSide == 1);
previousRight(~isfinite(C.PreviousChosenSide)) = NaN;
progress = standardizeFinite(C.ChoiceInBlock);
Xspatial = [C.RichOnRight, C.HighSalienceOnRight, C.T1OnRight, ...
    previousRight, progress];
spatialNames = {'RichOnRight', 'HighSalienceOnRight', 'T1OnRight', ...
    'PreviousRight', 'ChoiceProgress'};
spatialRows = fitOneLogisticModel('Choix droite', Xspatial, ...
    C.ChoseRight, spatialNames);
allRows = [allRows; spatialRows]; %#ok<AGROW>

% Modele identitaire. L'intercept capture un biais T1/T2. T1OnRight permet
% de detecter une preference spatiale independante de l'identite.
previousT1 = double(C.PreviousChosenTarget == 1);
previousT1(~isfinite(C.PreviousChosenTarget)) = NaN;
Xidentity = [C.T1IsRich, C.T1IsHighSalience, C.T1OnRight, ...
    previousT1, progress];
identityNames = {'T1IsRich', 'T1IsHighSalience', 'T1OnRight', ...
    'PreviousT1', 'ChoiceProgress'};
identityRows = fitOneLogisticModel('Choix T1', Xidentity, ...
    C.ChoseT1, identityNames);
allRows = [allRows; identityRows]; %#ok<AGROW>

if isempty(allRows)
    modelTable = table("Tous modeles", "Non execute", NaN, NaN, NaN, ...
        NaN, height(C), "Reponse constante ou predicteurs non estimables.", ...
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

% Retirer d'abord les colonnes constantes, puis les colonnes qui n'ajoutent
% aucun rang lineaire. Cela evite les erreurs dues aux confusions parfaites
% d'un seul bloc, par exemple T1IsRich constant.
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
            row.Note = "Coefficient extreme; separation probable.";
        else
            row.Note = "";
        end
        rows(end + 1, 1) = row; %#ok<AGROW>
    end
catch ME
    row = emptyModelRow();
    row.Model = string(modelName);
    row.Term = "Echec du modele";
    row.N = numel(y);
    row.Note = string(ME.message);
    rows(end + 1, 1) = row;
end

end

%% ========================================================================
% Interpretation synthetique
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
    interpretation.bestStrategyAll = "Aucune";
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
        "Les resultats de strategie sont uniquement descriptifs car aucun " + ...
        "choix avec controle oculaire reel n'est disponible."];
else
    interpretation.mainCaveat = "";
end
end

%% ========================================================================
% Constructeurs de lignes de tables
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
% inferenceMask est garde separement pour rendre explicite la population
% testee, meme si dans les controles de plan il est identique a mask.
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
% Statistiques elementaires sans toolbox
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
% Test binomial exact bilateral par definition de probabilite : somme des
% issues dont la probabilite sous H0 est <= a celle observee.
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
% Series glissantes et petits utilitaires
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
