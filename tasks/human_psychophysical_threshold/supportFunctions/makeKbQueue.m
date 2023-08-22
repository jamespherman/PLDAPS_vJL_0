function p   = makeKbQueue(p)

% get list of keyboard devices attached to system:
[keyboardIndices, productNames] = GetKeyboardIndices;

% if we can find the exact match to the device we think we're using, use
% that one, otherwise, let the user indicate which keyboard should be used:
respDevMatchLogical = endsWith(productNames, 'Dell KB216 Wired Keyboard');
if any(respDevMatchLogical)
    respDevIdx = find(respDevMatchLogical);
else

% User input to let user decide which keyboard should be used as the input
% device.
respDevIdx = inputdlg(cell2mat(cellfun(@(x, y)[num2str(y) ...
    '. ' x ' | '], ...
    productNames, num2cell(1:length(productNames)), ...
    'UniformOutput', false)), ...
    'Select User Input Device', 1, {num2str(length(productNames))});
respDevIdx =str2double(respDevIdx{:});
end

% define response device index:
p.init.respDevIdx = keyboardIndices(respDevIdx);

% create keyboard "queue" for response device:
KbQueueCreate(p.init.respDevIdx);