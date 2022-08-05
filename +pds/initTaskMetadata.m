function p = initTaskMetadata(p)
%   p = initTaskMetadata(p)

%% Taks Code:
% Each task gets its own unique task code for easy identification. These
% are the values that are strobed after taskCode is strboed. They are
% assigned here. See pds.initCodes for the actual code value.
codes           = pds.initCodes;
p.init.taskCode = codes.(['uniqueTaskCode_' p.init.taskName]);

%% Meta Data:

p.init.pldapsFolder     = pwd;                          % pldaps gui takes us to taks folder automatically once we choose a settings file
p.init.protocol_title   = [p.init.taskName '_task'];    % Define Banner text to identify the experimental protocol
p.init.date_1yyyy       = str2double(['1' datestr(now,'yyyy')]); % gotta add a '1' otherwise date/times starting with zero lose that zero in conversion to double.
p.init.date_1mmdd       = str2double(['1' datestr(now,'mmdd')]);
p.init.time_1hhmm       = str2double(['1' datestr(now,'HHMM')]);

% output files:
p.init.outputFolder     = fullfile(p.init.pldapsFolder, 'output');
p.init.figureFolder     = fullfile(p.init.pldapsFolder, 'output', 'figures');
p.init.sessionId        = [datestr(now,'yyyymmdd_tHHMM') '_' p.init.taskName];     % Define the prefix for the Output File
p.init.sessionFolder    = fullfile(p.init.outputFolder, p.init.sessionId);

% Define the "init", "next", "run", and "finish" ".m" files.
p.init.taskFiles.init   = [p.init.taskName '_init.m'];
p.init.taskFiles.next   = [p.init.taskName '_next.m'];
p.init.taskFiles.run    = [p.init.taskName '_run.m'];
p.init.taskFiles.finish = [p.init.taskName '_finish.m'];


end