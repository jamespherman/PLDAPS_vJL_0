function state = num2state(num, p)
%   state = num2state(code, p)
% 
% For a given state number ('num', e.g. 31) the function returns the 
% associated state string (e.g. 'fixBreak'). Can hadle array of codes.
%
% see state2num

if nargin < 2
    error('you must provide a num/state and the ''p'' struct')
end


numList    = cellfun(@(x) p.state.(x), fieldnames(p.state));
stateList  = fieldnames(p.state);

for ii = 1:numel(num)
    idx = num(ii)==numList;
    if sum(idx) == 1
        state{ii} = stateList{idx};
    elseif sum(idx) == 0
        state{ii} = num2str(num(ii));
    else
        error('values in the numList are not unique. Big no no')
    end
end

end

%%







