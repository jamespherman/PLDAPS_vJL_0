function p = initTrData(p)

%% trialData
% Here we define some vars that we aim to collect on every trial.
% These inlcude behavioral responses, timing of responses, analog data via
% datapixx, and more and more..

% loop over list of variables to be initialized and associated
% initialization values.
for i = 1:p.init.nTrDataListRows
    
    % build string to be evaluated
    evalString = [p.init.trDataInitList{i, 1} ' = ' p.init.trDataInitList{i, 2} ';'];
    
    % evaluate string, assigning initialization value to variable.
    eval(evalString);
end


end