function y = diffn(x,n)
%DIFFN	N-spaced difference.
%	DIFFN(X,N), for a vector X, is [... X(i)-X(i-N) ... X(n)-X(n-N)].
%	Because the first N values are not defined, they are set to NaN.
%	DIFFN(X,N), for a matrix X, is the matrix of row N-spaced differences.
%
%	DIFFN(X,1) is equivalent to DIFF(X) but has the same length as X, and 
%	first value is NaN.
%
%	Author: François Beauducel <beauducel@ipgp.fr>
%	  Institut de Physique du Globe de Paris
%	Created: 1996
%	Updated: 2009-12-31

%	Copyright (c) 1996-2009, François Beauducel, covered by BSD License.
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
%	     the documentation and/or other materials provided with the distribution
%	                           
%	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
%	AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
%	IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
%	ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
%	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
%	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
%	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
%	INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
%	CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
%	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
%	POSSIBILITY OF SUCH DAMAGE.

error(nargchk(1,2,nargin))

if ~isnumeric(x)
		error('X argument must be numeric.')
end
if size(x,1) == 1
	x = x';
end

if nargin < 2
	n = 0;
end
if ~isnumeric(n) | numel(n) ~= 1 | n < 0 | mod(n,1) ~= 0
	error('N argument must be a scalar positive integer.')
end

a = [1,zeros(1,n)];
b = [1,zeros(1,n-1),-1];
y = filter(b,a,x - repmat(x(1,:),size(x,1),1));
y(1:n,:) = NaN;

