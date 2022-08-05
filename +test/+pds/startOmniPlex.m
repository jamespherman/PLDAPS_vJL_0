function startOmniPlex

% startOmniPlex
%
% tells omniplex system to "unpause" by sending a strobe over DATAPixx

Datapixx('SetDoutValues', 2^17, 131072) % set RSTART to 1
Datapixx('RegWrRd');

% waiting 100ms, otherwise subsequent strobes might not get registered by
% plexon
WaitSecs(0.1);

end