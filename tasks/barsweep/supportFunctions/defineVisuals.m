function p = defineVisuals(p)
% p = defineVisuals(p)
%
% Resolve the v1 luminance-palette indices (1=dark, 2=mid, 3=light) into
% the actual CLUT slot values used by Screen('FillRect') and as the values
% painted into the bar / noise textures. Per the plan ("Luminance
% representation"), GUI-facing trVars stay index-based; this function
% gives downstream code a numeric handle in CLUT terms without each
% caller hard-coding clutIdx.* fields.

p.stim.luminanceLevels = p.stim.luminancePaletteClut;

end
