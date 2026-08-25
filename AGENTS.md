# Repository working agreement

- Work on exactly one GitHub issue at a time.
- Before editing, run `gh issue view X` and re-read the full issue plus its dependency PRs.
- Start from the latest `main` and use a fresh branch named `issue-X`, where X is the GitHub issue number.
- Keep each commit coherent and independently reviewable. Product-code commits must pass the issue-specific checks they affect.
- Before the first remote push, have a reviewer who did not implement the change inspect the complete `main...HEAD` diff at named base and head commits. Re-review changes made after that head before the next push or merge.
- Record the review commits, reviewer, findings (or `None`), and each finding's disposition in the pull request.
- Keep rules and state transitions in `Flip7Core`; SwiftUI only renders state and sends commands.
- Prefer native SwiftUI and standard controls. Guard custom Liquid Glass APIs with `if #available(iOS 26, *)` and keep an equivalent native iOS 18 fallback.
- Prefer the smallest clear implementation; correctness, accessibility, and performance outrank ornament, line count, or speculative abstraction.
- Record material decisions and test evidence in the issue or pull request before moving on.
- If product intent or a rule is ambiguous, ask the human owner in the issue instead of guessing.
- Do not copy commercial Flip 7 artwork, logos, or other protected assets.
- Do not publish under the Flip 7 name until the owner confirms trademark/licensing rights.
- Run `swift test` and the signing-free iOS build command from the README on the final pre-PR commit, and again after any later product-code change.
