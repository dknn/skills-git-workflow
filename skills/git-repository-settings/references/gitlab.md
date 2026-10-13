# GitLab provider guidance

Use this reference after the remote has been identified as GitLab. Prefer the
authenticated `glab` CLI or the GitLab UI for read-back and mutation; never place an
access token in a file, command argument that may be logged, or report.

## Required state

For the target branch:

- The branch is protected.
- `Allowed to push and merge` is `No one` unless an approved emergency policy says
  otherwise.
- `Allowed to merge` remains restricted to the intended reviewer role.
- Force-push remains disabled.
- Project merge settings require a successful pipeline.
- The CI configuration creates a merge-request pipeline containing Secret Detection.
- The effective `secret_detection` job has `allow_failure: false`.
- An active trusted runner is available to execute the job.

The job configuration alone is not proof that the gate works. Verify the actual
merge-request pipeline and job status. A job that is pending with `runner: null` is an
operational blocker.

## Runner handling

Inspect assigned project runners, other available project runners, group runners, and
instance runners. Use only a runner whose owner, scope, status, tags, and recent contact
are understood and approved for this repository.

Do not assign a runner that is stale, has never contacted GitLab, belongs to an unrelated
project, or is not approved for the repository's trust boundary. Escalate to the group or
GitLab administrator to register or enable a suitable runner instead.

## Safe application order

1. Validate `.gitlab-ci.yml` and inspect included jobs.
2. Ensure the merge-request pipeline rule is enabled and Secret Detection is blocking.
3. Confirm an active runner before relying on the pipeline as a merge gate.
4. Configure protected branch and merge settings.
5. Re-run the merge-request pipeline and read back the settings.

If a remote mutation is not permitted, report the setting, required role, and exact
follow-up. Do not change a less restrictive setting to compensate.
