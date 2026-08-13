# Contributing

## What this repository is

A teaching substrate for the tkxel DevOps intern rotation. That shapes every
contribution rule below: a change can be technically correct and pedagogically
wrong, and we care about both.

## Before you start

```bash
git clone https://github.com/adeelarshad414/devops-interns-proj && cd devops-interns-proj
cp .env.example .env
cp .githooks/pre-commit .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
make check          # static checks, no Docker needed
make up             # the stack
```

Install the pre-commit hook. It runs the same checks CI runs, in two seconds
instead of three minutes, and that ratio is the entire argument for shifting
left.

## The rules that are specific to this repository

### 1. Do not fix the deliberate defects

Several things are broken on purpose. They are listed in the README table and in
`SECURITY.md`. A pull request that "fixes" the N+1 in `dispatch` removes Day 4.

If you want to change a deliberate defect, update `docs/INSTRUCTOR.md` and the
relevant `docs/DAYn.md` in the same commit, and say why in the PR.

### 2. Verified (real) and verified (static) are different claims

`VERIFICATION.md` tracks which parts of this repository have actually been
executed and which have only been syntax-checked. **Do not blur them.** If your
change makes something executable, move the row and say what you ran.

Every PR asks what you actually ran. Answer honestly. "Should work" is a fine
thing to say; claiming otherwise is not.

### 3. Never a real credential

Placeholders are the literal string `CHANGE_ME_DEV_ONLY`, registered in
`DUMMY-VALUES.md` in the same commit. Never a plausible-looking fake — `hunter2`
gets committed to production, `CHANGE_ME_DEV_ONLY` does not.

### 4. Schema changes are additive only

New columns are nullable or defaulted. No `DROP`, no destructive `ALTER`. Rows
are temporal: mark state, do not delete history.

### 5. Comments explain why, not what

`// increment i` is noise. `// One NAT gateway, not one per AZ - deliberate cost
decision and a deliberate availability compromise` is the reason someone reads
the file. This repository is read far more often than it is run.

## Commits

Conventional commits, because it makes `git log --oneline` readable and lets
tooling decide what is a patch and what is a feature:

```
feat(orders):     a new capability
fix(dispatch):    a bug fix
docs(day4):       documentation only
refactor(shared): behaviour unchanged
test(orders):     tests only
chore(deps):      dependency bumps
security(vault):  fixes a vulnerability
```

Feature branches to pull request. No direct pushes to `main`.

```bash
git switch -c feat/add-order-cancellation
git add -p                    # stage hunk by hunk; read your own diff
git commit -m "feat(orders): add cancellation endpoint"
git push -u origin feat/add-order-cancellation
```

## Review

`CODEOWNERS` routes by path. Anything under `security/`, `vault/`,
`.github/workflows/` or `infra/` needs a security review specifically.

Two questions every reviewer should ask about this repository:

1. Is it correct?
2. Is it teachable?

The second one is easy to skip and is half the point.

## What gets rejected

- Removing a deliberate defect without updating the instructor notes
- Claiming verification that did not happen
- A real credential, in any form, including in a comment, including temporarily
- A destructive migration
- Code with no comment explaining a non-obvious decision
- Adding a tool without saying what question it answers that nothing else does
