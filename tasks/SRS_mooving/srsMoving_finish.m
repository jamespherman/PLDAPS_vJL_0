function p = srsMoving_finish(p)
%SRSMOVING_FINISH Finish/save one moving-target SRS trial.
%
% Before delegating to srsSmooth_finish, normalize the inactive salience
% strobe fields. The shared SRS strobe list always contains both hue and
% luminance metadata, but nextParams intentionally stores NaN in the
% inactive modality. DATAPixx paired strobes only accept finite integers in
% [0,32767], so NaNs must never be queued.
%
% salienceType == 1 (hue):
%   inactive luminance strobe values are encoded as 0.
% salienceType == 2 (luminance):
%   inactive hue strobe values are encoded as 0.
%
% salienceType itself is strobed, so offline decoding can distinguish a
% genuine zero from an inactive-modality placeholder.

p = prepareMovingTrialStrobes(p);
p = srsSmooth_finish(p);

end

function p = prepareMovingTrialStrobes(p)
%PREPAREMOVINGTRIALSTROBES Make every queued paired-strobe value legal.

salienceType = getFiniteScalar(p.trVars, 'salienceType', 0);

switch salienceType
    case 1  % hue
        p.trVars.ActualLuminanceT1_x1000 = 0;
        p.trVars.ActualLuminanceT2_x1000 = 0;
        p.trVars.MeasuredLuminanceT1_x100 = 0;
        p.trVars.MeasuredLuminanceT2_x100 = 0;

    case 2  % luminance
        p.trVars.backgroundHueIdx = 0;
        p.trVars.ActualHueT1_x10 = 0;
        p.trVars.ActualHueT2_x10 = 0;
        p.trVars.BackgroundHue_x10 = 0;
        p.trVars.HueContrastT1_x10 = 0;
        p.trVars.HueContrastT2_x10 = 0;

    otherwise
        error('SRS_mooving:InvalidSalienceTypeForStrobe', ...
            'Unsupported salienceType=%g before paired strobes.', salienceType);
end

% Validate the complete strobe list before anything reaches DATAPixx. This
% converts an opaque SetDoutValues failure into the exact offending field.
for ii = 1:size(p.init.strobeList, 1)
    codeName = p.init.strobeList{ii, 1};
    expression = p.init.strobeList{ii, 2};
    value = eval(expression);

    if ~(isnumeric(value) || islogical(value))
        error('SRS_mooving:InvalidStrobeType', ...
            'Strobe %s (%s) is not numeric/logical.', codeName, expression);
    end

    value = double(value(:));
    if isempty(value)
        error('SRS_mooving:EmptyStrobeValue', ...
            'Strobe %s (%s) evaluated to an empty value.', codeName, expression);
    end

    bad = ~isfinite(value) | value < 0 | value > 32767 | value ~= round(value);
    if any(bad)
        firstBad = value(find(bad, 1, 'first'));
        error('SRS_mooving:IllegalStrobeValue', ...
            ['Illegal paired-strobe value before DATAPixx: %s (%s) = %g. ', ...
             'Values must be finite integers in [0,32767].'], ...
            codeName, expression, firstBad);
    end
end

end

function value = getFiniteScalar(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName)
    candidate = s.(fieldName);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end
