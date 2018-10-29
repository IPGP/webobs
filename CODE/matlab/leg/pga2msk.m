function msk=pga2msk(pga,law)
%PGA2MSK Accelerations to macroseismic intensity.
%   PGA2MSK(PGA) returns predicted intensity in the MSK scale
%   (from 1 = I to 12=XII) from acceleration PGA (in cm/s2 or mg).
%
%   PGA2MSK(PGA,LAW) specifies the law for accelerations/intensities 
%   correspondances:
%       LAW = 'gutenberg' (default) for [Gutenberg & Richter, 1942],
%       LAW = 'bcube' for initial [Beauducel et al., 2004]
%       LAW = 'feuillard' for [Feuillard, 1985].
%
%   PGA2MSK returns float numbers. Use FLOOR or ROUND to produce integers.
%   Use MSK2STR to display intensities in roman numbers.
%
%
%   Author: F. Beauducel, IPGP
%   Created: 2009-01-16
%   Modified: 2009-01-19

if nargin < 2
    law = 'gutenberg';
end

switch law
    case 'feuillard'
        msk = log10(pga)*3 + 2;
    case 'bcube'
        msk = log10(pga)*3 + 1;
    otherwise
        msk = log10(pga)*3 + 3/2;
end

% fixes minimum of 1 and maximum of 12
msk(find(msk < 1)) = 1;
msk(find(msk > 12)) = 12;



