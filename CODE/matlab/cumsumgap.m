function y = cumsumgap(x)
%CUMSUMGAP Cumulative sum of elements with gaps
%	CUMSUMGAP(X) works as CUMSUM excepted that NaN values are ignored.
%	
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2013-10-02

k = find(isnan(x));	% finds the NaN's
x(k) = 0;		% replaces by 0
y = cumsum(x);		% normal cumsum
y(k) = NaN;		% back to NaN's

