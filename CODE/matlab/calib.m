function [dc,C]=calib(t,d,CLB,cco)
%CALIB  Calibrate data
%       [DC,C] = CALIB(T,D,CLB) calibrates data D(T) using information
%       from structure CLB (imported from stations using readnode), and
%       returns a matrix DC of calibrated data, and a structure C with
%       last valid informations about channels.
%
%	[...] = CALIB(T,D,CLB,'ChannelCodeOrder') reorders the channels using
%	indexes in the Channel Code field. This is done before applying the calibration.
%
%
%	Author: F. Beauducel, WEBOBS/IPGP
%	Created: 2004-09-01
%	Updated: 2025-04-26

if isempty(t) || (isscalar(t) && isnan(t))
	t = now;
end

if isempty(d)
	d = nan(1,CLB.nx);
end

if nargin > 3 && strcmpi(cco,'channelcodeorder')
	cco = true;
else
	cco = false;
end

if CLB.nx > 0
	dc = nan(size(d,1),CLB.nx);
else
	dc = d;
	CLB = [];
end

% Possibilitiy to transmit a single value for time (example: RAP)
if length(t) < size(d,1)
	t = t(1)*ones(size(d,1),1);
end

% main loop on calibration file lines
for j = 1:length(CLB)
    % replace html tags by ISO char
    CLB(j).nm = htm2tex(CLB(j).nm);
    CLB(j).un = htm2tex(CLB(j).un);
	% loop on data columns
	nv = unique(CLB.nv);
	for i = 1:length(nv)
		ki = find(CLB(j).nv == nv(i));
		if ~isempty(ki)
			[tt,kii] = sort(CLB(j).dt(ki));
			ki = ki(kii);
			tt = [tt,realmax];
			% loop on each calibration line for channel i
			for ii = 1:(length(tt)-1)
				k = find(t >= tt(ii) & t < tt(ii+1));
				if ~isempty(k)
					% selects the right column of raw data
					col = str2double(CLB(j).cd{ki(ii)});
					if ~cco || col <= 0 || col > size(d,2) || isnan(col)
						col = i;
					end
					x = d(k,col); % the raw data 
					fprintf('WEBOBS{calib}: channel %d ("%s") calibrated from %s column %d (%d data - min/max = %g/%g).\n', ...
						i,CLB(j).nm{ki(ii)},datestr(tt(ii)),col,length(k),minmax(x));
					% filtering of min/max values is computed on the raw data (before calibration)
					if ~isnan(CLB(j).vn(ki(ii))) || ~isnan(CLB(j).vm(ki(ii)))
						kk = (x < CLB(j).vn(ki(ii)) | x > CLB(j).vm(ki(ii)));
						if any(kk)
							x(kk) = NaN;
						end
					end
					% data calibration is here
					f = CLB(j).et{ki(ii)};
					if ~isempty(strfind(f,'x'))
						dc(k,i) = eval(regexprep(f,'[^\d\.+-\/\*^xE\ \(\)]','')); % removes any invalid characters
					else
						dc(k,i) = x*sstr2num(f);
					end
					dc(k,i) = dc(k,i)*CLB(j).ga(ki(ii)) + CLB(j).of(ki(ii)); % x gain + offset
					for f = {'nm','un','ns','cd','of','et','ga','vn','vm','az','la','lo','al','dp','sf','db','lc'}
						C.(char(f))(i) = CLB(j).(char(f))(ki(ii));
					end
				end
			end
		else
			% no channel info in CLB: just copy the raw data in same column
			dc(:,i) = d(:,i);
		end
	end
end

if isempty(CLB)
	C = struct('nx',0);
else
	C.nx = length(unique(CLB.nv));
end
