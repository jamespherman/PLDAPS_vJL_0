function [results, fig] = analyzePupilPE(varargin)
%ANALYZEPUPILPE Analyze and plot pupil prediction errors from PLDAPS tokens data
%
%   [results, fig] = analyzePupilPE()
%   [results, fig] = analyzePupilPE(filePath)
%
%   This function analyzes pupil responses to Reward Prediction Error (RPE),
%   Sensory Prediction Error (SPE), and their interaction from concatenated
%   PLDAPS tokens task data. It combines the functionality of analyze_pupil_pe.m
%   and plot_pupil_pe.m from the tokens-analysis-pipeline.
%
%   When called without arguments, prompts the user to select a concatenated
%   .mat file. When called with a file path, uses that file directly.
%
%   ANALYSIS PANELS:
%     Panel A - RPE (Magnitude-Matched Cross-Distribution):
%       4 conditions: Rare-Low, Common-Low, Rare-High, Common-High
%       2-way ANOVA at each time bin: Distribution x Magnitude
%
%     Panel B - SPE (AV sessions only):
%       4 conditions: noflicker_certain, flicker_omitted, flicker_surprising,
%                     flicker_certain
%       Pairwise contrast: flicker_surprising vs flicker_certain (ranksum)
%
%     Panels C/D - RPE x SPE Interaction (AV sessions only):
%       8 conditions crossing RPE with SPE
%       3-way ANOVA: Distribution x SPE x Magnitude
%
%   INPUTS:
%     filePath (optional) - Path to concatenated PLDAPS .mat file
%
%   OUTPUTS:
%     results - Struct containing analysis results (p-values, means, CIs)
%     fig     - Handle to the generated figure
%
%   The figure is automatically saved as a PDF in the same folder as the
%   input data file.
%
%   See also: pds.loadP, pdsActions.catOldOutput

%% Parse Input and Select File
if nargin > 0
    filePath = varargin{1};
    if ~exist(filePath, 'file')
        error('analyzePupilPE:FileNotFound', 'File not found: %s', filePath);
    end
else
    [fileName, folderPath] = uigetfile('*.mat', ...
        'Select a concatenated PLDAPS tokens .mat file');
    if isequal(fileName, 0)
        disp('File selection cancelled.');
        results = [];
        fig = [];
        return;
    end
    filePath = fullfile(folderPath, fileName);
end

%% Load Data
fprintf('Loading data from: %s\n', filePath);
data = load(filePath);

% Extract session ID from filename
[~, sessionId, ~] = fileparts(filePath);

%% Validate Data Structure
requiredFields = {'trVars', 'trData'};
for i = 1:numel(requiredFields)
    if ~isfield(data, requiredFields{i})
        error('analyzePupilPE:InvalidData', ...
            'Missing required field: %s', requiredFields{i});
    end
end

%% Determine Session Type
% Check if this is an AV session by looking for isAVTrial field
if isfield(data.trVars, 'isAVTrial')
    is_av_session = true;
    fprintf('Detected AV session (tokens_AV)\n');
else
    is_av_session = false;
    fprintf('Detected basic session (tokens_main)\n');
end

%% Filter for Successful Trials
% trialEndState == 21 indicates successful completion
trialEndStates = arrayfun(@(x) x.trialEndState, data.trData);
successMask = trialEndStates == 21;

% Also require valid pupil data and outcomeOn timing
hasValidPupil = arrayfun(@(x) ~isempty(x.eyeP) && ~isempty(x.eyeT), data.trData);
hasValidOutcome = arrayfun(@(x) isfield(x.timing, 'outcomeOn') && ...
    x.timing.outcomeOn > 0, data.trData);

validTrialMask = successMask & hasValidPupil & hasValidOutcome;
nValidTrials = sum(validTrialMask);
fprintf('Found %d valid trials out of %d total\n', nValidTrials, numel(successMask));

if nValidTrials < 10
    error('analyzePupilPE:InsufficientData', ...
        'Too few valid trials (%d). Need at least 10.', nValidTrials);
end

%% Extract Trial Information
validIndices = find(validTrialMask);
trVars = data.trVars(validIndices);
trData = data.trData(validIndices);

% Extract key variables
dist = arrayfun(@(x) x.dist, trVars);
rewardAmt = arrayfun(@(x) x.rewardAmt, trVars);
cueFile = arrayfun(@(x) x.cueFile, trVars, 'UniformOutput', false);

if is_av_session
    isAVTrial = arrayfun(@(x) x.isAVTrial, trVars);
else
    isAVTrial = false(nValidTrials, 1);
end

%% Preprocess Pupil Data
fprintf('Preprocessing pupil data...\n');
[pupil_traces, time_vector] = preprocessPupilData(trData, nValidTrials);

%% Define Condition Masks
fprintf('Defining task conditions...\n');
conditions = defineConditions(dist, rewardAmt, cueFile, isAVTrial, is_av_session);

%% Run Analysis
fprintf('Running pupil PE analysis...\n');
results = runAnalysis(pupil_traces, time_vector, conditions, is_av_session);

%% Generate Figure
fprintf('Generating figure...\n');
fig = generateFigure(results, sessionId, is_av_session);

%% Save Figure
[fileDir, ~, ~] = fileparts(filePath);
if is_av_session
    figFileName = fullfile(fileDir, sprintf('%s_pupil_pe.pdf', sessionId));
else
    figFileName = fullfile(fileDir, sprintf('%s_pupil_rpe.pdf', sessionId));
end
localPdfSave(figFileName, fig.Position(3:4)/72, fig);
fprintf('Saved figure to: %s\n', figFileName);

fprintf('Analysis complete.\n');

end % End of main function


%% ========================================================================
%  LOCAL FUNCTIONS
%  ========================================================================

function [pupil_traces, time_vector] = preprocessPupilData(trData, nTrials)
%PREPROCESSPUPILDATA Extract and preprocess pupil data aligned to outcome onset
%
% Parameters for preprocessing
sample_rate = 100;           % Hz (approximate, will interpolate)
baseline_window = [-0.5, -0.1];  % seconds relative to outcomeOn
deblink_threshold = -9.5;    % Values below this are blink artifacts
time_window = [-0.5, 1.5];   % Analysis window relative to outcomeOn

% Create common time vector
n_samples = round((time_window(2) - time_window(1)) * sample_rate);
time_vector = linspace(time_window(1), time_window(2), n_samples);

% Initialize output matrix
pupil_traces = nan(nTrials, n_samples);

% Process each trial
for iTrial = 1:nTrials
    % Get raw pupil data
    eyeP = trData(iTrial).eyeP;
    eyeT = trData(iTrial).eyeT;

    if isempty(eyeP) || isempty(eyeT)
        continue;
    end

    % Convert timestamps to trial-relative time
    % eyeT is in DataPixx clock, subtract trialStartDP to get time since trial start
    trialStartDP = trData(iTrial).timing.trialStartDP;
    outcomeOn = trData(iTrial).timing.outcomeOn;

    % Align time to outcome onset
    % Note: outcomeOn is stored as time relative to trial start (PTB clock),
    % but PTB and DP clocks are synchronized, so we can use the same offset
    pupil_time = eyeT - trialStartDP - outcomeOn;

    % Apply deblink correction
    pupil_trace = eyeP;
    pupil_trace(pupil_trace < deblink_threshold) = nan;

    % Compute baseline
    baseline_idx = (pupil_time >= baseline_window(1)) & ...
                   (pupil_time <= baseline_window(2));
    baseline_mean = mean(pupil_trace(baseline_idx), 'omitnan');

    if isnan(baseline_mean) || baseline_mean == 0
        continue;
    end

    % Normalize: (trace - baseline) / baseline
    normalized_trace = (pupil_trace - baseline_mean) / baseline_mean;

    % Interpolate to common time base
    pupil_traces(iTrial, :) = interp1(pupil_time, normalized_trace, ...
        time_vector, 'linear', nan);
end

end


function conditions = defineConditions(dist, rewardAmt, cueFile, isAVTrial, is_av_session)
%DEFINECONDITIONS Create logical masks for trial conditions

nTrials = numel(dist);

% Distribution conditions
conditions.is_normal_dist = (dist == 1);
conditions.is_uniform_dist = (dist == 2);

% Magnitude-matched RPE conditions
% Use 30th and 70th percentile thresholds from Normal distribution
reward_norm = rewardAmt(conditions.is_normal_dist);
if ~isempty(reward_norm)
    mag_thresholds = prctile(reward_norm, [30, 70]);
    mag_low_thresh = mag_thresholds(1);
    mag_high_thresh = mag_thresholds(2);
else
    % Fallback if no Normal distribution trials
    mag_low_thresh = 3;
    mag_high_thresh = 7;
end

% Apply same thresholds to both distributions
conditions.is_rare_low = conditions.is_normal_dist & (rewardAmt <= mag_low_thresh);
conditions.is_common_low = conditions.is_uniform_dist & (rewardAmt <= mag_low_thresh);
conditions.is_rare_high = conditions.is_normal_dist & (rewardAmt >= mag_high_thresh);
conditions.is_common_high = conditions.is_uniform_dist & (rewardAmt >= mag_high_thresh);

% SPE conditions (AV sessions only)
if is_av_session
    % cueFile naming convention:
    %   _01.jpg = no flicker (0% AV probability)
    %   _02.jpg = 50% AV probability
    %   _03.jpg = 100% AV probability (certain flicker)

    contains_01 = cellfun(@(x) contains(x, '_01'), cueFile);
    contains_02 = cellfun(@(x) contains(x, '_02'), cueFile);
    contains_03 = cellfun(@(x) contains(x, '_03'), cueFile);

    conditions.is_noflicker_certain = contains_01;
    conditions.is_flicker_omitted = contains_02 & ~isAVTrial;
    conditions.is_flicker_surprising = contains_02 & isAVTrial;
    conditions.is_flicker_certain = contains_03 & isAVTrial;
else
    % No-AV session: all SPE conditions are false
    conditions.is_noflicker_certain = false(nTrials, 1);
    conditions.is_flicker_omitted = false(nTrials, 1);
    conditions.is_flicker_surprising = false(nTrials, 1);
    conditions.is_flicker_certain = false(nTrials, 1);
end

% Ensure all masks are column vectors
fnames = fieldnames(conditions);
for i = 1:numel(fnames)
    conditions.(fnames{i}) = conditions.(fnames{i})(:);
end

end


function results = runAnalysis(pupil_traces, time_vector_raw, conditions, is_av_session)
%RUNANALYSIS Perform time-varying statistical analyses on pupil data

% Parameters
bin_width_sec = 0.100;
n_bootstrap = 1000;

[n_trials, ~] = size(pupil_traces);

%% Bin the Pupil Data
time_start = time_vector_raw(1);
time_end = time_vector_raw(end);
bin_edges = time_start:bin_width_sec:time_end;
n_bins = length(bin_edges) - 1;
bin_centers = bin_edges(1:end-1) + bin_width_sec / 2;

binned_pupil = nan(n_trials, n_bins);
for i_bin = 1:n_bins
    bin_start = bin_edges(i_bin);
    bin_end = bin_edges(i_bin + 1);
    in_bin = (time_vector_raw >= bin_start) & (time_vector_raw < bin_end);
    if any(in_bin)
        binned_pupil(:, i_bin) = mean(pupil_traces(:, in_bin), 2, 'omitnan');
    end
end

results.time_vector = bin_centers;
results.is_av_session = is_av_session;

%% Panel A: RPE Analysis (Magnitude-Matched)
rpe_masks = { ...
    conditions.is_rare_low(:), ...
    conditions.is_common_low(:), ...
    conditions.is_rare_high(:), ...
    conditions.is_common_high(:)};
rpe_labels = {'Rare-Low', 'Common-Low', 'Rare-High', 'Common-High'};

results.rpe.trial_counts = cellfun(@sum, rpe_masks);
results.rpe.labels = rpe_labels;

% Pre-allocate
results.rpe.p_dist = nan(1, n_bins);
results.rpe.p_mag = nan(1, n_bins);
results.rpe.p_dist_mag_interaction = nan(1, n_bins);
results.rpe.means = nan(4, n_bins);
results.rpe.ci_95 = nan(4, n_bins, 2);

% Build factors for 2-way ANOVA
dist_factor = nan(n_trials, 1);
mag_factor = nan(n_trials, 1);

dist_factor(rpe_masks{1}) = 1;  % Rare-Low
mag_factor(rpe_masks{1}) = 1;
dist_factor(rpe_masks{2}) = 2;  % Common-Low
mag_factor(rpe_masks{2}) = 1;
dist_factor(rpe_masks{3}) = 1;  % Rare-High
mag_factor(rpe_masks{3}) = 2;
dist_factor(rpe_masks{4}) = 2;  % Common-High
mag_factor(rpe_masks{4}) = 2;

valid_rpe = ~isnan(dist_factor) & ~isnan(mag_factor);

% Run 2-way ANOVA at each bin
for i_bin = 1:n_bins
    pupil_bin = binned_pupil(:, i_bin);
    valid_idx = valid_rpe & ~isnan(pupil_bin);

    y = pupil_bin(valid_idx);
    g_dist = dist_factor(valid_idx);
    g_mag = mag_factor(valid_idx);

    if length(unique(g_dist)) >= 2 && length(unique(g_mag)) >= 2
        try
            [~, tbl, ~] = anovan(y, {g_dist, g_mag}, ...
                'model', 'interaction', ...
                'varnames', {'Dist', 'Mag'}, ...
                'display', 'off');
            results.rpe.p_dist(i_bin) = tbl{2, 7};
            results.rpe.p_mag(i_bin) = tbl{3, 7};
            results.rpe.p_dist_mag_interaction(i_bin) = tbl{4, 7};
        catch
            % Leave as NaN
        end
    end

    % Compute means and CI for each condition
    for i_cond = 1:4
        cell_mask = rpe_masks{i_cond} & ~isnan(pupil_bin);
        cell_data = pupil_bin(cell_mask);
        cell_data = cell_data(~isnan(cell_data));
        n_valid = length(cell_data);

        if n_valid > 0
            results.rpe.means(i_cond, i_bin) = mean(cell_data);
            if n_valid >= 2
                boot_means = nan(n_bootstrap, 1);
                for i_boot = 1:n_bootstrap
                    boot_idx = randi(n_valid, n_valid, 1);
                    boot_means(i_boot) = mean(cell_data(boot_idx));
                end
                ci_bounds = prctile(boot_means, [2.5, 97.5]);
                results.rpe.ci_95(i_cond, i_bin, 1) = ci_bounds(1);
                results.rpe.ci_95(i_cond, i_bin, 2) = ci_bounds(2);
            else
                results.rpe.ci_95(i_cond, i_bin, :) = results.rpe.means(i_cond, i_bin);
            end
        end
    end
end

%% Panel B: SPE Analysis
if is_av_session
    spe_masks = { ...
        conditions.is_noflicker_certain(:), ...
        conditions.is_flicker_omitted(:), ...
        conditions.is_flicker_surprising(:), ...
        conditions.is_flicker_certain(:)};
    spe_labels = {'No-Flicker (0%)', 'Flicker Omitted (50%)', ...
        'Flicker Surprising (50%)', 'Flicker Certain (100%)'};

    results.spe.trial_counts = cellfun(@sum, spe_masks);
    results.spe.labels = spe_labels;

    results.spe.p_contrast = nan(1, n_bins);
    results.spe.means = nan(4, n_bins);
    results.spe.ci_95 = nan(4, n_bins, 2);

    mask_surprising = spe_masks{3};
    mask_certain = spe_masks{4};

    for i_bin = 1:n_bins
        pupil_bin = binned_pupil(:, i_bin);

        % Key contrast (ranksum test)
        data_surp = pupil_bin(mask_surprising & ~isnan(pupil_bin));
        data_cert = pupil_bin(mask_certain & ~isnan(pupil_bin));

        if length(data_surp) >= 2 && length(data_cert) >= 2
            try
                results.spe.p_contrast(i_bin) = ranksum(data_surp, data_cert);
            catch
            end
        end

        % Compute means and CI for each condition
        for i_cond = 1:4
            cell_mask = spe_masks{i_cond} & ~isnan(pupil_bin);
            cell_data = pupil_bin(cell_mask);
            cell_data = cell_data(~isnan(cell_data));
            n_valid = length(cell_data);

            if n_valid > 0
                results.spe.means(i_cond, i_bin) = mean(cell_data);
                if n_valid >= 2
                    boot_means = nan(n_bootstrap, 1);
                    for i_boot = 1:n_bootstrap
                        boot_idx = randi(n_valid, n_valid, 1);
                        boot_means(i_boot) = mean(cell_data(boot_idx));
                    end
                    ci_bounds = prctile(boot_means, [2.5, 97.5]);
                    results.spe.ci_95(i_cond, i_bin, 1) = ci_bounds(1);
                    results.spe.ci_95(i_cond, i_bin, 2) = ci_bounds(2);
                else
                    results.spe.ci_95(i_cond, i_bin, :) = results.spe.means(i_cond, i_bin);
                end
            end
        end
    end
else
    results.spe.trial_counts = nan(1, 4);
    results.spe.labels = {};
    results.spe.p_contrast = nan(1, n_bins);
    results.spe.means = nan(4, n_bins);
    results.spe.ci_95 = nan(4, n_bins, 2);
end

%% Panels C/D: RPE x SPE Interaction (3-way ANOVA)
if is_av_session
    is_unexpected_spe = conditions.is_flicker_surprising(:);
    is_expected_spe = conditions.is_flicker_certain(:);

    int_masks = { ...
        conditions.is_rare_low(:) & is_expected_spe, ...
        conditions.is_rare_low(:) & is_unexpected_spe, ...
        conditions.is_common_low(:) & is_expected_spe, ...
        conditions.is_common_low(:) & is_unexpected_spe, ...
        conditions.is_rare_high(:) & is_expected_spe, ...
        conditions.is_rare_high(:) & is_unexpected_spe, ...
        conditions.is_common_high(:) & is_expected_spe, ...
        conditions.is_common_high(:) & is_unexpected_spe};
    int_labels = { ...
        'Rare-Low, Expected', 'Rare-Low, Unexpected', ...
        'Common-Low, Expected', 'Common-Low, Unexpected', ...
        'Rare-High, Expected', 'Rare-High, Unexpected', ...
        'Common-High, Expected', 'Common-High, Unexpected'};

    results.interaction.trial_counts = cellfun(@sum, int_masks);
    results.interaction.labels = int_labels;

    results.interaction.p_dist = nan(1, n_bins);
    results.interaction.p_spe = nan(1, n_bins);
    results.interaction.p_mag = nan(1, n_bins);
    results.interaction.p_dist_spe = nan(1, n_bins);
    results.interaction.p_dist_mag = nan(1, n_bins);
    results.interaction.p_spe_mag = nan(1, n_bins);
    results.interaction.p_three_way = nan(1, n_bins);
    results.interaction.means = nan(8, n_bins);
    results.interaction.ci_95 = nan(8, n_bins, 2);

    dist_int_factor = nan(n_trials, 1);
    spe_int_factor = nan(n_trials, 1);
    mag_int_factor = nan(n_trials, 1);

    for i_cond = 1:8
        mask = int_masks{i_cond};
        if i_cond <= 2
            dist_int_factor(mask) = 1;
            mag_int_factor(mask) = 1;
        elseif i_cond <= 4
            dist_int_factor(mask) = 2;
            mag_int_factor(mask) = 1;
        elseif i_cond <= 6
            dist_int_factor(mask) = 1;
            mag_int_factor(mask) = 2;
        else
            dist_int_factor(mask) = 2;
            mag_int_factor(mask) = 2;
        end
        if mod(i_cond, 2) == 1
            spe_int_factor(mask) = 1;
        else
            spe_int_factor(mask) = 2;
        end
    end

    valid_int = ~isnan(dist_int_factor) & ~isnan(spe_int_factor) & ~isnan(mag_int_factor);

    for i_bin = 1:n_bins
        pupil_bin = binned_pupil(:, i_bin);
        valid_idx = valid_int & ~isnan(pupil_bin);

        y = pupil_bin(valid_idx);
        g_dist = dist_int_factor(valid_idx);
        g_spe = spe_int_factor(valid_idx);
        g_mag = mag_int_factor(valid_idx);

        if length(unique(g_dist)) >= 2 && length(unique(g_spe)) >= 2 && ...
                length(unique(g_mag)) >= 2
            try
                [~, tbl, ~] = anovan(y, {g_dist, g_spe, g_mag}, ...
                    'model', 'full', ...
                    'varnames', {'Dist', 'SPE', 'Mag'}, ...
                    'display', 'off');
                results.interaction.p_dist(i_bin) = tbl{2, 7};
                results.interaction.p_spe(i_bin) = tbl{3, 7};
                results.interaction.p_mag(i_bin) = tbl{4, 7};
                results.interaction.p_dist_spe(i_bin) = tbl{5, 7};
                results.interaction.p_dist_mag(i_bin) = tbl{6, 7};
                results.interaction.p_spe_mag(i_bin) = tbl{7, 7};
                results.interaction.p_three_way(i_bin) = tbl{8, 7};
            catch
            end
        end

        for i_cond = 1:8
            cell_mask = int_masks{i_cond} & ~isnan(pupil_bin);
            cell_data = pupil_bin(cell_mask);
            cell_data = cell_data(~isnan(cell_data));
            n_valid = length(cell_data);

            if n_valid > 0
                results.interaction.means(i_cond, i_bin) = mean(cell_data);
                if n_valid >= 2
                    boot_means = nan(n_bootstrap, 1);
                    for i_boot = 1:n_bootstrap
                        boot_idx = randi(n_valid, n_valid, 1);
                        boot_means(i_boot) = mean(cell_data(boot_idx));
                    end
                    ci_bounds = prctile(boot_means, [2.5, 97.5]);
                    results.interaction.ci_95(i_cond, i_bin, 1) = ci_bounds(1);
                    results.interaction.ci_95(i_cond, i_bin, 2) = ci_bounds(2);
                else
                    results.interaction.ci_95(i_cond, i_bin, :) = ...
                        results.interaction.means(i_cond, i_bin);
                end
            end
        end
    end
else
    results.interaction.trial_counts = nan(1, 8);
    results.interaction.labels = {};
    results.interaction.p_dist = nan(1, n_bins);
    results.interaction.p_spe = nan(1, n_bins);
    results.interaction.p_mag = nan(1, n_bins);
    results.interaction.p_dist_spe = nan(1, n_bins);
    results.interaction.p_dist_mag = nan(1, n_bins);
    results.interaction.p_spe_mag = nan(1, n_bins);
    results.interaction.p_three_way = nan(1, n_bins);
    results.interaction.means = nan(8, n_bins);
    results.interaction.ci_95 = nan(8, n_bins, 2);
end

%% Print Summary
fprintf('\n--- Panel A: RPE (Magnitude-Matched) ---\n');
fprintf('  Trial counts: Rare-Low=%d, Common-Low=%d, Rare-High=%d, Common-High=%d\n', ...
    results.rpe.trial_counts(1), results.rpe.trial_counts(2), ...
    results.rpe.trial_counts(3), results.rpe.trial_counts(4));

if is_av_session
    fprintf('\n--- Panel B: SPE ---\n');
    fprintf('  Trial counts: No-Flicker=%d, Omitted=%d, Surprising=%d, Certain=%d\n', ...
        results.spe.trial_counts(1), results.spe.trial_counts(2), ...
        results.spe.trial_counts(3), results.spe.trial_counts(4));

    fprintf('\n--- Panels C/D: RPE x SPE Interaction (8 conditions) ---\n');
    fprintf('  Trial counts:\n');
    fprintf('                     Expected  Unexpected\n');
    fprintf('    Rare-Low:        %4d      %4d\n', ...
        results.interaction.trial_counts(1), results.interaction.trial_counts(2));
    fprintf('    Common-Low:      %4d      %4d\n', ...
        results.interaction.trial_counts(3), results.interaction.trial_counts(4));
    fprintf('    Rare-High:       %4d      %4d\n', ...
        results.interaction.trial_counts(5), results.interaction.trial_counts(6));
    fprintf('    Common-High:     %4d      %4d\n', ...
        results.interaction.trial_counts(7), results.interaction.trial_counts(8));
else
    fprintf('\n--- No-AV session: SPE and Interaction analyses skipped ---\n');
end

end


function fig = generateFigure(results, sessionId, is_av_session)
%GENERATEFIGURE Create multi-panel figure showing analysis results

time_vec = results.time_vector;
alpha_thresh = 0.05;

%% Define Color Palettes
rpe_colors = [ ...
    0.40, 0.60, 0.85; ...  % Rare-Low (light blue)
    0.95, 0.60, 0.30; ...  % Common-Low (light orange)
    0.10, 0.25, 0.60; ...  % Rare-High (dark blue)
    0.80, 0.35, 0.10];     % Common-High (dark orange)

spe_colors = [ ...
    0.50, 0.50, 0.50; ...  % Gray - No-Flicker
    0.80, 0.60, 0.20; ...  % Gold - Flicker Omitted
    0.90, 0.30, 0.10; ...  % Red-orange - Flicker Surprising
    0.20, 0.70, 0.40];     % Green - Flicker Certain

int_colors_low = [ ...
    0.40, 0.60, 0.85; ...
    0.40, 0.60, 0.85; ...
    0.95, 0.60, 0.30; ...
    0.95, 0.60, 0.30];

int_colors_high = [ ...
    0.10, 0.25, 0.60; ...
    0.10, 0.25, 0.60; ...
    0.80, 0.35, 0.10; ...
    0.80, 0.35, 0.10];

p_color_dist = [0.20, 0.40, 0.70];
p_color_mag = [0.60, 0.20, 0.60];
p_color_int = [0.80, 0.00, 0.60];
p_color_spe = [0.20, 0.70, 0.40];
p_color_contrast = [0.90, 0.30, 0.10];
p_color_dist_spe = [0.00, 0.50, 0.50];

%% Create Figure
if is_av_session
    fig = figure('Position', [50, 50, 1800, 700], 'Color', 'w');
    panel_width = 0.20;
    panel_height = 0.35;
    gap_x = 0.04;
    gap_y = 0.08;
    margin_left = 0.05;
    margin_bottom = 0.10;
    x_positions = margin_left + (0:3) * (panel_width + gap_x);
    y_top = margin_bottom + panel_height + gap_y;
    y_bottom = margin_bottom;
else
    fig = figure('Position', [50, 50, 500, 700], 'Color', 'w');
    panel_width = 0.75;
    panel_height = 0.35;
    gap_y = 0.08;
    margin_left = 0.15;
    margin_bottom = 0.10;
    x_positions = margin_left;
    y_top = margin_bottom + panel_height + gap_y;
    y_bottom = margin_bottom;
end

%% Panel A: RPE Traces
ax_rpe = axes('Position', [x_positions(1), y_top, panel_width, panel_height]);
hold on;

rpe_means = results.rpe.means;
rpe_ci_lower = results.rpe.ci_95(:, :, 1);
rpe_ci_upper = results.rpe.ci_95(:, :, 2);

for i_cond = 1:4
    x_patch = [time_vec, fliplr(time_vec)];
    y_patch = [rpe_ci_lower(i_cond, :), fliplr(rpe_ci_upper(i_cond, :))];
    valid = ~isnan(y_patch);
    if any(valid)
        fill(x_patch(valid), y_patch(valid), rpe_colors(i_cond, :), ...
            'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end

h_rpe = gobjects(4, 1);
for i_cond = 1:4
    h_rpe(i_cond) = plot(time_vec, rpe_means(i_cond, :), ...
        'Color', rpe_colors(i_cond, :), 'LineWidth', 2);
end

xline(0, 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
ylabel('Pupil Response (norm.)');
xlim([time_vec(1), time_vec(end)]);
box off;
set(ax_rpe, 'TickDir', 'out', 'XTickLabel', []);
legend(h_rpe, results.rpe.labels, 'Location', 'northwest', 'FontSize', 7, 'Box', 'off');
tc = results.rpe.trial_counts;
title(sprintf('A. RPE: n=[%d,%d,%d,%d]', tc(1), tc(2), tc(3), tc(4)), 'FontWeight', 'normal');

%% Panel E: RPE P-values
ax_rpe_p = axes('Position', [x_positions(1), y_bottom, panel_width, panel_height]);
hold on;

p_dist = results.rpe.p_dist;
p_mag = results.rpe.p_mag;
p_dist_mag = results.rpe.p_dist_mag_interaction;

localShadeSignificant(time_vec, p_dist, alpha_thresh, p_color_dist, 0.15);
localShadeSignificant(time_vec, p_mag, alpha_thresh, p_color_mag, 0.15);
localShadeSignificant(time_vec, p_dist_mag, alpha_thresh, p_color_int, 0.15);

h_p_rpe(1) = plot(time_vec, p_dist, 'Color', p_color_dist, 'LineWidth', 1.5);
h_p_rpe(2) = plot(time_vec, p_mag, 'Color', p_color_mag, 'LineWidth', 1.5);
h_p_rpe(3) = plot(time_vec, p_dist_mag, 'Color', p_color_int, 'LineWidth', 1.5);

yline(alpha_thresh, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
xline(0, 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
xlabel('Time from Outcome (s)');
ylabel('p-value');
xlim([time_vec(1), time_vec(end)]);
ylim([0, 1]);
box off;
set(ax_rpe_p, 'TickDir', 'out');
legend(h_p_rpe, {'Dist', 'Mag', 'Dist x Mag'}, 'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
title('E. RPE 2-way ANOVA', 'FontWeight', 'normal');

%% AV Session Panels (B-H)
if is_av_session

    %% Panel B: SPE Traces
    ax_spe = axes('Position', [x_positions(2), y_top, panel_width, panel_height]);
    hold on;

    spe_means = results.spe.means;
    spe_ci_lower = results.spe.ci_95(:, :, 1);
    spe_ci_upper = results.spe.ci_95(:, :, 2);
    p_contrast = results.spe.p_contrast;

    localShadeSignificantBelow(time_vec, p_contrast, alpha_thresh, p_color_contrast, 0.3, ax_spe);

    for i_cond = 1:4
        x_patch = [time_vec, fliplr(time_vec)];
        y_patch = [spe_ci_lower(i_cond, :), fliplr(spe_ci_upper(i_cond, :))];
        valid = ~isnan(y_patch);
        if any(valid)
            fill(x_patch(valid), y_patch(valid), spe_colors(i_cond, :), ...
                'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end

    h_spe = gobjects(4, 1);
    line_widths = [1.5, 1.5, 2.5, 2.5];
    for i_cond = 1:4
        h_spe(i_cond) = plot(time_vec, spe_means(i_cond, :), ...
            'Color', spe_colors(i_cond, :), 'LineWidth', line_widths(i_cond));
    end

    xline(0, 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xlim([time_vec(1), time_vec(end)]);
    box off;
    set(ax_spe, 'TickDir', 'out', 'XTickLabel', [], 'YTickLabel', []);
    legend(h_spe, {'0% (No-Flicker)', '50% (Omitted)', '50% (Surprising)', '100% (Certain)'}, ...
        'Location', 'northwest', 'FontSize', 7, 'Box', 'off');
    tc = results.spe.trial_counts;
    title(sprintf('B. SPE: n=[%d,%d,%d,%d]', tc(1), tc(2), tc(3), tc(4)), 'FontWeight', 'normal');

    %% Panel F: SPE P-values
    ax_spe_p = axes('Position', [x_positions(2), y_bottom, panel_width, panel_height]);
    hold on;

    localShadeSignificant(time_vec, p_contrast, alpha_thresh, p_color_contrast, 0.2);
    plot(time_vec, p_contrast, 'Color', p_color_contrast, 'LineWidth', 1.5);

    yline(alpha_thresh, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(0, 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xlabel('Time from Outcome (s)');
    xlim([time_vec(1), time_vec(end)]);
    ylim([0, 1]);
    box off;
    set(ax_spe_p, 'TickDir', 'out', 'YTickLabel', []);
    title('F. SPE Contrast (ranksum)', 'FontWeight', 'normal');

    %% Panel C: Interaction - Low Rewards
    ax_int_low = axes('Position', [x_positions(3), y_top, panel_width, panel_height]);
    hold on;

    int_means = results.interaction.means;
    int_ci_lower = results.interaction.ci_95(:, :, 1);
    int_ci_upper = results.interaction.ci_95(:, :, 2);

    low_indices = [1, 2, 3, 4];
    low_means = int_means(low_indices, :);
    low_ci_lower = int_ci_lower(low_indices, :);
    low_ci_upper = int_ci_upper(low_indices, :);

    for i_cond = 1:4
        x_patch = [time_vec, fliplr(time_vec)];
        y_patch = [low_ci_lower(i_cond, :), fliplr(low_ci_upper(i_cond, :))];
        valid = ~isnan(y_patch);
        if any(valid)
            fill(x_patch(valid), y_patch(valid), int_colors_low(i_cond, :), ...
                'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end

    h_int_low = gobjects(4, 1);
    line_styles_int = {'-', '--', '-', '--'};
    for i_cond = 1:4
        h_int_low(i_cond) = plot(time_vec, low_means(i_cond, :), ...
            'Color', int_colors_low(i_cond, :), 'LineWidth', 2, ...
            'LineStyle', line_styles_int{i_cond});
    end

    xline(0, 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xlim([time_vec(1), time_vec(end)]);
    box off;
    set(ax_int_low, 'TickDir', 'out', 'XTickLabel', [], 'YTickLabel', []);
    legend(h_int_low, {'Rare-Low Exp', 'Rare-Low Unexp', 'Common-Low Exp', 'Common-Low Unexp'}, ...
        'Location', 'northwest', 'FontSize', 6, 'Box', 'off');
    tc = results.interaction.trial_counts;
    title(sprintf('C. RPE x SPE (Low): n=[%d,%d,%d,%d]', tc(1), tc(2), tc(3), tc(4)), 'FontWeight', 'normal');

    %% Panel G: 3-way ANOVA p-values (Low)
    ax_int_low_p = axes('Position', [x_positions(3), y_bottom, panel_width, panel_height]);
    hold on;

    p_dist_3way = results.interaction.p_dist;
    p_spe_3way = results.interaction.p_spe;
    p_dist_spe_3way = results.interaction.p_dist_spe;

    localShadeSignificant(time_vec, p_dist_3way, alpha_thresh, p_color_dist, 0.15);
    localShadeSignificant(time_vec, p_spe_3way, alpha_thresh, p_color_spe, 0.15);
    localShadeSignificant(time_vec, p_dist_spe_3way, alpha_thresh, p_color_dist_spe, 0.15);

    h_p_low(1) = plot(time_vec, p_dist_3way, 'Color', p_color_dist, 'LineWidth', 1.5);
    h_p_low(2) = plot(time_vec, p_spe_3way, 'Color', p_color_spe, 'LineWidth', 1.5);
    h_p_low(3) = plot(time_vec, p_dist_spe_3way, 'Color', p_color_dist_spe, 'LineWidth', 1.5);

    yline(alpha_thresh, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(0, 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xlabel('Time from Outcome (s)');
    xlim([time_vec(1), time_vec(end)]);
    ylim([0, 1]);
    box off;
    set(ax_int_low_p, 'TickDir', 'out', 'YTickLabel', []);
    legend(h_p_low, {'Dist', 'SPE', 'Dist x SPE'}, 'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
    title('G. 3-way ANOVA (Low)', 'FontWeight', 'normal');

    %% Panel D: Interaction - High Rewards
    ax_int_high = axes('Position', [x_positions(4), y_top, panel_width, panel_height]);
    hold on;

    high_indices = [5, 6, 7, 8];
    high_means = int_means(high_indices, :);
    high_ci_lower = int_ci_lower(high_indices, :);
    high_ci_upper = int_ci_upper(high_indices, :);

    for i_cond = 1:4
        x_patch = [time_vec, fliplr(time_vec)];
        y_patch = [high_ci_lower(i_cond, :), fliplr(high_ci_upper(i_cond, :))];
        valid = ~isnan(y_patch);
        if any(valid)
            fill(x_patch(valid), y_patch(valid), int_colors_high(i_cond, :), ...
                'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        end
    end

    h_int_high = gobjects(4, 1);
    for i_cond = 1:4
        h_int_high(i_cond) = plot(time_vec, high_means(i_cond, :), ...
            'Color', int_colors_high(i_cond, :), 'LineWidth', 2, ...
            'LineStyle', line_styles_int{i_cond});
    end

    xline(0, 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xlim([time_vec(1), time_vec(end)]);
    box off;
    set(ax_int_high, 'TickDir', 'out', 'XTickLabel', [], 'YTickLabel', []);
    legend(h_int_high, {'Rare-High Exp', 'Rare-High Unexp', 'Common-High Exp', 'Common-High Unexp'}, ...
        'Location', 'northwest', 'FontSize', 6, 'Box', 'off');
    title(sprintf('D. RPE x SPE (High): n=[%d,%d,%d,%d]', tc(5), tc(6), tc(7), tc(8)), 'FontWeight', 'normal');

    %% Panel H: 3-way ANOVA p-values (High)
    ax_int_high_p = axes('Position', [x_positions(4), y_bottom, panel_width, panel_height]);
    hold on;

    localShadeSignificant(time_vec, p_dist_3way, alpha_thresh, p_color_dist, 0.15);
    localShadeSignificant(time_vec, p_spe_3way, alpha_thresh, p_color_spe, 0.15);
    localShadeSignificant(time_vec, p_dist_spe_3way, alpha_thresh, p_color_dist_spe, 0.15);

    h_p_high(1) = plot(time_vec, p_dist_3way, 'Color', p_color_dist, 'LineWidth', 1.5);
    h_p_high(2) = plot(time_vec, p_spe_3way, 'Color', p_color_spe, 'LineWidth', 1.5);
    h_p_high(3) = plot(time_vec, p_dist_spe_3way, 'Color', p_color_dist_spe, 'LineWidth', 1.5);

    yline(alpha_thresh, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
    xline(0, 'k--', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    xlabel('Time from Outcome (s)');
    xlim([time_vec(1), time_vec(end)]);
    ylim([0, 1]);
    box off;
    set(ax_int_high_p, 'TickDir', 'out', 'YTickLabel', []);
    legend(h_p_high, {'Dist', 'SPE', 'Dist x SPE'}, 'Location', 'northeast', 'FontSize', 7, 'Box', 'off');
    title('H. 3-way ANOVA (High)', 'FontWeight', 'normal');

    %% Synchronize Y-axes for trace panels
    all_ci_lower = [rpe_ci_lower(:); spe_ci_lower(:); int_ci_lower(:)];
    all_ci_upper = [rpe_ci_upper(:); spe_ci_upper(:); int_ci_upper(:)];
    y_min = min(all_ci_lower, [], 'omitnan');
    y_max = max(all_ci_upper, [], 'omitnan');
    y_range = y_max - y_min;
    y_lim = [y_min - 0.1 * y_range, y_max + 0.1 * y_range];

    set(ax_rpe, 'YLim', y_lim);
    set(ax_spe, 'YLim', y_lim);
    set(ax_int_low, 'YLim', y_lim);
    set(ax_int_high, 'YLim', y_lim);

end

%% Set Y-limits for RPE panel (no-AV sessions)
if ~is_av_session
    y_min = min(rpe_ci_lower(:), [], 'omitnan');
    y_max = max(rpe_ci_upper(:), [], 'omitnan');
    y_range = y_max - y_min;
    y_lim = [y_min - 0.1 * y_range, y_max + 0.1 * y_range];
    set(ax_rpe, 'YLim', y_lim);
end

%% Add Supertitle
if is_av_session
    title_str = sprintf('Pupil Responses: %s', sessionId);
else
    title_str = sprintf('Pupil Responses (RPE only): %s', sessionId);
end
sgtitle(title_str, 'Interpreter', 'none', 'FontWeight', 'bold');

end


function localShadeSignificant(time_vec, p_values, alpha, color, face_alpha)
%LOCALSHADESIGNIFICANT Add shaded patches where p < alpha

is_sig = p_values < alpha;
if ~any(is_sig)
    return;
end

diff_sig = diff([0, is_sig, 0]);
starts = find(diff_sig == 1);
ends = find(diff_sig == -1) - 1;

for i_region = 1:length(starts)
    idx_start = starts(i_region);
    idx_end = ends(i_region);

    if idx_start > 1
        t_start = (time_vec(idx_start) + time_vec(idx_start - 1)) / 2;
    else
        t_start = time_vec(idx_start);
    end

    if idx_end < length(time_vec)
        t_end = (time_vec(idx_end) + time_vec(idx_end + 1)) / 2;
    else
        t_end = time_vec(idx_end);
    end

    x_patch = [t_start, t_end, t_end, t_start];
    y_patch = [0, 0, alpha, alpha];

    fill(x_patch, y_patch, color, 'FaceAlpha', face_alpha, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off');
end

end


function localShadeSignificantBelow(time_vec, p_values, alpha, color, face_alpha, ax)
%LOCALSHADESIGNIFICANTBELOW Add shaded bars at bottom of axes for significance

is_sig = p_values < alpha;
if ~any(is_sig)
    return;
end

yl = get(ax, 'YLim');
if all(yl == [0, 1])
    y_bar_height = 0.02;
    y_bar_bottom = yl(1);
else
    y_range = yl(2) - yl(1);
    y_bar_height = 0.03 * y_range;
    y_bar_bottom = yl(1);
end

diff_sig = diff([0, is_sig, 0]);
starts = find(diff_sig == 1);
ends = find(diff_sig == -1) - 1;

for i_region = 1:length(starts)
    idx_start = starts(i_region);
    idx_end = ends(i_region);

    if idx_start > 1
        t_start = (time_vec(idx_start) + time_vec(idx_start - 1)) / 2;
    else
        t_start = time_vec(idx_start);
    end

    if idx_end < length(time_vec)
        t_end = (time_vec(idx_end) + time_vec(idx_end + 1)) / 2;
    else
        t_end = time_vec(idx_end);
    end

    x_patch = [t_start, t_end, t_end, t_start];
    y_patch = [y_bar_bottom, y_bar_bottom, ...
        y_bar_bottom + y_bar_height, y_bar_bottom + y_bar_height];

    fill(x_patch, y_patch, color, 'FaceAlpha', face_alpha, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off');
end

end


function localPdfSave(fileName, paperSize, fh)
%LOCALPDFSAVE Save figure as PDF with WYSIWYG rendering

set(fh, 'PaperUnits', 'Inches', 'PaperSize', paperSize);
set(fh, 'PaperUnits', 'Normalized', 'PaperPosition', [0 0 1 1]);
saveas(fh, fileName, 'pdf');

end
