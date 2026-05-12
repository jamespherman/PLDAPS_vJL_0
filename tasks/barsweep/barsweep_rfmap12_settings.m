function p = barsweep_rfmap12_settings
%  p = barsweep_rfmap12_settings
%
%  rfmap12 regime of the barsweep task: 12 directions (0:30:330) ->
%  6 unique orientations after opposite-direction pooling. Online RF
%  reconstruction is a true 2D filtered back-projection via iradon.
%
%  Shares the barsweep quintet (init/next/run/finish). Only differences
%  vs. barsweep_cardinal4_settings.m:
%    - p.init.exptType = 'barsweep_rfmap12'
%    - two extra strobe rows for iradon filter and cutoff
%
%  Implemented as a thin wrapper over barsweep_cardinal4_settings() so
%  the two regimes can never silently drift in any other field.

p = barsweep_cardinal4_settings();

p.init.exptType    = 'barsweep_rfmap12';

% rfmap12-only strobes: filter and cutoff influence the online image but
% are unused in cardinal4. Append rather than rebuild so any new shared
% strobes added later carry over automatically.
p.init.strobeList(end + 1, :) = ...
    {'barsweepRfRampCutoff_x100',  'round(p.trVars.rfRampCutoff * 100)'};
p.init.strobeList(end + 1, :) = ...
    {'barsweepRfRampFilter',       'pds.barsweepRampFilterEnum(p.trVars.rfRampFilter)'};

% Override the exptType strobe (1 in cardinal4 base) -> 2 for rfmap12.
exptRow = find(strcmp(p.init.strobeList(:, 1), 'barsweepExptType'), 1);
assert(~isempty(exptRow), ...
    'barsweep_rfmap12_settings: barsweepExptType row missing from base strobeList.');
p.init.strobeList{exptRow, 2} = '2';

end
