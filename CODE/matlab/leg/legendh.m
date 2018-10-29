function [leghandle,labelhandles,outH,outM]=legendh(varargin)
%LEGENDH Graph legend horizontal.
%   See LEGEND for syntax and use.

pos = get(gca,'Position');
[leghandle,labelhandles,outH,outM] = legend(varargin);
