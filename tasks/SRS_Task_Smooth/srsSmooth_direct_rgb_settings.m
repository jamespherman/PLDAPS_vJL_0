function p = srsSmooth_direct_rgb_settings
%SRSSMOOTH_DIRECT_RGB_SETTINGS Direct-RGB Dubey-like luminance task.
%
% This wrapper selects salienceType 3 before initialization, causing the
% task to open a C24 RGB passthrough window and use the measured family-15
% red calibration. It contains only the standard two-target choice trials.

p = srsSmooth_settings;
p.init.exptType = 'srs_direct_rgb';
p.init.protocol_title = 'srsSmooth_direct_rgb_task';
p.init.sessionId = [p.init.date '_t' p.init.time '_srsSmooth_direct_rgb'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);
p.trVarsInit.salienceType = 3;
p.trVarsInit.displayModeCode = 3;
p.trVarsInit.useSingleStimTraining = false;
p.trVarsGuiComm = p.trVarsInit;

end
