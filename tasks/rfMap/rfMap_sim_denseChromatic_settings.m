function p = rfMap_sim_denseChromatic_settings
%   p = rfMap_sim_denseChromatic_settings
%
% Simulation-mode wrapper for dense chromatic rfMap. Calls the real
% settings file and overrides passEye + useSimulatedSpikes so the task
% runs through the GUI without an animal or Ripple connection.

p = rfMap_denseChromatic_settings();

p.trVarsInit.passEye             = 1;
p.trVarsInit.useSimulatedSpikes  = true;

p.trVarsGuiComm = p.trVarsInit;

end
