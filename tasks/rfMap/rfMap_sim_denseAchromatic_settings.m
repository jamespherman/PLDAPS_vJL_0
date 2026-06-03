function p = rfMap_sim_denseAchromatic_settings
%   p = rfMap_sim_denseAchromatic_settings
%
% Simulation-mode wrapper for dense achromatic rfMap. Calls the real
% settings file and overrides passEye + useSimulatedSpikes so the task
% runs through the GUI without an animal or Ripple connection.
%
% Set p.trVarsInit.simPopulationFile to a .mat path (from
% simGeneratePopulation) to use a shared population instead of a
% fresh kernel bank.

p = rfMap_denseAchromatic_settings();

p.trVarsInit.passEye             = 1;
p.trVarsInit.useSimulatedSpikes  = true;

p.trVarsGuiComm = p.trVarsInit;

end
