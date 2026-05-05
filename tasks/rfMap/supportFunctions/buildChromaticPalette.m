function [paletteRGB, stateBits] = buildChromaticPalette(dklAxes, dklContrasts)
% buildChromaticPalette  Pre-compute the 8-state tri-noise palette via dkl2rgb.
%
%   [paletteRGB, stateBits] = buildChromaticPalette(dklAxes, dklContrasts)
%
%   Tri-noise on the 3 DKL axes has 2^3 = 8 distinct color states (each
%   axis is binary +/- contrast). For inactive axes (not in dklAxes) the
%   contrast is 0; the corresponding bit still toggles in the state
%   index but produces the same color in both states, which means a few
%   CLUT slots get duplicate entries -- harmless and simpler than a
%   per-config compaction.
%
%   Convention (locked): bit ordering matches DKL axis ordering.
%     stateIdx = b0 | (b1 << 1) | (b2 << 2)
%       b0: L-M  sign (0 = -contrast, 1 = +contrast)
%       b1: S    sign
%       b2: Achr sign
%
%   Inputs:
%     dklAxes      - subset of [1 2 3] (1=L-M, 2=S, 3=Achro)
%     dklContrasts - scalar (broadcast) or vector of length numel(dklAxes)
%
%   Outputs:
%     paletteRGB - [3, 8] uint8 matrix; column k is the gamma-corrected
%                  framebuffer RGB triple for state k-1 (uint8 0..255).
%                  Built by dkl2rgb, which consumes the initmon globals.
%                  These uint8 values are CLUT *outputs* (post-gamma)
%                  scaled to 0..255 for direct insertion into
%                  p.draw.clut.expColors / subColors (which are [0,1]).
%                  Caller divides by 255 before assigning into the CLUT.
%     stateBits  - [3, 8] int8 of +/-1 signs per axis per state, in the
%                  same column order. Useful for offline reconstruction.

if isscalar(dklContrasts)
    cVec = repmat(double(dklContrasts), 1, 3);
    cVec(~ismember(1:3, dklAxes)) = 0;
else
    cVec = zeros(1, 3);
    cVec(dklAxes) = dklContrasts(:)';
end

paletteRGB = zeros(3, 8, 'uint8');
stateBits  = zeros(3, 8, 'int8');

for stateIdx = 0:7
    bLM    = bitget(stateIdx, 1);   % bit 0
    bS     = bitget(stateIdx, 2);   % bit 1
    bAchro = bitget(stateIdx, 3);   % bit 2

    signLM    = 2 * double(bLM)    - 1;
    signS     = 2 * double(bS)     - 1;
    signAchro = 2 * double(bAchro) - 1;

    stateBits(:, stateIdx + 1) = int8([signLM; signS; signAchro]);

    % dkl2rgb input row order: [Lum; LM; S]. Map our axis order
    % (1=LM, 2=S, 3=Achro) into that.
    dklVec = [signAchro * cVec(3);    % Lum
              signLM    * cVec(1);    % L-M
              signS     * cVec(2)];   % S

    [r, g, b] = dkl2rgb(dklVec);
    paletteRGB(:, stateIdx + 1) = uint8(round(255 * [r; g; b]));
end

end
