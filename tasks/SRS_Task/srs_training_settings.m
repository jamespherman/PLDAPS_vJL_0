function p = srs_training_settings
%SRS_TRAINING_SETTINGS Training variant of SRS_Fixate.
%
% Uses the same init/next/run/finish files as srs_settings.m, but adds
% 10 T1-only and 10 T2-only instruction trials at the beginning of every
% reward block. Target identity is counterbalanced across left/right sides.

p = srs_settings;

p.init.exptType = 'srs_training';
p.init.protocol_title = 'srs_training_task';
p.init.sessionId = [p.init.date '_t' p.init.time '_srs_training'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);

p.trVarsInit.useSingleStimTraining = true;
p.trVarsInit.nSingleT1PerBlock = 10;
p.trVarsInit.nSingleT2PerBlock = 10;
p.trVarsInit.randomizeTargetIdentitySides = true;

% Update the GUI communication copy after overriding training parameters.
p.trVarsGuiComm = p.trVarsInit;

end
