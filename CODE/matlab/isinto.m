function k=isinto(x,lim)
%ISINTO Is into an interval
%	ISINTO(X,[XMIN,XMAX]) returns a bolean vector of the same size as X, 
%	containing 1 where X is into the interval defined by [XLIM,XMAX]
%	inclusively, and 0 elsewhere.
%
%	ISINTO(X,Y) where Y is a vector or matrix, uses min/max values of Y
%	to define interval limits.
%
%
%	Author: F. Beauducel / WEBOBS
%	Created: 2014-12-17
%	Updated: 2016-04-18

k = x>=min(lim(:)) & x<=max(lim(:));
