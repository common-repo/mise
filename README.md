# mise

A [common-repo](https://github.com/common-repo/common-repo) upstream that
integrates [mise](https://mise.jdx.dev) with
[scripts-to-rule-them-all](https://github.com/common-repo/scripts-to-rule-them-all):
one dependency gives consumers consistent local and CI bootstrapping of
their dev tools.

`script/bootstrap` installs the tools declared in `mise.toml` (via a
drop-in into the scripts-to-rule-them-all harness), and an opt-in CI
fragment runs the official
[mise GitHub Action](https://github.com/jdx/mise-action) in the Test job.

## Distributed files

Applied to the consumer's root: `src/` first, then
[`common-repo/scripts-to-rule-them-all`](https://github.com/common-repo/scripts-to-rule-them-all)
v0.1.5 transitively.

| File | Source | Purpose |
|------|--------|---------|
| `script/.bootstrap/10-mise.sh` | `src/` | Bootstrap drop-in: fails with a pointer to the install docs when mise is missing, runs `mise install --locked` when `mise.lock` exists (else `mise install`), and puts `~/.local/share/mise/shims` on `PATH` for later drop-ins in the phase |
| `.common-repo/mise-action.yaml` | `src/` | Opt-in CI fragment adding the mise GitHub Action step to the Test job (see [below](#the-ci-fragment-opt-in)) |
| `script/bootstrap` … `script/console`, `script/.harness` | `scripts-to-rule-them-all` | The pluggable Scripts to Rule Them All harness and seven thin stubs the drop-in runs in |

## Usage

Requires [common-repo](https://github.com/common-repo/common-repo) ≥ 0.38.4,
the version this upstream is tested against (scripts-to-rule-them-all's
source API, inherited transitively, needs its additive `include:` and
`if-exists: preserve`).

Add to `.common-repo.yaml`:

```yaml
- repo:
    url: https://github.com/common-repo/mise
    ref: v0.1.0  # pin the latest tag
```

`scripts-to-rule-them-all` arrives transitively — one entry is enough.
Then `common-repo diff` to preview and `common-repo apply` to write.

## Behavior

**Local (`script/bootstrap`):** the drop-in checks for `mise` on `PATH`
and never auto-installs it. When mise is missing it fails the phase with a
pointer to https://mise.jdx.dev/getting-started.html. When mise is present
it runs `mise install --locked` if `mise.lock` exists at the repo root,
otherwise `mise install`, then adds `~/.local/share/mise/shims` to `PATH`
for the rest of the phase (exports are the sharing channel between
drop-ins), so later drop-ins resolve the installed tools.

**CI:** the fragment's `jdx/mise-action` step installs mise on the runner
and caches mise's installs via GitHub's cache (`install: true`,
`cache: true`). `script/bootstrap` still runs `mise install` wherever a
workflow invokes it — the action's install and the bootstrap drop-in are
complementary, not alternatives; the cache makes the latter fast.

## The CI fragment (opt-in)

`.common-repo/mise-action.yaml` is inert until merged. To add the mise
GitHub Action to the upstream-managed `ci.yaml` Test job, add to
`.common-repo.yaml`:

```yaml
- yaml:
    source: .common-repo/mise-action.yaml
    dest: .github/workflows/ci.yaml
    path: jobs.test.steps
    array_mode: merge_by_key
    position: start
```

`position: start` lands the step before `actions/checkout` today, so tools
still install via `script/bootstrap`, and the action's install/cache only
see `mise.toml` after checkout. Anchored placement is tracked at
https://github.com/common-repo/common-repo/issues/396.

## Locking tool versions

Run `mise lock` and commit the resulting `mise.lock` at the repo root.
The bootstrap drop-in detects it and runs `mise install --locked`, so
every machine (and CI) installs exactly the locked versions; without a
lockfile it resolves `mise.toml` afresh.

## Opting out

`with:` clauses on the repo entry scope an exclude to this upstream's own
files (note the nesting: `with:` sits inside `repo:`, and `exclude:` takes
a list):

```yaml
- repo:
    url: https://github.com/common-repo/mise
    ref: v0.1.0  # pin the latest tag
    with:
      - exclude: [".common-repo/mise-action.yaml"]
```

Don't want the CI step? The snippet above keeps the local integration and
drops only the fragment.

Not following the Scripts to Rule Them All pattern? A `with:`-scoped
`exclude: ["script/**"]` removes only this upstream's drop-in — the
harness and the seven stubs arrive transitively from
scripts-to-rule-them-all and survive it. To drop everything under
`script/`, use a top-level exclude after the repo entry:

```yaml
- repo:
    url: https://github.com/common-repo/mise
    ref: v0.1.0  # pin the latest tag
- exclude: ["script/**"]
```

## Developing this upstream

This repository runs its own harness, applied via the `self:` block in
`.common-repo.yaml`. `script/test` runs two drop-ins from `script/.test/`:

- `10-drop-in.sh` contract-tests the bootstrap drop-in without real mise:
  a stripped `PATH` exercises the missing-mise failure, and a stubbed
  `mise` that records its argv covers `--locked` vs plain install and the
  shims `PATH` export.
- `20-source-api.sh` needs `common-repo` on `PATH` and network access: it
  applies this checkout to scratch consumers, which clones
  scripts-to-rule-them-all from GitHub, and checks exactly what lands.

The drop-ins under the repo-root `script/` are local only — consumers
inherit `src/` and nothing else.

## License

[MIT](LICENSE)
