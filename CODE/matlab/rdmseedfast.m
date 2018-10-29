function [X,I]=rdmseedfast(f,bin)
%RDMSEEDFAST Read miniSEED file using external binary converter
%	[X,I]=RDMSEEDFAST(F) reads data from miniSEED file F and returns output
%	structures X (data blocks) and I (channels index), as RDMSEED does.
%
%	RDMSEEDFAST uses external converter (mseed2sac) for faster reading.
%	
%	Dependencies:
%		rdmseed.m
%		rdsac.m
%		mseed2sac (binary)
%
%	Author: François Beauducel / WEBOBS
%	Created: 2017-01-10 in Yogyakarta, Indonesia
%	Updated: 2018-07-02


if nargin < 2
	bin = 'mseed2sac';
end

[s,w] = wosystem(['which ',bin]);
if s==0 && ~isempty(w)

	ptmp = tempname;
	mkdir(ptmp);

	wosystem(sprintf('cd %s;%s %s',ptmp,bin,f));
	O = dir(ptmp);
	k = find(~cat(1,O.isdir));
	ChannelFullName = cell(size(k));
	for n = 1:length(k)
		fsac = O(k(n)).name;
		X(n) = rdsac(sprintf('%s/%s',ptmp,fsac));
		sv = split(fsac,'.');
		ChannelFullName{n} = sprintf('%s:%s:%s:%s',sv{1:4});
		SampleRate(n) = 1/X(n).HEADER.DELTA;
	end
	[channels,i,j] = unique(ChannelFullName);
	for n = 1:length(channels)
		k = find(strcmp(channels(n),ChannelFullName));
		I(n).XBlockIndex = k;
		I(n).ChannelFullName = channels{n};
	end
	for n = 1:length(k)
		X(n).SampleRate = SampleRate(n);
	end

	wosystem(['rm -rf ',ptmp]);

else

	% external converter not found: uses rdmseed function 
	fprintf('WEBOBS{rdmseedfast}: ** WARNING ** "%s" not found. Using rdmseed.m ...\n',bin);
	[X,I] = rdmseed(f);

end
