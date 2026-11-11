# mise

mise integration for common-repo consumers.

- `src/` is the distributed payload: `.common-repo.yaml` renames `src/script/.bootstrap/10-mise.sh` and `src/.common-repo/mise-action.yaml` into consumer roots; the drop-in contract (one function named after the stem, no `exit`, harness stdlib, exports propagate within a phase) lives in the scripts-to-rule-them-all README; do not place agent indexes under `src/`.
- `script/.test/` is local-only contract testing and is never distributed; `20-source-api.sh` needs `common-repo` on PATH and network access (the chain clones scripts-to-rule-them-all from GitHub).
- Root `script/` (harness, stubs, drop-in) and `.github/`, `.pre-commit-config.yaml`, `cog.toml` are applied from `upstream` v2.4.2 and `scripts-to-rule-them-all` v0.1.5 via the `self:` block in `.common-repo.yaml`.

## Maintaining this index

- Update the affected `AGENTS.md` files in the same change when paths, responsibilities, commands, dependencies, or conventions change.
- Keep indexes brief: record semantic entry points and non-obvious constraints; link to existing documentation instead of duplicating it.
- Add a directory index only when it provides useful navigation beyond its parent; omit generated, vendored, and fixture trees.
- Do not add `CLAUDE.md` files; Claude Code reads `AGENTS.md` natively, and a `CLAUDE.md` anywhere in the tree stops every `AGENTS.md` from loading.
