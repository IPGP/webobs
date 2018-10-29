function [maxtab, mxpos, ffpos]=music3c_peakdet7(force, f, seuil)  % v,f)
%PEAKDET Detect peaks in a vector
%        [MAXTAB, MINTAB, FFPOS] = PEAKDET(V, DELTA) finds the local
%        maxima and minima ("peaks") in the vector V.
%        MAXTAB and MINTAB consists of two columns. Column 1
%        contains indices in V, and column 2 the found values.
%      
%        With [MAXTAB, MINTAB] = PEAKDET(V, DELTA, X) the indices
%        in MAXTAB and MINTAB are replaced with the corresponding
%        X-values.
%
%        A point is considered a maximum peak if it has the maximal
%        value, and was preceded (to the left) by a value lower by
%        DELTA.
% Gipsa-Lap/ LIS 2008
% This function is released to the public domain; Any use is allowed.
force=force(:);f=f(:);
thresh=seuil*max(force)*ones(length(f),1);
v=force-thresh;

for I=1:length(v)
    if v(I) < 0
        v(I)=0;
    end
end


maxtab=[];
mxpos=[];
ffpos=[];
d=f(2)-f(1);
for i=3:length(v)-3
    if v(i) > v(i-1)
        if v(i) > v(i+1)
            maxtab = [maxtab v(i)]; 
            mxpos = [mxpos (i-1)*d];
            ffpos = [ffpos i];
         end
    end
end
maxtab=maxtab+thresh(1);
