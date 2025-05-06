function X = graphstr(s)
%GRAPHSTR Graph string interpreter
%	GRAPHSTR(S) interprets the char string S and return an array structure X
%	with fields:
%	   X(n).chan : channel number for graph n
%	   X(n).size : size of the graph n (positive integer)
%	   X(n).type : vector of graph type string (not functional)
%	   X(n).subplot : cell of arguments for the subplot function.
%
%   Syntax is:
%       - comma to separate channels in subplots
%       - multiple commas indicate a size factor for the previous subplot
%       - space to group channels in the same subplot
%
%	Examples:
%	   '1,2,3' means channels 1,2, and 3 on three equal-size subplots
%      '1 2,3' means channels 1 and 2 in the same first subplot, channel 3 in the second subplot
%	   '1,,,2,3,,' means channels 1, 2, and 3 with channel 1 three times higher
%       and channel 3 two times higher in size than channel 2.
%
%	To get the total graph size use sum(cat(1,X.size)).
%
%
%	Authors: F. Beauducel / WEBOBS, IPGP
%	Created: 2016-08-05, in Paris (France)
%	Updated: 2025-05-03


% splits the graphs (comma separated)
x = split(regexprep(s,'[^0-9, ]',''),',');

if ~isempty(x)
	k = find(~cellfun(@isempty,x));
	ng = length(k);

	k = [k,length(x)+1];

	for n = 1:ng
		X(n).chan = str2num(x{k(n)});
		X(n).size = k(n+1) - k(n);
		X(n).type = regexprep(x{k(n)},'[0-9]','');
	end

	% set the subplot arguments (doubles the height size)
	tot = 2*sum(cat(1,X.size));
	sp = 0;
	for n = 1:ng
		X(n).subplot = {tot,1,sp + (1:2*X(n).size)};
		sp = 2*sum(cat(1,X(1:n).size));
	end
else
	X = [];
end
