function varargout=timeplot(t,d,samp,varargin)
%TIMEPLOT Time series plot
%	TIMEPLOT(T,D,SAMP) plots time series D(T) using continuous line
%	where sampling rate is regular (about SAMP value), showing gaps
%	where time interval is more than 150%.
%
%	TIMEPLOT(T,D) or TIMEPLOT(T,D,[],...) will guess the sampling rate
%	automatically (using most frequent value of time interval).
%
%	TIMEPLOT(T,D,0) will force a continuous plot.
%
%	TIMEPLOT(...,'Param',value,...) adds any parameter to plot function.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2015-08-25 in Yogyakarta, Indonesia
%	Updated: 2024-07-10

dt = diff(t);

if nargin < 3
	samp = [];
end

if ~isempty(dt) && (isempty(samp) || isnan(samp) || ~isnumeric(samp))
	% guess the sampling rate
	samp = mode(dt);
end

if samp > 0

	k = find(abs(dt) > 1.5*samp);

	tk = cat(2,t(k),t(k+1));
	t = cat(1,t,mean(tk,2));
	d = cat(1,d,nan(length(k),1));

	[t,kk] = sort(t);

	h = plot(t,d(kk),varargin{:});
else
	h = plot(t,d,varargin{:});
end

if nargout > 0
	varargout{1} = h;
end
