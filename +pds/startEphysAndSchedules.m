function startEphysAndSchedules

% startEphysAndSchedules
%
% unpause recording and start ADC schedule.

% start omniplex
pds.startOmniPlex;

% start ADC schedule
Datapixx('StartAdcSchedule');
Datapixx('RegWrRd');

end