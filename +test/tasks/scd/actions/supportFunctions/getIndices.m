function ix = getIndices(p)
%   ix = getIndices(p)
%
% gets indices for various trial types in pldaps 'p'. 


ix = struct; 

currentTrialsArrayRow = arrayfun(@(x) x.currentTrialsArrayRow, p.trVars);
trArrayRow = p.init.trialsArray(currentTrialsArrayRow,:);

trEndState = arrayfun(@(x) x.trialEndState, p.trData);

% indices for trials that have both the cue and the foil on:
ix.cueOn       = arrayfun(@(x) x.cueOn, p.trVars);
ix.foilOn      = arrayfun(@(x) x.foilOn, p.trVars);
ix.twoPatch    = ix.cueOn & ix.foilOn;

% indices for location of cue/foil:
ix.loc1        = trArrayRow(:,1) == 1;


%% cue indices:

% for 1 stim where CUE change is in location 1, 2, or either:
ix.n(1).cueLoc(:,1)      = ~ix.twoPatch &  ix.loc1 & any([trEndState == p.state.hit, trEndState == p.state.miss], 2);
ix.n(1).cueLoc(:,2)      = ~ix.twoPatch & ~ix.loc1 & any([trEndState == p.state.hit, trEndState == p.state.miss], 2); 
ix.n(1).cue             = ~ix.twoPatch & any([trEndState == p.state.hit, trEndState == p.state.miss], 2);
% for the hits in these trials:
ix.n(1).cueHitLoc(:,1)   = ix.n(1).cueLoc(:,1) & trEndState == p.state.hit;
ix.n(1).cueHitLoc(:,2)   = ix.n(1).cueLoc(:,2) & trEndState == p.state.hit;
ix.n(1).cueHit          = ix.n(1).cue & trEndState == p.state.hit;

% for 2 stim where CUE change is in location 1, 2, or either:
ix.n(2).cueLoc(:,1)      = ix.twoPatch &  ix.loc1 & any([trEndState == p.state.hit, trEndState == p.state.miss], 2); 
ix.n(2).cueLoc(:,2)      = ix.twoPatch & ~ix.loc1 & any([trEndState == p.state.hit, trEndState == p.state.miss], 2); 
ix.n(2).cue             = ix.twoPatch  & any([trEndState == p.state.hit, trEndState == p.state.miss], 2); 
% for the hits in these trials:
ix.n(2).cueHitLoc(:,1)   = ix.n(2).cueLoc(:,1) & trEndState == p.state.hit;
ix.n(2).cueHitLoc(:,2)   = ix.n(2).cueLoc(:,2) & trEndState == p.state.hit;
ix.n(2).cueHit          = ix.n(2).cue & trEndState == p.state.hit;

%% foil indices:

% for 1 stim where FOIL change is in location 1, 2, or either:
ix.n(1).foilLoc(:,1)     = ~ix.twoPatch &  ix.loc1 & any([trEndState == p.state.cr, trEndState == p.state.foilFa], 2); 
ix.n(1).foilLoc(:,2)     = ~ix.twoPatch & ~ix.loc1 & any([trEndState == p.state.cr, trEndState == p.state.foilFa], 2);
ix.n(1).foil            = ~ix.twoPatch & any([trEndState == p.state.cr, trEndState == p.state.foilFa], 2);
% for the foil-falseAlarm (fFa) in these trials:
ix.n(1).foilFaLoc(:,1)   = ix.n(1).foilLoc(:,1) & trEndState == p.state.foilFa;
ix.n(1).foilFaLoc(:,2)   = ix.n(1).foilLoc(:,2) & trEndState == p.state.foilFa;
ix.n(1).foilFa          = ix.n(1).foil & trEndState == p.state.foilFa;

% for 2 stim where FOIL change is in location 1, 2, or either:
ix.n(2).foilLoc(:,1)     = ix.twoPatch &  ix.loc1 & any([trEndState == p.state.cr, trEndState == p.state.foilFa], 2);
ix.n(2).foilLoc(:,2)     = ix.twoPatch & ~ix.loc1 & any([trEndState == p.state.cr, trEndState == p.state.foilFa], 2);
ix.n(2).foil            = ix.twoPatch & any([trEndState == p.state.cr, trEndState == p.state.foilFa], 2);
% for the foil-falseAlarm (fFa) in these trials:
ix.n(2).foilFaLoc(:,1)   = ix.n(2).foilLoc(:,1) & trEndState == p.state.foilFa;
ix.n(2).foilFaLoc(:,2)   = ix.n(2).foilLoc(:,2) & trEndState == p.state.foilFa;
ix.n(2).foilFa          = ix.n(2).foil & trEndState == p.state.foilFa;





