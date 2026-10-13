# GitHub provider guidance

Use this reference after the remote has been identified as GitHub. Prefer the
authenticated `gh` CLI or GitHub UI for read-back and mutation; never place a token in a
file, command argument that may be logged, or report.

## Required state

For the target branch or ruleset:

- The branch is protected by a branch protection rule or ruleset.
- Pull requests are required before merging.
- Direct pushes are restricted to the explicitly approved administrators or automation.
- Force-push and branch deletion are disabled.
- The required status check for the Gitleaks workflow is enabled and matches the exact
  check name reported by the workflow.
- The check runs for pull requests and completes on a trusted runner.

Do not infer that a workflow is required merely because the YAML file exists. Read back
the ruleset/branch-protection configuration and verify a real pull-request check.

## Workflow handling

Preserve existing Actions conventions, permissions, concurrency, and runner policy. Add
Gitleaks using the repository's approved immutable action reference or approved tooling.
Do not introduce a floating third-party action when the repository has a pinning policy.

If the user lacks administration rights, prepare the workflow and produce the exact
ruleset changes a repository administrator must apply. Never use an administrator token
or bypass required reviews on the user's behalf.
