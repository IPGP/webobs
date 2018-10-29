function h=ellipse(x,y,a,b,varargin)
%ELLIPSE  Generalised 2-D ellipse plot
%
%	ELLIPSE(X,Y,A,B) draws an ellipse on current axis from position X,Y  
%	with semi-axis A and B.
%       
%	X and Y can be scalars or matrix. In the last case, any or both A and
%	B can be scalars or matrix of the same size as X and Y.
%
%	ELLIPSE(...,'param1',value1,'param2',value2,...) specifies any
%	additionnal properties of the Patch using standard parameter/value
%	pairs, like 'FaceColor','EdgeColor','LineWidth', ...
%
%	H=ELLIPSE(...) returns graphic's handle of patches.
%
%	Examples:
%
%	  ellipse(0,0,2,1,'FaceColor','none','LineWidth',3)
%
%	  [xx,yy] = meshgrid(1:10);
%	  ellipse(xx,yy,rand(size(xx)),rand(size(xx)))
%
%
%	Notes:
%
%	- Ellipse shape supposes an equal aspect ratio (axis equal).
%
%       See also ARROWS.
%
%	Author: Francois Beauducel <beauducel@ipgp.fr>
%	Created: 1995-12-20
%	Updated: 2014-02-05

%	Copyright (c) 2013, François Beauducel, covered by BSD License.
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

if nargin < 4
	error('Not enough input arguments.')
end

if ~isnumeric(x) | ~isnumeric(y) | ~isnumeric(a) | ~isnumeric(b)
	error('X, Y, A and B must be numeric.')
end


m = 100; % number of ellipse segments
circ = exp(1j*linspace(0,2*pi,m))';	% a unit circle in complex domain
if numel(x) > 1
	circ = repmat(circ,1,numel(x));
end

% needs to duplicate non-scalar arguments
x = repval(x,m);
y = repval(y,m);
a = repval(a,m);
b = repval(b,m);

% the beauty of this script: a single patch command to draw all the ellipses !
hh = patch(x + a.*real(circ), y + b.*imag(circ),'w','FaceColor','none',varargin{:});

	
if nargout > 0
	h = hh;
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function x = repval(x,n)

if numel(x) > 1
	x = repmat(x(:)',[n,1]);
end

