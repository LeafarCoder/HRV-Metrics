function [ power ] = get_freqband_power( pxx, f_axis, f_band )
%FREQBAND_POWER Calculates the power in a frequency band

% Convert to columns for consistency
pxx = pxx(:);
f_axis = f_axis(:);

%% Band power calculation

% Linearly interpolate the value of pxx at the freq band limits
pxx_f_band = interp1(f_axis, pxx, f_band, 'linear', 'extrap');

% Find the indices inside the band
idx_band = f_axis > f_band(1) & f_axis < f_band(2);

% Create integration segment (the part of the signal we'll integrate over).
f_int   = [f_band(1);  f_axis(idx_band); f_band(2)];
pxx_int = [pxx_f_band(1); pxx(idx_band); pxx_f_band(2)];

% Calcualte the integral
power = trapz(f_int, pxx_int);

end

