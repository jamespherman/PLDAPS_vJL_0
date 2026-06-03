function population = simGeneratePopulation(varargin)
% simGeneratePopulation  Create a simulated LGN population and save to disk.
%
%   population = simGeneratePopulation()
%   population = simGeneratePopulation('Name', Value, ...)
%
%   Generates a reusable population of LGN-like neurons with known RF
%   properties. The population file can be loaded by simLoadPopulation to
%   build task-specific kernel banks, enabling multi-task simulation
%   against the same ground truth.
%
%   Name-Value Parameters:
%     'nNeurons'       - Total neurons with RFs (default 12)
%     'nChannels'      - Total probe channels (default 64)
%     'hemifield'      - 'left' or 'right' (default 'left')
%     'eccentricityRange' - [min max] dva from fixation (default [1 6])
%     'elevationRange' - [min max] dva (default [-4 4])
%     'seed'           - RNG seed for reproducibility (default 42)
%     'saveFile'       - Path to save .mat (default: auto-named in
%                        simPopulations/ under rfMap task dir)
%     'baseRate'       - Median spontaneous rate, spk/s (default 2)
%     'peakRate'       - Median driven rate, spk/s (default 20)
%
%   Output struct fields:
%     population.neurons(k):
%       .centerDeg       [x, y] fixation-relative dva (+x right, +y up)
%       .sigmaCenterDeg  center Gaussian sigma (dva)
%       .sigmaSurrDeg    surround sigma (dva)
%       .surrWeight      surround suppression weight
%       .excPeakMs       excitatory temporal peak (ms)
%       .inhPeakMs       inhibitory temporal peak (ms)
%       .inhWeight       inhibitory temporal weight
%       .polarity        +1 (ON) or -1 (OFF)
%       .baseRate        spontaneous rate (spk/s)
%       .peakRate        peak driven rate (spk/s)
%       .dklWeights      [L-M, S, Achro] chromatic sensitivity
%       .channelIdx      probe channel this neuron appears on
%     population.noiseChannels - indices of channels with no RF neuron
%     population.noiseRates    - spontaneous rates for noise channels
%     population.params        - generation parameters for provenance
%     population.seed          - RNG seed used

ip = inputParser;
ip.addParameter('nNeurons', 12, @isscalar);
ip.addParameter('nChannels', 64, @isscalar);
ip.addParameter('hemifield', 'left', @(x) ismember(x, {'left','right'}));
ip.addParameter('eccentricityRange', [1 6], @(x) numel(x)==2);
ip.addParameter('elevationRange', [-4 4], @(x) numel(x)==2);
ip.addParameter('seed', 42, @isscalar);
ip.addParameter('saveFile', '', @ischar);
ip.addParameter('baseRate', 2, @isscalar);
ip.addParameter('peakRate', 20, @isscalar);
ip.parse(varargin{:});
opts = ip.Results;

rs = RandStream('mt19937ar', 'Seed', uint32(opts.seed));

nNeurons  = opts.nNeurons;
nChannels = opts.nChannels;

% Assign neurons to channels. Multiple neurons can share a channel
% (multi-unit), but we keep it simple: one neuron per channel for the
% first nNeurons channels, in random order.
channelPerm = randperm(rs, nChannels);
neuronChannels = channelPerm(1:nNeurons);

% Generate RF centers in the contralateral hemifield.
hemiSign = 1;
if strcmp(opts.hemifield, 'left'), hemiSign = -1; end

eccRange = opts.eccentricityRange;
elvRange = opts.elevationRange;

% Cell-type assignment: 80% P, 10% M, 10% K (Perry et al. 1984;
% Hendry & Reid 2000). Draw types for all neurons upfront.
typeRoll = rand(rs, nNeurons, 1);
cellTypes = repmat({'P'}, nNeurons, 1);
cellTypes(typeRoll >= 0.80 & typeRoll < 0.90) = {'M'};
cellTypes(typeRoll >= 0.90) = {'K'};

neurons = struct([]);
for k = 1:nNeurons
    n = struct();
    n.cellType = cellTypes{k};

    % RF center: eccentricity in the contralateral hemifield.
    ecc = eccRange(1) + (eccRange(2) - eccRange(1)) * rand(rs);
    elv = elvRange(1) + (elvRange(2) - elvRange(1)) * rand(rs);
    n.centerDeg = [hemiSign * ecc, elv];

    % Spatial extent: Croner & Kaplan 1995 power-law fits.
    %   P: sigma_c = 0.0264 * ecc^0.61
    %   M: sigma_c = 0.0583 * ecc^0.69
    %   K: approximate as P (limited data)
    % Add ±20% jitter for individual variation.
    switch n.cellType
        case 'P'
            sigmaBase = 0.0264 * ecc^0.61;
            surrRatio = 6.5 + 1.0 * (rand(rs) - 0.5);  % 6-7x
            n.surrWeight = 0.64 * (1 + 0.2 * (rand(rs) - 0.5));
        case 'M'
            sigmaBase = 0.0583 * ecc^0.69;
            surrRatio = 4.5 + 1.0 * (rand(rs) - 0.5);  % 4-5x
            n.surrWeight = 0.72 * (1 + 0.2 * (rand(rs) - 0.5));
        case 'K'
            sigmaBase = 0.0264 * ecc^0.61 * 1.2;  % slightly larger than P
            surrRatio = 6.0 + 1.0 * (rand(rs) - 0.5);
            n.surrWeight = 0.50 * (1 + 0.2 * (rand(rs) - 0.5));
    end
    n.sigmaCenterDeg = sigmaBase * (1 + 0.4 * (rand(rs) - 0.5));
    n.sigmaSurrDeg   = n.sigmaCenterDeg * surrRatio;

    % Temporal dynamics: P slower/sustained, M faster/transient.
    switch n.cellType
        case 'P'
            n.excPeakMs = 40 + 20 * rand(rs);    % 40-60 ms
            n.inhWeight = 0.2 + 0.2 * rand(rs);  % weakly biphasic (0.2-0.4)
        case 'M'
            n.excPeakMs = 25 + 10 * rand(rs);    % 25-35 ms
            n.inhWeight = 0.6 + 0.3 * rand(rs);  % strongly biphasic (0.6-0.9)
        case 'K'
            n.excPeakMs = 50 + 20 * rand(rs);    % 50-70 ms (slow)
            n.inhWeight = 0.2 + 0.2 * rand(rs);
    end
    n.inhPeakMs = n.excPeakMs * (1.8 + 0.4 * rand(rs));

    n.polarity = (rand(rs) > 0.5) * 2 - 1;

    % Firing rates (jittered around median). These represent
    % threshold-crossing rates, not single-unit rates.
    n.baseRate = opts.baseRate * (1 + 0.4 * (rand(rs) - 0.5));
    n.peakRate = opts.peakRate * (1 + 0.4 * (rand(rs) - 0.5));

    % Chromatic sensitivity by cell type.
    switch n.cellType
        case 'P'
            % 50% +L-M, 50% +M-L (Derrington et al. 1984)
            if rand(rs) > 0.5
                n.dklWeights = [1.0  0.0  0.0];   % +L-M
            else
                n.dklWeights = [-1.0  0.0  0.0];  % +M-L (sign flip)
            end
        case 'M'
            n.dklWeights = [0.0  0.0  1.0];       % achromatic (L+M)
        case 'K'
            n.dklWeights = [0.0  1.0  0.0];       % S-ON
    end
    wn = norm(n.dklWeights);
    if wn > 0, n.dklWeights = n.dklWeights / wn; end

    n.channelIdx = neuronChannels(k);

    if isempty(neurons)
        neurons = n;
    else
        neurons(k) = n;
    end
end

% Noise channels: all channels not assigned to a neuron.
allCh = 1:nChannels;
rfChannels = [neurons.channelIdx];
noiseCh = setdiff(allCh, rfChannels);
noiseRates = 2 + 2 * rand(rs, 1, numel(noiseCh));

population = struct( ...
    'neurons',       neurons, ...
    'noiseChannels', noiseCh, ...
    'noiseRates',    noiseRates, ...
    'nChannels',     nChannels, ...
    'hemifield',     opts.hemifield, ...
    'seed',          opts.seed, ...
    'params',        opts);

% Save to disk.
if isempty(opts.saveFile)
    popDir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'simPopulations');
    if ~isfolder(popDir), mkdir(popDir); end
    opts.saveFile = fullfile(popDir, ...
        sprintf('lgn_population_%03d.mat', opts.seed));
end
saveDir = fileparts(opts.saveFile);
if ~isempty(saveDir) && ~isfolder(saveDir), mkdir(saveDir); end
save(opts.saveFile, 'population', '-v7.3');
population.savedTo = opts.saveFile;

fprintf('simGeneratePopulation: %d RF neurons on %d/%d channels, %d noise channels\n', ...
    nNeurons, numel(unique(rfChannels)), nChannels, numel(noiseCh));
fprintf('  Hemifield: %s, eccentricity %.1f-%.1f dva\n', ...
    opts.hemifield, eccRange(1), eccRange(2));
fprintf('  Saved to: %s\n', opts.saveFile);

end
