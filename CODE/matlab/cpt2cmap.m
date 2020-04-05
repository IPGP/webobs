function [cmap, lims,ticks,bfncol,ctable] = cpt2cmap(file,ncol)
%CPT2CMAP Convert a .cpt file to colormap matrix.
%
%    [cmap, lims,ticks,bfncol,ctable] = cpt2cmap(file,ncol)
%
% This function creates a colormap defined in a color palette
% table (.cpt file).  For a full description of the cpt file format, see
% the Generic Mapping Tools documentation (http://gmt.soest.hawaii.edu/).
% Color palette files provide more flexible colormapping than Matlab's
% default schemes, including both discrete and continuous gradients, as
% well as easier direct color mapping.
%
% Limitations: X11 color names not supported, patterns not supported, CMYK
% not supported yet
% Inout variables:
%
%   file:       .cpt filename.
%
%   ncol:       number of colors in final colormap. If not included or NaN,
%               this function will try to choose the fewest number of
%               blocks needed to display the colormap as accurately as
%               possible. I have arbitrarily chosen that it will not try to
%               create more than 256 colors in the final colormap when
%               using this automatic scheme.  However, you can manually set
%               ncol higher if necessary to resolve all sharp breaks and
%               gradients in the colormap.
%
% Output variables:
%
%   cmap:       ncol x 3 colormap array
%
%   lims:       1 x 2 array holding minimum and maximum values for which
%               the colormap is defined.  
%
%   ticks:      vector of tick values specifying where colors were defined
%               in the original file
%
%   bfncol:     3 x 3 colormap array specifying the colors defined for
%               background (values lower than lowest color limit),
%               foreground (values higher than highest color limit), and
%               NaN values.  These do not affect the resulting colormap,
%               but can be applied by the user to replicate the behavior
%               seen in GMT.
%
%   ctable:     n x 8 color palette table, translated to Matlab color
%               space. Column 1 holds the lower limit of each color cell,
%               columns 2-4 the RGB values corresponding to the lower
%               limit, column 5 the upper limit of the color cell, and
%               columns 6-8 the RGB values of the upper limit.  When the
%               lower and upper colors are the same, this defines a
%               solid-colored cell; when they are different, colors are
%               linearly interpolated between the endpoints.
%
%
% Author:       Kelly Kearney, 2011-2016 (extract from original function cptcmap.m)
% Source:	https://fr.mathworks.com/matlabcentral/fileexchange/28943-color-palette-tables-cpt-for-matlab
%
% Modified by:  François Beauducel <beauducel@ipgp.fr>, WebObs Project
% Updated:      2020-04-05


if nargin < 1 || ~exist(file,'file')
    error('You must provide a valid colormap name.');
end

% Read file

fid = fopen(file);
txt = textscan(fid, '%s', 'delimiter', '\n');
txt = txt{1};
fclose(fid);

isheader = strncmp(txt, '#', 1);
isfooter = strncmp(txt, 'B', 1) | strncmp(txt, 'F', 1) | strncmp(txt, 'N', 1); 

% Extract color data, ignore labels (errors if other text found)

ctabletxt = txt(~isheader & ~isfooter);
ctable = str2num(strvcat(txt(~isheader & ~isfooter)));
if isempty(ctable)
    nr = size(ctabletxt,1);
    ctable = cell(nr,1);
    for ir = 1:nr
        ctable{ir} = str2num(strvcat(regexp(ctabletxt{ir}, '[\d\.-]*', 'match')))';
    end
    try 
        ctable = cell2mat(ctable);
    catch
        error('Cannot parse this format .cpt file yet');
    end 
end

% Determine which color model is used (RGB, HSV, CMYK, names, patterns,
% mixed)

[nr, nc] = size(ctable);
iscolmodline = cellfun(@(x) ~isempty(x), regexp(txt, 'COLOR_MODEL'));
if any(iscolmodline)
    colmodel = regexprep(txt{iscolmodline}, 'COLOR_MODEL', '');
    colmodel = strtrim(lower(regexprep(colmodel, '[#=]', '')));
else
    if nc == 8
        colmodel = 'rgb';
    elseif nc == 10
        colmodel = 'cmyk';
    else
        error('Cannot parse this format .cpt file yet');
    end
end
%     try
%         temp = str2num(strvcat(txt(~isheader & ~isfooter)));
%         if size(temp,2) == 8
%             colmodel = 'rgb';
%         elseif size(temp,2) == 10
%             colmodel = 'cmyk';
%         else % grayscale, maybe others
%             error('Cannot parse this format .cpt file yet');
%         end
%     catch % color names, mixed formats, dash placeholders
%         error('Cannot parse this format .cpt file yet');
%     end
% end
%     

% 
% iscmod = strncmp(txt, '# COLOR_MODEL', 13);
% 
% 
% if ~any(iscmod)
%     isrgb = true;
% else
%     cmodel = strtrim(regexprep(txt{iscmod}, '# COLOR_MODEL =', ''));
%     if strcmp(cmodel, 'RGB')
%         isrgb = true;
%     elseif strcmp(cmodel, 'HSV')
%         isrgb = false;
%     else
%         error('Unknown color model: %s', cmodel);
%     end
% end

% Reformat color table into one column of colors

cpt = zeros(nr*2, 4);
cpt(1:2:end,:) = ctable(:,1:4);
cpt(2:2:end,:) = ctable(:,5:8);

% Ticks

ticks = unique(cpt(:,1));

% Choose number of colors for output

if nargin < 2 || isnan(ncol)
    
    endpoints = unique(cpt(:,1));
    
    % For gradient-ed blocks, ensure at least 4 steps between endpoints
    
    issolid = all(ctable(:,2:4) == ctable(:,6:8), 2);
    
    for ie = 1:length(issolid)
        if ~issolid(ie)
            temp = linspace(endpoints(ie), endpoints(ie+1), 11)';
            endpoints = [endpoints; temp(2:end-1)];
        end
    end
    
    endpoints = sort(endpoints);
    
    % Determine largest step size that resolves all endpoints
    
    space = diff(endpoints);
    space = unique(space);
%     space = roundn(space, -3); % To avoid floating point issues when converting to integers
    space = round(space*1e3)/1e3;
    
    nspace = length(space);
    if ~isscalar(space)
        
        fac = 1;
        tol = .001;
        while 1
            if all(space >= 1 & (abs(space - round(space))) < tol)
                space = round(space);
                break;
            else
                space = space * 10;
                fac = fac * 10;
            end
        end
        
        pairs = nchoosek(space, 2);
        np = size(pairs,1);
        commonsp = zeros(np,1);
        for ip = 1:np
            commonsp(ip) = gcd(pairs(ip,1), pairs(ip,2));
        end
        
        space = min(commonsp);
        space = space/fac;
    end
            
    ncol = (max(endpoints) - min(endpoints))./space;
    ncol = min(ncol, 256);
    
end

% Remove replicates and mimic sharp breaks

isrep =  [false; ~any(diff(cpt),2)];
cpt = cpt(~isrep,:);

difc = diff(cpt(:,1));
minspace = min(difc(difc > 0));
isbreak = [false; difc == 0];
cpt(isbreak,1) = cpt(isbreak,1) + .01*minspace;

% Parse background, foreground, and nan colors

footer = txt(isfooter);
bfncol = nan(3,3);
for iline = 1:length(footer)
    if strcmp(footer{iline}(1), 'B')
        bfncol(1,:) = str2num(regexprep(footer{iline}, 'B', ''));
    elseif strcmp(footer{iline}(1), 'F')
        bfncol(2,:) = str2num(regexprep(footer{iline}, 'F', ''));
    elseif strcmp(footer{iline}(1), 'N')
        bfncol(3,:) = str2num(regexprep(footer{iline}, 'N', ''));
    end
end

% Convert to Matlab-format colormap and color limits

lims = [min(cpt(:,1)) max(cpt(:,1))];
endpoints = linspace(lims(1), lims(2), ncol+1);
midpoints = (endpoints(1:end-1) + endpoints(2:end))/2;

cmap = interp1(cpt(:,1), cpt(:,2:4), midpoints);

switch colmodel
    case 'rgb'
        cmap = cmap ./ 255;
        bfncol = bfncol ./ 255;
        ctable(:,[2:4 6:8]) = ctable(:,[2:4 6:8]) ./ 255;
        
    case 'hsv'
        cmap(:,1) = cmap(:,1)./360;
        cmap = hsv2rgb(cmap);
        
        bfncol(:,1) = bfncol(:,1)./360;
        bfncol = hsv2rgb(bfncol);
        
        ctable(:,2) = ctable(:,2)./360;
        ctable(:,6) = ctable(:,6)./360;
        
        ctable(:,2:4) = hsv2rgb(ctable(:,2:4));
        ctable(:,6:8) = hsv2rgb(ctable(:,6:8));
        
    case 'cmyk'
        error('CMYK color conversion not yet supported');
end

% Rouding issues: occasionally, the above calculations lead to values just
% above 1, which colormap doesn't like at all.  This is a bit kludgy, but
% should solve those issues

cmap(cmap > 1 & (abs(cmap-1) < 2*eps)) = 1;
