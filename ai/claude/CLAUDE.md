# Global Instructions

## Git
- Don't run `git commit` (including `--amend`) unless the repo's CLAUDE.md or CLAUDE.local.md says Claude may commit there. Otherwise stage files only when asked, then give the commit message as one paste-ready command and stop:
  ```bash
  git -C <abs repo path> commit -F - <<'EOF'
  feat: 🎸 add jira-cli to Brewfile

  Optional body
  EOF
  ```
- In a repo that allows committing, show the message and wait for approval before each commit.
- Stage with explicit paths (`git add <path>...`), never `git add -A`, `git add .`, or `git add -u`. This applies to staging commands suggested to the user too.
- No AI attribution in commits or PR descriptions: no `Co-authored-by` trailers, no "Generated with" lines, no `--author` flags referencing AI tools.
- Commit messages use Commitizen (git-cz) style: `<type>: <emoji> <subject>`. Types and emojis: `feat` 🎸, `fix` 🐛, `refactor` 💡, `docs` ✏️, `style` 💄, `test` 💍, `perf` ⚡️, `chore` 🤖, `ci` 🎡. Subject in lowercase imperative mood, no trailing period, no filler; at most a few lines of body.
- When the user says "pushed", follow the `update-pr` skill: check for an existing PR and offer to create or update it. Always ask first.

## Workflow
- Work one step at a time: agree on a step, make its changes, then stop and ask before starting the next.
- Use absolute paths in shell commands, staying inside the project directory. Prefer a tool's directory flag (`make -C <abs path>`, `go test -C <abs path>`, `git -C <abs path>`); when a tool has none, prefix with `cd <abs path> &&`.
- When the project has a wrapper (Makefile, scripts), build, lint, test, clean, and dependency steps go through it, not the underlying tool directly. If the wrapper can't do something, propose a fix to it rather than working around it.
- `cp`, `mv`, and `rm` are aliased to prompt first (`-i`). In shell commands an unanswered prompt skips the operation: a copy reports "not overwritten" and later steps run on an empty or stale file, and `rm` leaves the file in place. Use `command cp -f` / `command mv -f` / `command rm` or `cat src > dst`, check the result before writing over or deleting an original, and back up tracked files with `git show HEAD:<path>`. Scripts run as `bash script.sh` don't load the aliases.
- Never change anything outside the current repo without explicit permission. That includes `~/.claude` (memory, CLAUDE.md), other directories, and remote systems (deploys, pushes, APIs). The repo's Obsidian project folder (below) is the one standing exception.

## Project notes (Obsidian)
- Plans, prompts, notes, and proofs for a repo go in the Obsidian vault, not the repo. The vault is `$OBSIDIAN_VAULT` (default `~/obsidian/Second Brain`).
- The project folder and company for a repo come from the vault map imported in `~/.claude/CLAUDE.md`. When a repo has no entry, ask which folder to use and offer to add a row to the map.
- A note that isn't about the current repo (a call, a personal note) doesn't follow the map: ask which folder it belongs in. The machine or repo says nothing about whose note it is.
- Layout: `<project folder>/{plans,prompts,notes,proofs}/YYYY-MM-DD-<slug>.md`. Proofs are evidence: test output, screenshots, before/after captures.
- Every file starts with this frontmatter:
  ```yaml
  ---
  type: plan            # plan | prompt | note | proof
  project: <repo name>
  company: <company from the vault map, or personal>
  repo: <abs repo path>
  created: YYYY-MM-DD
  tags: [claude, plan]  # second tag matches type
  ---
  ```

## Scratch files
- Throwaway files (one-off downloads, probes, intermediate output): system `/tmp`.
- Verify checkouts and other working files that aren't project notes: `tmp/` at the project root. The global gitignore ignores it in every repo, so nothing needs adding to the repo's `.gitignore`.
- If unsure where something belongs, ask.

## PR tracking
- PRs are tracked per ticket in `~/.local/state/pr/` by `pr-state-record`. After opening a PR, or when one moves to another ticket or needs a better description, run `pr-state-record <url> [--ticket X] [--desc "..."]`. Never edit the state files by hand.
- For PR status, run `pr-status` (open PRs) or `pr-status --all` instead of querying `gh` per PR.

## Writing
- Write commit messages, code comments, and docs as concise, timeless facts about current behavior. Avoid "now", "used to be", "moved from X to Y", "no longer", and references to plans or future work: the reader has no context for what changed.
