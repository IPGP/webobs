function [no,bo] = histw(x,w,b,d)
%HISTW Weighted histogram count.
%   N = HISTW(X,W,EDGES), for vector X, counts the number of values in X
%   that fall between the elements in the EDGES vector (which must contain
%   monotonically non-decreasing values) using weight vector W.  N is a 
%   LENGTH(EDGES) vector containing these counts.  
%
%   N(k) will count the value X(i) if EDGES(k) <= X(i) < EDGES(k+1).  The
%   last bin will count any values of X that match EDGES(end).  Values
%   outside the values in EDGES are not counted.  Use -inf and inf in
%   EDGES to include all non-NaN values.
%
%   For matrices, HISTW(X,W,EDGES) is a matrix of column histogram counts.
%   For N-D arrays, HISTW(X,W,EDGES) operates along the first non-singleton
%   dimension.
%
%   HISTW(X,W,EDGES,DIM) operates along the dimension DIM. 
%
%   [N,BIN] = HISTW(X,W,...) also returns an index matrix BIN.  If X is a
%   vector, N(K) = SUM(BIN==K). BIN is zero for out of range values. If X
%   is an m-by-n matrix, then,
%     for j=1:n, N(K,j) = SUM(BIN(:,j)==K); end
%
%   Use BAR(EDGES,N,'histc') to plot the histogram.
%
%   Author: F. Beauducel, OVSG-IPGP
%   Created: 2005
%   Updated: 2011-01-03

if isempty(x)
	x = NaN*[0;0];
	w = [0;0];
end
if nargin < 4
    [no,bo] = histc(x,b);
else
    [no,bo] = histc(x,b,d);
end

for i = 1:length(no)
    no(i) = sum(w(bo==i));
end
