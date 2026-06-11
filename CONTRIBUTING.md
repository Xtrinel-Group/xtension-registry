# Contributing an Xtension

## Writing a manifest

Every Xtension is a single JSON file that conforms to `schema/manifest.schema.json`. Required fields:

| Field | Description |
|-------|-------------|
| `id` | Lowercase alphanumeric + hyphens. Must be globally unique. |
| `name` | Human-readable display name. |
| `version` | Semver (e.g. `1.0.0`). |
| `description` | One-line summary, max 200 characters. |
| `author` | Your name or GitHub username. |
| `entrypoint` | Relative path to the main script inside the package. |
| `permissions` | Array of permission strings the Xtension requires. |
| `tier` | `"free"` or `"pro"` — minimum VAAST plan required. |

Optional fields: `githubUrl`, `downloadUrl`, `checksum`, `minVaastVersion`, `uiType`.

See `schema/manifest.schema.json` for the full schema with allowed values.

## Submitting

1. Fork this repository
2. Create your manifest file at `registry/community/<your-id>.json`
3. Validate locally: `npx ajv-cli validate -s schema/manifest.schema.json -d registry/community/your-id.json --spec=draft7 -c ajv-formats`
4. Open a pull request against `main`

The CI pipeline will automatically validate your manifest. A maintainer will review and merge.

## Rules

- The `githubUrl` must point to a public GitHub repository
- The repository must use MIT or Apache-2.0 license
- No obfuscated, minified, or vendored binary code — source must be readable
- One manifest file per Xtension
- Updates to existing Xtensions: bump `version` in the same file and open a new PR

## Review process

1. Automated schema validation runs on every PR
2. A maintainer reviews the manifest and linked source code
3. On merge, the registry is rebuilt and published automatically
