function p = srsSmooth_training_settings
%SRSSMOOTH_TRAINING_SETTINGS Smooth-hue SRS with single-target training.
%
% Per reward block, 10 successful T1-only and 10 successful T2-only
% instruction rows are mixed in random order. Choice trials begin only
% after all 20 instruction rows have been completed successfully.

p = srsSmooth_settings;

p.init.exptType = 'srs_smooth_training';
p.init.protocol_title = 'srsSmooth_training_task';
p.init.sessionId = [p.init.date '_t' p.init.time '_srsSmooth_training'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);

p.trVarsInit.hueSamplingMode = 'smooth';
p.trVarsInit.hueModeCode = 2;
p.trVarsInit.useSingleStimTraining = true;
p.trVarsInit.nSingleT1PerBlock = 10;
p.trVarsInit.nSingleT2PerBlock = 10;
p.trVarsInit.randomizeTargetIdentitySides = true;

p.trVarsGuiComm = p.trVarsInit;
end
