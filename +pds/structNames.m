function namesOut = structNames(structIn, varargin)

namesOut = [];

fieldNames = fieldnames(structIn);

namesCount = 1;
for i = 1:length(fieldNames)
    if isstruct(structIn.(fieldNames{i}))
        if isempty(varargin)
            tempFieldNames = structNames(structIn.(fieldNames{i}), fieldNames{i});
        else
            tempFieldNames = structNames(structIn.(fieldNames{i}), [varargin{1} '.' fieldNames{i}]);
        end
        
        for j = 1:length(tempFieldNames)
            namesOut{namesCount, 1} = tempFieldNames{j};
            namesCount = namesCount + 1;
        end
    else
        if isempty(varargin)
            namesOut{namesCount, 1} = fieldNames{i};
        else
            namesOut{namesCount, 1} = [varargin{1} '.' fieldNames{i}];
        end
        namesCount = namesCount + 1;
    end
end

end