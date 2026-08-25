# Repository working agreement

- Work on exactly one GitHub issue at a time.
- Before editing, run `gh issue view X` and re-read the full issue plus its dependency PRs.
- Start from the latest `main` and use a fresh branch named `issue-X`, where X is the GitHub issue number.
- Keep rules and state transitions in `Flip7Core`; SwiftUI only renders state and sends commands.
- Record material decisions and test evidence in the issue or pull request before moving on.
- If product intent or a rule is ambiguous, ask the human owner in the issue instead of guessing.
- Do not copy commercial Flip 7 artwork, logos, or other protected assets.
- Do not publish under the Flip 7 name until the owner confirms trademark/licensing rights.
- Run `swift test` and the signing-free iOS build command from the README before opening a pull request.
