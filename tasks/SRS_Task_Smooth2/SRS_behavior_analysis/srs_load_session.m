function [T, meta] = srs_load_session(sessionFolder, blockRange)
%SRS_LOAD_SESSION Lire directement une session SRS sauvegardee par PLDAPS.
%
%   [T, META] = SRS_LOAD_SESSION(SESSIONFOLDER)
%
% Entree
% ------
% SESSIONFOLDER : dossier contenant trial0001.mat, trial0002.mat, etc.
%
% Sorties
% -------
% T    : table avec une ligne par tentative. Les variables brutes utiles
%        sont conservees, puis completees par des variables derivees :
%        choix riche, choix spatial, temps de reaction, transitions, etc.
% META : informations generales et avertissements de validite.
%
% Cette fonction ne depend pas de pds.loadP et ne modifie jamais les donnees
% originales. Elle charge uniquement trVars, trData, status et init depuis
% chaque fichier trialXXXX.mat.

%% Verifications du dossier
if nargin < 1 || isempty(sessionFolder)
    error('Un dossier de session doit etre fourni.');
end

% Par defaut, conserver tous les blocs afin de rester compatible avec les
% anciens appels a srs_load_session(sessionFolder).
if nargin < 2
    blockRange = [];
end

if ~isempty(blockRange)
    validateattributes(blockRange, {'numeric'}, ...
        {'vector', 'numel', 2, 'real', 'nonnan'}, ...
        mfilename, 'blockRange', 2);
    blockRange = double(blockRange(:)');
    if blockRange(1) > blockRange(2)
        error(['La limite inferieure de blockRange doit etre ', ...
            'inferieure ou egale a la limite superieure.']);
    end
end

if isstring(sessionFolder)
    sessionFolder = char(sessionFolder);
end

if ~isfolder(sessionFolder)
    error('Le dossier de session n''existe pas : %s', sessionFolder);
end

fileInfo = dir(fullfile(sessionFolder, 'trial*.mat'));
if isempty(fileInfo)
    error('Aucun fichier trialXXXX.mat trouve dans : %s', sessionFolder);
end

% Trier numeriquement, meme si un jour les numeros ne sont plus tous
% ecrits avec quatre chiffres.
fileNumbers = nan(numel(fileInfo), 1);
for iFile = 1:numel(fileInfo)
    token = regexp(fileInfo(iFile).name, 'trial(\d+)\.mat', ...
        'tokens', 'once');
    if ~isempty(token)
        fileNumbers(iFile) = str2double(token{1});
    end
end
[~, sortOrder] = sort(fileNumbers);
fileInfo = fileInfo(sortOrder);
fileNumbers = fileNumbers(sortOrder);

%% Lire le premier fichier pour identifier la session
firstFile = fullfile(sessionFolder, fileInfo(1).name);
firstData = load(firstFile, 'trVars', 'trData', 'status', 'init');

[~, folderName] = fileparts(sessionFolder);
sessionID = getText(firstData.init, 'sessionId', folderName);
experimentType = getText(firstData.init, 'exptType', 'unknown');
taskName = getText(firstData.init, 'taskName', 'srsSmooth');
sessionDate = getText(firstData.init, 'date', '');
sessionTime = getText(firstData.init, 'time', '');

nFiles = numel(fileInfo);
rows = repmat(emptyTrialRow(), nFiles, 1);

%% Lire chaque tentative
for iFile = 1:nFiles
    filePath = fullfile(sessionFolder, fileInfo(iFile).name);

    % Ne charger que les structures utiles. Cela evite le gros champ
    % __function_workspace__ present dans certains fichiers PLDAPS.
    S = load(filePath, 'trVars', 'trData', 'status', 'init');

    if ~isfield(S, 'trVars') || ~isfield(S, 'trData') || ...
            ~isfield(S, 'status')
        error('Le fichier %s ne contient pas trVars/trData/status.', ...
            fileInfo(iFile).name);
    end

    tv = S.trVars;
    td = S.trData;
    st = S.status;

    if isfield(td, 'timing') && isstruct(td.timing)
        timing = td.timing;
    else
        timing = struct();
    end

    r = emptyTrialRow();

    % Identification de la tentative
    r.SessionID = string(sessionID);
    r.ExperimentType = string(experimentType);
    r.FileName = string(fileInfo(iFile).name);
    r.FileTrialIndex = fileNumbers(iFile);
    r.Attempt = getScalar(st, 'iTrial', fileNumbers(iFile));
    r.GoodTrialIndexBefore = getScalar(st, 'iGoodTrial', NaN);

    % Structure de bloc et de condition
    r.Block = getScalar(st, 'CurrentBlockNumber', NaN);
    r.BlockAttempt = getScalar(st, 'blockAttemptCount', NaN);
    r.BlockGoodBefore = getScalar(st, 'CurrentBlockTrial', NaN);
    r.ExpectedTrialsInBlock = getScalar(st, 'TotalTrialsPerBlock', NaN);
    r.ExpectedChoiceTrialsInBlock = ...
        getScalar(st, 'TotalChoiceTrialsPerBlock', NaN);
    r.ExpectedInstructionTrialsInBlock = ...
        getScalar(st, 'TotalInstructionTrialsPerBlock', NaN);
    r.TotalBlocksTarget = getScalar(st, 'TotalBlocksTarget', NaN);
    r.BlockRichTarget = getScalar(st, 'CurrentBlockType', NaN);
    r.TrialType = getScalar(st, 'ActualTrialType', NaN);
    r.ConditionID = getScalar(tv, 'conditionID', NaN);
    r.SchedulePhase = getScalar(tv, 'schedulePhase', NaN);
    r.CurrentScheduleRow = getScalar(tv, 'currentTrialsArrayRow', NaN);
    r.TrialSeed = getScalar(tv, 'trialSeed', NaN);

    % Nombre et identite des cibles
    r.NStim = getScalar(tv, 'nStim', NaN);
    r.SingleTargetID = getScalar(tv, 'singleTargetID', NaN);
    r.T1Side = getScalar(tv, 'T1Side', NaN);
    r.T2Side = getScalar(tv, 'T2Side', NaN);

    % Cible riche et cible saillante. Ces valeurs sont valides pour la
    % tentative courante, meme si les compteurs cumulatifs de status sont
    % sauvegardes avant leur mise a jour dans srsSmooth_finish.
    r.RichTarget = getScalar(st, 'highRewardTargetID', ...
        getScalar(st, 'CurrentBlockType', NaN));
    r.RichSide = getScalar(st, 'highRewardSide', NaN);
    r.HighSalienceTarget = getScalar(st, 'highSalienceTargetID', NaN);
    r.HighSalienceSide = getScalar(st, 'highSalienceSide', NaN);

    % Reponse observee
    r.ChosenTarget = getScalar(td, 'chosenTargetID', 0);
    r.ChosenSide = getScalar(td, 'chosenSide', 0);
    r.Outcome = string(getText(td, 'outcome', ''));
    r.OutcomeCode = getScalar(td, 'outcomeCode', 0);
    r.TrialEndState = getScalar(td, 'trialEndState', NaN);

    goodField = getScalar(td, 'GoodTrial', NaN);
    if isfinite(goodField)
        r.GoodTrial = logical(goodField);
    else
        % 455 correspond a p.state.sacComplete dans cette version SRS.
        r.GoodTrial = r.TrialEndState == 455;
    end

    r.TrialRepeatFlag = getScalar(td, 'trialRepeatFlag', NaN);
    r.MissedFrames = getScalar(td, 'missedFrameCount', 0);

    % Modes de contournement/debug. passEye=1 force, dans le code de cette
    % tache, une selection de la cible riche sur les essais a deux cibles.
    r.PassEye = getScalar(tv, 'passEye', 0);
    r.PassJoy = getScalar(tv, 'passJoy', 0);
    r.MouseEyeSim = getScalar(tv, 'mouseEyeSim', 0);

    % Recompenses
    r.RewardT1Ms = getScalar(tv, 'rewardDurationT1', NaN);
    r.RewardT2Ms = getScalar(tv, 'rewardDurationT2', NaN);
    r.ActualRichRewardMs = getScalar(st, 'ActualRichReward', NaN);
    r.ActualPoorRewardMs = getScalar(st, 'ActualPoorReward', NaN);
    r.RewardDifferenceT1MinusT2Ms = r.RewardT1Ms - r.RewardT2Ms;

    if r.ChosenTarget == 1
        r.ChosenRewardMs = r.RewardT1Ms;
    elseif r.ChosenTarget == 2
        r.ChosenRewardMs = r.RewardT2Ms;
    else
        r.ChosenRewardMs = NaN;
    end

    % Saillance par teinte DKL
    r.SalienceType = getScalar(tv, 'salienceType', NaN);
    r.BackgroundHueDeg = getScalar(tv, 'BackgroundHue', NaN);
    r.HueT1Deg = getScalar(tv, 'ActualHueT1', NaN);
    r.HueT2Deg = getScalar(tv, 'ActualHueT2', NaN);
    r.HueContrastT1Deg = getScalar(tv, 'HueContrastT1', NaN);
    r.HueContrastT2Deg = getScalar(tv, 'HueContrastT2', NaN);
    r.HueContrastDifferenceT1MinusT2Deg = ...
        getScalar(tv, 'HueContrastDifferenceT1MinusT2', NaN);
    r.HueContrastMagnitudeDeg = ...
        getScalar(tv, 'HueContrastDifferenceMagnitude', NaN);

    % Saillance par luminance, si ce mode est utilise dans une autre session
    r.MeasuredLuminanceT1CdM2 = ...
        getScalar(tv, 'MeasuredLuminanceT1CdM2', NaN);
    r.MeasuredLuminanceT2CdM2 = ...
        getScalar(tv, 'MeasuredLuminanceT2CdM2', NaN);
    r.MeasuredLuminanceDifferenceT1MinusT2CdM2 = ...
        getScalar(tv, 'MeasuredLuminanceDifferenceT1MinusT2CdM2', NaN);

    % Evenements temporels. Les valeurs sont relatives au debut de l'essai,
    % sauf TrialStartPTB qui est une horloge absolue GetSecs.
    r.TrialStartPTB = getScalar(timing, 'trialStartPTB', NaN);
    r.TrialStartDP = getScalar(timing, 'trialStartDP', NaN);
    r.TrialDurationSec = getScalar(timing, 'trialEnd', NaN);
    r.FixOnSec = getScalar(timing, 'fixOn', NaN);
    r.FixAcquiredSec = getScalar(timing, 'fixAq', NaN);
    r.FixHoldReqMetSec = getScalar(timing, 'fixHoldReqMet', NaN);
    r.FixOffSec = getScalar(timing, 'fixOff', NaN);
    r.SaccadeOnsetSec = getScalar(timing, 'saccadeOnset', NaN);
    r.SaccadeOffsetSec = getScalar(timing, 'saccadeOffset', NaN);
    r.TargetAcquiredSec = getScalar(timing, 'targetAq', NaN);
    r.JoyPressSec = getScalar(timing, 'joyPress', NaN);
    r.JoyReleaseSec = getScalar(timing, 'joyRelease', NaN);
    r.RewardTimeSec = getScalar(timing, 'reward', NaN);

    % Latence d'acquisition de la fixation. Elle est utile comme indice
    % operationnel d'engagement, en complement du taux d'echec et des RT.
    % Les valeurs negatives utilisees par PLDAPS pour "non renseigne" sont
    % refusees automatiquement.
    if isfinite(r.FixOnSec) && isfinite(r.FixAcquiredSec) && ...
            r.FixOnSec >= 0 && r.FixAcquiredSec >= r.FixOnSec
        r.FixAcquisitionLatencyMs = ...
            1000 * (r.FixAcquiredSec - r.FixOnSec);
    else
        r.FixAcquisitionLatencyMs = NaN;
    end

    % Un RT n'est accepte que si les deux timestamps existent et sont dans
    % le bon ordre. passEye produit souvent un saccadeOnset avant fixOff ;
    % ces valeurs sont donc automatiquement marquees NaN.
    if isfinite(r.FixOffSec) && isfinite(r.SaccadeOnsetSec) && ...
            r.FixOffSec > 0 && r.SaccadeOnsetSec > r.FixOffSec
        r.ReactionTimeMs = 1000 * (r.SaccadeOnsetSec - r.FixOffSec);
    else
        r.ReactionTimeMs = NaN;
    end

    if isfinite(r.SaccadeOnsetSec) && isfinite(r.SaccadeOffsetSec) && ...
            r.SaccadeOffsetSec > r.SaccadeOnsetSec
        r.SaccadeDurationMs = ...
            1000 * (r.SaccadeOffsetSec - r.SaccadeOnsetSec);
    else
        r.SaccadeDurationMs = NaN;
    end

    % Temps total entre l'extinction de la fixation et l'acquisition de la
    % cible. Ce temps inclut la latence de declenchement et la saccade.
    if isfinite(r.FixOffSec) && isfinite(r.TargetAcquiredSec) && ...
            r.FixOffSec > 0 && r.TargetAcquiredSec > r.FixOffSec
        r.TargetAcquisitionLatencyMs = ...
            1000 * (r.TargetAcquiredSec - r.FixOffSec);
    else
        r.TargetAcquisitionLatencyMs = NaN;
    end

    rows(iFile) = r;
end

%% Convertir en table et ajouter les variables derivees
T = struct2table(rows);

% Ordre des lignes : les fichiers sont deja tries, mais trier par Attempt
% protege contre un fichier renomme ou copie dans le dossier.
[~, rowOrder] = sort(T.Attempt);
T = T(rowOrder, :);

% Filtrer avant de calculer les compteurs, temps et dependances sequentielles.
% Ainsi, le premier choix conserve ne depend jamais d'un bloc exclu.
if ~isempty(blockRange)
    availableBlocks = unique(T.Block(isfinite(T.Block)))';
    keepTrial = isfinite(T.Block) & ...
        T.Block >= blockRange(1) & T.Block <= blockRange(2);

    if ~any(keepTrial)
        error(['Aucune tentative trouvee dans les blocs %g a %g. ', ...
            'Blocs disponibles : %s'], ...
            blockRange(1), blockRange(2), mat2str(availableBlocks));
    end

    T = T(keepTrial, :);
end

nTrials = height(T);

T.TrialTypeLabel = repmat("Autre", nTrials, 1);
T.TrialTypeLabel(T.NStim == 1) = "Instruction";
T.TrialTypeLabel(T.NStim == 2 & T.TrialType == 1) = "Congruent";
T.TrialTypeLabel(T.NStim == 2 & T.TrialType == 2) = "Conflit";

T.T1SideLabel = sideLabels(T.T1Side);
T.T2SideLabel = sideLabels(T.T2Side);
T.ChosenSideLabel = sideLabels(T.ChosenSide);
T.RichSideLabel = sideLabels(T.RichSide);
T.HighSalienceSideLabel = sideLabels(T.HighSalienceSide);

T.IsInstruction = T.NStim == 1;
T.IsChoice = T.NStim == 2;
T.IsCongruent = T.IsChoice & T.TrialType == 1;
T.IsConflict = T.IsChoice & T.TrialType == 2;

T.GoodChoice = T.GoodTrial & T.IsChoice & ...
    ismember(T.ChosenTarget, [1 2]) & ismember(T.ChosenSide, [1 2]);

% Choix binaires. NaN signifie que la variable ne s'applique pas a cette
% tentative ou qu'aucun choix valide n'a ete produit.
T.ChoseRight = nan(nTrials, 1);
T.ChoseT1 = nan(nTrials, 1);
T.ChoseRich = nan(nTrials, 1);
T.ChoseHighSalience = nan(nTrials, 1);

validChoice = T.GoodChoice;
T.ChoseRight(validChoice) = double(T.ChosenSide(validChoice) == 1);
T.ChoseT1(validChoice) = double(T.ChosenTarget(validChoice) == 1);
T.ChoseRich(validChoice) = double( ...
    T.ChosenTarget(validChoice) == T.RichTarget(validChoice));
T.ChoseHighSalience(validChoice) = double( ...
    T.ChosenTarget(validChoice) == T.HighSalienceTarget(validChoice));

T.ChoseLeft = 1 - T.ChoseRight;
T.ChoseT2 = 1 - T.ChoseT1;
T.ChosePoor = 1 - T.ChoseRich;
T.ChoseLowSalience = 1 - T.ChoseHighSalience;

% Predicteurs utiles pour separer strategie spatiale, identitaire, reward et
% saillance dans les modeles de choix.
T.T1OnRight = double(T.T1Side == 1);
T.RichOnRight = double(T.RichSide == 1);
T.HighSalienceOnRight = double(T.HighSalienceSide == 1);
T.T1IsRich = double(T.RichTarget == 1);
T.T1IsHighSalience = double(T.HighSalienceTarget == 1);

% Verifier que le cote choisi correspond bien au cote de l'identite choisie.
T.ChoiceMappingValid = false(nTrials, 1);
mapT1 = validChoice & T.ChosenTarget == 1;
mapT2 = validChoice & T.ChosenTarget == 2;
T.ChoiceMappingValid(mapT1) = T.ChosenSide(mapT1) == T.T1Side(mapT1);
T.ChoiceMappingValid(mapT2) = T.ChosenSide(mapT2) == T.T2Side(mapT2);

% Indices cumulatifs calcules directement a partir des fichiers, sans faire
% confiance aux compteurs status sauvegardes avant updateStatusVariables.
T.GoodTrialOrdinal = cumsum(double(T.GoodTrial));
T.ChoiceOrdinal = nan(nTrials, 1);
T.ChoiceOrdinal(validChoice) = (1:sum(validChoice))';

% Un identifiant de bloc reste unique meme si plusieurs sessions sont ensuite
% concatenees dans l'analyse batch.
T.BlockUID = strings(nTrials, 1);
for iTrial = 1:nTrials
    if isfinite(T.Block(iTrial))
        T.BlockUID(iTrial) = sprintf('%s_B%03d', ...
            char(T.SessionID(iTrial)), round(T.Block(iTrial)));
    else
        T.BlockUID(iTrial) = sprintf('%s_Bmissing', ...
            char(T.SessionID(iTrial)));
    end
end

T.GoodTrialInBlock = nan(nTrials, 1);
T.ChoiceInBlock = nan(nTrials, 1);
uniqueBlocks = unique(T.BlockUID, 'stable');
for iBlock = 1:numel(uniqueBlocks)
    idx = find(T.BlockUID == uniqueBlocks(iBlock));
    goodCount = 0;
    choiceCount = 0;
    for j = 1:numel(idx)
        rowIdx = idx(j);
        if T.GoodTrial(rowIdx)
            goodCount = goodCount + 1;
            T.GoodTrialInBlock(rowIdx) = goodCount;
        end
        if T.GoodChoice(rowIdx)
            choiceCount = choiceCount + 1;
            T.ChoiceInBlock(rowIdx) = choiceCount;
        end
    end
end

% Temps ecoule et intervalle precedant chaque tentative.
firstStart = firstFinite(T.TrialStartPTB);
if isfinite(firstStart)
    T.SessionElapsedMin = (T.TrialStartPTB - firstStart) / 60;
else
    T.SessionElapsedMin = nan(nTrials, 1);
end

T.PreTrialIntervalSec = nan(nTrials, 1);
for iTrial = 2:nTrials
    previousEnd = T.TrialStartPTB(iTrial - 1) + ...
        T.TrialDurationSec(iTrial - 1);
    if isfinite(T.TrialStartPTB(iTrial)) && isfinite(previousEnd)
        intervalValue = T.TrialStartPTB(iTrial) - previousEnd;
        if intervalValue >= 0
            T.PreTrialIntervalSec(iTrial) = intervalValue;
        end
    end
end

% Dependances sequentielles entre choix successifs. Comme dans les online
% plots originaux, les essais instruction et les tentatives echouees sont
% sautes lorsque l'on cherche le choix precedent.
T.PreviousChosenTarget = nan(nTrials, 1);
T.PreviousChosenSide = nan(nTrials, 1);
T.PreviousRewardMs = nan(nTrials, 1);
T.PreviousChoiceSameBlock = false(nTrials, 1);
T.SwitchedTarget = nan(nTrials, 1);
T.SwitchedSide = nan(nTrials, 1);

lastChoiceRow = NaN;
for iTrial = 1:nTrials
    if ~T.GoodChoice(iTrial)
        continue;
    end

    if isfinite(lastChoiceRow)
        previousRow = lastChoiceRow;
        T.PreviousChosenTarget(iTrial) = T.ChosenTarget(previousRow);
        T.PreviousChosenSide(iTrial) = T.ChosenSide(previousRow);
        T.PreviousRewardMs(iTrial) = T.ChosenRewardMs(previousRow);
        T.PreviousChoiceSameBlock(iTrial) = ...
            T.BlockUID(iTrial) == T.BlockUID(previousRow);
        T.SwitchedTarget(iTrial) = double( ...
            T.ChosenTarget(iTrial) ~= T.ChosenTarget(previousRow));
        T.SwitchedSide(iTrial) = double( ...
            T.ChosenSide(iTrial) ~= T.ChosenSide(previousRow));
    end

    lastChoiceRow = iTrial;
end

T.StayedTarget = 1 - T.SwitchedTarget;
T.StayedSide = 1 - T.SwitchedSide;

% Les essais avec passEye ou une simulation de l'oeil restent utiles pour le
% controle technique, mais ne doivent pas entrer dans l'inference sur la
% strategie reelle de l'animal.
T.RealEyeChoice = T.GoodChoice & T.PassEye == 0 & T.MouseEyeSim == 0;

%% Metadonnees et avertissements
meta = struct();
meta.sessionFolder = sessionFolder;
meta.sessionID = sessionID;
meta.blockRangeRequested = blockRange;
meta.analyzedBlocks = unique(T.Block(isfinite(T.Block)), 'stable')';
meta.experimentType = experimentType;
meta.taskName = taskName;
meta.sessionDate = sessionDate;
meta.sessionTime = sessionTime;
meta.nAttemptFiles = nTrials;
meta.nGoodTrials = sum(T.GoodTrial);
meta.nGoodChoices = sum(T.GoodChoice);
meta.nRealEyeChoices = sum(T.RealEyeChoice);
meta.passEyeFraction = mean(T.PassEye ~= 0);
meta.passJoyFraction = mean(T.PassJoy ~= 0);
meta.mouseEyeSimFraction = mean(T.MouseEyeSim ~= 0);
meta.dataLikelySimulated = any(T.PassEye ~= 0 | T.MouseEyeSim ~= 0);
meta.nValidReactionTimes = sum(isfinite(T.ReactionTimeMs));
meta.nValidFixAcquisitionLatencies = ...
    sum(isfinite(T.FixAcquisitionLatencyMs));
meta.totalMissedFrames = sum(T.MissedFrames, 'omitnan');
meta.mappingErrors = sum(T.GoodChoice & ~T.ChoiceMappingValid);
meta.totalBlocksTarget = firstFinite(T.TotalBlocksTarget);

if isfinite(firstStart)
    finalEnd = T.TrialStartPTB(end) + T.TrialDurationSec(end);
    meta.sessionDurationMin = (finalEnd - firstStart) / 60;
else
    meta.sessionDurationMin = NaN;
end

warnings = strings(0, 1);
if meta.passEyeFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'passEye est actif sur %.1f %% des tentatives. Dans cette version ', ...
        'de SRS, passEye choisit automatiquement la cible riche sur les ', ...
        'essais a deux cibles. Les choix ne sont donc pas comportementaux.'], ...
        100 * meta.passEyeFraction);
end
if meta.passJoyFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'passJoy est actif sur %.1f %% des tentatives. Les mesures ', ...
        'd''engagement liees au joystick sont a interpreter avec prudence.'], ...
        100 * meta.passJoyFraction);
end
if meta.mouseEyeSimFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'mouseEyeSim est actif sur %.1f %% des tentatives.'], ...
        100 * meta.mouseEyeSimFraction);
end
if meta.mappingErrors > 0
    warnings(end + 1, 1) = sprintf([ ...
        '%d choix ont une incoherence entre identite choisie et cote choisi.'], ...
        meta.mappingErrors);
end
if meta.nGoodChoices > 0 && meta.nRealEyeChoices == 0
    warnings(end + 1, 1) = [ ...
        "Aucun choix a deux cibles avec controle oculaire reel n'est " + ...
        "disponible pour les tests inferentiels."];
end
meta.warnings = warnings;

end

%% ========================================================================
% Fonctions locales utilitaires
% ========================================================================

function r = emptyTrialRow()
% Definir une fois tous les champs garantit que struct2table obtient des
% colonnes homogenes, meme si certains champs manquent dans un essai avorte.

r = struct( ...
    'SessionID', "", ...
    'ExperimentType', "", ...
    'FileName', "", ...
    'FileTrialIndex', NaN, ...
    'Attempt', NaN, ...
    'GoodTrialIndexBefore', NaN, ...
    'Block', NaN, ...
    'BlockAttempt', NaN, ...
    'BlockGoodBefore', NaN, ...
    'ExpectedTrialsInBlock', NaN, ...
    'ExpectedChoiceTrialsInBlock', NaN, ...
    'ExpectedInstructionTrialsInBlock', NaN, ...
    'TotalBlocksTarget', NaN, ...
    'BlockRichTarget', NaN, ...
    'TrialType', NaN, ...
    'ConditionID', NaN, ...
    'SchedulePhase', NaN, ...
    'CurrentScheduleRow', NaN, ...
    'TrialSeed', NaN, ...
    'NStim', NaN, ...
    'SingleTargetID', NaN, ...
    'T1Side', NaN, ...
    'T2Side', NaN, ...
    'RichTarget', NaN, ...
    'RichSide', NaN, ...
    'HighSalienceTarget', NaN, ...
    'HighSalienceSide', NaN, ...
    'ChosenTarget', NaN, ...
    'ChosenSide', NaN, ...
    'Outcome', "", ...
    'OutcomeCode', NaN, ...
    'TrialEndState', NaN, ...
    'GoodTrial', false, ...
    'TrialRepeatFlag', NaN, ...
    'MissedFrames', NaN, ...
    'PassEye', NaN, ...
    'PassJoy', NaN, ...
    'MouseEyeSim', NaN, ...
    'RewardT1Ms', NaN, ...
    'RewardT2Ms', NaN, ...
    'ActualRichRewardMs', NaN, ...
    'ActualPoorRewardMs', NaN, ...
    'RewardDifferenceT1MinusT2Ms', NaN, ...
    'ChosenRewardMs', NaN, ...
    'SalienceType', NaN, ...
    'BackgroundHueDeg', NaN, ...
    'HueT1Deg', NaN, ...
    'HueT2Deg', NaN, ...
    'HueContrastT1Deg', NaN, ...
    'HueContrastT2Deg', NaN, ...
    'HueContrastDifferenceT1MinusT2Deg', NaN, ...
    'HueContrastMagnitudeDeg', NaN, ...
    'MeasuredLuminanceT1CdM2', NaN, ...
    'MeasuredLuminanceT2CdM2', NaN, ...
    'MeasuredLuminanceDifferenceT1MinusT2CdM2', NaN, ...
    'TrialStartPTB', NaN, ...
    'TrialStartDP', NaN, ...
    'TrialDurationSec', NaN, ...
    'FixOnSec', NaN, ...
    'FixAcquiredSec', NaN, ...
    'FixHoldReqMetSec', NaN, ...
    'FixOffSec', NaN, ...
    'SaccadeOnsetSec', NaN, ...
    'SaccadeOffsetSec', NaN, ...
    'TargetAcquiredSec', NaN, ...
    'JoyPressSec', NaN, ...
    'JoyReleaseSec', NaN, ...
    'RewardTimeSec', NaN, ...
    'FixAcquisitionLatencyMs', NaN, ...
    'ReactionTimeMs', NaN, ...
    'SaccadeDurationMs', NaN, ...
    'TargetAcquisitionLatencyMs', NaN);

end

function value = getScalar(s, fieldName, defaultValue)
% Retourner un scalaire numerique/logique ou une valeur par defaut.

if nargin < 3
    defaultValue = NaN;
end
value = defaultValue;

if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end

candidate = s.(fieldName);
if (isnumeric(candidate) || islogical(candidate)) && ...
        isscalar(candidate) && ~isempty(candidate)
    value = double(candidate);
end

end

function value = getText(s, fieldName, defaultValue)
% Convertir proprement char/string/cellstr en texte MATLAB char.

if nargin < 3
    defaultValue = '';
end
value = defaultValue;

if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end

candidate = s.(fieldName);
if isstring(candidate) && isscalar(candidate)
    value = char(candidate);
elseif ischar(candidate)
    value = candidate;
elseif iscell(candidate) && numel(candidate) == 1 && ...
        (ischar(candidate{1}) || isstring(candidate{1}))
    value = char(candidate{1});
end

end

function labels = sideLabels(sideValues)
labels = repmat("Aucun", size(sideValues));
labels(sideValues == 1) = "Droite";
labels(sideValues == 2) = "Gauche";
labels(~ismember(sideValues, [0 1 2])) = "Manquant";
end

function value = firstFinite(x)
idx = find(isfinite(x), 1, 'first');
if isempty(idx)
    value = NaN;
else
    value = x(idx);
end
end
