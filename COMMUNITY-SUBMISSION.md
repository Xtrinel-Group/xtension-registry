# Community Xtension Submission Guidelines

**For community authors submitting Xtensions to the VAAST registry.**

---

## Security Model

Community Xtensions are **hosted in Xtrinel's R2 bucket**, not the author's GitHub repository. This prevents approved authors from later swapping artifacts with malicious code after review.

**Key principles**:
1. **We host, we hash**: Checksums are computed by Xtrinel maintainers from the exact artifact uploaded to R2
2. **Immutable after publish**: Once an Xtension version is published, the artifact and checksum never change
3. **Checksum mismatch = security event**: If a user's install fails checksum verification, we treat it as tampering (not a bug to "fix" by updating the hash)

---

## Submission Flow

### 1. Prepare Your Xtension

**Required files**:
- `manifest.json` (see schema below)
- `dist/index.js` (bundled code, single file)

**Manifest schema** (`registry/community/<your-id>.json`):
```json
{
  "id": "your-xtension-id",
  "name": "Your Xtension Name",
  "version": "0.1.0",
  "description": "One-line summary (max 200 chars)",
  "author": "YourGitHubUsername",
  "githubUrl": "https://github.com/YourUsername/YourXtension",
  "entrypoint": "dist/index.js",
  "permissions": ["proxy.read", "scanner.write", "ui.tab"],
  "tier": "free",
  "minVaastVersion": "1.0.0",
  "uiType": "tab",
  "api_version": 2
}
```

**Key fields**:
- `api_version`: Must be `2` (VAAST 0.3.2+ requires sandboxed Xtensions)
- `tier`: Community Xtensions are `"free"` (no Pro gate)
- `id`: Lowercase alphanumeric + hyphens, globally unique
- `githubUrl`: Public repo (MIT or Apache-2.0 license) with readable source code

**DO NOT include** in your submission:
- `r2Path` (maintainers set this after upload)
- `checksum` (maintainers compute this after upload)
- `downloadUrl` (community Xtensions use R2, not GitHub Releases)

---

### 2. Build Your Artifact

Package your Xtension as a `.zip` with:
```
your-xtension-v0.1.0.zip
├── dist/
│   └── index.js
└── manifest.json
```

**Requirements**:
- Single `dist/index.js` file (bundle all dependencies)
- `manifest.json` with matching version
- `api_version: 2` in manifest
- No obfuscation, no minification (reviewable source)

**Build command** (example):
```bash
npm run build
zip -r your-xtension-v0.1.0.zip dist/ manifest.json
```

---

### 3. Submit via Pull Request

1. **Fork** `Xtrinel-Group/xtension-registry`
2. **Add your manifest** to `registry/community/<your-id>.json` (WITHOUT `r2Path` or `checksum`)
3. **Attach your `.zip`** to the PR description (or provide a GitHub Release link for initial review)
4. **Open PR** against `main`

**PR template**:
```markdown
## Xtension Submission

**Name**: Your Xtension Name
**Version**: 0.1.0
**Author**: @YourGitHubUsername
**GitHub Repo**: https://github.com/YourUsername/YourXtension
**License**: MIT / Apache-2.0

### Artifact

Attached: `your-xtension-v0.1.0.zip` (SHA-256: <paste checksum here>)

### What it does

<2-3 sentence summary>

### Permissions justification

- `proxy.read`: Needed to analyze captured requests
- `scanner.write`: Adds findings to VAAST workspace
- `ui.tab`: Renders UI tab for results

### Checklist

- [ ] Source code is public and readable (no obfuscation)
- [ ] License is MIT or Apache-2.0
- [ ] No hardcoded external URLs (http.fetch permission requires disclosure)
- [ ] api_version: 2 in manifest
- [ ] tier: "free" in manifest
```

---

### 4. Maintainer Review

Maintainers will:
1. **Review source code** at your GitHub repo (security, quality, permissions)
2. **Download and inspect** the attached `.zip`
3. **Rebuild from source** and compare to submitted artifact (reproducibility check)
4. **Upload reviewed artifact to R2** at `community/<your-id>-v<version>.zip`
5. **Compute SHA-256** of the R2 artifact
6. **Update manifest**:
   - Add `"r2Path": "community/<your-id>-v<version>.zip"`
   - Add `"checksum": "<sha256>"`
7. **Merge PR**
8. **Publish workflow runs** automatically, updating `registry.json` in R2

---

### 5. After Publish

Your Xtension will appear in VAAST's **Community Xtensions** section within ~60 seconds (CDN cache).

**Version updates**:
- Bump `version` in manifest
- Build new `.zip`
- Submit new PR with updated manifest + new artifact
- Same review process applies

**Security updates** (critical vulnerabilities):
- Tag PR as `[SECURITY]` for expedited review
- Provide CVE or GHSA if applicable
- Maintainers will fast-track review + publish

---

## Why We Host Community Artifacts

**Problem**: GitHub Releases are mutable. An approved author can:
1. Submit benign code for review
2. Get approved + merged
3. Replace the GitHub Release artifact with malicious code
4. Users download backdoored Xtension

**Solution**: Xtrinel hosts the exact reviewed artifact in R2. The `checksum` in the manifest is computed from the R2 copy, not the author's repo. If the R2 artifact is ever tampered with, checksum verification fails at install time.

**Checksum as security boundary**:
- Computed by maintainers from reviewed artifact
- Stored in `registry.json` (immutable per version)
- Verified by VAAST installer before loading bundle
- Mismatch = install blocked + security alert (not "update the hash")

---

## Permissions

Community Xtensions must declare all permissions in the manifest. Available permissions:

| Permission | Description | Requires Disclosure |
|------------|-------------|---------------------|
| `proxy.read` | Read intercepted HTTP requests/responses | No |
| `proxy.write` | Modify or send HTTP requests | No |
| `scanner.read` | Read scan findings | No |
| `scanner.write` | Add findings to workspace | No |
| `logger.read` | Read VAAST logs | No |
| `ui.tab` | Register a UI tab | No |
| `ui.panel` | Register a UI panel | No |
| `session.read` | Read session metadata | No |
| `http.fetch` | Make outbound HTTP requests | **YES** |

**If you use `http.fetch`**: Your manifest description MUST disclose what external URLs you contact and why. Example:

```json
{
  "description": "AI-powered finding summarizer (calls api.openai.com with finding text)",
  "permissions": ["scanner.read", "http.fetch"]
}
```

Undisclosed outbound requests = rejection during review.

---

## Review Criteria

Maintainers will reject submissions that:
- Contain obfuscated, minified, or binary code
- Make undisclosed outbound HTTP requests
- Request excessive permissions (e.g., `http.fetch` but don't use it)
- Have no public source repository
- Use restrictive licenses (not MIT/Apache-2.0)
- Duplicate existing functionality without clear value-add
- Contain known vulnerabilities or insecure patterns

Maintainers MAY request changes before approval (rename variables, reduce scope, fix bugs).

---

## Support

**Questions?** Open a discussion at https://github.com/Xtrinel-Group/xtension-registry/discussions

**Security issues in published Xtensions?** Email security@xtrinel.com (not a public GitHub issue)

---

**Last updated**: 2026-09-28
