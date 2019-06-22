function [tc,dc] = treatsignal(t,d,r,OPT)
% TREATSIGNAL Signal treatment: decimating and cleaning
% 	[TC,DC]=TREATSIGNAL(T,D,R,OPT) processes vector signal D(T) in the following order:
% 	   1. if OPT.FLAT_IS_NAN is OK, removes flat signals
% 	   2. if OPT.PICKS_CLEAN_PERCENT exists and >0, removes picks above the value %
% 	   3. if OPT.PICKS_CLEAN_STD exists and >0, removes picks above value*STD around mean
% 	   4. if OPT.MEDIAN_FILTER_SAMPLES exists and >0, filters the signal using value samples 
% 	   5. decimates by a factor of R (integer) using moving average,
% 	   6. if OPT.UNDERSAMPLING is OK, decimation is undersampling instead of averaging
%
%
%	Author: F. Beauducel / WEBOBS
% 	Created: 2015-08-24
% 	Updated: 2019-05-20


% removes flat intervals
if isok(OPT,'FLAT_IS_NAN')
	k = find(diff(d)==0);
	if ~isempty(k)
		d(k+1) = NaN;
	end
end

% cleanpicks filters
d = cleanpicks(d,OPT);

% median filter
m = field2num(OPT,'MEDIAN_FILTER_SAMPLES');
if m > 1
	d = mmed(d,m);
end

% decimation
if isok(OPT,'UNDERSAMPLING')
	tc = t(1:r:end);
	dc = d(1:r:end);
else
	tc = rdecim(t,r);
	dc = rdecim(d,r);
end

