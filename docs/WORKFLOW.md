# Issue-driven workflow

GitHub issues are the durable memory for this long-running project. Each branch addresses one issue and carries no unrelated cleanup.

## Start an issue

1. Read the full issue from GitHub, including dependencies and recent comments.
2. Confirm dependencies are merged into `main`.
3. Update local `main` with a fast-forward-only pull.
4. Create `issue-X`, where X is the issue number.
5. Restate any uncertain product or rule decision in the issue and ask the owner before choosing an irreversible direction.

## Finish an issue

1. Run the issue-specific tests plus `swift test` and the README build command.
2. Review the diff for unrelated or generated files.
3. Commit and push `issue-X`.
4. Open a focused pull request with `Closes #X`.
5. Record decisions, limitations, and exact verification results in the pull request.
6. Begin another issue only from the updated `main` after the prior dependency is merged.

## Context reset checklist

- What outcome and acceptance criteria does the current issue require?
- Which dependency PRs changed the relevant contracts?
- What decisions have already been recorded?
- What is the smallest next change that advances only this issue?
- Which command will prove the change works?
