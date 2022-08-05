function p = blackScreen(p)

Screen('FillRect', p.draw.window, 0);
Screen('Flip', p.draw.window);

end