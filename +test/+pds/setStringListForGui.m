function stringList = setStringListForGui(inStruct)
%   stringList = setStringListForGui(inStruct)
%
% For a given input struct 'inStruct', the function takes each and every 
% field (including up to 1 substrcut) and creates a string out of the 
% fieldname. if the fieldname is a substracut the string has a perioud 
% ('.') in the name.

% 20180611 lnk &jph



stringList = {};

ii = 1;
flds1   = fieldnames(inStruct);
nFlds1  = numel(flds1);
for iF1 = 1:nFlds1
    % if field is not a struct, add its fieldname to the string list:
    if ~isstruct(inStruct.(flds1{iF1}))
        stringList{ii} = flds1{iF1};
        ii = ii+1;
    else
        % otherwise, create string that inlcudes the period:
        flds2 = fieldnames(inStruct.(flds1{iF1}));
        nFlds2 = numel(flds2);
        for iF2=1:nFlds2
            stringList{ii} = [flds1{iF1} '.' flds2{iF2}];
            ii = ii+1;
        end
    end
end
