# Test playbook
The `test_playbook.yml` includes the `mkfd` role multiple times but uses
different parameters to build many configuration bundles.

## Basic operation
A pair of helper scripts in the `tasks` directory assist:
  * `rm_dirs`: Removes directories as a cleanup step when tests are
    executed locally.
  * `count_files`: After each run, the number of output files are
    counted to ensure the right number of files were generated. It
    counts the config files, documentation files, checksum files,
    and the number of lines in each checksum file.

## Auxiliary files
This playbook uses a custom inventory which has variables embedded
directly in it for brevity. It also uses a custom configuration file
because, in the future, the actual role may configure network devices,
but the tests will always execute on the control machine.

## Test cases
There are currently 7 test cases which cover the different
capabilities of the role.
  * `Test 1: Run empty mkfd to build dirs, no outputs`
  * `Test 2: Run mkfd with dummy template, no archive`
  * `Test 3: Run mkfd with 2 dummy templates, no archive`
  * `Test 4: Run mkfd with 2 dummy templates, with archive`
  * `Test 5: Run mkfd with 2 dummy templates, with doc`
  * `Test 6: Run mkfd with 2 dummy templates, with doc/arch`
  * `Test 7: Run mkfd with 2 dummy templates, no checksum`
