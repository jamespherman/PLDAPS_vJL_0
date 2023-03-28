function p   = makeKbQueue(p)

% get list of keyboard devices attached to system:
[keyboardIndices, productNames] = GetKeyboardIndices;

% find 2nd one named "Dell KB216 Wired Keyboard"
respDevIdx = find(...
    contains(productNames, 'Dell KB216 Wired Keyboard') & ...
    ~contains(productNames, 'Control'), ...
    1, 'first');

% define response device index:
p.init.respDevIdx = keyboardIndices(respDevIdx);

% create keyboard "queue" for response device:
KbQueueCreate(p.init.respDevIdx);