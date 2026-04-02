# Amplitude Feature Flags

Use the local `amplitude-flags` helper for Amplitude Experiment feature flag management.

## Credentials

- Source `~/.secrets/credentials`.
- The helper uses:
  - `AMPLITUDE_MGMT_API_KEY_DEV`
  - `AMPLITUDE_MGMT_API_KEY_STAGING`
  - `AMPLITUDE_MGMT_API_KEY_PROD`
- These are Amplitude Experiment Management API keys, not deployment keys.

## Tool

- Script: `dotfiles/claude/scripts/amplitude-flags`
- Endpoint default: `https://experiment.amplitude.com`
- Auth: `Authorization: Bearer <management-api-key>`

## Safety

- Read commands are safe by default.
- Write commands require `--yes`.
- Prefer `get` or `versions` before mutating a flag.
- For risky changes in prod, inspect current config first and patch only the fields that need to change.

## Read Commands

```bash
amplitude-flags deployments dev
amplitude-flags flags prod --key ff_some_flag
amplitude-flags flags staging --project-id 123456 --limit 100
amplitude-flags get prod 898640
amplitude-flags versions prod 898640
```

## Write Commands

```bash
amplitude-flags enable prod 898640 --yes
amplitude-flags disable prod 898640 --yes
amplitude-flags patch prod 898640 '{"enabled":true,"rolloutPercentage":100}' --yes
amplitude-flags create prod @flag.json --yes
amplitude-flags add-deployment prod 898640 32637 --yes
amplitude-flags remove-deployment prod 898640 32637 --yes
```

## Common Flows

### Find a flag by key

```bash
amplitude-flags flags prod --key ff_some_flag
```

### Inspect a flag before changing it

```bash
amplitude-flags get prod 898640
amplitude-flags versions prod 898640
```

### Toggle a flag

```bash
amplitude-flags enable prod 898640 --yes
amplitude-flags disable prod 898640 --yes
```

### Change rollout percentage

```bash
amplitude-flags patch prod 898640 '{"rolloutPercentage":50}' --yes
```

### Update targeted config

Put the full patch body in a file first, then apply it:

```bash
amplitude-flags patch prod 898640 @flag-patch.json --yes
```

Note: when patching arrays and objects like `targetSegments` or `tags`, send the full desired replacement value.

## API Notes

- Management API can create and control flags, experiments, deployments, and versions.
- Flag list endpoint supports filtering by `key` and `projectId`.
- Deployment list endpoint is useful for discovering deployment IDs before attaching a flag to a deployment.
- Management API keys are distinct from deployment keys used by the runtime SDK for local/remote evaluation.

## Local Verification

The helper was live-verified on 2026-03-19 against the Amplitude Management API by successfully listing deployments and flags from the dev environment.
