#!/usr/bin/env bats

# Bats is a testing framework for Bash
# Documentation https://bats-core.readthedocs.io/en/stable/
# Bats libraries documentation https://github.com/ztombol/bats-docs

# For local tests, install bats-core, bats-assert, bats-file, bats-support
# And run this in the add-on root directory:
#   bats ./tests/test.bats
# To exclude release tests:
#   bats ./tests/test.bats --filter-tags '!release'
# For debugging:
#   bats ./tests/test.bats --show-output-of-passing-tests --verbose-run --print-output-on-failure

setup() {
  set -eu -o pipefail

  # Override this variable for your add-on:
  export GITHUB_REPO=lemachinarbo/ddev-compwser

  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"
  mkdir -p ~/tmp
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
}

health_checks() {
  # Do something useful here that verifies the add-on

  # You can check for specific information in headers:
  # run curl -sfI https://${PROJNAME}.ddev.site
  # assert_output --partial "HTTP/2 200"
  # assert_output --partial "test_header"

  # Or check if some command gives expected output:
  DDEV_DEBUG=true run ddev launch
  assert_success
  assert_output --partial "FULLURL https://test-ddev-compwser.ddev.site"
}

teardown() {
  set -eu -o pipefail
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  # Persist TESTDIR if running inside GitHub Actions. Useful for uploading test result artifacts
  # See example at https://github.com/ddev/github-action-add-on-test#preserving-artifacts
  if [ -n "${GITHUB_ENV:-}" ]; then
    [ -e "${GITHUB_ENV:-}" ] && echo "TESTDIR=${HOME}/tmp/${PROJNAME}" >> "${GITHUB_ENV}"
  else
    # [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
    echo "removing... ${TESTDIR}"
  fi
}

# The following tests are commented out for step-by-step debugging.
# Uncomment one at a time to debug each test individually.


@test "install from directory" {
  set -eu -o pipefail
  echo "# ddev add-on get ${DIR} with project ${PROJNAME} in $(pwd)" >&3
  run ddev add-on get "${DIR}"
  assert_success
  run ddev restart -y
  assert_success
  health_checks
}


# @test "install from release" {
#   set -eu -o pipefail
#   echo "# ddev add-on get ${GITHUB_REPO} with project ${PROJNAME} in $(pwd)" >&3
#   run ddev add-on get "${GITHUB_REPO}"
#   assert_success
#   run ddev restart -y
#   assert_success
#   health_checks
# }

@test "dewire command is available" {
  run ddev dewire --help
  assert_success
  assert_output --partial "dewire"
}

@test "dw-install command runs" {
  run ddev dw-install --help
  assert_success
  assert_output --partial "dw-install"
}

@test "dw-deploy command runs" {
  run ddev dw-deploy --help
  assert_success
  assert_output --partial "dw-deploy"
}

@test "dw-config-split command runs" {
  run ddev dw-config-split --help
  assert_success
  assert_output --partial "dw-config-split"
}

@test "dw-gh-env command runs" {
  run ddev dw-gh-env --help
  assert_success
  assert_output --partial "dw-gh-env"
}

@test "dw-gh-workflow command runs" {
  run ddev dw-gh-workflow --help
  assert_success
  assert_output --partial "dw-gh-workflow"
}

@test "dw-sshkeys-gen command runs" {
  run ddev dw-sshkeys-gen --help
  assert_success
  assert_output --partial "dw-sshkeys-gen"
}

@test "dw-sshkeys-install command runs" {
  run ddev dw-sshkeys-install --help
  assert_success
  assert_output --partial "dw-sshkeys-install"
}

@test "dw-sync command runs" {
  run ddev dw-sync --help
  assert_success
  assert_output --partial "dw-sync"
}

@test "rs command runs" {
  run ddev rs --help
  assert_success
  assert_output --partial "rs"
}
