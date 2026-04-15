function p = initTrData(p)
% p = initTrData(p)
%
% Initialize per-trial data fields from the list defined in _settings.m.
% Uses eval to assign initial values from string expressions.

for i = 1:p.init.nTrDataListRows
    evalString = [p.init.trDataInitList{i, 1} ' = ' ...
                  p.init.trDataInitList{i, 2} ';'];
    eval(evalString);
end

end
