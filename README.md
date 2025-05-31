# Artifact for "Failing with Purpose: Coverage-Guided Negative Test Generation from a Mechanized P4 Type System"

## Organization

In this README, we explain how to:

1. Setup the environment with Docker
2. Build SpecTec
3. Reproduce the running example with a minified P4 type system
4. Reproduce RQ1-3

## 1. Getting Started with Docker

We provide two ways to build our artifact: building from a pre-built image on DockerHub or from a dockerfile.
You can install Docker by following the official instructions at [Docker Installation](https://docs.docker.com/get-started/) and download the container images using the following commands.

We provide two images, `p4spectec` and `p4spectec_with_p4c`.

`p4spectec_with_p4c` is the full version, including the P4C compiler build files.
However do take caution, as due to the large build size of the P4C compiler, especially with debugging and coverage profiling enabled, it can take very long to download and use.

Therefore we also provide `p4spectec`, which contains everything **except for the p4c compiler** with a much smaller image size.
`p4spectec` is enough to reproduce the running example and RQ1-2.

#### A. From DockerHub 

We provide Docker images that contains all the necessary dependencies to run the experiments.

```bash
# without p4c
$ docker pull p4spectec/p4spectec
$ docker run --name artifact -it --rm p4spectec/p4spectec

# with p4c, for RQ3-b branch coverage measurement
$ docker pull p4spectec/p4spectec_with_p4c
$ docker run --name artifact -it --rm p4spectec/p4spectec_with_p4c
```

#### B. From dockerfile

Or, you may build an image from the dockerfiles on this repo.

First, fetch P4C version v1.2.5.6:
```bash
$ git submodule init
$ git submodule update
```

Then build the Docker image:
```bash
# without p4c
$ docker build -f p4spectec.dockerfile -t p4spectec:latest .

# with p4c, for RQ3-b branch coverage measurement
$ docker build -f p4spectec_p4c.dockerfile -t p4spectec_with_p4c:latest .
```

## 2. Building SpecTec

To build SpecTec, at the project root, run:
```bash
$ make build-spec
```
This creates a binary `p4spectec` at the project root.

## 3. Mini-Spec: a subset of the P4 specification

We provide a mini-spec in `spec-mini` directory for the running example `spec-mini/shift-well.p4` in the paper.
Note that this is a very restricted subset of the full P4 language, just enough to demonstrate the running example.
The P4 syntax is defined in `spec-mini/1a-syntax-el.watsup`, the IR syntax is defined in `spec-mini/3-syntax-il.watsup`, and the shift expression typing rule is in `spec-mini/4e-typing-expr.watsup`.

To structure the mini-spec, we use the following command:

```bash
$ ./p4spectec struct spec-mini/*.watsup
```

This prints the structured mini-spec to stdout. Check that the output contains:

```
2. Case (% is in [(SHL), (SHR)])
  1. (Expr_ok: C |- expr_l : exprIL_l)
  2. (Expr_ok: C |- expr_r : exprIL_r)
  3. (Let (( typ_l )) be $typeof(exprIL_l))
  4. (Let (( typ_r )) be $typeof(exprIL_r))
  5. If ($compatible_shift(typ_l, typ_r)), then
    1. If ((($is_intt(typ_r) \/ $is_fintt(typ_r)) => $is_ctk_non_neg(C, exprIL_r))), then
      1. Result in (BinE binop exprIL_l exprIL_r (( typ_l )))
    1. Else Phantom#42
  5. Else Phantom#43
```

Here, `Phantom#42` denotes a dangling premise with ID 42.
To run the executable type system against the running example,
```bash
$ ./p4spectec run-sl spec-mini/*.watsup -p spec-mini/shift-well.p4 -mini
```
This will print the result, `well-typed` to stdout.

To run the fuzzer, first create a directory to store the generated tests and run the fuzzing command:
```bash
$ mkdir running-example
$ ./p4spectec testgen spec-mini/*.watsup -fuel 10 -gen running-example -silent -cold spec-mini -mini
```
After the fuzzer runs, check the `running-example/fuzz-[timestamp]/illtyped` directory for the generated ill-typed programs.
Check whether it contains a program covering dangling premise 42, for example:
```p4
header Hdr {
  int<32> src;

}
bit<32> f(in bit<32> x, in Hdr hdr) {
  return ((x) << (hdr.src));
}
```

## 4. Reproducing RQ1-3 

### Experiment Setup

The full P4 type system mechanization is provided in the `spec` directory.
The complete list of excluded tests in the P4C test suite is provided in `excludes` directory.

* `exclude-bug`: Limitation of the mechanized type system
* `exclude-future`: Features not yet standardized
* `exclude-target-specific`: Compile target-specific features
* `exclude-p4c-discussion`, `exclude-spec-discussion`: Under discussion with the language design working group or P4C developers

### RQ1: Coverage of Generated Tests

Run the following command to generate tests and measure coverage.
Note that the full fuzz loop may take 12-18 hours, depending on the machine.

```bash
$ python3 scripts/fuzz.py --loops 5 --timeout 86400 --mode hybrid --reduce [rq1_dir]
```

Where `[rq1_dir]` should be replaced with the directory where you want to store the generated tests.
Note that we give an arbitrarily large timeout to complete 5 loops of reducing/fuzzing.
Then, you can run the following scripts to generate summaries:
```bash
# collect coverage in 5-minute intervals
$ python3 scripts/rq0_cov.py [dir] > coverage.csv
# number of total generated programs per mutation in the fuzzing process
$ python3 scripts/rq1_mut.py [dir] > mutation.csv
# elapsed time and number of reduced/generated programs for each phase
$ python3 scripts/rq1_phase.py [dir] > phase.csv
```
Where `[dir]` should be replaced with the root directory of the fuzz results.

### RQ2: Effectiveness of VDG and Reducer

In this section, we run the fuzzing campaign with six different configurations (C1 to C6) to compare the effectiveness of the VDG (Value Dependency Graph) and reducer in generating illtyped programs.
Run the following commands for each of C1 to C6.

```bash
# C1, C2, C3: With Reducer, Derive / Random / Hybrid
$ python3 scripts/fuzz.py --loops 20 --timeout 43200 --mode derive --reduce [c1_dir]
$ python3 scripts/fuzz.py --loops 20 --timeout 43200 --mode random --reduce [c2_dir] 
$ python3 scripts/fuzz.py --loops 20 --timeout 43200 --mode hybrid --reduce [c3_dir]
# C4, C5, C6: Without Reducer, Derive / Random / Hybrid
$ python3 scripts/fuzz.py --loops 20 --timeout 43200 --mode derive [c4_dir]
$ python3 scripts/fuzz.py --loops 20 --timeout 43200 --mode random [c5_dir]
$ python3 scripts/fuzz.py --loops 20 --timeout 43200 --mode hybrid [c6_dir]
```

Where each `[dir]` should be replaced with the directory where you want to store the generated tests. Note that we give an arbitrarily large number of loops to run the reducer/fuzzer until a timeout of 12 hours.Add commentMore actions
After timeout, the fuzzing stops and cleanup is performed which typically takes 4~5 more hours for final reduction of generated programs and coverage measurement. The file `total.coverage` in the root directory of each configuration shows the resultant coverage.
You can generate a more detailed coverage report per function/relation via the following script:
```bash
$ python3 scripts/summarize.py [dir]/total.coverage > summary.out
```
We also provide a script to compare the coverage of two different configurations.
```bash
$ python3 scripts/compare.py [dir1]/total.coverage [dir2]/total.coverage > compare.out
```

### RQ3: Adequacy of the Coverage Metric

In this section, we compare the effectiveness and sensitivity of the P4C compiler branch coverage and our proposed dangling coverage. We compare dangling coverage and branch coverage for six sets of P4 programs: F_pos, F_neg, F_all, P_pos, P_neg, and P_all where F and P denote our fuzzer and the P4C test suite respectively.
First, we measure dangling coverage for the 6 program sets.
```bash
$ ./p4spectec cover-sl spec/*.watsup -i p4c/p4include -cov fuzzer_all.coverage -ignore coverage/relation.ignore -ignore coverage/function.ignore -e excludes -d [rq1_dir]/*/welltyped -d [rq1_dir]/reduced -d p4c/testdata/p4_16_samples
$ ./p4spectec cover-sl spec/*.watsup -i p4c/p4include -cov fuzzer_neg.coverage -ignore coverage/relation.ignore -ignore coverage/function.ignore -e excludes -d [rq1_dir]/*/illtyped
$ ./p4spectec cover-sl spec/*.watsup -i p4c/p4include -cov fuzzer_all.coverage -ignore coverage/relation.ignore -ignore coverage/function.ignore -e excludes -d [rq1_dir]/*/illtyped -d [rq1_dir]/*/welltyped -d [rq1_dir]/reduced -d p4c/testdata/p4_16_samples
$ ./p4spectec cover-sl spec/*.watsup -i p4c/p4include -cov p4c_pos.coverage -ignore coverage/relation.ignore -ignore coverage/function.ignore -e excludes -d p4c/testdata/p4_16_samples
$ ./p4spectec cover-sl spec/*.watsup -i p4c/p4include -cov p4c_neg.coverage -ignore coverage/relation.ignore -ignore coverage/function.ignore -e excludes -d p4c/testdata/p4_16_errors
$ ./p4spectec cover-sl spec/*.watsup -i p4c/p4include -cov p4c_all.coverage -ignore coverage/relation.ignore -ignore coverage/function.ignore -e excludes -d p4c/testdata/p4_16_samples -d p4c/testdata/p4_16_errors
```
Where `[rq1_dir]` should be replaced with the directory where you stored the generated tests in RQ1. Coverage is written to the filenames supplied by `-cov` .

Next, we measure the P4C compiler branch coverage for the 6 program sets.
Run the following commands to measure branch coverage of each set of programs.
```bash
# Positive branch coverage of our fuzzer
$ ./run_coverage.sh -o [fuzzer_pos_dir] [rq1_dir]/*/welltyped [rq1_dir]/reduced p4c/testdata/p4_16_samples
# Negative branch coverage of our fuzzer
$ ./run_coverage.sh -o [fuzzer_neg_dir] [rq1_dir]/*/illtyped
# Total branch coverage of our fuzzer
$ ./run_coverage.sh -o [fuzzer_all_dir] [rq1_dir]/*/illtyped [rq1_dir]/*/welltyped [rq1_dir]/reduced p4c/testdata/p4_16_samples
# Positive branch coverage of the P4C test suite
$ ./run_coverage.sh -o [p4c_pos_dir] p4c/testdata/p4_16_samples
# Negative branch coverage of the P4C test suite
$ ./run_coverage.sh -o [p4c_neq_dir] p4c/testdata/p4_16_errors
# Total branch coverage of the P4C test suite
$ ./run_coverage.sh -o [p4c_all_dir] p4c/testdata/p4_16_samples p4c/testdata/p4_16_errors
```
Where `[rq1_dir]` should be replaced with the directory where you stored the generated tests in RQ1, and each `[output_dir]` should be replaced with the directories in which you want to store the coverage results. Coverage reports are generated in `[output_dir]/coverage_report.gcovr` , and at the very bottom are the number of total branches, versus the number of covered branches.
Note that gcovr may print out errors about missing data files / unresolved working directories for `CMakeCXXCompilerId.cpp`, `CMakeCCompilerId.c` and `lexer.yy.c`. They are boilerplate code generated by `cmake` and `flex`, and thus these errors can be safely ignored.
