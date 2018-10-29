% TERNPLOT plot ternary phase diagram
%   TERNPLOT(A, B) plots ternary phase diagram for three components.  C is calculated
%      as 1 - A - B.
%
%   TERNPLOT(A, B, C) plots ternary phase data for three components A B and C.  If the values 
%       are not fractions, the values are normalised by dividing by the total.
%
%   TERNPLOT(A, B, C, LINETYPE) the same as the above, but with a user specified LINETYPE (see PLOT
%       for valid linetypes).
%   
%   NOTES
%   - An attempt is made to keep the plot close to the default plot type.  The code has been based largely on the
%     code for POLAR.       
%   - The regular TITLE and LEGEND commands work with the plot from this function, as well as incrimental plotting
%     using HOLD.  Labels can be placed on the axes using TERNLABEL
%
%   See also TERNLABEL PLOT POLAR

%       c
%      / \
%     /   \
%    a --- b 

% Author: Carl Sandrock 20020827
% Modified: François Beauducel 20040318


function hpol = ternplot(A, B, C, line_style,tlabels)
xoffset = 0.04;
yoffset = 0.02;

majors = 5;

if nargin < 3
    C = 1 - (A+B);
end

if nargin < 4
    line_style = 'auto';
end

if nargin < 5
    tlabels = 1;
end

Total = (A+B+C);
fA = A./Total;
fB = B./Total;
fC = 1-(fA+fB);

[x, y] = frac2xy(fA, fC);

% Sort data points in x order
[x, i] = sort(x);
y = y(i);

% get hold state
cax = newplot;
next = lower(get(cax,'NextPlot'));
hold_state = ishold;

% get x-axis text color so grid is in same color
tc = get(cax,'xcolor');
ls = get(cax,'gridlinestyle');

% Hold on to current Text defaults, reset them to the
% Axes' font attributes so tick marks use them.
fAngle  = get(cax, 'DefaultTextFontAngle');
fName   = get(cax, 'DefaultTextFontName');
fSize   = get(cax, 'DefaultTextFontSize');
fWeight = get(cax, 'DefaultTextFontWeight');
fUnits  = get(cax, 'DefaultTextUnits');

set(cax, 'DefaultTextFontAngle',  get(cax, 'FontAngle'), ...
    'DefaultTextFontName',   get(cax, 'FontName'), ...
    'DefaultTextFontSize',   get(cax, 'FontSize'), ...
    'DefaultTextFontWeight', get(cax, 'FontWeight'), ...
    'DefaultTextUnits','data')

% only do grids if hold is off
if ~hold_state
	%plot axis lines
	hold on;
	plot ([0 1 0.5 0],[0 0 sin(1/3*pi) 0], 'color', tc, 'linewidth',1,...
                   'handlevisibility','off');
	set(gca, 'visible', 'off');

    % plot background if necessary
    if ~isstr(get(cax,'color')),
       patch('xdata', [0 1 0.5 0], 'ydata', [0 0 sin(1/3*pi) 0], ...
             'edgecolor',tc,'facecolor',get(gca,'color'),...
             'handlevisibility','off');
    end
    
	% Generate labels
   	majorticks = linspace(0, 1, majors + 1);
   	majorticks = majorticks(1:end-1);
   	labels = num2str(majorticks'*100);
	
   	zerocomp = zeros(1, length(majorticks));
	
  	% Plot right labels
  	[lxc, lyc] = frac2xy(zerocomp, majorticks);
    if tlabels == 1
    	text(lxc, lyc, [repmat('  ', length(labels), 1) labels]);
    end
	
    % Plot bottom labels
    [lxb, lyb] = frac2xy(1-majorticks, zerocomp); % fA = 1-fB
    if tlabels == 1
    	text(lxb, lyb, labels, 'VerticalAlignment', 'Top');
    end
    
    % Plot left labels
    [lxa, lya] = frac2xy(majorticks, 1-majorticks);
    if tlabels == 1
    	text(lxa-xoffset, lya, labels);
    end
    
	nlabels = length(labels)-1;
	for i = 1:nlabels
        plot([lxa(i+1) lxb(nlabels - i + 2)], [lya(i+1) lyb(nlabels - i + 2)], ls, 'color', tc, 'linewidth',1,...
           'handlevisibility','off');
        plot([lxb(i+1) lxc(nlabels - i + 2)], [lyb(i+1) lyc(nlabels - i + 2)], ls, 'color', tc, 'linewidth',1,...
           'handlevisibility','off');
        plot([lxc(i+1) lxa(nlabels - i + 2)], [lyc(i+1) lya(nlabels - i + 2)], ls, 'color', tc, 'linewidth',1,...
           'handlevisibility','off');
	end;
end;

% Reset defaults
set(cax, 'DefaultTextFontAngle', fAngle , ...
    'DefaultTextFontName',   fName , ...
    'DefaultTextFontSize',   fSize, ...
    'DefaultTextFontWeight', fWeight, ...
    'DefaultTextUnits',fUnits );

% plot data
if strcmp(line_style, 'auto')
    q = plot(x, y);
else
    q = plot(x, y, line_style);
end
if nargout > 0
    hpol = q;
end
if ~hold_state
    set(gca,'dataaspectratio',[1 1 1]), axis off; set(cax,'NextPlot',next);
end

function [x, y] = frac2xy(fA, fC);
y = fC*sin(pi/3);
x = 1 - fA - y*cot(pi/3);
