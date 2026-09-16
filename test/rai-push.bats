# Tests for rai-push, run end-to-end against the real script (real
# `rai-config`/`rai-provider-selfhosted`/`rai-common`), with `ssh` and `git
# push` stubbed.
#
# `ssh` is stubbed via stub_ssh_eval (see test_helper.bash) - a
# capture-then-eval trick that mimics what a real remote login shell does,
# so injection tests prove the shell_quote() fix holds rather than just
# eyeballing the built string.
#
# `git` is real for everything except the `push` subcommand, which we
# intercept and fake as an immediate success. Reasons: (a) `git push` over
# an ssh:// URL drives git's own ssh transport (running `ssh ... git-
# receive-pack ...`), which our stub_ssh_eval `ssh` doesn't speak - it would
# just fail the real network call, which is correct but tells us nothing
# about rai-push's own shell-quoting; (b) rai-push's *other* git calls
# (symbolic-ref, rev-parse --verify, update-ref) are exactly the
# `set -euo pipefail` guard behavior this file also tests, so those need to
# be real.

load test_helper

REAL_GIT="$(command -v git)"

setup() {
  setup_stub_dir
  export RAI_PROVIDER=selfhosted
  export RAI_STATIC_IP=127.0.0.1
  export RAI_USER=testuser
  # A writable stand-in for the default /home/$RAI_USER/workspaces, since
  # the stub_ssh_eval trick really does run the remote setup/checkout
  # commands against this path (it's the local machine standing in for the
  # remote one).
  export RAI_REMOTE_BASE="$STUB_DIR/remote_base"

  make_stub git "
if [ \"\$1\" = push ]; then
  printf '%s\n' \"\$@\" > \"$STUB_DIR/git_push_invocation\"
  exit 0
fi
exec \"$REAL_GIT\" \"\$@\"
"

  stub_ssh_eval
}

teardown() {
  teardown_stub_dir
}

# init_repo DIR [BRANCH] - create a real git repo at DIR with one commit,
# optionally checked out on BRANCH instead of the default branch.
init_repo() {
  local dir="$1"
  local branch="${2:-}"
  mkdir -p "$dir"
  (
    cd "$dir"
    "$REAL_GIT" init -q
    "$REAL_GIT" config user.email test@example.com
    "$REAL_GIT" config user.name test
    "$REAL_GIT" commit -q --allow-empty -m init
    if [ -n "$branch" ]; then
      "$REAL_GIT" checkout -q -b "$branch"
    fi
  )
}

@test "rai-push: detached HEAD fails with a clear error, not a crash" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo"
  ( cd "$repo" && "$REAL_GIT" checkout -q --detach )

  run env -C "$repo" "$REPO_ROOT/rai-push"
  [ "$status" -eq 1 ]
  [[ "$output" == *"detached HEAD"* ]]
  # Never got as far as trying to push.
  [ ! -e "$STUB_DIR/git_push_invocation" ]
}

@test "rai-push: injection-attempt repo dir name is not executed in the remote setup command" {
  pwn_sentinel="$STUB_DIR/pwned"
  # Reference the sentinel by an *exported env var name*, not its expanded
  # path: a directory name is a single path component and can't itself
  # contain a literal '/', so baking an absolute path directly into it
  # would make the local `mkdir -p` (setting up the source repo below)
  # create nested directories instead of the one maliciously-named leaf
  # directory we actually want to test. No quote characters either: unlike
  # the branch-name test below, this value is never wrapped in the
  # script's own quotes, so a bare `;` is already enough to prove the
  # point without a stray unmatched `'` accidentally self-cancelling
  # between this value's two uses (mkdir and git init both take it).
  export PWN_MARKER="$pwn_sentinel"
  malicious_name="foo; touch \$PWN_MARKER; echo done"
  repo="$BATS_TEST_TMPDIR/repos/$malicious_name"
  init_repo "$repo"
  # Detach HEAD so the script exits (cleanly) right after the remote-setup
  # ssh call we're testing, before it gets to `git push`.
  ( cd "$repo" && "$REAL_GIT" checkout -q --detach )

  run env -C "$repo" "$REPO_ROOT/rai-push"

  [ ! -e "$pwn_sentinel" ]
  # Delivered as one intact argument: a directory with the exact malicious
  # name (no injected side effects) exists under the remote base.
  [ -d "$RAI_REMOTE_BASE/$malicious_name" ]
}

@test "rai-push: injection-attempt branch name is not executed in the checkout command" {
  repo="$BATS_TEST_TMPDIR/repo"
  # No spaces: git ref names disallow spaces, so a realistic malicious
  # branch name relies on \$IFS as the word separator instead, exactly as a
  # real attacker would to smuggle a space-free payload past that
  # restriction.
  pwn_sentinel="$STUB_DIR/pwned"
  malicious_branch='foo'"'"';touch$IFS'"$pwn_sentinel"';echo'"'"
  init_repo "$repo" "$malicious_branch"

  run env -C "$repo" "$REPO_ROOT/rai-push"

  [ ! -e "$pwn_sentinel" ]
  # git's own error message echoes back the exact pathspec it received -
  # proof it arrived as one intact argument rather than extra shell syntax.
  [[ "$output" == *"pathspec '$malicious_branch'"* ]]
}

@test "rai-push: first push with no existing lease ref does not crash" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"

  # Note: this run's final `git -C ... checkout feature-branch` ssh call is
  # expected to fail on its own (our faked `git push` never actually moves
  # any commits into the fake "remote" repo the setup call created, so
  # there's no such branch there yet to check out) - that's a harness
  # limitation, not something under test here. What we're locking in is
  # that computing `expected_sha` from a lease ref that doesn't exist yet
  # (guarded by `|| true` in rai-push) doesn't blow up under `set -euo
  # pipefail`, and that `git push` gets invoked with a sensible value.
  run env -C "$repo" "$REPO_ROOT/rai-push"

  [[ "$output" != *"unbound variable"* ]]
  push_invocation="$(cat "$STUB_DIR/git_push_invocation")"
  # force-with-lease with an empty expected sha (no prior lease ref yet)
  [[ "$push_invocation" == *"--force-with-lease=feature-branch:"* ]]
}

@test "rai-push: remote-config is ensured even on an already-initialized remote repo" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"

  # Simulate a remote repo that was `git init`'d before the
  # denyCurrentBranch config existed (or by some other pre-fix rai-push):
  # .git is already there, so the creation `if` is false, but the config
  # is missing.
  remote_repo="$RAI_REMOTE_BASE/$(basename "$repo")"
  mkdir -p "$remote_repo"
  "$REAL_GIT" init -q "$remote_repo"
  run "$REAL_GIT" -C "$remote_repo" config --get receive.denyCurrentBranch
  [ "$status" -ne 0 ]

  # Same harness caveat as above re: the final checkout call failing.
  env -C "$repo" "$REPO_ROOT/rai-push" || true

  [ "$("$REAL_GIT" -C "$remote_repo" config --get receive.denyCurrentBranch)" = updateInstead ]
}

@test "rai-push: normal repo dir name and branch produce working ssh commands" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"

  # Same harness caveat as above re: the final checkout call failing.
  run env -C "$repo" "$REPO_ROOT/rai-push"

  invocation="$(cat "$STUB_DIR/ssh_invocation")"
  [[ "$invocation" == *"$(basename "$repo")"* ]]
  [[ "$invocation" == *"feature-branch"* ]]
}

# stub_ssh_checkout_result RESULT - like stub_ssh_eval (still `eval`s the
# remote-setup command for real, against RAI_REMOTE_BASE standing in for the
# remote), but intercepts specifically the final `git ... checkout ...`
# command and makes it exit with RESULT instead of actually running it. That
# isolates the thing the two tests below care about - rai-push's own
# lease-ordering control flow - from the harness limitation (noted above)
# that a real checkout against our fake "remote" can't succeed since the
# stubbed `git push` never actually lands the branch there.
stub_ssh_checkout_result() {
  local result="$1"
  make_stub ssh "
    { printf '%s\n' \"\$@\"; echo ---; } >> \"$STUB_DIR/ssh_invocation\"
    cmd=\"\${@: -1}\"
    case \"\$cmd\" in
      *checkout*)
        exit $result
        ;;
      *)
        eval \"\$cmd\"
        ;;
    esac
  "
}

@test "rai-push: lease ref is NOT updated when the remote checkout fails" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"
  stub_ssh_checkout_result 1

  run env -C "$repo" "$REPO_ROOT/rai-push"

  [ "$status" -ne 0 ]
  [[ "$output" == *"Remote checkout"* ]]
  run "$REAL_GIT" -C "$repo" rev-parse --verify -q refs/rai-remote/feature-branch
  [ "$status" -ne 0 ]
}

@test "rai-push: lease ref IS updated once the remote checkout succeeds" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"
  stub_ssh_checkout_result 0

  run env -C "$repo" "$REPO_ROOT/rai-push"

  [ "$status" -eq 0 ]
  branch_sha="$("$REAL_GIT" -C "$repo" rev-parse feature-branch)"
  lease_sha="$("$REAL_GIT" -C "$repo" rev-parse refs/rai-remote/feature-branch)"
  [ "$branch_sha" = "$lease_sha" ]
}

@test "rai-push: remote checkout is quiet and succeeds when already on the target branch" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"

  # Pre-create the "remote" repo already checked out on feature-branch -
  # the common case rai-push hits on every push once the VM is in sync,
  # which used to print git's own "Already on 'feature-branch'" noise.
  remote_repo="$RAI_REMOTE_BASE/$(basename "$repo")"
  mkdir -p "$remote_repo"
  "$REAL_GIT" init -q "$remote_repo"
  "$REAL_GIT" -C "$remote_repo" config user.email test@example.com
  "$REAL_GIT" -C "$remote_repo" config user.name test
  "$REAL_GIT" -C "$remote_repo" checkout -q -b feature-branch
  "$REAL_GIT" -C "$remote_repo" commit -q --allow-empty -m init

  run env -C "$repo" "$REPO_ROOT/rai-push"

  [ "$status" -eq 0 ]
  [[ "$output" != *"Already on"* ]]
  invocation="$(cat "$STUB_DIR/ssh_invocation")"
  [[ "$invocation" == *"checkout -q"* ]]
}

@test "rai-push: clean working tree pushes without any uncommitted-changes warning" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"

  # Same harness caveat as earlier tests re: the final checkout call failing.
  run env -C "$repo" "$REPO_ROOT/rai-push"

  [[ "$output" != *"Warning"* ]]
  [ -e "$STUB_DIR/git_push_invocation" ]
}

@test "rai-push: untracked-only changes do not trigger the uncommitted-changes warning" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"
  echo "scratch" > "$repo/untracked.txt"

  run env -C "$repo" "$REPO_ROOT/rai-push"

  [[ "$output" != *"Warning"* ]]
  [ -e "$STUB_DIR/git_push_invocation" ]
}

@test "rai-push: uncommitted tracked changes warn but don't hang, and still push non-interactively" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"
  ( cd "$repo" && echo v1 > f.txt && "$REAL_GIT" add f.txt && "$REAL_GIT" commit -q -m "add f" )
  echo v2 > "$repo/f.txt"   # unstaged modification to an already-tracked file

  # `run` gives the command no tty, exercising exactly the non-interactive
  # path - if this hung, the test would time out instead of completing.
  run env -C "$repo" "$REPO_ROOT/rai-push"

  [[ "$output" == *"Warning: you have uncommitted changes"* ]]
  [[ "$output" == *"Non-interactive session"* ]]
  # Warned but still proceeded - push machinery still ran.
  [ -e "$STUB_DIR/git_push_invocation" ]
}

@test "rai-push: staged uncommitted changes also trigger the warning" {
  repo="$BATS_TEST_TMPDIR/repo"
  init_repo "$repo" "feature-branch"
  ( cd "$repo" && echo v1 > new.txt && "$REAL_GIT" add new.txt )

  run env -C "$repo" "$REPO_ROOT/rai-push"

  [[ "$output" == *"Warning: you have uncommitted changes"* ]]
  [ -e "$STUB_DIR/git_push_invocation" ]
}
