function p                      = initEyelink(p)
%
% initEyelink is a function that intializes the connection to the Eyelink
% "Host PC", as well as defining variables related to using the tracker.
%

% initialize connection to tracker - if we want to debug or develop this
% task with no eyelink connected, use "dummy mode" (variable defined in
% "settings.m".
EyelinkInit(p.init.elDummyMode);
p.init.eyeLinkStatus = Eyelink('IsConnected');

% Open dialog box for EyeLink Data file name entry. File name up to 8 characters
prompt = {'Enter EDF file name (up to 8 characters)'};
dlg_title = 'Create EDF file';
def = {'demo'}; % Create a default edf file name
answer = inputdlg(prompt, dlg_title, 1, def); % Prompt for new EDF file name
% Print some text in Matlab's Command Window if a file name has not been entered
if  isempty(answer)
    fprintf('Session cancelled by user\n')
    error('Session cancelled by user'); % Abort experiment (see cleanup function below)
end
p.init.edfFile = answer{1}; % Save file name to a variable
% Print some text in Matlab's Command Window if file name is longer than 8 characters
if length(p.init.edfFile) > 8
    fprintf('Filename needs to be no more than 8 characters long (letters, numbers and underscores only)\n');
    error('Filename needs to be no more than 8 characters long (letters, numbers and underscores only)');
end

% Open an EDF file and name it
failOpen = Eyelink('OpenFile', p.init.edfFile);
if failOpen ~= 0 % Abort if it fails to open
    fprintf('Cannot create EDF file %s', p.init.edfFile); % Print some text in Matlab's Command Window
    error('Cannot create EDF file %s', p.init.edfFile); % Print some text in Matlab's Command Window
end

% Define "el" structurecc v  
% o, and set some default variable values.
p.init.el = EyelinkInitDefaults(p.draw.window);

% Define appearance of background and targets for calibration / validiation
% / drift-correction. Note: background colour must be similar to that used
% during experiment to prevent large luminance-based pupil size changes
% (which can cause a drift in the eye movement data)
p.init.el.calibrationtargetsize = 3;% Outer tgt size as % of screen pxls
p.init.el.calibrationtargetwidth = 0.7;% Inner tgt size as % of screen pxls
p.init.el.backgroundcolour = ...
    fix(p.draw.clut.expColors(p.draw.color.background + 1, :)*255);
p.init.el.calibrationtargetcolour = [0 0 0];% RGB black

% Set "Camera Setup" instructions text colour different from background
p.init.el.msgfontcolour = [0 0 0];% RGB black

% Set calibration beeps (0 = sound off, 1 = sound on)
p.init.el.targetbeep = 0;  % beep when a target is presented
p.init.el.feedbackbeep = 0;  % beep after calibration or drift check

% Make use of values defined in "el" structure:
EyelinkUpdateDefaults(p.init.el);

% Set display coordinates for EyeLink data by entering left, top, right and
% bottom coordinates in screen pixels
Eyelink('Command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, ...
    p.draw.screenRect(3) - 1, p.draw.screenRect(4) - 1);

% Write DISPLAY_COORDS message to EDF file: sets display coordinates in
% DataViewer. See DataViewer manual section: Protocol for EyeLink Data to
% Viewer Integration > Pre-trial Message Commands
Eyelink('Message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, ...
    p.draw.screenRect(3) - 1, p.draw.screenRect(4) - 1);

% Set number of calibration/validation dots and spread: horizontal-only(H)
% or horizontal-vertical(HV) as H3, HV3, HV5, HV9 or HV13
Eyelink('Command', 'calibration_type = HV9'); % horz-vert 9-points

% Allow a supported EyeLink Host PC button box to accept calibration or
% drift-check/correction targets via button 5
Eyelink('Command', 'button_function 5 "accept_target_fixation"');

% Hide mouse cursor
% HideCursor(screenNumber);
              
% Start listening for keyboard input. Suppress keypresses to Matlab windows
ListenChar(-1);

% Clear Host PC display from any previous drawing
Eyelink('Command', 'clear_screen 0'); 

% Put EyeLink Host PC in Camera Setup mode for participant setup / 
% calibration
EyelinkDoTrackerSetup(p.init.el);

disp('EyelinkDoTrackerSetup execution has completed.')

end