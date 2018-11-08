function hout = plotregsamp(t,d,varargin)
%PLOTREGSAMP Plot regular sampling data
%	PLOTREGSAMP(T,D) plots data D(T) considering a regular sampling rate
%	(auto detected): using solid line where sample rate is respected at 50%
%	of tolerance, showing gaps if not.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2014-09-24
%	Updated: 2018-11-07

tol = 1.5;
ddt = diff(t);
dt = mode(ddt);

holdflag = ishold;

kgap = find(abs(ddt) > tol*dt);
if isempty(kgap)
	h = plot(t,d,'-',varargin{:});
else
	k = 1:kgap(1);
	h = nan(length(kgap),1);
	h(1) = plot(t(k),d(k),'-',varargin{:});
	hold on
	for n = 2:length(kgap)
		k = (kgap(n-1)+1):kgap(n);
		h(n) = plot(t(k),d(k),'-',varargin{:});
	end
	k = (kgap(n)+1):length(t);
	h(n) = plot(t(k),d(k),'-',varargin{:});
	if ~holdflag
		hold off
	end
end

if nargout > 0
	hout = h;
end
