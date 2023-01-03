# HRV-Metrics
A MATLAB software tool for the analysis of Heart Rate Variability (HRV).

> "Over the years, many correlations were made between the autonomic nervous system and cardiovascular mortality and morbidity. This motivated the development of quantitative indicators of autonomic activity, such as measures of Heart Rate Variability (HRV), which describes changes over time in the interval between consecutive heart beats. HRV is modulated by several physiological mechanisms, the main one being the balance between the activity of the sympathetic and parasympathetic nervous systems. HRV parameters aim at characterizing large amounts of ECG data in an effort to identify patterns and abnormalities with clinical significance. However, due to the complexity of HRV, a lack of significant clinical correlations exists for some of these measures. Additional clinical data and HRV research tools may help establish such correlations. The present work led to the development of a programme for the analysis of HRV (called HRV Metrics). For a given ECG record it reports back several types of parameters such as time- and frequency- domain metrics as well as nonlinear metrics."

(from the project's paper Abstract)


The folder 'ECG records' contains 48 ECG records from the <a href="https://physionet.org/physiobank/database/mitdb/">MIT-BIH arrhythmia batabase</a> which is a well-known and widely used database to verify ECG-related algorithms’ performance and test softwares that deal with this kind of physiological signal (ECG).

Once in MATLAB, the file 'programa.mlapp' must be opened using AppDesigner and then executed. It is also possible to convert it into an executable file (.exe) using the deploytool command.


## Screenshots

### Peak detection
The basis for all HRV analysis is the identification of the heart rate peaks.

<img src="/Screenshots/peak_detection.PNG" width="700"/>


### Tachogram
After applying the peak detection algorithm, a tachogram can be generated which shows the average interval between peaks (RR intervals). With this intervals, the heart rate can also be easily calculated through the inverse of the RR interval multiplied by 60.

<img src="/Screenshots/tachogram.PNG" width="700"/>


### Time domain analysis
Through a time domain analysis various relevant statistical metrics can be derived such as the standard deviation for the NN intervals (normalized peak-to-peak intervals).

<img src="/Screenshots/time_domain.PNG" width="700"/>


### Frequency domain analysis

<img src="/Screenshots/frequency_domain.PNG" width="700"/>



### Non-linear analysis
After time and frequency domain analysis, non-linear analysis can be done. Such analysis include the use of [Poincaré plots](https://en.wikipedia.org/wiki/Poincar%C3%A9_plot), entropy plots and recurrence plots.

Poincaré plot (2D and 3D)

<img src="/Screenshots/poincare_plot.PNG" width="700"/>
<img src="/Screenshots/poincare_3D_plot.PNG" width="700"/>

Entropy plots

<img src="/Screenshots/entropy.PNG" width="700"/>

Recurrence plots

<img src="/Screenshots/recurrence_plot.PNG" width="700"/>

