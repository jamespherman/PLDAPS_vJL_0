function p = srs_training_settings
%SRS_TRAINING_SETTINGS Training variant of SRS_Task.
%
% Uses the same init/next/run/finish files as srs_settings.m, but adds
% 10 successful trials from one single-target identity are completed as
% one uninterrupted group, followed by 10 successful trials from the other
% identity. Group order is randomized once per reward block. Target side is
% counterbalanced within each group; failed trials remain in the active group.

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
