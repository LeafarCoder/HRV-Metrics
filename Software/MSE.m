%This function is developed to calculate the multi scale sample entropy
function msse = MSE(datas, minScale, maxScale)
msse = zeros(1, maxScale - minScale + 1);
scales = minScale : maxScale;

for i = 1:length(scales)
    scale = scales(i);
    % num indicates how many sections of datas for the current scalefactor
    num = floor(length(datas)/scale);
    currentdata = zeros(1,num);
    
    for j=1:num
        head = (j-1)*scale + 1;
        tail = j*i;
        currentdata(j) = mean(datas(head:tail));
    end
    
    r = 0.2*std(currentdata);
    msse(i) = SampEn(2,r,currentdata);
end

return