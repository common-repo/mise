# Regression test for the source API in .common-repo.yaml: applies this
# checkout as a local-path upstream into throwaway consumers and checks
# what lands — the mise payload plus, transitively, the
# scripts-to-rule-them-all harness and stubs (cloned from GitHub, so
# network is required). `common-repo validate` and `diff` only exercise
# the self: block, so nothing else covers this. Not distributed:
# consumers inherit src/ only.
20-source-api() {
  command -v common-repo >/dev/null 2>&1 || return $(fail "common-repo is not installed")

  local tmp failures=0 stub before
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/mise-source-api.XXXXXX")"

  # consumer <name> — new repo consuming this checkout
  consumer() {
    C="$tmp/$1"
    mkdir -p "$C"
    git -C "$C" init -q
    printf -- '- repo:\n    url: %s\n    ref: main\n' "$REPO_ROOT" >"$C/.common-repo.yaml"
  }
  apply() {
    (cd "$C" && common-repo --quiet apply) || { not_ok "common-repo apply failed in ${C##*/}"; return 0; }
  }
  not_ok() {
    failures=$((failures + 1))
    error "not ok: $*"
  }
  # Everything this upstream should write, and nothing else.
  check_layout() {
    for stub in .harness bootstrap setup update test cibuild server console; do
      [ -x "$C/script/$stub" ] || not_ok "${C##*/}: script/$stub missing or not executable"
    done
    [ -f "$C/script/.bootstrap/10-mise.sh" ] || not_ok "${C##*/}: script/.bootstrap/10-mise.sh missing"
    [ -f "$C/.common-repo/mise-action.yaml" ] || not_ok "${C##*/}: .common-repo/mise-action.yaml missing"
    [ ! -e "$C/src" ] || not_ok "${C##*/}: src/ leaked into the consumer"
    local extra
    extra="$(cd "$C" && find . -path ./.git -prune -o -type f -print | sort |
      grep -v -x -e ./.common-repo.yaml -e './script/[a-z]*' -e ./script/.harness \
        -e ./script/.bootstrap/10-mise.sh -e ./.common-repo/mise-action.yaml || true)"
    [ -z "$extra" ] || not_ok "${C##*/}: unexpected files: ${extra//$'\n'/ }"
  }
  # Content digest of everything but .git — re-apply must not change it.
  digest() {
    (cd "$C" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort |
      while IFS= read -r f; do shasum "$f"; done | shasum)
  }

  # A fresh consumer gets the payload and the transitive harness/stubs.
  consumer fresh
  apply
  check_layout
  cmp -s "$C/script/.bootstrap/10-mise.sh" "$REPO_ROOT/src/script/.bootstrap/10-mise.sh" ||
    not_ok "fresh: script/.bootstrap/10-mise.sh is not the payload"
  cmp -s "$C/.common-repo/mise-action.yaml" "$REPO_ROOT/src/.common-repo/mise-action.yaml" ||
    not_ok "fresh: .common-repo/mise-action.yaml is not the payload"

  # A consumer's own scripts survive (scripts-to-rule-them-all preserves
  # stubs), and applying again changes nothing.
  consumer bespoke
  mkdir -p "$C/script"
  printf '#!/bin/sh\necho bespoke\n' >"$C/script/test"
  chmod +x "$C/script/test"
  apply
  check_layout
  [ "$("$C/script/test" 2>&1)" = bespoke ] || not_ok "bespoke: script/test was not preserved"
  before="$(digest)"
  apply
  check_layout
  [ "$(digest)" = "$before" ] || not_ok "bespoke: re-apply changed files"
  [ "$("$C/script/test" 2>&1)" = bespoke ] || not_ok "bespoke: script/test was not preserved on re-apply"

  rm -rf "$tmp"
  [ "$failures" -eq 0 ] || return $(fail "$failures source API check(s) failed")
}
