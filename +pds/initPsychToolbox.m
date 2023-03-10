function p                      = initPsychToolbox(p)
% initPsychToolbox is a function that intializes PsychToolbox

% PsychTweak('UseGPUIndex', 2);
% Screen('Preference', 'ScreenToHead', 1, 1, 2);
Screen('Preference', 'TextRenderer', 0);
Screen('Preference', 'TextAntiAliasing', 0);
Screen('Preference', 'DefaultFontName', 'Helvetica');
Screen('Preference', 'DefaultFontStyle', 1);
Screen('Preference', 'DefaultFontSize', 24);

AssertOpenGL;
PsychImaging('PrepareConfiguration');

[p.draw.window, p.draw.screenRect]  = PsychImaging('OpenWindow', 1, [0 0 0]);

% MUST FIGURE OUT HOW WE'RE GOING TO DO THIS PART:
% Screen('LoadNormalizedGammaTable', p.draw.window, p.draw.clut.combinedClut, 2);

p.rig.refreshRate                   = FrameRate(p.draw.window);

% Fill the window with the background color.
Screen('FillRect', p.draw.window, [0.5 0.5 0.5])
Screen('Flip', p.draw.window);
end