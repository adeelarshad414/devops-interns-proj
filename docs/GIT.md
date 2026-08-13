# Git - Day 1, first ninety minutes

Git comes first because every other day depends on it, and because most fresh
graduates arrive able to `commit` and `push` and nothing else. That is enough
for coursework and not enough for a team.

## What they already know versus what they need

| Already fine | Actually needed |
|---|---|
| `clone`, `add`, `commit`, `push` | Branch strategy, and why |
| `pull` | `fetch` + `rebase` versus `merge`, and when |
| — | Reading and resolving a conflict without panic |
| — | `log`, `diff`, `blame` as **diagnostic** tools |
| — | `bisect` to find which commit broke it |
| — | `reflog` to undo something frightening |
| — | Why a commit message is written for a stranger |

The reframe worth making: **Git is an investigation tool, not just a save
button.** Half of incident diagnosis is "what changed, and when". `git log`
answers that faster than any dashboard.

## Lab 1 — the workflow (30 min)

```bash
git switch -c feat/add-order-cancellation
# make a change
git add -p                              # stage HUNK by hunk, not file by file
git commit -m "feat(orders): add cancellation endpoint"
git push -u origin feat/add-order-cancellation
# open a PR, get a review, merge
```

`git add -p` is the single highest-value command most people never learn. It
forces you to read your own diff before committing it, which catches more bugs
than any linter.

### Conventional commits

```
feat(orders):     a new capability
fix(dispatch):    a bug fix
refactor(kitchen): behaviour unchanged
docs(readme):     documentation only
chore(deps):      dependency bumps
test(orders):     tests only
```

Not bureaucracy. It makes `git log --oneline` readable, makes changelogs
generatable, and lets CI decide whether something is a patch or a feature.

## Lab 2 — conflict, on purpose (20 min)

Pair up. Both people edit the same lines of `services/orders/src/index.js` on
separate branches. Merge one, then merge the other.

Resolve it by hand. Then look at it a second way:

```bash
git log --merge -p services/orders/src/index.js   # both sides' history
git checkout --ours   / --theirs                  # when you know which wins
git merge --abort                                 # the escape hatch
```

The lesson is emotional as much as technical: a conflict is not a failure
state, it is Git telling you two humans changed the same thing and it will not
guess which one is right.

## Lab 3 — Git as a diagnostic tool (25 min)

This is the part that pays off on Day 4 and Friday.

```bash
git log --oneline --graph --decorate -20
git log -S "computeSurgeScore" --oneline      # when did this function appear?
git blame services/kitchen/src/index.js       # who wrote this line, and when?
git diff HEAD~5..HEAD -- services/            # what changed in the last 5?
```

Then `bisect`, which finds a bad commit in log₂(n) steps:

```bash
git bisect start
git bisect bad HEAD
git bisect good v0.1.0
# test, then: git bisect good | git bisect bad ... repeat
git bisect reset
```

Twenty commits, five tests, one culprit. Show them the maths; it is genuinely
impressive the first time.

## Lab 4 — undoing frightening things (15 min)

```bash
git reflog                       # everything you have done, including "lost" work
git reset --hard HEAD@{2}        # go back to a previous state
git revert <sha>                 # undo a commit that is already pushed
git restore --staged <file>      # unstage without losing changes
git stash / git stash pop        # park work, switch branch, come back
```

Say this explicitly: **almost nothing in Git is unrecoverable, and `reflog` is
why.** Interns are frightened of Git because they believe they can destroy
work. Removing that fear makes them experiment, and experimenting is how they
get good.

The genuine exceptions, worth naming: `git clean -fdx` on untracked files, and
a force-push over someone else's commits. Two things to be careful with, rather
than a whole tool to be afraid of.

## Hooks - shift-left before CI

```bash
cp .githooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Catches stray dummy credentials and syntax errors locally, in two seconds,
instead of in CI three minutes later. Same check, thirty times faster feedback.
Point at that ratio — it is the entire argument for shifting left.
