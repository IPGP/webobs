function y = decim(x,r,method)
%DECIM	Fast data decimation.
%	DECIM(X,R) resamples data in vector X at 1/R times the original sample
%	rate, using the mean value of R consecutive samples. The resulting
%	resampled vector is R times shorter. If X is a matrix, it returns the
%	decimated vectors of each column.
%
%   DECIM(X,R,METHOD) uses one of the following METHOD for decimation:
%	    'mean' : mean value
%	   'rmean' : mean value excuding NaN (default)
%	  'median' : median value
%	 'rmedian' : median value exculding NaN
%	     'sum' : sum value
%	    'rsum' : sum value excluding NaN
%	     'min' : minimum value
%	     'max' : maximum value
%
%   Dependencies: RMEAN, RMEDIAN, RSUM.
%
%	Author: François Beauducel, IPGP
%	Created: 1996
%	Updated: 2025-03-31

%	Copyright (c) 2025, François Beauducel, covered by BSD License.
%	All rights reserved.
%
%	Redistribution and use in source and binary forms, with or without
%	modification, are permitted provided that the following conditions are
%	met:
%
%	   * Redistributions of source code must retain the above copyright
%	     notice, this list of conditions and the following disclaimer.
%	   * Redistributions in binary form must reproduce the above copyright
%	     notice, this list of conditions and the following disclaimer in
%	     the documentation and/or other materials provided with the
%	     distribution
%
%	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
%	IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
%	TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
%	PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
%	OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
%	SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
%	LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
%	DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
%	THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
%	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
%	OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

if nargin < 2
	error('Not enough input arguments.')
end

if ~isscalar(r) || r ~= abs(round(r))
	error('R must be an positive integer scalar!')
end

if nargin > 2
	if ~ischar(method) || ~ismember(method,{'mean','rmean','median','rmedian','sum','rsum','min','max'})
		error('Unknown METHOD argument.')
	end
else
	method = 'mean';
end

% Matlab standard behavior: row vector is processed as a column vector
if size(x,1) == 1
	x = x';
end

if r == 1
	y = x;
	return
end

[m,n] = size(x);

if m < r
	error('X too short (%d elements) to be decimated by R (%d)',m,r)
end

mr = floor(m/r);
y = nan(mr,n);

for j = 1:n
	xx = reshape(x(1:mr*r,j),[],mr);
	switch lower(method)
		case 'mean'
			y(:,j) = mean(xx)';
		case 'median'
			y(:,j) = median(xx)';
		case 'rmedian'
			y(:,j) = rmedian(xx)';
		case 'sum'
			y(:,j) = sum(xx)';
		case 'rsum'
			y(:,j) = rsum(xx)';
		case 'min'
			y(:,j) = min(xx)';
		case 'max'
			y(:,j) = max(xx)';
		otherwise
			y(:,j) = rmean(xx)';
	end
end
