function p = rfMap_sim_denseAchromatic_settings
%   p = rfMap_sim_denseAchromatic_settings
%
% Simulation-mode wrapper for dense achromatic rfMap. Calls the real
% settings file and overrides passEye + useSimulatedSpikes so the task
% runs through the GUI without an animal or Ripple connection.
%
% If simPopulations/lgn_population_042.mat exists (created by
% sim_setup_population.m), it is loaded as the shared ground truth.

p = rfMap_denseAchromatic_settings();

p.trVarsInit.passEye             = 1;
p.trVarsInit.useSimulatedSpikes  = true;
p.trVarsInit.connectRipple       = 0;
p.trVarsInit.stimHemifield       = 'left';

popFile = fullfile(fileparts(mfilename('fullpath')), ...
    'simPopulations', 'lgn_population_042.mat');
if exist(popFile, 'file')
    p.trVarsInit.simPopulationFile = popFile;
end

p.trVarsGuiComm = p.trVarsInit;

end
