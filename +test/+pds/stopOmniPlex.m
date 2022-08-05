function stopOmniPlex

% stopOmniPlex
%
% tells omniplex to pause recording via strobe through DATAPixx

Datapixx('SetDoutValues', 0, hex2dec('020000')) % set RSTART to 0
Datapixx('RegWrRd');

% waiting 50ms after sending stop command, just for good measure
WaitSecs(0.05);

end