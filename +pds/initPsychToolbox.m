function p                      = initPsychToolbox(p)
% initPsychToolbox is a function that intializes PsychToolbox

% PsychTweak('UseGPUIndex', 2);
% Screen('Preference', 'ScreenToHead', 1, 1, 2);
% Screen('Preference', 'TextRenderer', 0);
% Screen('Preference', 'TextAntiAliasing', 0);
% Screen('Preference', 'DefaultFontName', 'Helvetica');
% Screen('Preference', 'DefaultFontStyle', 1);
% Screen('Preference', 'DefaultFontSize', 24);
% Screen('Preference', 'Verbosity', 6);

% Select screen with maximum id for output window:
screenid = max(Screen('Screens'));

% Open a fullscreen, onscreen window with gray background. Enable 32bpc
% floating point framebuffer via imaging pipeline on it, if this is possible
% on your hardware while alpha-blending is enabled. Otherwise use a 16bpc
% precision framebuffer together with alpha-blending. We need alpha-blending
% here to implement the nice superposition of overlapping gabors. The demo will
% abort if your graphics hardware is not capable of any of this.
PsychImaging('PrepareConfiguration');
PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
[p.draw.window, p.draw.screenRect] = PsychImaging('OpenWindow', ...
    screenid, 128);
p.draw.middleXY                     = [p.draw.screenRect(3)/2, ...
    p.draw.screenRect(4)/2];

% Now that we have the window open, we can use that information to estimate
% the refresh rate / frame duration.
p.rig.refreshRate                   = FrameRate(p.draw.window);
p.rig.frameDuration

% define color range:
p.draw.colorRange = Screen('ColorRange', p.draw.window);

% Fill the window with the background color.
Screen('FillRect', p.draw.window, [0.5 0.5 0.5])
Screen('Flip', p.draw.window);
end