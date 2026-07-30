function p = initDataPixxC24(p)
%INITDATAPIXXC24 Initialize the task in true 8-bit RGB passthrough mode.
%
% salienceType 3 cannot use the usual L48 dual-CLUT window because L48
% interprets the red channel as a CLUT index. This initializer opens a C24
% window, loads an identity GPU gamma table, and lets Screen receive direct
% [R G B] values in the 0-255 range.

Screen('Preference', 'TextRenderer', 0);
Screen('Preference', 'TextAntiAliasing', 0);
Screen('Preference', 'DefaultFontName', 'Helvetica');
Screen('Preference', 'DefaultFontStyle', 1);
Screen('Preference', 'DefaultFontSize', 24);
AssertOpenGL;

Datapixx('Open');
Datapixx('StopAllSchedules');
Datapixx('SetVideoMode', 0); % C24: conventional RGB passthrough
Datapixx('RegWrRd');

PsychImaging('PrepareConfiguration');
[p.draw.window, p.draw.screenRect] = PsychImaging('OpenWindow', 1, [0 0 0]);
Screen('ColorRange', p.draw.window, 255);
LoadIdentityClut(p.draw.window);

p.draw.middleXY = [p.draw.screenRect(3) / 2, p.draw.screenRect(4) / 2];
p.rig.refreshRate = FrameRate(p.draw.window);
p.rig.frameDuration = 1 / p.rig.refreshRate;

Screen('FillRect', p.draw.window, p.trVarsInit.directRgbBackgroundRGB255);
Screen('Flip', p.draw.window);

Datapixx('StopAllSchedules');
Datapixx('DisableDinDebounce');
Datapixx('SetDinLog');
Datapixx('StartDinLog');
Datapixx('SetDoutValues', 0);
Datapixx('RegWrRd');
Datapixx('DisableDacAdcLoopback');
Datapixx('DisableAdcFreeRunning');
Datapixx('EnableVideoScanningBacklight');

p.draw.displayMode = 'C24_DIRECT_RGB';
p.draw.isDirectRgb = true;
p.draw.color.background = double(p.trVarsInit.directRgbBackgroundRGB255(:)');
p.draw.color.fix = p.draw.color.background;

end
