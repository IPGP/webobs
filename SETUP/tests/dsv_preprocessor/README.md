# Tests for the preprocessor script of the DSV format

The script `run_all_tests.sh` in this directory can be used to test a
preprocessor script like the default `dsv_generic` provided by WebObs
to avoid any regression and clarify its behaviour in some corner cases.


## Usage information

Use the `-h` or `--help` option with `run_all_tests.sh` for information
on how to run the script. It should print a screen like this one:

```
Usage: run_all_tests.sh <preprocessor_script> [<test_script>[:<test_function>]] ...

  Run the provided preprocessor script using arguments and input data
  provided by functions in the test scripts.

  If the <test_script> argument is provided, run tests from this file.
  Otherwise, read all files in the script directory matching 'test_*.sh'.

  If <test_function> is provided, only the test described in this
  function from <test_script> will be run.  Otherwise, run the tests
  defined by all the test functions listed in the array ALL_TESTS.

Options:

  -x|--exitfirst
      Stop execution after the first failed test
  -f|--hide-failed
      Hide details about passed tests (printed by default)
  -p|--show-passed
      Show details about passed tests (hidden by default)
  -h|--help
      This help screen
```


## Test files

Test files should be named to match the glob `test_*.sh` for `run_all_tests.sh`
to detect it automatically.

Test scripts should define test functions and list them in an `ALL_TESTS` array 
to allow `run_all_tests.sh` to execute all tests in the file.

Test function should simply define 4 global variables:

- `DESCRIPTION`

	A short description about the goal of the test that will be printed along
	with the test details (by default only when a test fails).
    The string can include newlines for a nicer display. Any leading tabulation
	on the beginning of a line will be stripped to allow the test script to be
	indented in a natural fashion.

- `ARGUMENTS`

	The arguments to pass to the preprocessor, separated by spaces.

- `INPUT`

	The input to pass to preprocessor. The string can naturally include
	newlines and will be passed unchanged to the tested script.

- `EXPECTED_OUTPUT`

	The expected output of a successful test. It will be compared to the
	actual output of the tested script to determine whether the execution
	succeeded or not.


## Examples of output

Below is the execution of tests from a specific test file, with all tests passing:
```
$ ./run_all_tests.sh ../dsv_generic.new  ./test_comments_headers.sh

## Running tests from ./test_comments_headers.sh

-- Running test 'test_discard_comments'... PASSED
-- Running test 'test_discard_headers'... PASSED
-- Running test 'test_additional_separators'... PASSED

All tests PASSED.
```

Here is the same execution with one test failing:
```
$ ./run_all_tests.sh ../dsv_generic.new  ./test_comments_headers.sh

## Running tests from ./test_comments_headers.sh

-- Running test 'test_discard_comments'... PASSED
-- Running test 'test_discard_headers'... FAILED

| Test description:
| The third argument specifies the number of header lines to discard

| Test command:
../dsv_generic.new NODEXXX ',' 2 0

| Input data:
----------------------8<----------------------
"col1","col2","col3"
"Avg","Samp","Samp"
1,2,3,4
----------------------8<----------------------

| Actual output of the script:
----------------------8<----------------------
"Avg","Samp","Samp"
1;2;3;4
----------------------8<----------------------

| Expected output:
----------------------8<----------------------
1;2;3;4
----------------------8<----------------------

-- Running test 'test_additional_separators'... PASSED

1 test(s) FAILED.
```
