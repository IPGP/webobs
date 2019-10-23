#!/bin/bash
#
#
# Run all scripts in the current directory matching 'test_*'
# with the path to the script to test.
#


# Constants and variables -----------------------------------------------------

SCRIPT_NAME=${0##*/}
SHORT_OPTS="xpfh"
LONG_OPTS='exitfirst,show-passed,hide-failed,help'

# Default values for indicators that can be changed by script options
#
# Exit after first error
EXIT_FIRST_ERR=0
# Show command, input, output and expected output after a passed test
SHOW_PASSED_DETAILS=0
# Show command, input, output and expected output after a failed test
SHOW_FAILED_DETAILS=1

# Indicate the number of failed tests
declare -i failed_tests=0


# Helper functions ------------------------------------------------------------


function usage() {
	cat <<-__EOD__
	Usage: $SCRIPT_NAME <preprocessor_script> [<test_script>[:<test_function>]] ...

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
	__EOD__
}


function process_script_opts() {
	#
	# Parse and read script options and arguments,
	# setting PROCESSED_ARGS to the remaining arguments
	#
	declare -g PROCESSED_ARGS PREPROCESSOR
	# Default
	declare -g EXIT_FIRST_ERR=0 SHOW_PASSED_DETAILS=0 SHOW_FAILED_DETAILS=1
	PROCESSED_ARGS=$(getopt -o $SHORT_OPTS --long $LONG_OPTS -n $SCRIPT_NAME -- "$@")
	[ $? -ne 0 ] && { echo; usage; exit -1; } # getopt returned an error
	# Note: quotes around `$PROCESSED_ARGS' are mandatory
	eval set -- $PROCESSED_ARGS

	# Loop on script options
	while true; do
		case "$1" in
			-x|--exitfirst)
				EXIT_FIRST_ERR=1;;
			-p|--show-passed)
				SHOW_PASSED_DETAILS=1;;
			-f|--hide-failed)
				SHOW_FAILED_DETAILS=0;;
			-h|--help)
				usage; exit -1;;
			--)
				shift; break;;
			*)
				usage; exit -1;;
		esac
		shift
	done

	# Script parameters
	PREPROCESSOR="$1"
	shift

	# At least the preprocessor script must be provided
	if [ -z "$PREPROCESSOR" ]; then
		usage
		exit -1
	fi

	# If no argument is provided, we use all test scripts 
	# in the current directory matching test_*.sh
	if [ -z "$*" ]; then
		set $(dirname $0)/test_*.sh
	fi

	# Update PROCESSED_ARGS
	PROCESSED_ARGS="$*"
}


# Main functions --------------------------------------------------------------


function run_test() {
	#
	# Run a single test defined by the $test_func function that is 
	# expected to define the following variables describing the test:
	#     DESCRIPTION  A short description about the goal of the test
	#       ARGUMENTS  The arguments to pass to $PREPROCESSOR
	#           INPUT  The input to pass to $PREPROCESSOR
	# EXPECTED_OUTPUT  The expected output of a successful test
	#
	# Return 1 if the test failed, 0 otherwise
	#
	local test_func="$1" output show_details=0 test_failed=0
	local DESCRIPTION ARGUMENTS INPUT EXPECTED_OUTPUT

	# Call the test function defining the variables above
	$test_func

	echo -n "-- Running test '$test_func'... "
	output=$(eval "$PREPROCESSOR $ARGUMENTS <<< '$INPUT'" 2>&1)

	if [[ "$output" == "$EXPECTED_OUTPUT" ]]; then
		echo "PASSED"
		[[ $SHOW_PASSED_DETAILS -eq 1 ]] && show_details=1
	else
		echo "FAILED"
		test_failed=1
		[[ $SHOW_FAILED_DETAILS -eq 1 ]] && show_details=1
	fi

	if [[ $show_details -eq 1 ]]; then
		cat <<-__EOD__

		| Test description:
		$(sed 's/^\t*//; s/^/| /' <<<"$DESCRIPTION")
		
		| Test command:
		$PREPROCESSOR $ARGUMENTS
		
		| Input data:
		----------------------8<----------------------
		$INPUT
		----------------------8<----------------------

		| Actual output of the script:
		----------------------8<----------------------
		$output
		----------------------8<----------------------
		
		| Expected output:
		----------------------8<----------------------
		$EXPECTED_OUTPUT
		----------------------8<----------------------

		__EOD__
	fi

	return $test_failed
}


function run_test_file() {
	#
	# Run one test (if $test_function is provided) or all tests from
	# the test file $test_file, which is expected to define:
	# - an ALL_TESTS variable which lists all the test functions
	#   the file provides (space-separated list of function names)
	# - the test functions themselves
	#
	# Return the number of failed tests
	#
	local test_file="$1" test_function="$2"
	local -i failed_tests=0

	echo -e "\n## Running tests from $test_file\n"
	source $test_file || {
		echo "ERROR: cannot read file '$test_file'"
		exit -1
	}

	if [[ -n "$test_function" ]]; then
		# Run the designated function from $test_file
		TEST_LIST="$test_function"
	else
		# Run all functions exported from $test_file
		if [[ -z "$ALL_TESTS" ]]; then
			echo "ERROR: file '$test_file' does not list its tests in \$ALL_TESTS"
			exit -1
		fi
		TEST_LIST="${ALL_TESTS[*]}"
	fi

	for t_func in $TEST_LIST; do

		if ! declare -f $t_func > /dev/null; then
			echo "ERROR: function $t_func could not be found" >&2
			continue
		fi

		# Run the test defined by the function
		# (run in a subprocess to avoid mixing environments)
		( run_test "$t_func" ) || {
			# The test has failed
			failed_tests+=1
			if [[ $EXIT_FIRST_ERR == 1 ]]; then
				return 1
			fi
		}
	done

	# Return the number of failed tests
	return $failed_tests
}


# Main instructions -----------------------------------------------------------


# Parse and read options and arguments
process_script_opts "$@"
eval set $PROCESSED_ARGS


# Run all test files provided as script parameters
for test_spec; do

	# Read the file and optional test function that
	# can be provided as "file:function"
	IFS=: read test_file test_function <<< "$test_spec"

	# Run in a subprocess to avoid leaking definitions from $test_file
	( run_test_file "$test_file" "$test_function" )
	rc=$?
	if [[ $rc -ne 0 ]]; then
		failed_tests+=$rc
		[[ $EXIT_FIRST_ERR == 1 ]] && break
	fi

done

if [[ $failed_tests -eq 0 ]]; then
	echo -e "\nAll tests PASSED."
elif [[ $EXIT_FIRST_ERR == 1 ]]; then
	echo -e "Execution stopped because a test FAILED and -x/--firstexit was used."
else
	echo -e "\n$failed_tests test(s) FAILED."
fi
