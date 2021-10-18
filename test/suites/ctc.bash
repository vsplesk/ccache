ctc_PROBE() {
    if [ -z "$REAL_CTC" ]; then
        echo "ctc is not available"
    fi
}

ctc_SETUP() {
    # null command
    :;
}

expect_ctc_src_equal() {
    if [ ! -e "$1" ]; then
        test_failed_internal "expect_ctc_src_equal: $1 missing"
    fi
    if [ ! -e "$2" ]; then
        test_failed_internal "expect_ctc_src_equal: $2 missing"
    fi
    # remove the compiler invocation lines that could differ
    cp $1 $1_for_check
    cp $2 $2_for_check
    sed_in_place '/.compiler_invocation/d' $1_for_check $2_for_check

    if ! cmp -s "$1_for_check" "$2_for_check"; then
        test_failed_internal "$1 and $2 differ: $(echo; diff -u "$1_for_check" "$2_for_check")"
    fi
}

ctc_tests() {
    # -------------------------------------------------------------------------
    TEST "Preprocessor base case"

    generate_code 1 test1.c

    # test compilation without ccache to get a reference file
    $REAL_CTC --core=tc1.6.2 -o reference_test1.src test1.c

    # First compile.
    $CCACHE $REAL_CTC --core=tc1.6.2 test1.c
    expect_stat preprocessed_cache_hit 0
    expect_stat cache_miss 1
    expect_stat files_in_cache 1
    expect_ctc_src_equal reference_test1.src test1.src

    # Second compile.
    $CCACHE $REAL_CTC --core=tc1.6.2 test1.c
    expect_stat preprocessed_cache_hit 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 1
    expect_ctc_src_equal reference_test1.src test1.src

    # Third compile, test output option
    $CCACHE $REAL_CTC --core=tc1.6.2 --output=test1.src test1.c
    expect_stat preprocessed_cache_hit 2
    expect_stat cache_miss 1
    expect_stat files_in_cache 1
    expect_ctc_src_equal reference_test1.src test1.src

    # Test for a different core -> parameter stays in the hash along with the preprocessor output
    $CCACHE $REAL_CTC --core=tc1.3 test1.c
    expect_stat preprocessed_cache_hit 2
    expect_stat cache_miss 2
    expect_stat files_in_cache 2

    # Test for a different core -> parameter stays in the hash along with the preprocessor output
    $CCACHE $REAL_CTC --core=tc1.3 --align=4 test1.c
    expect_stat preprocessed_cache_hit 2
    expect_stat cache_miss 3
    expect_stat files_in_cache 3

    # test with the same option in a file
    echo "--core=tc1.3" > file.opt
    echo "--align=4" >> file.opt
    $CCACHE $REAL_CTC -f file.opt test1.c
    expect_stat preprocessed_cache_hit 3
    expect_stat cache_miss 3
    expect_stat files_in_cache 3

    # test with the same option in a file
    $CCACHE $REAL_CTC --option-file=file.opt test1.c
    expect_stat preprocessed_cache_hit 4
    expect_stat cache_miss 3
    expect_stat files_in_cache 3

    # modify the C file
    generate_code 2 test1.c
    $CCACHE $REAL_CTC --option-file=file.opt test1.c
    expect_stat preprocessed_cache_hit 4
    expect_stat cache_miss 4
    expect_stat files_in_cache 4

    # -------------------------------------------------------------------------
    TEST "Direct mode base case"
    generate_code 1 test1.c

    unset CCACHE_NODIRECT

    # First compile.
    $CCACHE $REAL_CTC --core=tc1.6.2 test1.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 0
    expect_stat direct_cache_miss 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 2

    # Second compile.
    $CCACHE $REAL_CTC --core=tc1.6.2 test1.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 2

    # modify the C file
    generate_code 2 test1.c
    $CCACHE $REAL_CTC --core=tc1.6.2 test1.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 1
    expect_stat cache_miss 2
    expect_stat files_in_cache 4

    # -------------------------------------------------------------------------
    TEST "Direct mode header modification case"

    mkdir -p subdir/src subdir/include
    cat <<EOF >subdir/src/test.c
#include <test.h>
int foo(int x) { return test + x; }
EOF
    cat <<EOF >subdir/include/test.h
int test;
EOF

    # after creation of the file, wait a couple of seconds
    sleep 2

    unset CCACHE_NODIRECT

    # First compile.
    $CCACHE $REAL_CTC -I subdir/include --core=tc1.6.2 subdir/src/test.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 0
    expect_stat direct_cache_miss 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 2

    # Second compile -> direct hit
    $CCACHE $REAL_CTC -I subdir/include --core=tc1.6.2 subdir/src/test.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 2

    # modify the header file
    cat <<EOF >subdir/include/test.h
int test;
int test2;
EOF

    # after modification of the file, wait a couple of seconds
    sleep 2

    $CCACHE $REAL_CTC -I subdir/include --core=tc1.6.2 subdir/src/test.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 1
    expect_stat cache_miss 2
    # here we have only three files because the same key is used to match the command line, but the manifest (include files sha)
    # changed
    expect_stat files_in_cache 3

    # -------------------------------------------------------------------------
    TEST "Extra long CLI parameters"

    mkdir -p subdir/src subdir/include
    cat <<EOF >subdir/src/test.c
#include <test.h>
int foo(int x) { return test + x; }
EOF
    cat <<EOF >subdir/include/test.h
int test;
EOF

    # after creation of the file, wait a couple of seconds
    sleep 2

    unset CCACHE_NODIRECT

    local i
    local params=""
    for ((i = 1; i <= 1000; i++)); do
        params="$params -I subdir/include"
    done

    # fallback to original compiler
    $CCACHE $REAL_CTC $params -n --core=tc1.6.2 subdir/src/test.c
    expect_stat output_to_stdout 1

    remove_cache

    # with arguments
    $CCACHE $REAL_CTC $params --core=tc1.6.2 subdir/src/test.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 0
    expect_stat direct_cache_miss 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 2

    remove_cache

    # with option
    rm -f optionfile
    for ((i = 1; i <= 1000; i++)); do
         echo " -I subdir/include" >>optionfile
    done

    $CCACHE $REAL_CTC -f optionfile --core=tc1.6.2 subdir/src/test.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 0
    expect_stat direct_cache_miss 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 2

    return 0

}

SUITE_ctc_PROBE() {
    ctc_PROBE
}

SUITE_ctc_SETUP() {
    ctc_SETUP
}

SUITE_ctc() {
    ctc_tests
}
