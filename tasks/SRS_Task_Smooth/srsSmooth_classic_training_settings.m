function p = srsSmooth_classic_training_settings
%SRSSMOOTH_CLASSIC_TRAINING_SETTINGS Classic hues with mixed single training.

p = srsSmooth_classic_settings;

p.init.exptType = 'srs_classic_training';
p.init.protocol_title = 'srsSmooth_classic_training_task';
p.init.sessionId = [p.init.date '_t' p.init.time '_srsSmooth_classic_training'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);

p.trVarsInit.useSingleStimTraining = true;
p.trVarsInit.nSingleT1PerBlock = 10;
p.trVarsInit.nSingleT2PerBlock = 10;
p.trVarsInit.randomizeTargetIdentitySides = true;

p.trVarsGuiComm = p.trVarsInit;
end
