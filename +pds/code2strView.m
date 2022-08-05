function [strings] = code2strView(codeValue, codes)
%   [strings] = code2strView(codeValue, codes)
% 
% For a given code value (e.g. 30001) the function returns the associated
% string (e.g. 'trialBegin'). Can hadle array of code values.
%
% see str2code

if nargin < 2
    error('you must provide a code/str and the ''codes'' struct')
end


codeList    = cellfun(@(x) codes.(x), fieldnames(codes));
strList     = fieldnames(codes);

for ii = 1:numel(codeValue)
    idx = codeValue(ii)==codeList;
    if sum(idx) == 1
        str{ii} = strList{idx};
    elseif sum(idx) == 0
        str{ii} = num2str(codeValue(ii));
    else
        error('values in the codeList are not unique. Big no no')
    end
end



%%


 for ii = 1:numel(str)
     strings{ii} = [str{ii} ' - ' num2str(codeValue(ii))];
 end
 strings = strings';

 disp(strings)







