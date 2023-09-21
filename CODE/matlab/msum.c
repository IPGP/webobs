#include "mex.h"

/*
 * msum.c
 * Moving sum general case
 *
 * The calling syntax is:
 *
 *	y=msumv(t,x,tw)
 *
 * t is a time vector (e.g. in datenum format), x is data vector, tw is the 
 * time window for moving sum (same unit as t), y is the moving sum result.
 * t is a vector (size Mx1), x a vector (Mx1), tw is a scalar, y has the same 
 * size as x.
 *
 * This is a MEX-file for Matlab/Octave.
 *
 * Author: François Beauducel, IPGP/WebObs
 * Created: 2023-09-15
 * Updated: 2023-09-15
 */


void msum(double* t, double* x, double tw, double* y, size_t numel) {
	mwSize i, j;

	for (i = 0; i < numel; i++) {
		for (j = i; j >= 0; j--) {
			if (*(t + i) - tw < *(t + j)) {
				*(y + i) += *(x + j);
			} else {
				break;
			}
		}
	}
}

/*
 * the gateway function for MEX
 */
void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {

	double *t, *x, *tw, *y;
	mwSize ndim;
	const mwSize *sz;
	size_t numel;
	int n;

	/* check for proper number of arguments */
	if (nrhs != 3)
		mexErrMsgIdAndTxt("MATLAB:msum:invalidNumInputs", "Three inputs required.");
	if (nlhs != 1)
		mexErrMsgIdAndTxt("MATLAB:msum:invalidNumOutputs", "One outputs required.");

	/*  get the dimensions of the matrix input x */
	ndim = mxGetNumberOfDimensions(prhs[0]);
	sz = mxGetDimensions(prhs[0]);
	numel = mxGetNumberOfElements(prhs[0]);

	/* check to make sure all input arguments are real, double matrix and same size as x */
	for (n = 0; n < nrhs; n++) {
		if (!mxIsDouble(prhs[n]) 
			|| (n < 2 && (mxGetNumberOfElements(prhs[n]) != numel ))
			|| (n == 2 && !mxIsScalar(prhs[n])))
			mexErrMsgIdAndTxt("MATLAB:msum:fieldNotRealMatrix",
				"All input arguments must be real, double matrix with same size.");
	}

	/*  create pointers to each of the input matrices */
	t  = mxGetPr(prhs[0]);
	x  = mxGetPr(prhs[1]);
	tw = mxGetPr(prhs[2]);

	/*  create the output matrix */
	plhs[0] = mxCreateNumericArray(ndim, sz, mxDOUBLE_CLASS, mxREAL);

	/*  create pointers to a copy of the output matrix */
	y = mxGetPr(plhs[0]);

	/*  call the C subroutine */
	msum(t, x, *tw, y, numel);
}
