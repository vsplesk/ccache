cctc_PROBE() {
    if [ -z "$REAL_CCTC" ]; then
        echo "ctc is not available"
    fi
}

cctc_SETUP() {
    generate_code 1 test1.c
}

cctc_tests() {
    # -------------------------------------------------------------------------
    TEST "Base case"

    # test compilation without ccache to get a reference file
    $REAL_CCTC --core=tc1.6.2 --create=object -o reference_test1.o test1.c

    # First compile.
    $CCACHE $REAL_CCTC --core=tc1.6.2 --create=object test1.c
    expect_stat preprocessed_cache_hit 0
    expect_stat cache_miss 1
    expect_stat files_in_cache 1
#    expect_equal_content reference_test1.o test1.o

    # Second compile.
    $CCACHE $REAL_CCTC --core=tc1.6.2 --create=object test1.c
    expect_stat preprocessed_cache_hit 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 1
#    expect_equal_content reference_test1.o test1.o

    # Third compile, test output option
    $CCACHE $REAL_CCTC --core=tc1.6.2 --output=test1.o --create=object test1.c
    expect_stat preprocessed_cache_hit 2
    expect_stat cache_miss 1
    expect_stat files_in_cache 1
#    expect_equal_content reference_test1.o test1.o

    # Test for a different core -> parameter stays in the hash along with the preprocessor output
    $CCACHE $REAL_CCTC --core=tc1.3 --create=object test1.c
    expect_stat preprocessed_cache_hit 2
    expect_stat cache_miss 2
    expect_stat files_in_cache 2

    # Test for a different core -> parameter stays in the hash along with the preprocessor output
    $CCACHE $REAL_CCTC --core=tc1.3 --align=4 --create=object test1.c
    expect_stat preprocessed_cache_hit 2
    expect_stat cache_miss 3
    expect_stat files_in_cache 3

    # test with the same option in a file
    echo "--core=tc1.3" > file.opt
    echo "--align=4" >> file.opt
    echo "--create=object " >> file.opt
    $CCACHE $REAL_CCTC -f file.opt test1.c
    expect_stat preprocessed_cache_hit 3
    expect_stat cache_miss 3
    expect_stat files_in_cache 3

    $CCACHE $REAL_CCTC --option-file=file.opt test1.c
    expect_stat preprocessed_cache_hit 4
    expect_stat cache_miss 3
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
    $CCACHE $REAL_CCTC $params -n --core=tc1.6.2 subdir/src/test.c
    expect_stat output_to_stdout 1

    remove_cache

    # with arguments
    $CCACHE $REAL_CCTC $params --core=tc1.6.2 --create=object subdir/src/test.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 0
    expect_stat direct_cache_miss 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 2

    rm -f optionfile
    for ((i = 1; i <= 1000; i++)); do
         echo " -I subdir/include" >>optionfile
    done

    remove_cache

    # with option
    $CCACHE $REAL_CCTC -f optionfile --core=tc1.6.2 --create=object subdir/src/test.c
    expect_stat preprocessed_cache_hit 0
    expect_stat direct_cache_hit 0
    expect_stat direct_cache_miss 1
    expect_stat cache_miss 1
    expect_stat files_in_cache 2

    return 0

}

SUITE_cctc_PROBE() {
    cctc_PROBE
}

SUITE_cctc_SETUP() {
    cctc_SETUP
}

SUITE_cctc() {
    cctc_tests
}
