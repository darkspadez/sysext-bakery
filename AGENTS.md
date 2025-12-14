# AI Agent Merge Strategy Documentation

## Purpose

This document provides instructions for AI agents (Claude, Copilot, Cursor, Aider, etc.) when performing merge operations on this repository. This is a **fork** with specific customizations that must be preserved.

---

## Repository Context

- **Fork**: `darkspadez/sysext-bakery`
- **Upstream**: Original sysext-bakery repository
- **Fork Hub**: `sysext.darkspadez.me`
- **Customization Commit**: `939ef0ac6144eeb90e1ae357d00aed3d560c118f`

This fork has been customized to:
1. Ship **Docker ONLY** (without standalone containerd/runc)
2. Use **EROFS** filesystem format by default (not squashfs)
3. Maintain fork-specific identity and versions

---

## Protected Files and Patterns

### MUST PRESERVE: .env File

**File**: `.env`

**Content**:
```bash
bakery="darkspadez/sysext-bakery"
bakery_hub="sysext.darkspadez.me"
```

**Rules**:
- This file must always exist
- These two variables must always have these exact values
- If upstream adds `.env`, merge contents but keep these variables unchanged

---

### MUST PRESERVE: Docker-Only Build Logic

**File**: `docker.sysext/create.sh`

**Function**: `populate_sysext_root()`

**Critical Code Block**:
```bash
announce "Removing containerd / runc from sysext as requested (shipping docker only)"

rm "${sysextroot}/usr/bin/containerd" \
    "${sysextroot}/usr/bin/containerd-shim-runc-v2" \
    "${sysextroot}/usr/bin/ctr" \
    "${sysextroot}/usr/bin/runc"
```

**Context**:
- Upstream version has conditional logic with `--without docker` or `--without containerd` options
- This fork has **removed that conditional logic** permanently
- The function always removes containerd/runc binaries

**Rules**:
- Never reintroduce the `if [[ "${without}" == docker ]]` conditional blocks
- Always keep the simplified Docker-only removal logic
- If upstream adds new containerd binaries, add them to the removal list

---

### MUST DELETE: Containerd Service Files

The following files were deleted in the fork and **must never be restored**:

```
docker.sysext/files/usr/lib/systemd/system/containerd.service
docker.sysext/files/usr/lib/systemd/system/multi-user.target.d/10-containerd-service.conf
docker.sysext/files/usr/share/containerd/config.toml
docker.sysext/files/usr/share/containerd/config-cgroupfs.toml
```

**Rules**:
- If these files appear during a merge from upstream, **delete them after merging**
- Do not keep containerd as a systemd service in this fork
- These files are incompatible with the Docker-only strategy

---

### MUST PRESERVE: EROFS Default Format

**File**: `lib/generate.sh`

**Function**: `generate_sysext()`

**Critical Line**:
```bash
local format="$(get_optional_param "format" "erofs" "${@}")"
```

**Context**:
- Upstream default is `squashfs`
- This fork uses `erofs` as the default

**Rules**:
- When merging changes to `generate_sysext()`, ensure the default format parameter remains `erofs`
- Do not revert to `squashfs` unless explicitly requested by the fork maintainer

---

### MUST PRESERVE: Custom Release Versions

**File**: `release_build_versions.txt`

**Fork-Specific Entries**:
```
docker 28.2.1
tailscale v1.84.0
```

**Rules**:
- These versions are specific to this fork's needs
- When merging upstream changes, preserve these version entries
- If upstream adds newer versions, keep both sets (fork + upstream)
- Maintain alphabetical/version ordering

---

## Automated Merge Procedure

When instructed to merge from upstream, follow these steps:

### 1. Pre-Merge State Capture
```bash
# Store current protected content
cp .env .env.fork-backup
cp docker.sysext/create.sh create.sh.fork-backup
cp lib/generate.sh generate.sh.fork-backup
cp release_build_versions.txt versions.fork-backup
```

### 2. Perform Merge
```bash
git fetch upstream main
git merge upstream/main
```

### 3. Automatic Conflict Resolution Rules

For each conflict, apply these resolution strategies:

#### .env Conflicts
```
Strategy: MERGE + PRESERVE
- Accept all upstream additions
- Ensure fork variables are present:
  bakery="darkspadez/sysext-bakery"
  bakery_hub="sysext.darkspadez.me"
```

#### docker.sysext/create.sh Conflicts
```
Strategy: PRESERVE FORK LOGIC
- Review upstream changes for bug fixes/security patches
- Apply fixes while maintaining Docker-only removal logic
- Do NOT reintroduce conditional --without logic
- Final code must always remove: containerd, containerd-shim-runc-v2, ctr, runc
```

#### lib/generate.sh Conflicts
```
Strategy: ACCEPT UPSTREAM + OVERRIDE DEFAULT
- Accept upstream changes
- Ensure format default is "erofs" not "squashfs"
```

#### release_build_versions.txt Conflicts
```
Strategy: UNION
- Include both upstream and fork versions
- Sort appropriately
- Keep: docker 28.2.1, tailscale v1.84.0
```

### 4. Post-Merge Validation

Run these checks automatically:

```bash
# Check 1: .env exists with correct variables
grep -q 'bakery="darkspadez/sysext-bakery"' .env || echo "VALIDATION FAILED: .env missing fork bakery"
grep -q 'bakery_hub="sysext.darkspadez.me"' .env || echo "VALIDATION FAILED: .env missing fork hub"

# Check 2: Docker-only logic present
grep -q 'Removing containerd / runc from sysext as requested (shipping docker only)' docker.sysext/create.sh || echo "VALIDATION FAILED: Docker-only message missing"

# Check 3: No conditional --without logic
grep -q 'if \[\[ "${without}" ==' docker.sysext/create.sh && echo "VALIDATION FAILED: Conditional logic reintroduced"

# Check 4: Containerd files deleted
[ -f docker.sysext/files/usr/lib/systemd/system/containerd.service ] && echo "VALIDATION FAILED: containerd.service exists"
[ -f docker.sysext/files/usr/share/containerd/config.toml ] && echo "VALIDATION FAILED: containerd config exists"

# Check 5: Default format is erofs
grep -q 'format="$(get_optional_param "format" "erofs"' lib/generate.sh || echo "VALIDATION FAILED: Default format not erofs"

# Check 6: Custom versions present
grep -q "docker 28.2.1" release_build_versions.txt || echo "VALIDATION FAILED: docker 28.2.1 missing"
grep -q "tailscale v1.84.0" release_build_versions.txt || echo "VALIDATION FAILED: tailscale v1.84.0 missing"
```

### 5. Auto-Fix Validation Failures

If any validation fails, apply automatic fixes:

```bash
# Fix .env
if ! grep -q 'bakery="darkspadez/sysext-bakery"' .env; then
  echo 'bakery="darkspadez/sysext-bakery"' >> .env
fi
if ! grep -q 'bakery_hub="sysext.darkspadez.me"' .env; then
  echo 'bakery_hub="sysext.darkspadez.me"' >> .env
fi

# Fix containerd files (delete if they exist)
rm -f docker.sysext/files/usr/lib/systemd/system/containerd.service
rm -f docker.sysext/files/usr/lib/systemd/system/multi-user.target.d/10-containerd-service.conf
rm -f docker.sysext/files/usr/share/containerd/config.toml
rm -f docker.sysext/files/usr/share/containerd/config-cgroupfs.toml

# If docker.sysext/create.sh has wrong logic, restore from fork backup
if grep -q 'if \[\[ "${without}" ==' docker.sysext/create.sh; then
  # Restore fork version and re-apply upstream changes manually
  echo "WARNING: Conditional logic detected in create.sh - manual review needed"
fi

# Fix format default in lib/generate.sh
sed -i 's/format="$(get_optional_param "format" "squashfs"/format="$(get_optional_param "format" "erofs"/' lib/generate.sh
```

---

## Decision Tree for Conflicts

```
Is this a merge from upstream?
├─ YES → Apply fork preservation rules
│   │
│   ├─ File: .env
│   │   └─ Keep fork variables, accept upstream additions
│   │
│   ├─ File: docker.sysext/create.sh
│   │   └─ Preserve Docker-only logic, reject conditional --without logic
│   │
│   ├─ File: lib/generate.sh
│   │   └─ Keep erofs as default format
│   │
│   ├─ File: release_build_versions.txt
│   │   └─ Union merge (keep fork + upstream versions)
│   │
│   └─ Files: containerd services/configs
│       └─ DELETE if present
│
└─ NO → Standard merge procedure
```

---

## Commit Message Template

After merging and fixing conflicts:

```
Merge upstream/main while preserving fork customizations

Preserved fork customizations:
- .env fork identity (darkspadez/sysext-bakery)
- Docker-only build logic in docker.sysext/create.sh
- EROFS default format in lib/generate.sh
- Custom release versions (docker 28.2.1, tailscale v1.84.0)
- Removed reintroduced containerd service files

Applied upstream changes:
- [List significant upstream changes merged]

Validation: All post-merge checks passed

Reference: Fork customizations from 939ef0ac6144eeb90e1ae357d00aed3d560c118f
```

---

## Error Recovery

If fork customizations are lost after a merge:

```bash
# Restore from original customization commit
git show 939ef0ac6144eeb90e1ae357d00aed3d560c118f:.env > .env
git show 939ef0ac6144eeb90e1ae357d00aed3d560c118f:docker.sysext/create.sh > docker.sysext/create.sh
git show 939ef0ac6144eeb90e1ae357d00aed3d560c118f:lib/generate.sh > lib/generate.sh

# Remove containerd files
find docker.sysext/files -name "*containerd*" -delete

# Commit the restoration
git add .
git commit -m "Restore fork customizations lost during merge

Reference: 939ef0ac6144eeb90e1ae357d00aed3d560c118f"
```

---

## Agent-Specific Notes

### For Claude
- This fork's design philosophy: Docker-only, EROFS format, custom identity
- Always validate post-merge before committing
- If uncertain, preserve fork customization over upstream change

### For GitHub Copilot / Cursor
- Treat patterns in protected files as "required" not "suggested"
- Do not auto-complete with upstream patterns
- Flag conflicts in protected files for manual review

### For Aider
- Use "preserve fork" mode when merging
- Protected files should have higher precedence than upstream
- Auto-apply validation fixes before committing

### For Any Agent
- The fork's purpose is specific: Docker-only builds with EROFS
- Upstream compatibility is secondary to fork customizations
- When in doubt, check commit `939ef0ac6144eeb90e1ae357d00aed3d560c118f`

---

## Summary Checklist

After any merge operation, verify:

- [ ] `.env` exists with `bakery="darkspadez/sysext-bakery"` and `bakery_hub="sysext.darkspadez.me"`
- [ ] `docker.sysext/create.sh` contains Docker-only removal logic (no conditional --without)
- [ ] `lib/generate.sh` has default format as `erofs` (not squashfs)
- [ ] `release_build_versions.txt` includes `docker 28.2.1` and `tailscale v1.84.0`
- [ ] No containerd systemd service files exist in `docker.sysext/files/`
- [ ] No containerd config files exist in `docker.sysext/files/`
- [ ] Build test passes: `./build.sh docker latest`

**All checks must pass before pushing merged changes.**

---

## Contact

If you are an AI agent encountering an ambiguous merge scenario not covered by this document:

1. Consult `CLAUDE.md` for additional context
2. Examine commit `939ef0ac6144eeb90e1ae357d00aed3d560c118f` directly
3. Default to preserving fork customizations
4. Request human review if critical upstream changes conflict with fork philosophy

**The fork exists for a specific purpose. Maintain that purpose through all merges.**
