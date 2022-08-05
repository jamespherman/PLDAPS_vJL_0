function p = updateStatusVariables(p)
%
% p = updateStatusVariables(p)
%

% iterate "good trial" count
p.status.iGoodTrial = p.status.iGoodTrial + double(~p.trData.trialRepeatFlag);

% iterator for visual & memeory saccades:
p.status.iGoodVis = p.status.iGoodVis + (p.trVars.isVisSac & double(~p.trData.trialRepeatFlag));
p.status.iGoodMem = p.status.iGoodMem + (~p.trVars.isVisSac & double(~p.trData.trialRepeatFlag));

% proportion good for visual & memeory saccades:
p.status.pGoodVis = p.status.iGoodVis / p.status.iGoodTrial;
p.status.pGoodMem = p.status.iGoodMem / p.status.iGoodTrial;

p.status.trialsLeftInBlock  = p.stim.nTargetLocations - (p.status.iTarget-1);


% 
% % was the last trial a "two patch" trial?
% twoPatch    = p.trVars.cueOn & p.trVars.foilOn;
% 
% % was the last trial location 1?
% loc1 = p.init.trialsArray(p.trVars.currentTrialsArrayRow,1) == 1;
% 
% % compute hit / correct reject counts and rates for each location
% % separately for single patch and two patch.
% p.status.cue1CtLoc1                 = p.status.cue1CtLoc1 + double(~twoPatch & loc1 & ismember(p.trData.trialEndState, [p.state.hit, p.state.miss])); % count of single patch cue change trials at location 1
% p.status.foil1CtLoc1                = p.status.foil1CtLoc1 + double(~twoPatch & loc1 & ismember(p.trData.trialEndState, [p.state.cr, p.state.foilFa])); % count of single patch foil change trials at location 1
% p.status.cue1CtLoc2                 = p.status.cue1CtLoc2 + double(~twoPatch & ~loc1 & ismember(p.trData.trialEndState, [p.state.hit, p.state.miss])); % count of single patch cue change trials at location 2
% p.status.foil1CtLoc2                = p.status.foil1CtLoc2 + double(~twoPatch & ~loc1 & ismember(p.trData.trialEndState, [p.state.cr, p.state.foilFa])); % count of single patch foil change trials at location 2
% p.status.cue2CtLoc1                 = p.status.cue2CtLoc1 + double(twoPatch & loc1 & ismember(p.trData.trialEndState, [p.state.hit, p.state.miss])); % count of two patch cue change trials at location 1
% p.status.foil2CtLoc1                = p.status.foil2CtLoc1 + double(twoPatch & loc1 & ismember(p.trData.trialEndState, [p.state.cr, p.state.foilFa])); % count of two patch foil change trials at location 1
% p.status.cue2CtLoc2                 = p.status.cue2CtLoc2 + double(twoPatch & ~loc1 & ismember(p.trData.trialEndState, [p.state.hit, p.state.miss])); % count of two patch cue change trials at location 2
% p.status.foil2CtLoc2                = p.status.foil2CtLoc2 + double(twoPatch & ~loc1 & ismember(p.trData.trialEndState, [p.state.cr, p.state.foilFa])); % count of two patch foil change trials at location 2
% 
% p.status.hc1Loc1                    = p.status.hc1Loc1 + double(~twoPatch & loc1 & p.trData.trialEndState == p.state.hit); % hit count for single patch at location 1
% p.status.crc1Loc1                   = p.status.crc1Loc1 + double(~twoPatch & loc1 & p.trData.trialEndState == p.state.cr); % correct reject count for single patch at location 1
% p.status.hc1Loc2                    = p.status.hc1Loc2 + double(~twoPatch & ~loc1 & p.trData.trialEndState == p.state.hit); % hit count for single patch at location 2
% p.status.crc1Loc2                   = p.status.crc1Loc2 + double(~twoPatch & ~loc1 & p.trData.trialEndState == p.state.cr); % correct reject count for single patch at location 2
% p.status.hc2Loc1                    = p.status.hc2Loc1 + double(twoPatch & loc1 & p.trData.trialEndState == p.state.hit); % hit count for two patch at location 1
% p.status.crc2Loc1                   = p.status.crc2Loc1 + double(twoPatch & loc1 & p.trData.trialEndState == p.state.cr); % correct reject count for two patch at location 1
% p.status.hc2Loc2                    = p.status.hc2Loc2 + double(twoPatch & ~loc1 & p.trData.trialEndState == p.state.hit); % hit count for two patch at location 2
% p.status.crc2Loc2                   = p.status.crc2Loc2 + double(twoPatch & ~loc1 & p.trData.trialEndState == p.state.cr); % correct reject count for two patch at location 2
% 
% p.status.hr1Loc1                    = p.status.hc1Loc1 / p.status.cue1CtLoc1; % hit rate for single patch at location 1
% p.status.cr1Loc1                    = p.status.crc1Loc1 / p.status.foil1CtLoc1; % correct reject rate for single patch at location 1
% p.status.hr1Loc2                    = p.status.hc1Loc2 / p.status.cue1CtLoc2; % hit rate for single patch at location 2
% p.status.cr1Loc2                    = p.status.crc1Loc2 / p.status.foil1CtLoc2; % correct reject rate for single patch at location 2
% p.status.hr2Loc1                    = p.status.hc2Loc1 / p.status.cue2CtLoc1; % hit rate for two patch at location 1
% p.status.cr2Loc1                    = p.status.crc2Loc1 / p.status.foil2CtLoc1; % correct reject rate for two patch at location 1
% p.status.hr2Loc2                    = p.status.hc2Loc2 / p.status.cue2CtLoc2; % hit rate for two patch at location 2
% p.status.cr2Loc2                    = p.status.crc2Loc2 / p.status.foil2CtLoc2; % correct reject rate for two patch at location 2
% 
% % calculate how many trials are left in the block
% p.status.trialsLeftInBlock          = nnz(p.status.trialsArrayRowsPossible);

end