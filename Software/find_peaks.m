function [locs] = find_peaks(ecg, Fs)

% Stage 1: QRS enhancement and noise reduction

% ############### NEW ADITTION ##################
%x = ecg;
x = ecg  - mean(ecg);   % subtract mean makes next spet (bandpass) less prone to sharp transients in the begining and the end
x = x/max(x);         % Normalize ECG

band_pass = bandpass(x, [5 20], Fs);    % try [15,20],...
x = diff(band_pass);        % d[n] = f[n+1] - f[n]

% Stage 2: New nonlinear transformation

% ############### NEW ADITTION ##################
x(x<0) = 0;

% Squaring and Adaptive Thresholding
x = x.^2;
N = length(x);
sigma = sqrt(sum((x - mean(x)).^2)/N);  % standard deviation
x(x < sigma) = 0;             % Set values below threshold to zero

% Shannon Energy Computation and Smoothing
x = (x/max(x)).^2;     % normalized and square
x = (-x) .* max(-1000*ones(1,N), log(x));

% APPLY FINITE IMPULSE RESPONSE (FIR) TO SMOOTH S (instead of Envelope?)
% Envelope
[u, ~] = envelope(x,10);
x = smooth(u, 45);
x = x - min(x);

% Create "..." to then convolute
M = 0.15*Fs;
temp = 1:M;
sigma = 36;
w = exp(-0.5 * (temp - M*0.5).^2 / (sigma^2));  % Generate Gaussina
wd = diff(w);   % Generate 'swing' (look up the real name)

% Convolute
x = conv(wd, x);

% zeros locations (initiate as -1 vector for speed performance)
% Estimate number of peal locations at 80BPM
%peak_loc = -ones(1, ceil((N/Fs)*80/60));
peak_loc = [];
n_loc = 0;          % number of peaks

for i = 1:length(x)-1
    l_t = max(1,ceil(i-0.2*Fs)) : min(length(x),ceil(i+0.2*Fs));
    threshold = max(x(l_t)) / 100;      % heuristic to avoid errors on peak detection
    if(x(i)> 0 && x(i+1) < 0 && x(i) - x(i+1) > threshold)
        n_loc = n_loc + 1;
        peak_loc(n_loc) = i;
    end
end

% ############### NEW ADITTION ##################
look_for = band_pass;   % the true peak locations are looked for in the function by its maximum
%look_for = ecg;

% find true locations given approximate locations
locs = zeros(1,n_loc);        % true peaks x (time)
k = round(0.15*Fs);         % window size (define based on Fs and medium QRS duration, 0.1s)
if(mod(k,2)~=0); k=k+1;end   % if k is odd make it even
for i = 1:n_loc
    center = peak_loc(i);
    window = look_for(max(1,center-k/2) : min(length(look_for), center+k/2));
    [~,I] = max(window);
    locs(i) = I;
    locs(i) = locs(i) + center - k/2 - 1;
end
end

