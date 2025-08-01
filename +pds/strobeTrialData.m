function p = strobeTrialData(p)
%
% p = strobeTrialData(p)
%
%
% Loop over "p.init.strobeList" and strobe the strbCode (in 1st column)
% followed by the strbValue (2nd column).
%

% loop over p.init.strobeList and add strbCodes & strbValues to
% classyStrobe's list of values to strobe:

nStrobesToSend = size(p.init.strobeList, 1);
try
for ii = 1:nStrobesToSend

    strbCode = p.init.codes.(p.init.strobeList{ii, 1});
    strbVal  = eval(p.init.strobeList{ii, 2});
    
    % if each varCode is followed by 1 varVal then all's good:
    if isscalar(strbVal)
        % add variableCode and variableValue to list:
        p.init.strb.addValue(strbCode);
        p.init.strb.addValue(strbVal);
    end
    
    % if however there are multiple varVals, then strobe each of them,
    % preceded by the varCode (this happens, for example, during the
    % passFix task where we want to strobe the location of each od many
    % stimuli):
    if numel(strbVal) > 1
        for iV = 1:numel(strbVal)
            p.init.strb.addValue(strbCode);
            p.init.strb.addValue(strbVal(iV));
        end
    end
    
end
catch me
    keyboard
end

% strobe list of values.
p.init.strb.strobeList;

end