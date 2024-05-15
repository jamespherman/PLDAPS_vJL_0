% Initialize the fields for the new struct
fields = {'global', 'loc1', 'loc3'};

% Get the field names of the extractedData struct
extractedDataFields = fieldnames(extractedData);

% Loop through each of the 4 fields in the original struct
for i = 2:5
    % Get the field name
    fieldName = extractedDataFields{i};
    
    % Create a new struct for the current field
    newStruct = struct();
    
    % Loop through each field in the new struct
    for j = 1:numel(fields)
        % Get the field name
        subFieldName = fields{j};
        
        % Initialize an empty array to store the values
        newStruct.(subFieldName) = zeros(1, 48);
        
        % Loop through each of the 48 structs in the current field
        for k = 1:48
            % Get the current struct
            currStruct = extractedData.fieldName(k);
            
            % Assign the value to the corresponding cell in the new struct
            newStruct.(subFieldName)(k) = currStruct.(subFieldName);
        end
    end
    
    % Assign the new struct to the current field in the extractedData struct
    extractedData.(fieldName) = {newStruct};
end