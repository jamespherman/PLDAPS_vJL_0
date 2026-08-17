function p = srsClassic_Moretraining_settings
%SRSSMOOTH_MORETRAINING_SETTINGS Smooth-hue SRS with single-target training.
%
% Per reward block, 25 successful T1-only and 25 successful T2-only
% instruction rows are mixed in random order. Less Choice trials begin only
% after all 50 instruction rows have been completed successfully.

p = srsSmooth_settings;

p.init.exptType = 'srs_classic_Moretraining';
p.init.protocol_title = 'srsClassic_Moretraining_task';
p.init.sessionId = [p.init.date '_t' p.init.time '_srsClassic_Moretraining'];
p.init.sessionFolder = fullfile(p.init.outputFolder, p.init.sessionId);

p.trVarsInit.hueSamplingMode = 'classic';
p.trVarsInit.hueModeCode = 2;
p.trVarsInit.useSingleStimTraining = true;
p.trVarsInit.nSingleT1PerBlock = 25;
p.trVarsInit.nSingleT2PerBlock = 25;
p.trVarsInit.randomizeTargetIdentitySides = true;
p.trVarsInit.minTrialsPerBlock      = 10;
p.trVarsInit.maxTrialsPerBlock      = 50;

% A new target-onset -> fixation-offset delay is drawn for every trial.
% The sampled value remains fixed within that trial, and immediate repeats
% are excluded when this interval contains more than one millisecond.
p.trVarsInit.delay_ms_min = 300;
p.trVarsInit.delay_ms_max = 600;

% Three distinct, deterministic feedback tones for learning:
%   high-reward target = 900 Hz
%   low-reward target  = 450 Hz
%   failed trial       = 150 Hz
% Each tone lasts 100 ms and is played immediately before reward delivery
% (successful trials) or when the failure state is finalized.

p.trVarsInit.useThreeOutcomeTones = true;
p.audio.feedbackHighRewardFreqHz = 900;
p.audio.feedbackLowRewardFreqHz = 450;
p.audio.feedbackFailureFreqHz = 150;

p.trVarsGuiComm = p.trVarsInit;
end
