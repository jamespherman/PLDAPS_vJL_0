function p = initTrData(p)
%   p = initTrData(p)
%
% Initialize trial data variables at the start of each trial.
% Loop over list of variables defined in settings and assign
% initialization values.

for i = 1:p.init.nTrDataListRows

    % build string to be evaluated
    evalString = [p.init.trDataInitList{i, 1} ' = ' ...
        p.init.trDataInitList{i, 2} ';'];

    % evaluate string, assigning initialization value to variable.
    eval(evalString);
end

end
