function p = rfMap_sparseBalanced_settings
%   p = rfMap_sparseBalanced_settings
%
% Settings file for rfMap sparse balanced noise mode. A small number of
% isolated bright/dark spots per frame on an otherwise mid-gray screen,
% with exactly N/2 white + N/2 black per frame (Twin-Deck/Pad-Block-
% Shuffle, ported from feng_LGN/create_sparsechecks.m). The balanced
% constraint eliminates whole-field mean-luminance modulation that
% contaminates STA in surround-suppressed cells (SC, etc.).
%
% Loads via the PLDAPS GUI: Browse  ->  this file  ->  Initialize  ->  Run.

%% pin stim type FIRST
p = struct;
p.init.stimType = 'sparse';

%% common configuration
p = rfMap_commonSettings(p);

%% stim-type-specific overrides
% Number of spots per frame. Must be even for the balanced TwinDeck
% constraint; if odd, the generator rounds down with a warning.
p.trVarsInit.nSparseSpots = 6;

% Use the new balanced TwinDeck generator. Set to 1 for the legacy
% uniform-random sparse path (regression-only; not for shipping).
p.trVarsInit.sparseBalancedFlag = 2;

%% strobe additions specific to sparse mode
p.init.strobeList = [p.init.strobeList; { ...
    'noiseNSparseSpots',        'p.trVars.nSparseSpots'; ...
    'rfMapSparseBalancedFlag',  'p.trVars.sparseBalancedFlag'; ...
    }];

%% finalize gui-comm mirror
p.trVarsGuiComm = p.trVarsInit;

end
