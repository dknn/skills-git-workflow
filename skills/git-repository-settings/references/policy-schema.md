# Repository policy profile

An organisation-wide settings repository can store desired state separately from the
skill. Keep the schema small, provider-neutral, and declarative. A policy profile does
not grant permission to apply itself.

Example:

```yaml
version: 1

baselines:
  secure-main:
    target_branch: main
    protected: true
    allow_direct_push: false
    allow_force_push: false
    require_successful_pipeline: true
    required_security_check: gitleaks

repositories:
  - provider: gitlab
    project: ms-team/example-service
    baseline: secure-main
  - provider: github
    repository: example-org/example-service
    baseline: secure-main
```

Rules for consumers:

- Resolve the target repository and provider before selecting a profile.
- Treat an unknown provider or missing profile as `UNKNOWN` and stop before mutation.
- Compare desired and current state; apply only an approved, monotonic tightening.
- Keep credentials and runner registration tokens out of the policy repository.
- Record blocked changes for an administrator rather than silently skipping them.
- Validate the policy file before any provider API operation.
