function p = srsSmooth_Moretraining_settings
%SRSSMOOTH_MORETRAINING_SETTINGS Smooth-hue SRS with single-target training.
%
% Per reward block, 25 successful T1-only and 24 successful T2-only
% instruction rows are mixed in random order. Less Choice trials begin only
% after all 50 instruction rows have been completed successfully.

p = srsSmooth_settings;

p.init.exptType = 'srs_smooth_Moretraining';
p.init.protocol_title = 'srsSmooth_Moretraining_task';
p.init.sessionId = [p.init.date '_t' p.init.time '_srsSmooth_Moretraining'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);

p.trVarsInit.hueSamplingMode = 'smooth';
p.trVarsInit.hueModeCode = 2;
p.trVarsInit.useSingleStimTraining = true;
p.trVarsInit.nSingleT1PerBlock = 25;
p.trVarsInit.nSingleT2PerBlock = 25;
p.trVarsInit.randomizeTargetIdentitySides = true;
p.trVarsInit.minTrialsPerBlock      = 10;
p.trVarsInit.maxTrialsPerBlock      = 50;

p.trVarsGuiComm = p.trVarsInit;
end
