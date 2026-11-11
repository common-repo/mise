# Contract tests for the bootstrap drop-in (src/script/.bootstrap/10-mise.sh)
# that need no real mise: syntax and single-definition checks, the
# missing-mise failure path under a stripped PATH, and a stubbed mise that
# records its argv to cover --locked vs plain install, the shims PATH
# export, and the MISE_DATA_DIR shims override. Not distributed: consumers
# inherit src/ only.
10-drop-in() {
  local tmp failures=0 out rc src S R
  src="$REPO_ROOT/src/script/.bootstrap/10-mise.sh"
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/mise-drop-in.XXXXXX")"

  not_ok() {
    failures=$((failures + 1))
    error "not ok: $*"
  }
  # fixture <case> — the applied script/ tree (harness, stubs, drop-in)
  # minus this repo's test machinery; the drop-in always comes from src/.
  fixture() {
    R="$tmp/$1"
    mkdir -p "$R"
    cp -R "$REPO_ROOT/script" "$R/script"
    rm -rf "$R/script/.test"
    mkdir -p "$R/script/.bootstrap"
    cp "$src" "$R/script/.bootstrap/10-mise.sh"
    S="$R/script"
  }
  # stub_mise — a mise executable first on PATH that records its argv and
  # answers `data-dir` the way real mise does (MISE_DATA_DIR, else default)
  stub_mise() {
    mkdir -p "$tmp/bin"
    cat >"$tmp/bin/mise" <<STUB
#!/bin/sh
printf '%s\n' "\$*" >>'$tmp/argv'
if [ "\$1" = data-dir ]; then
  echo "\${MISE_DATA_DIR:-\$HOME/.local/share/mise}"
fi
STUB
    chmod +x "$tmp/bin/mise"
    : >"$tmp/argv"
  }
  # run <path> — bootstrap the fixture with the given PATH (and $run_env
  # as extra env assignments for the data-dir override case)
  run() {
    rc=0
    out="$(env -u DEBUG ${run_env:-} PATH="$1" "$S/bootstrap" 2>&1)" || rc=$?
  }
  check() {
    local name="$1" want_rc="$2"
    shift 2
    local ok=1 arg
    [ "$rc" -eq "$want_rc" ] || ok=0
    for arg in "$@"; do
      case "$arg" in
        !*) case "$out" in *"${arg#!}"*) ok=0 ;; esac ;;
        *)  case "$out" in *"$arg"*) ;; *) ok=0 ;; esac ;;
      esac
    done
    if [ "$ok" -eq 1 ]; then
      debug "ok: $name"
    else
      failures=$((failures + 1))
      error "not ok: $name (exit $rc, wanted $want_rc)"
      printf '%s\n' "$out" | sed 's/^/    | /' >&2
    fi
  }

  # -- syntax and single definition ----------------------------------------
  bash -n "$src" || not_ok "drop-in has a syntax error"
  [ "$(grep -c '^10-mise()' "$src")" -eq 1 ] ||
    not_ok "drop-in must define 10-mise() exactly once"
  (. "$src"; [ "$(type -t 10-mise)" = "function" ]) ||
    not_ok "sourcing the drop-in does not define 10-mise()"

  # -- mise missing: friendly message, hard failure, nothing installed ------
  fixture missing
  if env PATH="/usr/bin:/bin" sh -c 'command -v mise' >/dev/null 2>&1; then
    not_ok "precondition: mise visible on the stripped PATH (/usr/bin:/bin); cannot test the missing-mise path"
  else
    run "/usr/bin:/bin"
    check "missing mise fails bootstrap pointing at the install docs" 1 \
      "https://mise.jdx.dev/getting-started.html" \
      "FAIL: mise not found on PATH" "FAIL   10-mise"
  fi

  # -- mise present, no mise.lock: plain install, shims exported ------------
  fixture unlocked
  stub_mise
  mkdir -p "$S/.bootstrap"
  # A later drop-in in the same phase must see the shims directory on PATH
  # (exports are the sharing channel).
  printf '20-shims() {\n  case ":$PATH:" in\n    *":$HOME/.local/share/mise/shims:"*) info "shims on PATH" ;;\n    *) return $(fail "shims directory not on PATH") ;;\n  esac\n}\n' \
    >"$S/.bootstrap/20-shims.sh"
  run "$tmp/bin:/usr/bin:/bin"
  check "without mise.lock: mise install, then shims on PATH" 0 \
    "shims on PATH" "pass   20-shims"
  [ "$(head -n 1 "$tmp/argv")" = "install" ] ||
    not_ok "unlocked: mise argv was '$(head -n 1 "$tmp/argv")', wanted 'install'"

  # -- MISE_DATA_DIR set: shims come from the configured data dir ----------
  fixture custom-data-dir
  stub_mise
  mkdir -p "$S/.bootstrap"
  # A later drop-in must resolve tools through the CUSTOM data dir, not
  # mise's default (Devin: hard-coded default shim path ignores MISE_DATA_DIR).
  printf '20-shims() {\n  case ":$PATH:" in\n    *":%s/shims:"*) info "custom shims on PATH" ;;\n    *) return $(fail "custom data dir shims not on PATH") ;;\n  esac\n}\n' \
    "$R/custom-data" >"$S/.bootstrap/20-shims.sh"
  run_env="MISE_DATA_DIR=$R/custom-data"
  run "$tmp/bin:/usr/bin:/bin"
  run_env=""
  check "with MISE_DATA_DIR: shims from the configured data dir" 0 \
    "custom shims on PATH" "pass   20-shims"

  # -- mise present, mise.lock: locked install ------------------------------
  fixture locked
  stub_mise
  : >"$R/mise.lock"
  run "$tmp/bin:/usr/bin:/bin"
  check "with mise.lock: mise install --locked" 0 "pass   10-mise"
  [ "$(head -n 1 "$tmp/argv")" = "install --locked" ] ||
    not_ok "locked: mise argv was '$(head -n 1 "$tmp/argv")', wanted 'install --locked'"

  rm -rf "$tmp"
  [ "$failures" -eq 0 ] || return $(fail "$failures drop-in check(s) failed")
}
