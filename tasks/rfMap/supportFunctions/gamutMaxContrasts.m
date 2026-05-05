function [maxScale, perAxisMax, cornerRGB] = gamutMaxContrasts( ...
    dklAxes, axisRatios)
% gamutMaxContrasts  Find the largest in-gamut scaling of DKL tri-noise.
%
%   [maxScale, perAxisMax, cornerRGB] = gamutMaxContrasts( ...
%       dklAxes, axisRatios)
%
%   Tri-noise on the active DKL axes places stimuli at the 8 corners
%   (+/-c_LM, +/-c_S, +/-c_Achro). For a given shape (axisRatios),
%   this returns the largest scalar `maxScale` such that
%       (maxScale * axisRatios)
%   keeps all 8 corners in-gamut on the rig currently loaded by
%   initmon (i.e., the dkl2rgb forward map's pre-LUT RGB stays in
%   [0, 255] for every corner).
%
%   Inputs:
%     dklAxes    - subset of [1 2 3] (1=L-M, 2=S, 3=Achro). Inactive
%                  axes contribute zero contrast at every corner.
%     axisRatios - 3-vector of relative contrast magnitudes per axis,
%                  in axis order [LM, S, Achro]. Default [1 1 1] (scalar
%                  shape; equivalent to the legacy single-contrast use
%                  case). Inactive axes can have any value -- they're
%                  zeroed out internally.
%
%   Outputs:
%     maxScale   - the largest scalar `s` such that scaling axisRatios
%                  by s keeps all 8 corners in-gamut. Multiply by your
%                  desired safety margin (e.g., 0.95) before passing as
%                  p.trVarsInit.dklContrasts.
%     perAxisMax - 3-vector = maxScale * axisRatios (with inactive axes
%                  zeroed). Convenient shorthand for setting
%                  p.trVarsInit.dklContrasts as a vector.
%     cornerRGB  - [3 x 8] linear RGB at the gamut-edge corners (pre-
%                  gamma, pre-quantization, in [0, 255] arithmetic).
%                  Useful for visual inspection / debugging.
%
%   Method:
%     For each corner k = 0..7, the linear RGB is
%       rgb_k = 255 * (0.5 + 0.5 * M_dkl2rgb * dklVec_k)
%     where dklVec_k = sign_k(:) .* contrastVec(:), in dkl2rgb's
%     [Lum; LM; S] row order. We require rgb_k in [0, 255] for every
%     corner. Linearity in `s` makes this a simple per-corner-per-channel
%     constraint:
%         lower:  255 * (0.5 + 0.5 * M * sign_k .* axisInDkl2rgbOrder * s) >= 0
%         upper:                                                          <= 255
%     Solve each constraint for the maximum permissible s and take the
%     min over all 6 * 8 = 48 constraints.
%
%   Requires initmon(...) to have been called so the M_dkl2rgb global
%   is populated.

if nargin < 2 || isempty(axisRatios), axisRatios = [1 1 1]; end
if numel(axisRatios) ~= 3
    error('gamutMaxContrasts:badRatios', ...
        'axisRatios must be a 3-vector in order [LM, S, Achro].');
end
if any(~ismember(dklAxes, [1 2 3]))
    error('gamutMaxContrasts:badAxes', ...
        'dklAxes must be a subset of [1 2 3].');
end

global M_dkl2rgb %#ok<GVMIS>
if isempty(M_dkl2rgb)
    error('gamutMaxContrasts:noCalib', ...
        ['M_dkl2rgb global is empty -- call initmon(LUTfile) first ' ...
         '(initClut.m does this at task init time).']);
end

% Zero out inactive axes (they contribute 0 to every corner).
ratios = double(axisRatios(:)');
ratios(~ismember(1:3, dklAxes)) = 0;

% Scan the 8 corners. Convert each to dkl2rgb's row order [Lum; LM; S].
maxScalePerCorner = inf(8, 1);
cornerRGB = zeros(3, 8);

for stateIdx = 0:7
    bLM    = bitget(stateIdx, 1);
    bS     = bitget(stateIdx, 2);
    bAchro = bitget(stateIdx, 3);
    signs  = [2*bLM - 1, 2*bS - 1, 2*bAchro - 1];   % [LM, S, Achro]

    % DKL vector at this corner per unit `s`:
    %   dklVec_per_s in dkl2rgb order = [Achro_sign*ratio_Achro;
    %                                     LM_sign*ratio_LM;
    %                                     S_sign*ratio_S]
    dklVecPerS = [signs(3) * ratios(3);   % Lum
                  signs(1) * ratios(1);   % L-M
                  signs(2) * ratios(2)];  % S

    % Linear RGB at this corner: rgb = 255 * (0.5 + 0.5 * M * dklVec)
    %                                = 127.5 + 127.5 * M * dklVec
    % As a function of s:           = 127.5 + (127.5 * M * dklVecPerS) * s
    rgbCoef = 127.5 * (M_dkl2rgb * dklVecPerS);
    rgbBase = 127.5 * ones(3, 1);

    % Constraint per channel: 0 <= rgbBase + rgbCoef * s <= 255
    % Solve for the maximum |s| separately on each channel:
    %   if rgbCoef > 0: s <= (255 - rgbBase) / rgbCoef = 127.5 / rgbCoef
    %   if rgbCoef < 0: s <= (0   - rgbBase) / rgbCoef = -127.5 / rgbCoef
    %                   (both branches give a positive bound on s)
    %   if rgbCoef == 0: no constraint from that channel.
    cornerMaxS = inf;
    for ch = 1:3
        c = rgbCoef(ch);
        if c > 0
            cornerMaxS = min(cornerMaxS, 127.5 / c);
        elseif c < 0
            cornerMaxS = min(cornerMaxS, -127.5 / c);
        end
    end
    maxScalePerCorner(stateIdx + 1) = cornerMaxS;
    cornerRGB(:, stateIdx + 1) = rgbBase + rgbCoef * cornerMaxS;
end

maxScale   = min(maxScalePerCorner);
perAxisMax = maxScale * ratios;

end
