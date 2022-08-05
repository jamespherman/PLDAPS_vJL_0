function num = state2num(state, p)
%   code = state2num(str, p)
% 
% For a given state (e.g. 'fixBreak') the function returns the associated 
% code (e.g. 31). Can hadle cellarray of strings.
%
% see num2state


if nargin < 2
    error('you must provide a num/state and the ''p'' struct')
end


for ii = 1:numel(state)
    num(ii) = p.init.codes.(state{ii});
end

end

%%







