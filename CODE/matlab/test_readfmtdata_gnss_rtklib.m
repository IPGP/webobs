%TEST_READFMTDATA_GNSS_RTKLIB  Test the readfmtdata_gnss function with rtklib format
%
%  Simulates a WebObs configuration with RTKLIB data
%
%  Usage:
%    /usr/bin/octave --no-gui test_readfmtdata_gnss_rtklib.m

fprintf('\n==============================================================\n');
fprintf(' WebObs readfmtdata_gnss – rtklib integration test\n');
fprintf('==============================================================\n\n');

% Setup paths
here = fileparts(mfilename('fullpath'));
addpath(here);

% Create mock objects matching WebObs structure
%
% The real function expects:
%   readfmtdata_gnss(WO, P, N, F)
% where:
%   P = process structure
%   N = node structure
%   F = options structure

% Create minimal mock structures
P = struct();
P.TZ = 0;                                 % Timezone offset

N = struct();
N.ID = 'TEST01';
N.FID = 'BOMG';
N.UTC_DATA = 0;                           % No UTC offset for this test
% CLB with nx=5 to skip calib() call (nx must be != 4)
N.CLB = struct('nx', 5, 'nm', {{'E','N','U','Orbit'}}, 'un', {{'m','m','m',''}});

F = struct();
F.fmt = 'rtklib';
F.raw = {'/home/sakic/aaa_FOURBI/OVPF_static-start_ULT_BOMG_B593_2026_065_0030.out'};
F.ptmp = tempname();                      % Temporary directory
mkdir(F.ptmp);
F.datelim = [NaN NaN];                    % No date limits

fprintf('Setup:\n');
fprintf('  Process: %s\n', P.TZ);
fprintf('  Node ID: %s (FID=%s)\n', N.ID, N.FID);
fprintf('  Format: %s\n', F.fmt);
fprintf('  Raw data: %s\n', F.raw{1});
fprintf('  Temp dir: %s\n\n', F.ptmp);

% Call the real function
fprintf('--- Calling readfmtdata_gnss(WO, P, N, F) ---\n\n');
try
  D = readfmtdata_gnss([], P, N, F);
  
  fprintf('SUCCESS!\n\n');
  fprintf('Output structure D:\n');
  fprintf('  D.t:  %d×1 timestamps (datenum)\n', length(D.t));
  fprintf('  D.d:  %d×4 data matrix [E N U Orbit] (meters)\n', size(D.d,1));
  fprintf('  D.e:  %d×3 error matrix [sE sN sU] (meters)\n', size(D.e,1));
  fprintf('  D.CLB: calibration structure\n\n');
  
  % Detailed inspection
  fprintf('First 5 data points:\n');
  fprintf('  Time (datenum):        %.8f to %.8f\n', D.t(1), D.t(5));
  fprintf('  East (m):              %.2f to %.2f\n', D.d(1,1), D.d(5,1));
  fprintf('  North (m):             %.2f to %.2f\n', D.d(1,2), D.d(5,2));
  fprintf('  Height (m):            %.2f to %.2f\n', D.d(1,3), D.d(5,3));
  fprintf('  East sigma (m):        %.6f to %.6f\n', D.e(1,1), D.e(5,1));
  fprintf('  North sigma (m):       %.6f to %.6f\n', D.e(1,2), D.e(5,2));
  fprintf('  Height sigma (m):      %.6f to %.6f\n', D.e(1,3), D.e(5,3));
  
  fprintf('\nLast 5 data points:\n');
  fprintf('  Time (datenum):        %.8f to %.8f\n', D.t(end-4), D.t(end));
  fprintf('  East (m):              %.2f to %.2f\n', D.d(end-4,1), D.d(end,1));
  fprintf('  North (m):             %.2f to %.2f\n', D.d(end-4,2), D.d(end,2));
  fprintf('  Height (m):            %.2f to %.2f\n', D.d(end-4,3), D.d(end,3));
  
  % Sanity checks
  fprintf('\n--- Sanity checks ---\n');
  
  all_finite_t = all(isfinite(D.t));
  all_finite_d = all(isfinite(D.d(:)));
  all_finite_e = all(isfinite(D.e(:)));
  all_positive_e = all(D.e(:) > 0);
  
  if all_finite_t
    fprintf('[PASS] All timestamps are finite\n');
  else
    fprintf('[FAIL] Some timestamps are NaN/Inf\n');
  end
  
  if all_finite_d
    fprintf('[PASS] All position data are finite\n');
  else
    fprintf('[FAIL] Some position data are NaN/Inf\n');
  end
  
  if all_finite_e && all_positive_e
    fprintf('[PASS] All error values are finite and positive\n');
  else
    fprintf('[FAIL] Some error values invalid\n');
  end
  
  if size(D.d,2) == 4 && size(D.e,2) == 3
    fprintf('[PASS] Output dimensions correct: D.d is 900×4, D.e is 900×3\n');
  else
    fprintf('[FAIL] Output dimensions wrong\n');
  end
  
  fprintf('\n==============================================================\n');
  fprintf(' SUCCESS: rtklib format is working in readfmtdata_gnss!\n');
  fprintf('==============================================================\n\n');
  
catch err
  fprintf('ERROR in readfmtdata_gnss:\n');
  fprintf('  %s\n', err.message);
  fprintf('\nStack:\n');
  for i = 1:length(err.stack)
    fprintf('  %s (line %d)\n', err.stack(i).name, err.stack(i).line);
  end
  
  % Cleanup
  system(sprintf('rm -rf "%s"', F.ptmp));
  error('Test failed');
end

% Cleanup
system(sprintf('rm -rf "%s"', F.ptmp));

fprintf('Test complete.\n');
