function sArray = unifyStructArray(cellOfStructs)
%   sArray = unifyStructArray(cellOfStructs)
%
% Converts a cell array of structs into a struct array, adding missing
% fields (as empty []) to ensure all structs have identical field names.
% This enables concatenation of trial data where different trials may have
% different fields due to early termination (e.g., fixBreak trials).
%
% Input:
%   cellOfStructs - cell array where each element is a struct
%
% Output:
%   sArray - struct array with unified field names across all elements
%
% Example:
%   s1.a = 1; s1.b = 2;
%   s2.a = 3; s2.c = 4;  % s2 has 'c' but not 'b'
%   sArray = pds.unifyStructArray({s1, s2});
%   % Result: sArray(1).a=1, sArray(1).b=2, sArray(1).c=[]
%   %         sArray(2).a=3, sArray(2).b=[], sArray(2).c=4
%
% See also pds.loadP

% Handle empty input
if isempty(cellOfStructs)
    sArray = struct([]);
    return;
end

% Get union of all field names across all structs
allFields = {};
for i = 1:numel(cellOfStructs)
    if ~isempty(cellOfStructs{i})
        allFields = union(allFields, fieldnames(cellOfStructs{i}));
    end
end

% If no fields found, return empty struct array
if isempty(allFields)
    sArray = struct([]);
    return;
end

% Add missing fields to each struct (set to empty [])
for i = 1:numel(cellOfStructs)
    for j = 1:numel(allFields)
        if ~isfield(cellOfStructs{i}, allFields{j})
            cellOfStructs{i}.(allFields{j}) = [];
        end
    end
end

% Convert cell array to struct array
% Note: structs must have fields in same order for concatenation
% Re-order fields alphabetically to ensure consistency
for i = 1:numel(cellOfStructs)
    cellOfStructs{i} = orderfields(cellOfStructs{i});
end

sArray = [cellOfStructs{:}]';

end
