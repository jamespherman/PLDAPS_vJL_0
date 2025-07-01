function p = updateStatusVariables(p)
%
% p = updateStatusVariables(p)
%

% iterate "good trial" count
p.status.iGoodTrial = p.status.iGoodTrial + double(~p.trData.trialRepeatFlag);

% iterator for visual & memeory saccades:
p.status.iGoodVis = p.status.iGoodVis + (p.trVars.isVisSac & double(~p.trData.trialRepeatFlag));
p.status.iGoodMem = p.status.iGoodMem + (~p.trVars.isVisSac & double(~p.trData.trialRepeatFlag));

% iterator for two target and one vs two dot tasks:
p.status.iGoodOneTargetOneDot = p.status.iGoodOneTargetOneDot + (p.trVars.numTargets == 1 & (p.trVars.numDots == 1) & double(~p.trData.trialRepeatFlag));
p.status.iGoodOneTargetTwoDots = p.status.iGoodOneTargetTwoDots + (p.trVars.numTargets == 1 & (p.trVars.numDots == 2) & double(~p.trData.trialRepeatFlag));
p.status.iGoodTwoTargetOneDot = p.status.iGoodTwoTargetOneDot + (p.trVars.numTargets == 2 & (p.trVars.numDots == 1) & double(~p.trData.trialRepeatFlag));
p.status.iGoodTwoTargetTwoDots = p.status.iGoodTwoTargetTwoDots + (p.trVars.numTargets == 2 & (p.trVars.numDots == 2) & double(~p.trData.trialRepeatFlag));

p.status.iWrongOneTargetOneDot = p.status.iWrongOneTargetOneDot + (p.trVars.numTargets == 1 & (p.trVars.numDots == 1) & (p.trData.trialEndState == p.state.wrongTarget));
p.status.iWrongOneTargetTwoDots = p.status.iWrongOneTargetTwoDots + (p.trVars.numTargets == 1 & (p.trVars.numDots == 2) & (p.trData.trialEndState == p.state.wrongTarget));
p.status.iWrongTwoTargetOneDot = p.status.iWrongTwoTargetOneDot + (p.trVars.numTargets == 2 & (p.trVars.numDots == 1) & (p.trData.trialEndState == p.state.wrongTarget));
p.status.iWrongTwoTargetTwoDots = p.status.iWrongTwoTargetTwoDots + (p.trVars.numTargets == 2 & (p.trVars.numDots == 2) & (p.trData.trialEndState == p.state.wrongTarget));
            
% iterator for diff/same color and one vs two dot tasks:
p.status.iGoodUpTargsSameColor = p.status.iGoodUpTargsSameColor + (p.trVars.targsSameColor & (p.trVars.numDots == 1) & double(~p.trData.trialRepeatFlag));
p.status.iGoodUpTargsDiffColor = p.status.iGoodUpTargsDiffColor + (~p.trVars.targsSameColor & (p.trVars.numDots == 1) & double(~p.trData.trialRepeatFlag));
p.status.iGoodDownTargsSameColor = p.status.iGoodDownTargsSameColor + (p.trVars.targsSameColor & (p.trVars.numDots == 2) & double(~p.trData.trialRepeatFlag));
p.status.iGoodDownTargsDiffColor = p.status.iGoodDownTargsDiffColor + (~p.trVars.targsSameColor & (p.trVars.numDots == 2) & double(~p.trData.trialRepeatFlag));

p.status.iWrongUpTargsSameColor = p.status.iWrongUpTargsSameColor + (p.trVars.targsSameColor & (p.trVars.numDots == 1) & (p.trData.trialEndState == p.state.wrongTarget));
p.status.iWrongUpTargsDiffColor = p.status.iWrongUpTargsDiffColor + (~p.trVars.targsSameColor & (p.trVars.numDots == 1) & (p.trData.trialEndState == p.state.wrongTarget));
p.status.iWrongDownTargsSameColor = p.status.iWrongDownTargsSameColor + (p.trVars.targsSameColor & (p.trVars.numDots == 2) & (p.trData.trialEndState == p.state.wrongTarget));
p.status.iWrongDownTargsDiffColor = p.status.iWrongDownTargsDiffColor + (~p.trVars.targsSameColor & (p.trVars.numDots == 2) & (p.trData.trialEndState == p.state.wrongTarget));

% proportion good for visual & memeory saccades:
p.status.pGoodVis = p.status.iGoodVis / p.status.iGoodTrial;
p.status.pGoodMem = p.status.iGoodMem / p.status.iGoodTrial;

p.status.trialsLeftInBlock  = nnz(p.status.trialsArrayRowsPossible);


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
