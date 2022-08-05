function code = str2code(str, codes)
%   code = str2code(str, codes)
% 
% For a given str (e.g. 'trialBegin') the function returns the associated 
% code (e.g. 30001). Can hadle cellarray of strings.
%
% see code2str


if nargin < 2
    error('you must provide a code/str and a ''codes'' struct')
end


for ii = 1:numel(str)
    code(ii) = codes.(str{ii});
end

end

%%







