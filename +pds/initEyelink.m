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

% Define "el" structure, and set some default variable values.
p.init.el = EyelinkInitDefaults(p.draw.window);

% Define appearance of background and targets for calibration / validiation
% / drift-correction. Note: background colour must be similar to that used
% during experiment to prevent large luminance-based pupil size changes
% (which can cause a drift in the eye movement data)
p.init.el.calibrationtargetsize = 3;% Outer tgt size as % of screen pxls
p.init.el.calibrationtargetwidth = 0.7;% Inner tgt size as % of screen pxls
p.init.el.backgroundcolour = ...
    p.draw.clut.expColors(p.draw.color.background + 1, :);
p.init.el.calibrationtargetcolour = [0 0 0];% RGB black

% Set "Camera Setup" instructions text colour different from background
p.init.el.msgfontcolour = [0 0 0];% RGB black

% Set calibration beeps (0 = sound off, 1 = sound on)
p.init.el.targetbeep = 1;  % beep when a target is presented
p.init.el.feedbackbeep = 1;  % beep after calibration or drift check

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
% Eyelink('Command', 'button_function 5 "accept_target_fixation"');

% Hide mouse cursor
% HideCursor(screenNumber);

% Start listening for keyboard input. Suppress keypresses to Matlab windows
% ListenChar(-1);

% Clear Host PC display from any previous drawing
Eyelink('Command', 'clear_screen 0'); 

% Put EyeLink Host PC in Camera Setup mode for participant setup / 
% calibration
EyelinkDoTrackerSetup(p.init.el);

end