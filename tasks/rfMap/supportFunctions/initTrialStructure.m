function p = initTrialStructure(p)
% p = initTrialStructure(p)
%
% Minimal trial structure for rfMap. This task doesn't have conditions
% to counterbalance -- each trial presents the next chunk of pre-generated
% noise. The trial array is a simple column of trial indices.

% Total noise frames and frames per trial:
frameDurS       = p.trVarsInit.noiseFrameHold * p.rig.frameDuration;
nNoiseFrames    = ceil(p.trVarsInit.movieDurationMin * 60 / frameDurS);
framesPerTrial  = round(p.trVarsInit.trialDurationS / frameDurS);
nTrials         = ceil(nNoiseFrames / framesPerTrial);

% Simple trial array: one row per trial, one column (trial index)
p.init.trialsArray = (1:nTrials)';
p.init.trialArrayColumnNames = {'trialIndex'};

% All trials available
p.status.trialsArrayRowsPossible = 1:nTrials;

fprintf('rfMap trial structure: %d trials (%.1f min movie, %.1f s/trial)\n', ...
    nTrials, p.trVarsInit.movieDurationMin, p.trVarsInit.trialDurationS);

end
