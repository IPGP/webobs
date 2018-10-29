function y=gmice(x,law,varargin)
%GMICE Ground motion to intensity conversion equations.
%	GMICE(PGA) returns predicted intensity in the MSK scale
%	(from 1 = I to 12=XII) from acceleration PGA (in cm/s2 or mg).
%
%	GMICE(PGA,LAW) specifies the law for accelerations/intensities 
%	correspondances, using following available LAW:
%
%                gr42 : Gutenberg & Richter [1942] (default)
%         beauducel04 : Beauducel et al. [2004]
%         feuillard85 : Feuillard [1985]
%
%	GMICE returns float numbers. Use FLOOR or ROUND to produce integers.
%	Use MSK2STR to display intensities in roman numbers.
%
%	GMICE(MSK,LAW,'bound') bounds MSK values between 1 and 12.
%
%	GMICE(MSK,LAW,'reverse') returns PGA value from MSK.
%
%
%   Author: F. Beauducel, WEBOBS/IPGP
%   Created: 2009-01-16, Paris, France
%   Updated: 2016-05-25

if nargin < 2
    law = 'gr42';
end

reverse = 0;
if nargin > 2
	reverse = any(strcmpi(varargin,'reverse'));
end
bound = 0;
if nargin > 2
	bound = any(strcmpi(varargin,'bound'));
end

switch lower(law)
	case 'gr42'
		if reverse
			y = 10.^(x/3 - 1/2);
		else
			y = log10(x)*3 + 3/2;
		end
	case 'feuillard85'
		if reverse
			y = 10.^(x/3 - 2/3);
		else
			y = log10(x)*3 + 2;
		end
	case 'beauducel04'
		if reverse
			y = 10.^(x/3 - 1/3);
		else
			y = log10(x)*3 + 1;
		end
	otherwise
		error('unknown law %s.',law);
end

if ~reverse && bound
	% fixes minimum of 1 and maximum of 12
	y(y < 1) = 1;
	y(y > 12) = 12;
end


