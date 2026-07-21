function p = srsSmooth_classic_settings
%SRSSMOOTH_CLASSIC_SETTINGS SRS_Task_Smooth folder using classic hues.
%
% This settings file uses the fixed DKL hue combination 0/20/180/200 deg
% while sharing all code with the smooth version.

p = srsSmooth_settings;

p.init.exptType = 'srs_classic';
p.init.protocol_title = 'srsSmooth_classic_task';
p.init.sessionId = [p.init.date '_t' p.init.time '_srsSmooth_classic'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);

p.trVarsInit.hueSamplingMode = 'classic';
p.trVarsInit.hueModeCode = 1;
p.trVarsInit.useSingleStimTraining = false;

p.trVarsGuiComm = p.trVarsInit;
end
