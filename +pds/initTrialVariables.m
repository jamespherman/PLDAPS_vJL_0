function c = initTrialVariables(c)
%
% c = initTrialVariables(c)
%
% Initialize trial variables (set them to what they need to be at the
% beginning of a trial). The list "c.trialVars" is defined in the settings
% file.

% loop over "c.trialVars" to set variables to initialization values
% % % % for i = 1:c.nTrialVars
% % % %     c.(c.trialVars{i,1}) = c.trialVars{i,2};
% % % % end

for i = 1:c.nTrialVars
    evalc(['c.' c.trialVars{i,1} ' = c.trialVars{i,2};']);
end

end