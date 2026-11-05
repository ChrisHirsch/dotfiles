# Global Instructions

## Git
- Never run `git commit` (including `--amend`). Stage files only when asked, then propose a commit message and stop. The user commits.
- Never add or suggest `Co-authored-by` trailers or `--author` flags referencing AI tools.
- Commit messages: concise, factual, imperative mood, no trailing period, no filler.
- When the user says "pushed", follow the `update-pr` skill: check for an existing PR and offer to create or update it. Always ask first.

## Workflow
- Ask before making changes, and before moving on to the next step. One step at a time.
- Use fully qualified absolute paths in shell commands, staying inside the project directory (for example `make -C <abs path>`, `go test -C <abs path>`, `git -C <abs path>`). Avoid `cd` and relative paths.
- Prefer the project's Makefile targets (`make lint`, `make test`, `make {service}_lint`) over raw `go` / `golangci-lint` commands.

## PR tracking
- PRs are tracked per ticket in `~/.local/state/pr/` by `pr-state-record`. A hook records PRs from `gh pr create`. For a PR opened another way, or one that moves to another ticket or needs a better description, run `pr-state-record <url> [--ticket X] [--desc "..."]`. Never edit the state files by hand.
- For PR status, run `pr-status` (open PRs) or `pr-status --all` instead of querying `gh` per PR.
- Machine-specific notes, when present: @~/.claude/private.md

## Writing
- Write code comments and docs as timeless facts about current behavior. Avoid "now", "used to be", "moved from X to Y", "no longer": the reader has no context for what changed.
