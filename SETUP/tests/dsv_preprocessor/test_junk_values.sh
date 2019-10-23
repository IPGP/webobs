
ALL_TESTS=(
	"test_semicolon_in_input_field"
	"test_comma_in_input_field"
	"test_minus_inf"
	)


function test_semicolon_in_input_field() {
	DESCRIPTION="If an input field includes a semicolon, it should
	be removed as any non-numerical character"

	ARGUMENTS="NODEXXX ',' 0 0"
	INPUT="1,11;33,3,4"
	EXPECTED_OUTPUT="1;1133;3;4"
	# Note: this is not the best behaviour we could expect, but
	# at least it won't create a new column and is coherent with
	# other non-numerical character.
}


function test_comma_in_input_field() {
	DESCRIPTION="If an input field includes a comma,
	it should be removed as any non-numerical character"

	ARGUMENTS="NODEXXX ';' 0 0"
	INPUT="1;9,9;3;4"
	EXPECTED_OUTPUT="1;99;3;4"
	# Note: this is not the best behaviour we could expect, but
	# at least it won't create a new column and is coherent with
	# other non-numerical character.
}


function test_minus_inf {
	DESCRIPTION="A field of value '-INF' should be replaced by NaN"

	ARGUMENTS="XXX ',' 0 0"
	INPUT='"2010-01-14 16:56:00",1,,"-INF"'
	EXPECTED_OUTPUT="2010;01;14;16;56;00;1;NaN;NaN"
}
