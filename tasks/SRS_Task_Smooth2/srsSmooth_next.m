function p = srsSmooth_next(p)
%SRSSMOOTH_NEXT Prepare one SRS trial before the run function.

% (1) Iterate the attempt counter.
p.status.iTrial = p.status.iTrial + 1;

% (2) Pull the latest GUI-editable values. This is why correctionTrial and
% correctionTrialMaxRepetition can be changed while the task is running.
p.trVars = p.trVarsGuiComm;
% Read the dedicated correction window after the normal GUI copy so live
% controls cannot be overwritten by stale startup values.
p = readCorrectionControlWindow(p);

% (3) Select the schedule row and define trial parameters.
p = nextParams(p);
p = updateCorrectionControlWindow(p);

% (4) Define visual elements.
p = defineVisuals(p);

% C24 mirrors the subject image on the DATAPixx console. Exp-only overlays
% are therefore shown in a separate MATLAB preview, never in the subject
% RGB stream. The preview is updated once per trial, outside critical
% stimulus timing.
if isfield(p, 'draw') && isfield(p.draw, 'isDirectRgb') && ...
        p.draw.isDirectRgb

    previewDisabled = isfield(p, 'status') && ...
        isfield(p.status, 'directRgbPreviewDisabledAfterError') && ...
        p.status.directRgbPreviewDisabledAfterError;

    if ~previewDisabled
        try
            p = updateDirectRgbExperimenterPreview(p);
        catch previewError
            % The preview is diagnostic only. Never abort the behavioral
            % task because a MATLAB figure failed to update.
            p.status.directRgbPreviewDisabledAfterError = true;
            warning('SRS:DirectRgbPreviewDisabled', ...
                ['Direct-RGB experimenter preview disabled after an error: ' ...
                 '%s'], previewError.message);
        end
    end
end

% (5) Configure DATAPixx schedules.
p = pds.setSchedules(p);

% (6) Initialize trial data.
p = initTrData(p);

% Record schedule and correction metadata after initTrData so they are not
% overwritten by the generic trial-data initialization.
p.trData.currentTrialsArrayRow = p.trVars.currentTrialsArrayRow;
p.trData.conditionID = p.trVars.conditionID;
p.trData.nStim = p.trVars.nStim;
p.trData.singleTargetID = p.trVars.singleTargetID;
p.trData.T1Side = p.trVars.T1Side;
p.trData.T2Side = p.trVars.T2Side;
p.trData.schedulePhase = p.trVars.schedulePhase;
p.trData.trialRepeatFlag = true;
p.trData.correctionTrialEnabled = double( ...
    isfield(p.trVars, 'correctionTrial') && logical(p.trVars.correctionTrial));
p.trData.correctionBothSides = getScalarOrDefault( ...
    p.trVars, 'correctionBothSides', 0);
p.trData.correctionTrialTriggerSide = getScalarOrDefault( ...
    p.trVars, 'correctionTrialTriggerSide', 0);
p.trData.correctionTrialActive = getScalarOrDefault( ...
    p.trVars, 'correctionTrialActive', 0);
p.trData.correctionTrialRepetition = getScalarOrDefault( ...
    p.trVars, 'correctionTrialRepetition', 0);
p.trData.correctionRightRewardReductionLevel = getScalarOrDefault( ...
    p.trVars, 'correctionRightRewardReductionLevel', 0);
p.trData.correctionTrialMaxRepetition = getScalarOrDefault( ...
    p.trVars, 'correctionTrialMaxRepetition', 15);
p.trData.correctionReduceRightReward = getScalarOrDefault( ...
    p.trVars, 'correctionReduceRightReward', 0);
p.trData.correctionRightRewardMultiplier = getScalarOrDefault( ...
    p.trVars, 'correctionRightRewardMultiplier', 0.50);
p.trData.correctionRightRewardMinimumMs = getScalarOrDefault( ...
    p.trVars, 'correctionRightRewardMinimumMs', 1);
p.trData.correctionRightRewardAppliedMs = getScalarOrDefault( ...
    p.trVars, 'correctionRightRewardAppliedMs', 0);
p.trData.correctionOriginalRightRewardMs = getScalarOrDefault( ...
    p.trVars, 'correctionOriginalRightRewardMs', 0);
p.trData.correctionSnapshotValid = getScalarOrDefault( ...
    p.trVars, 'correctionSnapshotValid', 0);

% (7) Stimulus generation is not required for the rectangle targets.

% (8) Start electrophysiology and acquisition schedules.
pds.startEphysAndSchedules;

end

function value = getScalarOrDefault(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName)
    candidate = s.(fieldName);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end
