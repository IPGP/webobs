function CLB = clbdefault(nx)
%CLBDEFAULT makes default CLB structure
%	CLBDEFAULT(N) returns a CLB structure with N channels and default values

if nx > 0
	CLB.nm = cellstr(reshape(sprintf('data%-2d',1:nx)',[],nx)')';
else
	CLB.nm = cell(1,0);
end
CLB.un = repmat({'-'},1,nx);
CLB.ns = repmat({''},1,nx);
CLB.cd = repmat({''},1,nx);
CLB.of = zeros(1,nx);
CLB.et = ones(1,nx);
CLB.ga = ones(1,nx);
CLB.vn = nan(1,nx);
CLB.vm = nan(1,nx);
CLB.az = zeros(1,nx);
CLB.la = nan(1,nx);
CLB.lo = nan(1,nx);
CLB.al = nan(1,nx);
CLB.dp = zeros(1,nx);
CLB.sf = nan(1,nx);
CLB.db = repmat({''},1,nx);
CLB.lc = repmat({''},1,nx);
CLB.nx = nx;

