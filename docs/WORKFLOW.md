# Issue-driven workflow

GitHub issues are the durable memory for this long-running project. Each branch addresses one issue and carries no unrelated cleanup.

## Start an issue

1. Read the full issue from GitHub, including dependencies and recent comments.
2. Confirm dependencies are merged into `main`.
3. Update local `main` with a fast-forward-only pull.
4. Create `issue-X`, where X is the issue number.
5. Restate any uncertain product or rule decision in the issue and ask the owner before choosing an irreversible direction.

## Finish an issue

1. Commit each coherent checkpoint locally and run the issue-specific checks affected by product-code changes.
2. On the final pre-PR commit, run `swift test` and the README signing-free build command.
3. Record the `main` base and branch head commits. Before pushing, ask a reviewer who did not implement the change to attack that complete diff for correctness, scope, counterexamples, unnecessary code, and performance or accessibility regressions.
4. Resolve every finding or record the evidence for rejecting it. If the branch changes, rerun affected checks and have the resulting diff re-reviewed before the next push.
5. Push `issue-X` and open a focused pull request with `Closes #X`.
6. Record decisions, limitations, exact verification results, the reviewed commits, the reviewer, findings (or `None`), and dispositions in the pull request.
7. Begin another issue only from updated `main` after the prior dependency is merged.

Frequent local commits do not require frequent pushes. Documentation-only edits need their issue-specific checks at each checkpoint; the full test and build pair is required once on the final pre-PR commit.

## Change behavior or fix a defect

1. Run every recorded command from a clean worktree at its named commit. Before writing the test, cite the issue criterion, authoritative source, or owner decision that established the expected behavior. Run the affected baseline checks green and record their commit and commands; that commit must be the red commit's exact parent.
2. Add one deterministic test at the nearest public behavior or invariant boundary. Do not target private helpers or rely on sleeps, unseeded randomness, unisolated shared mutable state, incidental formatting, or broad snapshots. Commit only test-side changes against the unfixed production code.
3. List the test identifiers, then run the intended test with the current nondeprecated filter:

   ```sh
   swift test list -Xswiftc -warnings-as-errors
   swift test -Xswiftc -warnings-as-errors --filter 'ModuleName\.testFunctionName'
   ```

4. Count the red only when the build succeeds, only the intended test function or cases run with their count recorded, the claimed scenario executes, and the contract assertion fails because the observed behavior differs from the approved expectation. Compilation errors, setup failures, crashes, timeouts, unrelated failures, zero selected tests, and deliberately impossible fixtures are invalid.
5. If the test passes or fails for the wrong reason, stop before editing production code. Reassess the report, authoritative source, wording, fixture, and assertion, then record the conclusion in the issue or pull request. Any later change to the test, its fixtures, its target or configuration, or the focused command requires a new red run against unfixed production code.
6. Without changing the test, fixtures, test target/configuration, or focused command, make the smallest fix in a separate commit. Run the focused command and verify that the same intended test function or cases and count run and pass, not skip, then run affected suites and final project checks.
7. Keep the red and green commits reachable from the pull-request head. Never push or merge while red is the branch head.

Record TDD as `N/A` with a reason only when a change cannot affect observable runtime behavior; file type alone is not an exemption. Pure refactors record affected checks green before and after without fabricating a failure.

## SwiftUI review evidence

For every SwiftUI change:

1. Consult the current official Apple Developer Documentation, API reference, and applicable Human Interface Guidelines instead of relying on memory or third-party summaries.
2. Record the Apple URLs, Xcode version, SDK version, and the exact availability of every introduced API newer than the iOS 18 deployment target.
3. Preserve equivalent behavior and hierarchy on the iOS 18 deployment target when using a newer API.
4. Run the README warning-as-error commands and confirm there are no deprecated API diagnostics.
5. Have an independent reviewer compare the implementation with those Apple sources before push or merge.

## Context reset checklist

- What outcome and acceptance criteria does the current issue require?
- Which dependency PRs changed the relevant contracts?
- What decisions have already been recorded?
- What is the smallest next change that advances only this issue?
- Which command will prove the change works?
- Which base and head commits were reviewed, what was found, and how was each finding resolved?
- For SwiftUI work, which current Apple sources and SDK declarations govern the implementation?
