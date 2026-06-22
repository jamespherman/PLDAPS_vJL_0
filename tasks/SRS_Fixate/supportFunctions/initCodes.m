function codes = initCodes
% task-specific function that initializes codes used by a certain task to 
% strobe events to the ehpys recording system.
% These are the same codes that will be identify events in the ephys file
% so this file is holy. Once a task has been used in a recording session,
% this file is the only way to retrieve the data.
% WARNING: do not change this file. Ever. new task - new initCodes.m.



%% currently using fst codse...

% trial codes
codes.trialBegin        = 30001; %1001;
codes.trialEnd          = 30009; %1009;
codes.connectPLX        = 11001;
codes.trialCount        = 11002;
codes.blockNumber       = 11003;
codes.trialInBlock      = 11004;
codes.setNumber         = 11005;
codes.state             = 11008;
codes.trialCode         = 11009;
codes.trialType         = 11010;
codes.fileSufix         = 11011; 
codes.taskType          = 11099;
codes.goodTrialCount    = 11100;

% 1 = Visually guided saccades; 2 = Memory guided saccades; 3 = Attn Motion
% task; 4 = Microstimulation; 5- dir tuning; 6- Orn tuning; 7 - Attn Orn
% Task; 8 - RF mapping; 9-object tuning task; 10-Aud tuning; 11 -vis guided
% choicetask; 12 - mem guided chocie task
codes.repeat20          = 11098; % 1 = 20 repeat trials during MemSac task.
codes.vissac            = 11097; % 1 = vis sac; 0 = memsac protocol
codes.inactivation      = 11095; % during inactivation
codes.useMotionStim     = 11094; % use motion stim for mapping

% joystick codes
codes.joyPress          = 2001;
codes.joyRelease        = 2002;
codes.joyBreak          = 2005;
codes.nonStart          = 2004;

% fixation codes
codes.fixOn             = 3001;
codes.fixDim            = 3002;
codes.fixOff            = 3003;
codes.fixAq             = 3004;
codes.fixBreak          = 3005;
codes.fixBreak2         = 3006; % this is if monkey breaks fixation whennot holding joystick in attn task
codes.fixTheta          = 13001;
codes.fixRadius         = 13002;
codes.fixDimValue       = 13003;
codes.fixChangeTrial    = 13004;

% saccade codes (used in VisSac and MemSac tasks)
codes.saccadeOnset      = 2003;
codes.saccadeOffset     = 2004;

% target codes (used in VisSac and MemSac tasks)
codes.targetOn          = 4001;
codes.targetDim         = 4002;
codes.targetOff         = 4003;
codes.targetAq          = 4004;
codes.targetFixBreak    = 4005;
codes.targetReillum     = 4006; % target reillumination after a successful memory guided saccade
codes.targetTheta       = 14001;
codes.targetRadius      = 14002;

% cue codes (used in Attn tasks)
codes.cueOn             = 5001;
codes.cueOff            = 5003;
codes.stimLoc1Elev      = 15001;
codes.stimLoc1Ecc       = 15002;
codes.stimLoc2Elev      = 15003;
codes.stimLoc2Ecc       = 15004;

% stimulus codes (used in Attn tasks)
codes.stimOn                    = 6002;
codes.stimOff                   = 6003;
codes.cueChange                 = 6004;
codes.foilChange                = 6005;
codes.noChange                  = 6006;
codes.isCueChangeTrial          = 6007;
codes.isFoilChangeTrial         = 6008;
codes.isNoChangeTrial           = 6009;
codes.cueMotionDelta            = 6010;
codes.foilMotionDelta           = 6011;
codes.cueStimIsOn               = 6012; % cued stimulus was shown in this trial
codes.foilStimIsOn              = 6013; % foil stimulus was shown in this trial
codes.isContrastChangeTrial     = 6014; % this trial had a contrast change
codes.hit                       = 6015; % this trial ended in a hit
codes.miss                      = 6016; % this trial ended in a miss
codes.foilFa                    = 6017; % this trial ended in a foil FA
codes.cr                        = 6018; % this trial ended in a CR
codes.fa                        = 6019; % this trial ended in a FA
codes.rfLocEcc                  = 16001;
codes.rfLocTheta                = 16002;
codes.stimChangeTrial           = 16003;
codes.changeLoc                 = 16004;

% codes for PA motion task
codes.loc1dir           = 16005;
codes.loc2dir           = 16006;
codes.loc1del           = 16007;
codes.loc2del           = 16008;

% codes for PA orientation task
codes.loc1orn           = 16005;
codes.loc2orn           = 16006;
codes.loc1amp           = 16007;
codes.loc2amp           = 16008;

% code for motion directions in dir tuning task
codes.motDir            = 24000; % this is to send stim info; for eevnt codes for each dir see trialcodes.dirtun.m

% code for orientations in orn tuning task
codes.orn               = 25000; % this is to send stim info; for eevnt codes for each orn see trialcodes.orntun.m

% reward code
codes.reward            = 8000;
codes.rewardDuration    = 18000;

% micro stim codes
codes.microStimOn       = 7001;

% audio codes
codes.audioFBKon        = 9000;
codes.lowTone           = 9001;
codes.noiseTone         = 9002;
codes.highTone          = 9003;

% code for random number generation seeds
codes.stimSeed          = 16666;
codes.trialSeed         = 16667;

