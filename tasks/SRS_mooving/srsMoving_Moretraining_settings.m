function p = srsMoving_Moretraining_settings
%SRSMOVING_MORETRAINING_SETTINGS Moving-target SRS with extra instructions.
%
% Same current schedule parameters as srsSmooth_Moretraining_settings:
% 20 successful T1-only and 20 successful T2-only instruction trials per
% reward block, followed by a uniformly sampled balanced number of choices.
% The only task-level difference is the moving target geometry.

p = srsMoving_settings;

p.init.exptType = 'srs_moving_Moretraining';
p.init.protocol_title = 'srsMoving_Moretraining_task';
p.init.sessionId = [p.init.date '_t' p.init.time '_srsMoving_Moretraining'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);

p.trVarsInit.hueSamplingMode = 'smooth';
p.trVarsInit.hueModeCode = 2;
p.trVarsInit.useSingleStimTraining = true;
p.trVarsInit.nSingleT1PerBlock = 20;
p.trVarsInit.nSingleT2PerBlock = 20;
p.trVarsInit.randomizeTargetIdentitySides = true;
p.trVarsInit.minTrialsPerBlock = 16;
p.trVarsInit.maxTrialsPerBlock = 28;

p.trVarsGuiComm = p.trVarsInit;

end
