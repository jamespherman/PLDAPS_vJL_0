function p = initTrialStructure(p)
% p = initTrialStructure(p)
%
% Build the trial array. Stim-type-conditional:
%
%   denseAchromatic / denseChromatic / sparse:
%     The noise movie is presented continuously across trials; trials
%     just chunk the playback. One column ('trialIndex'), one row per
%     chunk.
%
%   checkerboard:
%     Each trial presents a fixed (checkSize, contrast) condition for
%     the trial duration. Pseudorandom-without-replacement permutation
%     of nRepsPerCondition copies of each (size, contrast) pair, so
%     every condition gets the same number of trials and the order is
%     balanced. Columns:
%        1: trialIndex
%        2: checkSizeIdx       (1..nCheckSize)
%        3: contrastIdx        (1..nContrast)
%        4: completed          (filled in at trial end)

if isfield(p, 'init') && isfield(p.init, 'stimType') && ...
        strcmp(p.init.stimType, 'checkerboard')
    p = initTrialStructure_checkerboard(p);
else
    p = initTrialStructure_noiseMovie(p);
end

end


function p = initTrialStructure_noiseMovie(p)
% Continuous-movie chunking (denseAchromatic, denseChromatic, sparse).

frameDurS       = p.trVarsInit.noiseFrameHold * p.rig.frameDuration;
nNoiseFrames    = ceil(p.trVarsInit.movieDurationMin * 60 / frameDurS);
framesPerTrial  = round(p.trVarsInit.trialDurationS / frameDurS);
nTrials         = ceil(nNoiseFrames / framesPerTrial);

p.init.trialsArray = (1:nTrials)';
p.init.trialArrayColumnNames = {'trialIndex'};
p.status.trialsArrayRowsPossible = 1:nTrials;

fprintf('rfMap trial structure: %d trials (%.1f min movie, %.1f s/trial)\n', ...
    nTrials, p.trVarsInit.movieDurationMin, p.trVarsInit.trialDurationS);

end


function p = initTrialStructure_checkerboard(p)
% Per-condition counterbalanced trial array for checkerboard.

nCheckSize = numel(p.trVarsInit.checkSizesDva);
nContrast  = numel(p.trVarsInit.checkContrasts);
nReps      = p.trVarsInit.checkRepsPerCondition;

% Build (sz, ct) pairs repeated nReps times each.
[szGrid, ctGrid] = ndgrid(1:nCheckSize, 1:nContrast);
sizesCol     = repmat(szGrid(:), nReps, 1);
contrastsCol = repmat(ctGrid(:), nReps, 1);

% Pseudorandom permutation. Use a fixed seed so the trial order is
% reproducible across runs of the same settings. Read from
% p.trVarsInit (settings-time) since this runs before
% generateStimForTask sets p.init.noiseRngSeed.
rngState = rng();   % save current state
rng(p.trVarsInit.noiseRngSeed, 'twister');
permIdx = randperm(numel(sizesCol));
rng(rngState);      % restore (so global RNG isn't disturbed)

trialIndex = (1:numel(sizesCol))';
sizesCol     = sizesCol(permIdx);
contrastsCol = contrastsCol(permIdx);
completedCol = zeros(numel(trialIndex), 1);

p.init.trialsArray = [trialIndex, sizesCol, contrastsCol, completedCol];
p.init.trialArrayColumnNames = ...
    {'trialIndex', 'checkSizeIdx', 'contrastIdx', 'completed'};
p.status.trialsArrayRowsPossible = 1:numel(trialIndex);

fprintf(['rfMap trial structure (checkerboard): %d trials = ' ...
    '%d sizes x %d contrasts x %d reps\n'], ...
    numel(trialIndex), nCheckSize, nContrast, nReps);

end
