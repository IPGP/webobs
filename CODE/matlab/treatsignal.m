function [tc,dc,lr,tre] = treatsignal(t,d,r,OPT)
% TREATSIGNAL Signal treatment: decimating and cleaning
% 	[TC,DC]=TREATSIGNAL(T,D,R,OPT) processes vector signal D(T) in the following order:
% 	   1. if OPT.FLAT_IS_NAN is OK, removes flat signals
% 	   2. if OPT.PICKS_CLEAN_PERCENT exists and >0, removes picks above the value %
% 	   3. if OPT.PICKS_CLEAN_STD exists and >0, removes picks above value*STD around mean
% 	   4. if OPT.MEDIAN_FILTER_SAMPLES exists and >0, filters the signal using value samples 
% 	   5. decimates by a factor of R (integer) using moving average,
% 	   6. if OPT.UNDERSAMPLING is OK, decimation is undersampling instead of averaging
%
%   [TC,DC,LR,TRE]=TREATSIGNAL(...) also returns linear regression LR and trend error TRE, using
%   optional second column of D as errors, and some optional parameters:
%       OPT.TREND_FACTOR is a dimensionless factor applied to the trend value initially in data unit/day
%       OPT.TREND_MIN_DAYS is minimum time window (in days) needed to compute a trend
%       OPT.TREND_MIN_PERC is minimum time window (in percent) needed to compute a trend
%       OPT.TREND_TLIM_DAYS is trend time limits: extreme parts (in days) of time window to be used in trend computation
%       OPT.TREND_TLIM_PERC is trend time limits: extreme parts (in percent) of time window to be used in trend computation
%       OPT.TREND_ERROR_MODE is trend error calculation mode: 1 = lscov, 2 = std, 3 = corrcoef
%       OPT.TREND_ERROR_COMPLETION is trend error factor based on the data completion
%
%   TREATSIGNAL uses ISOK, FIELD2NUM, CLEANPICKS, MMED, and RDECIM functions.
%
%	Author: F. Beauducel / WEBOBS
% 	Created: 2015-08-24
% 	Updated: 2025-02-27

if size(d,2) > 1
    e = d(:,2); % data error vector
    d = d(:,1);
else
    e = ones(size(d));
end

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
	ec = e(1:r:end);
else
	tc = rdecim(t,r);
	dc = rdecim(d,r);
	ec = rdecim(e,r);
end

% linear trend
k = find(~isnan(dc));
tlim = minmax(t);
if nargout > 3 && ~isempty(k) && diff(tlim) > 0
    terrmod = field2num(OPT,'TREND_ERROR_MODE',1);
    trendmindays = field2num(OPT,'TREND_MIN_DAYS',1);
    trendminperc = field2num(OPT,'TREND_MIN_PERCENT',50);
    trendtlimdays = field2num(OPT,'TREND_TLIM_DAYS');
    trendtlimperc = field2num(OPT,'TREND_TLIM_PERC');
    trendcompletion = isok(OPT,'TREND_ERROR_COMPLETION',0);

    tk = tc(k);
    dk = dc(k);
    ek = ec(k);
    dt = diff(minmax(tk));
    if numel(k) >= 2 && dt >= trendmindays && 100*dt/diff(tlim) >= trendminperc && ~all(isnan(dk))
        kk = find(tk);
        [lr,stdx] = wls(tk(kk)-tk(1),dk(kk),1./ek(kk));
        % different modes for error estimation
        switch terrmod
        case 2
            tre = std(dk(kk) - polyval(lr,tk(kk)-tk(1)))/diff(tlim);
        case 3
            cc = corrcoef(tk(kk)-tk(1),dk(kk));
            r2 = sqrt(abs(cc(2)));
            tre = stdx(1)/r2;
        otherwise
            tre = stdx(1);
        end
        % all errors are adjusted with sampling completeness factor
        if trendcompletion
            acq = numel(kk)*median(diff(tk))/abs(diff(tlim));
            if acq > 0
                tre = tre/sqrt(acq);
            end
        end
    else
        lr = [NaN,0];
        tre = NaN;
    end

end