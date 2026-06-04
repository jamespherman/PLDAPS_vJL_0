% sim_setup_population.m
%
% Run this ONCE before using the rfMap_sim_*_settings wrappers in the GUI.
% Generates a shared LGN population file that the sim wrappers auto-detect.
%
% After running this, the GUI workflow is:
%   1. Browse -> rfMap_sim_checkerboard_settings.m -> Initialize -> Run
%      (run ~48-108 trials for pre-screening)
%   2. Browse -> rfMap_sim_denseAchromatic_settings.m -> Initialize -> Run
%      (run ~500 trials for RF center estimation)
%   3. After stopping, run sim_evaluate_session.m from the command window
%      (or use pdsActions.evaluateRFQuality from the GUI action menu)

projRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));

popDir = fullfile(fileparts(mfilename('fullpath')), 'simPopulations');
if ~isfolder(popDir), mkdir(popDir); end

popFile = fullfile(popDir, 'lgn_population_042.mat');

if exist(popFile, 'file')
    fprintf('Population file already exists: %s\n', popFile);
    fprintf('Delete it first if you want to regenerate.\n');
    tmp = load(popFile, 'population');
    pop = tmp.population;
else
    pop = simGeneratePopulation( ...
        'nNeurons',          12, ...
        'nChannels',         64, ...
        'hemifield',         'left', ...
        'eccentricityRange', [2 5], ...
        'elevationRange',    [-3 3], ...
        'seed',              42, ...
        'baseRate',          2, ...
        'peakRate',          20, ...
        'saveFile',          popFile);
end

% Print ground truth for reference.
fprintf('\n=== GROUND TRUTH RF LOCATIONS ===\n');
fprintf('  ch | type | center (x, y) dva | sigma_c (dva)\n');
fprintf('  ---+------+-------------------+--------------\n');
for k = 1:numel(pop.neurons)
    n = pop.neurons(k);
    fprintf('  %2d |   %s  | (%+5.1f, %+5.1f)    | %.3f\n', ...
        n.channelIdx, n.cellType, n.centerDeg(1), n.centerDeg(2), ...
        n.sigmaCenterDeg);
end
fprintf('\n  Noise channels: %d (of %d total)\n', ...
    numel(pop.noiseChannels), pop.nChannels);
fprintf('\n  Population file: %s\n', popFile);
fprintf('\n  Next: load rfMap_sim_checkerboard_settings in the GUI.\n');
