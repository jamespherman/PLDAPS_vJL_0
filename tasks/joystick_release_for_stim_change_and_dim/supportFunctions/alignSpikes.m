function p = alignSpikes(p)
% Initialize PSTH plotter app if not already done
if ~isfield(p.draw, 'psthPlotterApp')
   p.draw.psthPlotterApp = PSTH_plotter;
   
   % Initialize empty data structures in the app
   p.draw.psthPlotterApp.psthPlotterAppUIFigure.UserData.spikeTimes = [];
   p.draw.psthPlotterApp.psthPlotterAppUIFigure.UserData.spikeClusters = [];
   
   % Create eventTimes structure with fields matching p.trData.timing
   timingFields = setdiff(fieldnames(p.trData.timing), ...
       {'flipTime', 'lastFrameTime', 'reactionTime', 'fixHoldReqMet', ...
       'trialStartPTB', 'trialStartDP'});
   for iField = 1:length(timingFields)
       p.draw.psthPlotterApp.psthPlotterAppUIFigure.UserData.eventTimes.(timingFields{iField}) = [];
   end
end

% Extract all timing events for this trial into a structure by mapping strobed
% event codes to timing field names
eventTimes = struct();

% Create code-to-field mapping for tone events
toneCodeList = [p.init.codes.lowTone, p.init.codes.noiseTone, p.init.codes.highTone];

% Loop through each timing field and look for corresponding event code
for i = 1:length(p.trData.eventValues)
   code = p.trData.eventValues(i);
   time = p.trData.eventTimes(i);
   
   % map the code to a field name
   switch code
       case p.init.codes.fixOn
           eventTimes.fixOn = time;
       case p.init.codes.fixAq
           eventTimes.fixAq = time;
       case p.init.codes.stimOn
           eventTimes.stimOn = time;
       case p.init.codes.stimOff
           eventTimes.stimOff = time;
       case p.init.codes.cueOn
           eventTimes.cueOn = time;
       case p.init.codes.cueOff
           eventTimes.cueOff = time;
       case p.init.codes.stimChange
           eventTimes.stimChg = time;
       case p.init.codes.noChange
           eventTimes.noChg = time;
       case p.init.codes.fixBreak
           eventTimes.brokeFix = time;
       case p.init.codes.joyBreak
           eventTimes.brokeJoy = time;
       case p.init.codes.reward
           eventTimes.reward = time;
       case p.init.codes.joyPress
           eventTimes.joyPress = time;
       case p.init.codes.joyRelease
           eventTimes.joyRelease = time;
       case p.init.codes.freeReward
           eventTimes.freeReward = time;
       case p.init.codes.optoStimOn
           eventTimes.optoStim = time;
       case p.init.codes.trialBegin
           eventTimes.trialBegin = time;
       case p.init.codes.trialEnd
           eventTimes.trialEnd = time;
   end
   
   % Check if this is any type of tone
   if ismember(code, toneCodeList)
       eventTimes.tone = time;
   end
end

% Set any missing events to 0 (not -1) so they're properly ignored by nonzeros()
timingFields = setdiff(fieldnames(p.trData.timing), ...
   {'flipTime', 'lastFrameTime', 'reactionTime', 'fixHoldReqMet', ...
   'trialStartPTB', 'trialStartDP'});
for iField = 1:length(timingFields)
   if ~isfield(eventTimes, timingFields{iField})
       eventTimes.(timingFields{iField}) = 0;
   end
end

% Update the PSTH plotter app with new data
try
   p.draw.psthPlotterApp.updateData(p.trData.spikeTimes, ...
       p.trData.spikeClusters, eventTimes);
catch ME
   warning('Error updating PSTH plotter app: %s', ME.message);
end

end