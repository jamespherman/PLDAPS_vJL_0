function p = srsSmooth_direct_rgb_training_settings
%SRSSMOOTH_DIRECT_RGB_TRAINING_SETTINGS Direct RGB with mixed singles.
%
% Per reward block, 10 successful T1-only and 10 successful T2-only rows
% are mixed. Choice trials start after all 20 instruction rows succeed.

p = srsSmooth_settings;
p.init.exptType = 'srs_direct_rgb_training';
p.init.protocol_title = 'srsSmooth_direct_rgb_training_task';
p.init.sessionId = [p.init.date '_t' p.init.time ...
    '_srsSmooth_direct_rgb_training'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);
p.trVarsInit.salienceType = 3;
p.trVarsInit.displayModeCode = 3;
p.trVarsInit.useSingleStimTraining = true;
p.trVarsInit.nSingleT1PerBlock = 10;
p.trVarsInit.nSingleT2PerBlock = 10;
p.trVarsInit.randomizeTargetIdentitySides = true;
p.trVarsGuiComm = p.trVarsInit;

end
