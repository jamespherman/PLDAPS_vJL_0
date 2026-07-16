function codes = initCodes
%   codes = pds.initCodes
%
% PAN-TASK function that initializes codes used to strobe events to the 
% ehpys recording system.
% These are the same codes that will identify events in the ephys file
% so this file is HOLY. 
% Once recording has been done, this file is the only way to reconstruct 
% the data so I'm not kidding-- H O L Y.
%
% For every new taks you code, it will likely use many event codes that are
% already present in this file. Enjoy them. For any new codes you might
% need, just add them to this file and verify that don't overlap with
% existing codes by running the verification cell at the bottom. 

% two kinds of strobes:
% Paired-strobe
% timing-strobe

%% task code
% Paired-strobe. Its pair is a unique task code that is set in the
% settings file, and takes the value of one of the unique task codes 
% defined in the cell "holy unique task codes", below.
codes.taskCode          = 32000;

%% holy unique task codes:
% Each task gets its own unique task code for easy identification. These
% are the values that are strobed after taskCode is strboed. 
codes.uniqueTaskCode_mcd        	= 32001;
codes.uniqueTaskCode_gSac    		= 32002;
codes.uniqueTaskCode_freeView   	= 32003;
codes.uniqueTaskCode_pFix       	= 32004;
codes.uniqueTaskCode_pFixLfp    	= 32005;
codes.uniqueTaskCode_pFixMotDir 	= 32006;
codes.uniqueTaskCode_mFlash     	= 32007;
codes.uniqueTaskCode_tod        	= 32008;
codes.uniqueTaskCode_scd        	= 32009;
codes.uniqueTaskCode_nfl        	= 32010;
codes.uniqueTaskCode_gSac_jph  		= 32011;
codes.uniqueTaskCode_gSac_contrast  	= 32012;
codes.uniqueTaskCode_seansFirstTask 	= 32013;
codes.uniqueTaskCode_tokens         	= 32014;
codes.uniqueTaskCode_gSac_4factors  	= 32015;
codes.uniqueTaskCode_conflict_task  	= 32016;
codes.uniqueTaskCode_numerosity         = 32017;
codes.uniqueTaskCode_sacc_to_phosph     = 32019;
codes.uniqueTaskCode_rfMap              = 32020;
codes.uniqueTaskCode_barsweep           = 32022;
codes.uniqueTaskCode_SRS_task           = 32023;

%% unique codes that are internal to the 'classyStrobe' function class
% (see pds.classyStrobe.m for more details)
ss                  = pds.classyStrobe;
codes.isCell        = ss.internalStrobeCodes.isCell;
codes.cellLength    = ss.internalStrobeCodes.cellLength;


%% currently using fst codse...

% trial codes
codes.trialBegin        = 30001; % The very beginning of a trial
codes.trialRunDone      = 30008; % End of trial loop in _run.m: behavioral execution complete (eye/joy polling stopped, state machine done). Distinct from trialEnd, which closes the trial record in _finish.m after parameter strobes.
codes.trialEnd          = 30009; % End of trial record in _finish.m: emitted after pds.strobeTrialData, before any post-trial waits. Inter-strobe gap trialEnd[N] -> fixOn[N+1] contains iti/timeout/postRewardDuration only.
codes.connectPLX        = 11001; % ???
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
codes.goodtrialornot    = 21101;
codes.trialEndState 	= 11101;
% Gongchen Added on 2019/12/30 I think it is better than goodTrialCount
                                 % Also I think these codes are better
                                 % start from '2~9' rather than 1, because
                                 % the code.time_1hhmm can sometimes contaminate the code  
%%  date & time
% these codes have a '1' before the date/time signifiers because a given
% date could lose its 0, e.g. the time_hhmm: 0932, would be sent as 932. By
% adding a '1' we get 10932, thus saving the 0. As long as user remembers
% to remove the first digit from the strobed values, we're all good.
codes.date_1yyyy      = 11102;
codes.date_1mmdd      = 11103;
codes.time_1hhmm      = 11104;

%%
codes.repeat20          = 11098; % 1 = 20 repeat trials during MemSac task.
codes.vissac            = 11097; % 1 = vis sac; 0 = memsac protocol
codes.inactivation      = 11095; % during inactivation
codes.useMotionStim     = 11094; % use motion stim for mapping


%% end of trial codes:
% code to represent a trial non strat
codes.nonStart              = 22004;
codes.joyBreak              = 2005;
codes.fixBreak          = 3005;
codes.fixBreak2         = 3006; % this is if monkey breaks fixation whennot holding joystick in attn task

codes.saccToTargetOne	= 3007; % Used to identify which target monkey made a saccade to
codes.saccToTargetTwo	= 3008;
codes.noResponse        = 3009; % no saccade within response window (conflict_task)
codes.inaccurate        = 3010; % saccade landed outside target window(s)


%% optical stimulation codes
codes.optoStimOn        = 17001;
codes.optoStimTrial     = 17002;
codes.optoStimSham      = 17003;

%% joystick codes
codes.joyPress              = 2001;
codes.joyRelease            = 2002;
codes.joyPressVoltDir       = 2010; 
codes.passJoy               = 2011;

%% fixation codes
codes.fixOn             = 3001;
codes.fixDim            = 3002;
codes.fixOff            = 3003;
codes.fixAq             = 3004;
codes.fixTheta          = 13001;
codes.fixRadius         = 13002;
codes.fixDimValue       = 13003;
codes.fixChangeTrial    = 13004;

%% saccade codes (used in gSac)
codes.saccadeOnset      = 2003;
codes.saccadeOffset     = 2004;
codes.blinkDuringSac    = 2007;

%% target codes (used in gSac)
codes.targetOn          = 4001;
codes.targetDim         = 4002;
codes.targetOff         = 4003;
codes.targetAq          = 4004;
codes.targetFixBreak    = 4005;
codes.targetReillum     = 4006; % target reillumination after a successful memory guided saccade
codes.targetTheta       = 14001;
codes.targetRadius      = 14002;

%% cue codes (used in mcd)
codes.cueOn             = 5001;
codes.cueOff            = 5003;
codes.stimLoc1Elev      = 15001;
codes.stimLoc1Ecc       = 15002;
codes.stimLoc2Elev      = 15003;
codes.stimLoc2Ecc       = 15004;

%% stimulus codes (used in mcd, pFix, etc.)

codes.stimOnDur                 = 5991;
codes.stimOffDur                = 5992;
codes.stimOn                    = 6002; % timing
codes.stimOff                   = 6003; % timing

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
codes.stimChange                = 6020;
codes.noChange                  = 6021;
codes.isStimChangeTrial         = 6022;
codes.isNoChangeTrial           = 6023;
codes.stimLoc1On                = 6024; % stimulus at location one was on in this trial
codes.stimLoc2On                = 6025; % stimulus at location one was on in this trial
codes.stimLoc3On                = 6026; % stimulus at location one was on in this trial
codes.stimLoc4On                = 6027; % stimulus at location one was on in this trial
codes.stimChangeTrial           = 16003;
codes.chgLoc                    = 16004;
codes.cueLoc                    = 16005;

% stimulus location & direction:
codes.stimLocRadius_x100  = 16001; % used to be named 'rfLocEcc'
codes.stimLocTheta_x10    = 16002; % used to be named 'rfLocTheta'
codes.stimMotDir          = 24000; % this is to send stim info; for eevnt codes for each dir see trialcodes.dirtun.m

% code for random number generation seeds
codes.stimSeed          = 16666;
codes.trialSeed         = 16667;

% code for orientations in orn tuning task
codes.orn               = 25000; % this is to send stim info; for eevnt codes for each orn see trialcodes.orntun.m

% reward code
codes.reward            = 8000;
codes.freeReward        = 8001;
codes.noFreeReward      = 8002;
codes.rewardDuration    = 18000;

% micro stim codes
codes.microStimOn       = 7001;
codes.microStimChannel  = 17101;
codes.microStimCurrAmp  = 17102;
codes.microStimPolarity = 17103;

% audio codes
codes.audioFBKon        = 9000;
codes.lowTone           = 9001;
codes.noiseTone         = 9002;
codes.highTone          = 9003;

% image codes (used in freeview)
codes.imageId           = 6660;     % id of image
codes.imageOn           = 6661;     % time of image onset
codes.imageOff          = 6662;     % time of image offset
codes.freeViewDur       = 6663;     % duration of free image viewing

% tokens task codes
codes.CUE_ON = 5; % [cite: 1]
codes.REWARD_GIVEN = 7; % [cite: 1]
codes.TRIAL_END = 6; % [cite: 1]
codes.REWARD_AMOUNT_BASE = 100; % Base for strobing reward amount [cite: 1]
codes.OUTCOME_DIST_BASE = 90; % Base for strobing outcome distribution type [cite: 1]
codes.rwdAmt = 101;

% gSac_4factors codes
codes.halfBlock     = 16010;
codes.stimType      = 16011;
codes.salience      = 16012;
codes.targetColor   = 16013;
codes.targetLocIdx  = 16014;

% conflict_task codes
codes.deltaT                = 16020;  % stimulus onset asynchrony (value + 1000 to handle negatives)
codes.highRewardLocation    = 16021;  % 1=A, 2=B
codes.highSalienceLocation  = 16022;  % 1=A, 2=B (same as highSalienceSide)
codes.hueType               = 16025;  % 1 or 2 (counterbalanced color scheme)
codes.chosenTarget          = 16023;  % 1=A, 2=B, 0=neither (same as chosenSide)
codes.outcomeCode           = 16024;  % 1=goal-directed, 2=capture, 3+=error types
codes.phaseNumber           = 16026;  % experimental phase (1, 2, or 3)
codes.rewardDurationLeft    = 16027;  % reward duration for left target (ms)
codes.rewardDurationRight   = 16028;  % reward duration for right target (ms)
codes.choseHighSalience     = 16029;  % 0 or 1: did subject choose high salience target?
codes.leftTargTheta         = 16030;  % left target angle (degrees * 10, add 1800 for negatives)
codes.leftTargRadius        = 16031;  % left target eccentricity (degrees * 100)
codes.rightTargTheta        = 16032;  % right target angle (degrees * 10, add 1800 for negatives)
codes.rightTargRadius       = 16033;  % right target eccentricity (degrees * 100)
codes.singleStimSide        = 16034;  % 0=dual, 1=single-left, 2=single-right
codes.rewardRatioBig_x100   = 16035;  % reward ratio * 100 (e.g., 2.0 -> 200)
codes.rewardProbHigh_x1000  = 16036;  % P(canonical reward) * 1000 (e.g., 0.9 -> 900)

% rfMap task codes (dense noise RF mapping)
codes.noiseOn               = 16101;  % DEPRECATED 2026-05-18: superseded by generic stimOn (6002) for cross-task consistency. Number reserved, do not reuse.
codes.noiseOff              = 16102;  % DEPRECATED 2026-05-18: superseded by generic stimOff (6003) for cross-task consistency. Number reserved, do not reuse.
codes.noiseCheckSize_x100   = 16103;  % check size in degrees * 100
codes.noiseFrameHold        = 16104;  % display frames per noise update
codes.noiseColorMode        = 16105;  % DEPRECATED post-rfMap unified merge: superseded by rfMapStimType (16140). Number reserved, do not reuse.
codes.noiseRngSeed          = 16106;  % RNG seed (lower 16 bits)
codes.noiseRngSeedHigh      = 16107;  % RNG seed (upper 16 bits)
codes.noiseTrialFrameStart  = 16108;  % starting frame index in movie (this trial)
codes.noiseTrialFrameEnd    = 16109;  % ending frame index in movie (this trial)
codes.noiseTotalFrames      = 16110;  % total frames in movie (clamped to 32767)
codes.noiseGridW            = 16111;  % noise grid width (number of checks)
codes.noiseGridH            = 16112;  % noise grid height (number of checks)
codes.noiseStimMode         = 16113;  % DEPRECATED post-rfMap unified merge: superseded by rfMapStimType (16140). Old session meaning was 1=dense, 2=sparse; new stimType enum is 1=denseAchro, 2=denseChroma, 3=sparse, 4=checker. Number reserved, do not reuse.
codes.noiseNSparseSpots     = 16114;  % spots per frame in sparse mode

% barsweep task codes (translating bar sweep, passive fixation)
codes.barsweepAngle_x10           = 16115;  % path angle * 10 (0..3600)
codes.barsweepCenterTheta_x10     = 16116;  % path center polar angle * 10 + 1800
codes.barsweepCenterRadius_x100   = 16117;  % path center eccentricity * 100
codes.barsweepPathLength_x100     = 16118;  % path length (dva) * 100
codes.barsweepSpeed_x100          = 16119;  % speed (dva/s) * 100
codes.barsweepWidth_x100          = 16120;  % bar thickness (dva) * 100
codes.barsweepLength_x100         = 16121;  % bar end-to-end length (dva) * 100
codes.barsweepFixTheta_x10        = 16122;  % fix point polar angle * 10 + 1800
codes.barsweepFixRadius_x100      = 16123;  % fix point eccentricity * 100
codes.barsweepFixWinWidth_x100    = 16124;  % fix window width (dva) * 100
codes.barsweepFixWinHeight_x100   = 16125;  % fix window height (dva) * 100
codes.barsweepStimMode            = 16126;  % 1 = noise, 2 = solid
codes.barsweepBgLumIdx            = 16127;  % background luminance palette index
codes.barsweepBarLumIdx           = 16128;  % bar luminance palette index (solid mode)
codes.barsweepNoiseLumLowIdx      = 16129;  % low-luminance palette index (noise mode)
codes.barsweepNoiseLumHighIdx     = 16130;  % high-luminance palette index (noise mode)
codes.barsweepNoiseGrain_x100     = 16131;  % noise check size (dva) * 100

% Online RF-mapping additions (cardinal4 + rfmap12 regimes)
codes.barsweepExptType            = 16132;  % 1 = cardinal4, 2 = rfmap12
codes.barsweepRfLatency           = 16133;  % response latency (ms, 1 ms resolution)
codes.barsweepRfPosBin_x100       = 16134;  % position-bin width (dva) * 100
codes.barsweepRfRampCutoff_x100   = 16135;  % iradon cutoff * 100 (rfmap12 only)
codes.barsweepRfRampFilter        = 16136;  % 1=Ram-Lak, 2=Hann, 3=Shepp-Logan, 4=Cosine (rfmap12 only)

% rfMap unified merge codes (post-Phase-1 of rfMap_unified_merge_plan.md)
% Reserved range: 16140-16175 (36 codes total). 16137-16139 left as a gap
% between the barsweep block and rfMap block for visual separation.
codes.rfMapStimType                  = 16140;  % 1=denseAchro, 2=denseChroma, 3=sparse, 4=checker
codes.rfMapSessionFormatVersion      = 16141;  % schema version (integer)
codes.rfMapDklAxisIdx                = 16142;  % DKL axis index (1=L-M, 2=S, 3=achromatic, 4=mixed) -- Phase 2
codes.rfMapDklContrast_x100          = 16143;  % DKL contrast * 100                                  -- Phase 2
codes.rfMapDklHue_x10                = 16144;  % DKL hue (deg) * 10 (0..3600)                        -- Phase 2
codes.rfMapDklCalibSource            = 16145;  % 1=measured_primaries, 2=vendor_primaries            -- Phase 2
codes.rfMapCheckSizeIdx              = 16146;  % index into checkSizesDva                            -- Phase 3
codes.rfMapCheckContrastIdx          = 16147;  % index into checkContrasts                           -- Phase 3
codes.rfMapCheckReversalHz_x10       = 16148;  % reversal rate (Hz) * 10                             -- Phase 3
codes.rfMapCheckPolaritySign         = 16149;  % 1 = +1 polarity, 2 = -1 polarity                    -- Phase 3
codes.rfMapCheckReversalEvent        = 16150;  % strobed at each reversal flip (value = polarity)    -- Phase 3
% 16151-16157 reserved-but-unused (jitter/aperture features cancelled
% before implementation; never strobed in any session, but do not reuse
% per the "holy" rule). See rfMap_unified_merge_plan.md goal section.
codes.rfMapSparseBalancedFlag        = 16158;  % 1 = uniform-random (legacy), 2 = balanced TwinDeck
codes.rfMapRngSeedHigh               = 16159;  % RNG seed upper 16 bits (lower 16 in noiseRngSeed 16106)
codes.rfMapNoiseCycleCount           = 16160;  % # times the pre-generated noise movie has wrapped (0 = first pass)
codes.rfMapStimHemifield              = 16161;  % 0=full, 1=left, 2=right
% 16162-16169 reserved for future per-stim-type params
% 16170-16175 reserved as headroom




%% Codes for SRS_Task

% codes.CurrentBlockNumber            = 20000; % Current Block Number
% codes.CurrentBlockType              = 20001; % 1 = T1 Rich ; 2 = T2 Rich
% codes.ActualTrialType               = 20002; % 1 = Congruent ; 2 = Conflict
% codes.ActualRichReward              = 20003; % Actual Reward with the gaussian noise for Rich target (depends on the blocktype and TrialType)
% codes.ActualPoorReward              = 20004; % Actual Reward with the gaussian noise for Poor target (depends on the blocktype and TrialType)
% codes.salienceType                  = 20005; %1 = Hue ; 2 = Luminance
% codes.ActualLuminanceT1             = 20006; %Luminance Value for T1
% codes.ActualLuminanceT2             = 20007; %Luminance Value for T2
% codes.LuminanceDifferenceT1MinusT2_x1000 =20008;
% codes.backgroundHueIdx = 20009;              % Background hue condition: 1 = DKL 0 background, 2 = DKL 180 background
% codes.ActualHueT1_x1000 = 20010;             % T1 DKL hue angle in degrees x1000
% codes.ActualHueT2_x1000 = 20011;             % T2 DKL hue angle in degrees x1000
% codes.BackgroundHue_x1000 = 20012;           % Background DKL hue angle in degrees x1000
% codes.HueContrastT1_x1000 = 20013;           % T1 hue distance from background in degrees x1000
% codes.HueContrastT2_x1000 = 20014;           % T2 hue distance from background in degrees x1000
% codes.T1_colorIdx = 20015;                   % CLUT index used to draw T1
% codes.T2_colorIdx = 20016;                   % CLUT index used to draw T2

codes.CurrentBlockNumber            = 20000; % Current Block Number
codes.CurrentBlockType              = 20001; % 1 = T1 Rich ; 2 = T2 Rich
codes.ActualTrialType               = 20002; % 1 = Congruent ; 2 = Conflict
codes.ActualRichReward              = 20003; % Actual Reward with the gaussian noise for Rich target (depends on the blocktype and TrialType)
codes.ActualPoorReward              = 20004; % Actual Reward with the gaussian noise for Poor target (depends on the blocktype and TrialType)
codes.salienceType                  = 20005; %1 = Hue ; 2 = Luminance
codes.ActualLuminanceT1             = 20006; %Luminance Value for T1
codes.ActualLuminanceT2             = 20007; %Luminance Value for T2
codes.LuminanceDifferenceT1MinusT2_x1000 =20008;
codes.backgroundHueIdx = 20009;              % Background hue condition: 1 = DKL 0 background, 2 = DKL 180 background
codes.ActualHueT1_x1000 = 20010;             % T1 DKL hue angle in degrees x1000
codes.ActualHueT2_x1000 = 20011;             % T2 DKL hue angle in degrees x1000
codes.BackgroundHue_x1000 = 20012;           % Background DKL hue angle in degrees x1000
codes.HueContrastT1_x1000 = 20013;           % T1 hue distance from background in degrees x1000
codes.HueContrastT2_x1000 = 20014;           % T2 hue distance from background in degrees x1000
codes.T1_colorIdx = 20015;                   % CLUT index used to draw T1
codes.T2_colorIdx = 20016;                   % CLUT index used to draw T2
codes.nStim = 20017;                         % Number of visible targets: 1 or 2
codes.singleTargetID = 20018;                % 0=dual, 1=T1 only, 2=T2 only
codes.T1Side = 20019;                        % Spatial side of T1: 1=right, 2=left
codes.T2Side = 20020;                        % Spatial side of T2: 1=right, 2=left
codes.chosenTargetID = 20021;                % Chosen identity: 0=none, 1=T1, 2=T2
codes.schedulePhase = 20022;                 % 1=instruction, 2=two-target choice



%% validation

% making sure that every code is listed once (i.e. unique)
values = [];
flds = fieldnames(codes);
for iF = 1:numel(flds)
    if ~isstruct(codes.(flds{iF})) % so that we don't go over the uniqueTaskCode struct
        values(iF) = codes.(flds{iF}); %#ok<AGROW>
    end
end
% find duplicate values:
uValues         = unique(values);
ptr             = hist(values, uValues)>1;
duplicateCodes  = uValues(ptr);

if isempty(duplicateCodes)
    % all good! no duplicate values!
else
    disp('you have duplicate code numbers!!!')
    disp(duplicateCodes)
    error('YOU MUST FIX IT')
    keyboard
end

