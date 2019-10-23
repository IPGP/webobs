
ALL_TESTS=(
	"test_min_usable_fields"
	)


function test_min_usable_fields {
	DESCRIPTION="When no number of fields is provided, the preprocessor should still
	discard lines with less than 3 fields on output."

	ARGUMENTS="XXX ';' 0 0"
	INPUT="2009-001;1
2009-002"
	EXPECTED_OUTPUT="2009;001;1"
}
