function c=shademap(map,y)
%SHADEMAP Shading color map
%	SHADEMAP(MAP) applies the MAP colormap shaded from white to full 
%	saturated color with linear contrast. See COLORMAP for available
%	color maps.
%
%	SHADEMAP(MAP,Y) uses vector Y as a function Y = f(X) for shading.
%	Elements of Y must be in the interval (0,1) and correspond to the 
%	constrast values of monotonically spaced values from 0 to 1, i.e.,
%	a vector linspace(0,1,length(Y)).
%
%	SHADEMAP(MAP,N) uses a shading of X^N. N = 1 is linear shading. Use
%	N = 2 to strengthen the shading contrast or N = 0.5 to attenuate it.
%
%	SHADEMAP without argument uses JET colormap and linear shading.
%
%	C=SHADEMAP(...) returns an M-by-3 matrix containing the colormap, that 
%	can be used with COLORMAP function like other colormaps. It does not
%	apply the colormap to current figure.
%
%
%	Author: Francois Beauducel, IPGP
%	Created: 2015-01-01
%	Updated: 2017-04-05

%	Copyright (c) 2017, François Beauducel, covered by BSD License.
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

if nargin < 1 || isempty(map)
	map = jet(256);
end

if nargin < 2
	y = 1;
end

if size(map,2) ~= 3 || any(map(:) < 0 | map(:) > 1)
	error('MAP must be a M-by-3 matrix of values in the [0,1] interval.')
end

if isscalar(y) && y <= 0
	error('N must be a strictly positive scalar')
end

if numel(y) > 1 && ~all(isinto(y,[0,1]))
	error('Y values must be in the (0,1) interval')
end

x = linspace(0,1,size(map,1))';
switch numel(y)
case 1
	shade = x.^y;
otherwise
	shade = interp1(linspace(0,1,length(y)),y,x);
end

shade = repmat(shade,1,3);
map = map.*shade + 1 - shade;

if nargout < 1
	colormap(map)
else
	c = map;
end

