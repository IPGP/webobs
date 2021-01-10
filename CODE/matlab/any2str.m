function y=any2str(varargin)
%ANY2STR Convert any variables to one string
%	ANY2STR(...) converts any input argument into a single string, space
%	delimited.
%
%	Author: F. Beauducel <beauducel@ipgp.fr>
%	Created: 2021-01-01, in Yogyakarta, Indonesia

y = '';
for n = 1:length(varargin)
	if ischar(varargin{n})
		y = cat(2,y,' ',varargin{n});
	elseif isnumeric(varargin{n})
		y = cat(2,y,sprintf(' %g',varargin{n}));
	elseif isstruct(varargin{n})
		for f = fieldnames(varargin{n})'
			v = varargin{n}.(f{:});
			if ischar(v)
				v = ['''' v ''''];
			else
				v = ['[' num2str(v) ']'];
			end
			y = cat(2,y,sprintf(' %s: %s',f{:},v));
		end
	end
end
