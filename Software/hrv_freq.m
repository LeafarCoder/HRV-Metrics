function [ hrv_fd, pxx, f_axis, plot_data ] = hrv_freq( nni, varargin )
%NN interval spectrum and frequency-domain HRV metrics This function estimates
%the PSD (power spectral density) of a given nn-interval sequence, and
%calculates the power in various frequency bands.
%
%:param nni: RR/NN intervals, in seconds.
%
%:param varargin: Pass in name-value pairs to configure advanced options:
%
%   - methods: A cell array of strings containing names of methods to use to
%     estimate the spectrum. Supported methods are:
%
%       - ``lomb``: Lomb-scargle periodogram.
%       - ``ar``: Yule-Walker autoregressive model. Data will be resampled. No windowing will
%         be performed for this method.
%       - ``welch``: Welch's method (overlapping windows).
%       - ``fft``: Simple fft-based periodogram, no overlap (also known as
%         Bartlett's method).
%
%     In all cases, a window will be used on the samples according to the
%     ``win_func`` parameter.  Data will be resampled for all methods except
%     ``lomb``.  Default value is ``{'lomb', 'ar', 'welch'}``.
%
%   - time_intervals: specify the time interval vector tnn. If it is not
%     specified then it will be computed from the nni time series.
%   - power_methods: The method(s) to use for calculating the power in each
%     band. A cell array where each element can be any one of the methods given
%     in 'methods'. This also determines the spectrum that will be returned
%     from this function (pxx).  Default: First value in ``methods``.
%   - norm_method: A string, either ``total`` or ``lf_hf``. If ``total``,
%     then the power in each band will be normalized by the total
%     power in the entire frequency spectrum. If ``lf_hf``, then only
%     for the LF and HF bands, the normalization will be performed
%     by the (LF+HF) power. This is the standard method used in
%     many papers to normalize these bands. In any case, VLF and
%     user-defined custom bands are not affected by this parameter.
%   - band_factor: A factor that will be applied to the frequency bands. Useful
%     for shifting them linearly to adapt to non-human data. Default: 1.0 (no
%     shift).
%   - vlf_band: 2-element vector of frequencies in Hz defining the VLF band.
%     Default: [0.003, 0.04].
%   - lf_band: 2-element vector of frequencies in Hz defining the LF band.
%     Default: [0.04, 0.15].
%   - hf_band: 2-element vector of frequencies in Hz defining the HF band.
%     Default: [0.15, 0.4].
%   - extra_bands: A cell array of frequency pairs, for example
%     ``{[f_start,f_end], ...}``. Each pair defines a custom band for
%     which the power and normalized power will be calculated.
%   - window_minutes: Split intervals into windows of this length, calcualte
%     the spectrum in each window, and average them. A window funciton will be
%     also be applied to each window after breaking the intervals into windows.
%     Set to [] if you want to disable windowing.  Default: 5 minutes.
%   - detrend_order: Order of polynomial to fit to the data for detrending.
%     Default: 1 (i.e. linear detrending).
%   - ar_order: Order of the autoregressive model to use if ``ar`` method is specific.
%     Default: 24.
%   - welch_overlap: Percentage of overlap between windows when using Welch's method.
%     Default: 50 percent.
%   - win_func: The window function to apply to each segment. Should be a
%     function that accepts one parameter (length in samples) and returns a
%     window of that length. Default: @hamming.
%   - plot: true/false whether to generate plots. Defaults to true if no output
%     arguments were specified.
%
%:returns:
%
%   - hrv_fd: Table containing the following HRV metrics:
%
%       - TOTAL_POWER: Total power in all three bands combined.
%       - VLF_POWER: Power in the VLF band.
%       - LF_POWER: Power in the LF band.
%       - HF_POWER: Power in the HF band.
%       - VLF_NORM: 100 * Ratio between VLF power and total power.
%       - LF_NORM: 100 * Ratio between LF power and total power or the sum of
%         LF and HF power (see 'norm_method').  - HF_NORM: 100 * Ratio between HF
%         power and total power or the sum of LF and HF power (see
%         ``norm_method``).
%       - LF_TO_HF: Ratio between LF and HF power.
%       - LF_PEAK: Frequency of highest peak in the LF band.
%       - HF_PEAK: Frequency of highest peak in the HF band.
%       - BETA: Slope of log-log frequency plot in the VLF band.
%
%     Note that each of the above metrics will be calculated for each value
%     given in ``power_methods``, and their names will be suffixed with the
%     method name (e.g. LF_PEAK_LOMB).
%
%   - pxx: Power spectrum. It's type is determined by the first value in
%     ``power_methods``.
%   - f_axis: Frequencies, in Hz, at which pxx was calculated.

import mhrv.defaults.*;

%% Input
SUPPORTED_METHODS = {'Lomb', 'AR', 'Welch', 'FFT'};

% Defaults
DEFAULT_METHODS = mhrv_get_default('hrv_freq.methods', 'value');
DEFAULT_POWER_METHODS = mhrv_get_default('hrv_freq.power_methods', 'value');
DEFAULT_NORM_METHOD = mhrv_get_default('hrv_freq.norm_method', 'value');
DEFAULT_BAND_FACTOR = 1;
DEFAULT_BETA_BAND = mhrv_get_default('hrv_freq.beta_band', 'value');
DEFAULT_VLF_BAND = mhrv_get_default('hrv_freq.vlf_band', 'value');
DEFAULT_LF_BAND  = mhrv_get_default('hrv_freq.lf_band', 'value');
DEFAULT_HF_BAND  = mhrv_get_default('hrv_freq.hf_band', 'value');
DEFAULT_EXTRA_BANDS = mhrv_get_default('hrv_freq.extra_bands', 'value');
DEFAULT_WINDOW_MINUTES = mhrv_get_default('hrv_freq.window_minutes', 'value');
DEFAULT_AR_ORDER = mhrv_get_default('hrv_freq.ar_order', 'value');
DEFAULT_WELCH_OVERLAP = mhrv_get_default('hrv_freq.welch_overlap', 'value');
DEFAULT_NUM_PEAKS = 5;
DEFAULT_RESAMPLE_FACTOR = mhrv_get_default('hrv_freq.resample_factor', 'value');
DEFAULT_FREQ_OSF = mhrv_get_default('hrv_freq.osf', 'value');
DEFAULT_WIN_FUNC = mhrv_get_default('hrv_freq.win_func', 'value');

% Define input
p = inputParser;
p.addRequired('nni', @(x) isnumeric(x) && ~isscalar(x));
p.addParameter('time_intervals', [], @(x) isnumeric(x) && ~isscalar(x));
p.addParameter('methods', DEFAULT_METHODS, @(x) iscellstr(x) && ~isempty(x));
p.addParameter('power_methods', DEFAULT_POWER_METHODS, @iscellstr);
p.addParameter('norm_method', DEFAULT_NORM_METHOD, @ischar);
p.addParameter('band_factor', DEFAULT_BAND_FACTOR, @(x) isnumeric(x)&&isscalar(x)&&x>0);
p.addParameter('beta_band', DEFAULT_BETA_BAND, @(x) isempty(x)||(isnumeric(x)&&length(x)==2&&x(2)>x(1)));
p.addParameter('vlf_band', DEFAULT_VLF_BAND, @(x) isnumeric(x)&&length(x)==2&&x(2)>x(1));
p.addParameter('lf_band', DEFAULT_LF_BAND, @(x) isnumeric(x)&&length(x)==2&&x(2)>x(1));
p.addParameter('hf_band', DEFAULT_HF_BAND, @(x) isnumeric(x)&&length(x)==2&&x(2)>x(1));
p.addParameter('extra_bands', DEFAULT_EXTRA_BANDS, @(x) all(cellfun(@(y)isnumeric(y)&&length(y)==2&&y()>y(1), x)));
p.addParameter('window_minutes', DEFAULT_WINDOW_MINUTES, @(x) isnumeric(x));
p.addParameter('ar_order', DEFAULT_AR_ORDER, @(x) isnumeric(x)&&isscalar(x));
p.addParameter('welch_overlap', DEFAULT_WELCH_OVERLAP, @(x) isnumeric(x)&&isscalar(x)&&x>=0&&x<100);
p.addParameter('num_peaks', DEFAULT_NUM_PEAKS, @(x) isnumeric(x)&&isscalar(x));
p.addParameter('resample_factor', DEFAULT_RESAMPLE_FACTOR, @(x) isnumeric(x)&&isscalar(x)&&x>=2);
p.addParameter('freq_osf', DEFAULT_FREQ_OSF, @(x) isnumeric(x)&&isscalar(x)&&x>=1);
p.addParameter('win_func', DEFAULT_WIN_FUNC, @(x) isa(x,'function_handle') || ischar(x));
p.addParameter('plot', nargout == 0, @islogical);

% Get input
p.parse(nni, varargin{:});
tnn = p.Results.time_intervals;
methods = p.Results.methods;
power_methods = p.Results.power_methods;
norm_method = p.Results.norm_method;
band_factor = p.Results.band_factor;
beta_band = p.Results.beta_band .* band_factor;
vlf_band = p.Results.vlf_band .* band_factor;
lf_band = p.Results.lf_band   .* band_factor;
hf_band = p.Results.hf_band   .* band_factor;
extra_bands = p.Results.extra_bands;
window_minutes = p.Results.window_minutes;
ar_order = p.Results.ar_order;
welch_overlap = p.Results.welch_overlap;
num_peaks = p.Results.num_peaks;
resample_factor = p.Results.resample_factor;
freq_osf = p.Results.freq_osf;
win_func = p.Results.win_func;
should_plot = p.Results.plot;

% Validate methods
methods_validity = cellfun(@(method) any(strcmpi(SUPPORTED_METHODS, method)), methods);
if (~all(methods_validity))
    invalid_methods = methods(~methods_validity);
    error('Invalid methods given: %s.', strjoin(invalid_methods, ', '));
end

% Validate power method
if (isempty(power_methods))
    % Use the first provided method if power_method not provided
    power_methods = methods(1);
else
    power_methods_validity = cellfun(@(power_method) any(strcmpi(methods, power_method)), power_methods);
    if (~all(power_methods_validity))
        error('Invalid power_method given: %s.', strjoin(power_methods(~power_methods_validity), ', '));
    end
end

% Validate norm_method
if ~(strcmpi(norm_method, 'total') || strcmpi(norm_method, 'lf_hf'))
    error('Invalid norm_method given: %s', norm_method);
end

% Default beta_band to vlf_band if unspecified
if isempty(beta_band)
    beta_band = vlf_band;
end

% Convert window function to function handle if specified as string
if (ischar(win_func))
    win_func = str2func(win_func);
end

%% Preprocess

% Calculate zero-based interval time axis
nni = nni(:);
if isempty(tnn)
    tnn = [0; cumsum(nni(1:end-1))];
end

% Zero mean to remove DC component
nni = nni - mean(nni);

%% Initializations

% Default window_minutes to maximal value if requested
if (isempty(window_minutes))
    window_minutes = max(1, floor((tnn(end)-tnn(1)) / 60));
end

t_max = tnn(end);
f_min = min(beta_band(1), vlf_band(1));
f_max = hf_band(2);

% Minimal window length (in seconds) needed to resolve f_min
t_win_min = 1/f_min;

% Increase window size if it's too small
t_win = 60 * window_minutes; % Window length in seconds
if t_win < t_win_min
    t_win = t_win_min;
end

% In case there's not enough data for one window, use entire signal length
num_windows = floor(t_max / t_win);
if (num_windows < 1)
    num_windows = 1;
    t_win = floor(tnn(end)-tnn(1));
end

% Uniform sampling freq: Take at least 2x more than f_max
fs_uni = resample_factor * f_max; %Hz

% Uniform time axis
tnn_uni = tnn(1) : 1/fs_uni : tnn(end);
n_win_uni = floor(t_win / (1/fs_uni)); % number of samples in each window
num_windows_uni = floor(length(tnn_uni) / n_win_uni);

% Build a frequency axis
ts = t_win / (n_win_uni-1);   % Sampling time interval
f_res = 1 / (n_win_uni * ts); % Frequency resolution (also known as f_min of delta_f), theoretical limit
f_res = f_res / freq_osf;     % Apply oversampling factor (causes interpolation in freq. domain)

f_axis = (f_res : f_res : f_max)';
beta_idx = f_axis >= beta_band(1) & f_axis <= beta_band(2);

% Check Nyquist criterion: We need atleast 2*f_max*t_win samples in each window to resolve f_max.
if (n_win_uni < 2*f_max*t_win)
    warning('Nyquist criterion not met for given window length and frequency bands');
end

% Initialize outputs
pxx_lomb  = []; calc_lomb  = false;
pxx_ar    = []; calc_ar    = false;
pxx_welch = []; calc_welch = false;
pxx_fft   = []; calc_fft   = false;

if (any(strcmp(methods, 'lomb')))
    pxx_lomb = zeros(length(f_axis), 1);
    calc_lomb = true;
end
if (any(strcmp(methods, 'ar')))
    pxx_ar = zeros(length(f_axis), 1);
    calc_ar = true;
end
if (any(strcmp(methods, 'welch')))
    pxx_welch = zeros(length(f_axis), 1);
    calc_welch = true;
end
if (any(strcmp(methods, 'fft')))
    pxx_fft = zeros(length(f_axis), 1);
    calc_fft = true;
end

% Interlopate nn-intervals if needed
if (calc_ar || calc_fft || calc_welch)
    nni_uni = interp1(tnn, nni, tnn_uni, 'spline')';
end

%% Lomb method
if (calc_lomb)
    for curr_win = 1:num_windows
        curr_win_idx = (tnn >= t_win * (curr_win-1)) & (tnn < t_win * curr_win);

        nni_win = nni(curr_win_idx);
        tnn_win = tnn(curr_win_idx);
        nni_win = nni_win - mean(nni_win);

        n_win = length(nni_win);
        window = win_func(n_win);
        nni_win = nni_win .* window;

        % Check Nyquist criterion
        min_samples_nyquist = ceil(2*f_max*t_win);
        if (n_win < min_samples_nyquist)
            warning('Nyquist criterion not met for lomb periodogram in window %d (only %d of %d samples)',...
                    curr_win, n_win, min_samples_nyquist);
        end

        [pxx_lomb_win, ~] = plomb(nni_win, tnn_win, f_axis);
        pxx_lomb_win = pxx_lomb_win * (1/mean(window)); % gain correction
        pxx_lomb = pxx_lomb + pxx_lomb_win;
    end
    % Average
    pxx_lomb = pxx_lomb ./ num_windows;
end

%% AR Method
if (calc_ar)
    for curr_win = 1:num_windows_uni
        curr_win_idx = ((curr_win - 1) * n_win_uni + 1) : (curr_win * n_win_uni);
        nni_win = nni_uni(curr_win_idx);
        nni_win = nni_win - mean(nni_win);

        % AR periodogram
        [pxx_ar_win, ~] = pyulear(nni_win, ar_order, f_axis, fs_uni);
        pxx_ar = pxx_ar + pxx_ar_win;
    end
    % Average
    pxx_ar = pxx_ar ./ num_windows_uni;
end

%% Welch Method
if (calc_welch)
    window = win_func(n_win_uni);
    welch_overlap_samples = floor(n_win_uni * welch_overlap / 100);
    [pxx_welch, ~] = pwelch(nni_uni, window, welch_overlap_samples, f_axis, fs_uni);
    pxx_welch  = pxx_welch * (1/mean(window)); % gain correction
end

%% FFT method
if (calc_fft)
    window = win_func(n_win_uni);
    for curr_win = 1:num_windows_uni
        curr_win_idx = ((curr_win - 1) * n_win_uni + 1) : (curr_win * n_win_uni);
        nni_win = nni_uni(curr_win_idx);
        nni_win = nni_win - mean(nni_win);

        % FFT periodogram
        [pxx_fft_win, ~] = periodogram(nni_win, window, f_axis, fs_uni);
        pxx_fft_win = pxx_fft_win * (1/mean(window)); % gain correction
        pxx_fft = pxx_fft + pxx_fft_win;
    end
    % Average
    pxx_fft = pxx_fft ./ num_windows_uni;
end

%% Metrics
hrv_fd = table;
hrv_fd.Properties.Description = 'Frequency Domain HRV Metrics';

% Get entire frequency range
total_band = [f_axis(1), f_axis(end)];

% Loop over power methods and calculate metrics based on each one. Loop in reverse order so that
% the first power method is the last and it's variables retain their values (pxx, column names).
for ii = length(power_methods):-1:1
    % Current PSD for metrics calculations
    pxx = eval(['pxx_' lower(power_methods{ii})]);
    suffix = ['_' upper(power_methods{ii})];

    % Absolute power in each band
    col_total_power = ['TOTAL_POWER' suffix];
    hrv_fd{:,col_total_power} = mhrv.util.freqband_power(pxx, f_axis, total_band) * 1e6;
    hrv_fd.Properties.VariableUnits{col_total_power} = 'ms^2';
    hrv_fd.Properties.VariableDescriptions{col_total_power} = sprintf('Total power (%s)', power_methods{ii});

    col_vlf_power = ['VLF_POWER' suffix];
    hrv_fd{:,col_vlf_power} = mhrv.util.freqband_power(pxx, f_axis, vlf_band) * 1e6;
    hrv_fd.Properties.VariableUnits{col_vlf_power} = 'ms^2';
    hrv_fd.Properties.VariableDescriptions{col_vlf_power} = sprintf('Power in the very low frequency band (%s)', power_methods{ii});

    col_lf_power = ['LF_POWER' suffix];
    hrv_fd{:,col_lf_power}  = mhrv.util.freqband_power(pxx, f_axis, lf_band) * 1e6;
    hrv_fd.Properties.VariableUnits{col_lf_power} = 'ms^2';
    hrv_fd.Properties.VariableDescriptions{col_lf_power} = sprintf('Power in the low frequency band (%s)', power_methods{ii});

    col_hf_power = ['HF_POWER' suffix];
    hrv_fd{:,col_hf_power}  = mhrv.util.freqband_power(pxx, f_axis, [hf_band(1) f_axis(end)]) * 1e6;
    hrv_fd.Properties.VariableUnits{col_hf_power} = 'ms^2';
    hrv_fd.Properties.VariableDescriptions{col_hf_power} = sprintf('Power in the high frequency band (%s)', power_methods{ii});

    % Calculate normalized power in each band (normalize by TOTAL_POWER)
    total_power = hrv_fd{:,col_total_power};
    if strcmpi(norm_method, 'total')
        total_power_lfhf = total_power;
    else
        total_power_lfhf = hrv_fd{:,col_lf_power} + hrv_fd{:,col_hf_power};
    end

    col_vlf_norm = ['VLF_NORM' suffix];
    hrv_fd{:,col_vlf_norm} = 100 * hrv_fd{:,col_vlf_power} / total_power;
    hrv_fd.Properties.VariableUnits{col_vlf_norm} = '%';
    hrv_fd.Properties.VariableDescriptions{col_vlf_norm} = sprintf('Very low frequency power in normalized units: (%s)', power_methods{ii});

    col_lf_norm = ['LF_NORM' suffix];
    hrv_fd{:,col_lf_norm} = 100 * hrv_fd{:,col_lf_power} / total_power_lfhf;
    hrv_fd.Properties.VariableUnits{col_lf_norm} = '%';
    hrv_fd.Properties.VariableDescriptions{col_lf_norm} = sprintf('Low frequency power in normalized units: LF/(Total power - VLF)*100 (%s)', power_methods{ii});

    col_hf_norm = ['HF_NORM' suffix];
    hrv_fd{:,col_hf_norm} = 100 * hrv_fd{:,col_hf_power} / total_power_lfhf;
    hrv_fd.Properties.VariableUnits{col_hf_norm} = '%';
    hrv_fd.Properties.VariableDescriptions{col_hf_norm} = sprintf('High frequency power in normalized units: HF/(Total power - VLF)*100 (%s)', power_methods{ii});

    % Calculate LF/HF ratio
    col_lf_to_hf = ['LF_TO_HF' suffix];
    hrv_fd{:,col_lf_to_hf}  = hrv_fd{:,col_lf_power}  / hrv_fd{:,col_hf_power};
    hrv_fd.Properties.VariableUnits{col_lf_to_hf} = 'n.u.';
    hrv_fd.Properties.VariableDescriptions{col_lf_to_hf} = sprintf('Low frequency band to high frequency band power ratio (LF/HF) (%s)', power_methods{ii});

    % Calculate power in the extra bands
    for jj = 1:length(extra_bands)
        extra_band = extra_bands{jj};
        extra_band_power = mhrv.util.freqband_power(pxx, f_axis, extra_band) * 1e6;

        column_name = sprintf('EX%d_POWER%s', jj, suffix);
        hrv_fd{:,column_name} = extra_band_power;
        hrv_fd.Properties.VariableUnits{column_name} = 'ms^2';
        hrv_fd.Properties.VariableDescriptions{column_name} =...
            sprintf('Power in custom band [%.5f,%.5f] (%s)', extra_band(1), extra_band(2), power_methods{ii});

        column_name = sprintf('EX%d_NORM%s', jj, suffix);
        hrv_fd{:,column_name}  = 100 * extra_band_power / total_power;
        hrv_fd.Properties.VariableUnits{column_name} = 'n.u.';
        hrv_fd.Properties.VariableDescriptions{column_name} =...
            sprintf('Custom band %d to total power ratio (%s)', ii, power_methods{ii});
    end

    % Find peaks in the spectrum
    lf_band_idx = f_axis >= lf_band(1) & f_axis <= lf_band(2);
    hf_band_idx = f_axis >= hf_band(1) & f_axis <= hf_band(2);
    [~, f_peaks_lf, ~, p_peaks_lf] = findpeaks(pxx(lf_band_idx), f_axis(lf_band_idx));
    [~, f_peaks_hf, ~, p_peaks_hf] = findpeaks(pxx(hf_band_idx), f_axis(hf_band_idx));
    if isempty(f_peaks_lf)
        f_peaks_lf(1) = NaN;
    else % Sort by peak prominence & pad to length num_peaks
        [~,sort_idx] = sort(p_peaks_lf, 'descend');
        f_peaks_lf = f_peaks_lf(sort_idx)';
        f_peaks_lf = padarray(f_peaks_lf, [0,max([0,num_peaks-length(f_peaks_lf)])],NaN,'post');
        f_peaks_lf = f_peaks_lf(1:num_peaks);
    end
    if isempty(f_peaks_hf)
        f_peaks_hf(1) = NaN;
    else % Sort by peak prominence & & pad to length num_peaks
        [~,sort_idx] = sort(p_peaks_hf, 'descend');
        f_peaks_hf = f_peaks_hf(sort_idx)';
        f_peaks_hf = padarray(f_peaks_hf, [0,max([0, num_peaks-length(f_peaks_hf)])],NaN,'post');
        f_peaks_hf = f_peaks_hf(1:num_peaks);
    end

    col_lf_peak = ['LF_PEAK' suffix];
    hrv_fd{:,col_lf_peak} = f_peaks_lf(1);
    hrv_fd.Properties.VariableUnits{col_lf_peak} = 'Hz';
    hrv_fd.Properties.VariableDescriptions{col_lf_peak} = sprintf('Peak frequency in the low frequency band (%s)', power_methods{ii});

    col_hf_peak = ['HF_PEAK' suffix];
    hrv_fd{:,col_hf_peak} = f_peaks_hf(1);
    hrv_fd.Properties.VariableUnits{col_hf_peak} = 'Hz';
    hrv_fd.Properties.VariableDescriptions{col_hf_peak} = sprintf('Peak frequency in the high frequency band (%s)', power_methods{ii});

    % Calculate beta (VLF slope)
    % Take the log of the spectrum in the VLF frequency band
    pxx_beta_log = log10(pxx(beta_idx));
    f_axis_beta_log = log10(f_axis(beta_idx));

    % Fit a line and get the slope
    pxx_fit_beta = polyfit(f_axis_beta_log, pxx_beta_log, 1);

    col_beta = ['BETA' suffix];
    hrv_fd{:,col_beta} = pxx_fit_beta(1);
    hrv_fd.Properties.VariableUnits{col_beta} = 'n.u.';
    hrv_fd.Properties.VariableDescriptions{col_beta} = 'Slope of the linear interpolation of the spectrum in a log-log scale for frequencies below the upper bound of the VLF band';
end

% Sort by metric, not by power method
hrv_fd = hrv_fd(:, sort(hrv_fd.Properties.VariableNames));

%% Plot
plot_data.name = 'Intervals Spectrum';
plot_data.f_axis = f_axis;
plot_data.pxx_lomb = pxx_lomb;
plot_data.pxx_ar = pxx_ar;
plot_data.pxx_welch = pxx_welch;
plot_data.pxx_fft = pxx_fft;
plot_data.vlf_band = vlf_band;
plot_data.lf_band = lf_band;
plot_data.hf_band = hf_band;
plot_data.f_max = f_max;
plot_data.t_win = t_win;
plot_data.welch_overlap = welch_overlap;
plot_data.ar_order = ar_order;
plot_data.num_windows = num_windows;
plot_data.lf_peaks = f_peaks_lf;
plot_data.hf_peaks = f_peaks_hf;
plot_data.beta_idx = beta_idx;

if (should_plot)
    figure('Name', plot_data.name);
    plot_hrv_freq_spectrum(gca, plot_data, 'peaks', true);
    
    figure('Name', 'Beta');
    plot_hrv_freq_beta(gca, plot_data);
end
end