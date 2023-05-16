function p   = makeKbQueue(p)

% get list of keyboard devices attached to system:
[keyboardIndices, productNames] = GetKeyboardIndices;

% find 2nd one named "Dell KB216 Wired Keyboard"
respDevIdx = inputdlg(cell2mat(cellfun(@(x, y)[num2str(y) ...
    '. ' x ' | '], ...
    productNames, num2cell(1:length(productNames)), ...
    'UniformOutput', false)), ...
    'Select User Input Device', 1, {num2str(length(productNames))});
respDevIdx =str2double(respDevIdx{:});

% define response device index:
p.init.respDevIdx = keyboardIndices(respDevIdx);

% create keyboard "queue" for response device:
KbQueueCreate(p.init.respDevIdx);