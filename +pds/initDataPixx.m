function p                      = initDataPixx(p)
% INITDATAPIXX is a function that intializes the DATAPIXX, preparing it for
% experiments. Critically, the PSYCHIMAGING calls sets up the dual CLUTS
% (Color Look Up Table) for two screens.  These two CLUTS are in the
% condition file "c".
% Modified from initDataPixx, getting rid of global variables: window,
% screenRect, refreshrate, overlay

% PsychTweak('UseGPUIndex', 2);
% Screen('Preference', 'ScreenToHead', 1, 1, 2);
Screen('Preference', 'TextRenderer', 0);
Screen('Preference', 'TextAntiAliasing', 0);
Screen('Preference', 'DefaultFontName', 'Helvetica');
Screen('Preference', 'DefaultFontStyle', 1);
Screen('Preference', 'DefaultFontSize', 24);

AssertOpenGL;
PsychImaging('PrepareConfiguration');

% if we're going to play a movie, don't bother trying to do fancy separate
% colors for monkey / experimenter; otherwise enable separate colors for
% monkey / experimenter displays.
if ~isfield(p.draw, 'movie') && ~isfield(p.stim, 'token')
    PsychImaging('AddTask', 'General', 'EnableDataPixxL48Output');
end

p.draw.clut.combinedClut            = [p.draw.clut.subCLUT; p.draw.clut.expCLUT];
[p.draw.window, p.draw.screenRect]  = PsychImaging('OpenWindow', 1, [0 0 0]);
p.draw.middleXY                     = [p.draw.screenRect(3)/2 p.draw.screenRect(4)/2];
Screen('LoadNormalizedGammaTable', p.draw.window, p.draw.clut.combinedClut, 2);

p.rig.refreshRate                   = FrameRate(p.draw.window);

% load an identity CLUT into the graphics-card hardware to make sure that
% it doesn't transform our pixel colors at all. This uses the stored CLUT
% found by tweaking.
oldClut = LoadIdentityClut(p.draw.window);

% Fill the window with the background color.
Screen('FillRect', p.draw.window, [0.5 0.5 0.5])
Screen('Flip', p.draw.window);

% VIEWPixx settings
Datapixx('Open');
Datapixx('StopAllSchedules');
Datapixx('DisableDinDebounce');
Datapixx('SetDinLog');
Datapixx('StartDinLog');
Datapixx('SetDoutValues',0);
Datapixx('RegWrRd');
Datapixx('DisableDacAdcLoopback');
Datapixx('DisableAdcFreeRunning');          % For microsecond-precise sample windows
Datapixx('EnableVideoScanningBacklight');

end