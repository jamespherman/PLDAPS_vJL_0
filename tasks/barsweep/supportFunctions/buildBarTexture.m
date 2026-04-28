function tex = buildBarTexture(p, barWidthPix, barLengthPix)
% tex = buildBarTexture(p, barWidthPix, barLengthPix)
%
% Build a single solid-color bar texture sized to the current bar
% dimensions. Pixel values are CLUT slot indices (uint8); the actual
% color is determined by the current CLUT bound to the slot at draw time.
%
% Convention: long axis is the X dimension of the texture (width-pixels);
% Screen('DrawTexture') applies a rotation so that the long axis aligns
% with bar orientation (= pathAngleDeg + 90).

barLumVal = p.stim.luminanceLevels(p.trVars.barLumIdx);

% Width in tex coordinates -> long axis (length); Height -> short axis (width).
texW = max(1, round(barLengthPix));
texH = max(1, round(barWidthPix));

texData = repmat(uint8(barLumVal), [texH, texW]);

tex = Screen('MakeTexture', p.draw.window, texData);

end
