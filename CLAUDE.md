# Claude AI Merge Strategy Guide

## Critical Fork Customizations

This repository is a fork of the upstream sysext-bakery with specific customizations that **MUST BE PRESERVED** during all merge operations. The customizations were implemented in commit `939ef0ac6144eeb90e1ae357d00aed3d560c118f`.

## Protected Changes - DO NOT REVERT

### 1. Fork Identity (.env)

**File: `.env`**

This file defines the fork's identity and must always exist with these exact values:

```bash
bakery="darkspadez/sysext-bakery"
bakery_hub="sysext.darkspadez.me"
```

**Merge Rule:**
- If upstream adds a `.env` file, merge the contents but ALWAYS keep the above two variables
- NEVER change the bakery name or hub URL to upstream values

---

### 2. Docker-Only Build Configuration

**File: `docker.sysext/create.sh`**

This fork ships **Docker ONLY** (without containerd/runc as separate components).

The `populate_sysext_root()` function has been simplified to **always** remove containerd/runc:

```bash
announce "Removing containerd / runc from sysext as requested (shipping docker only)"

rm "${sysextroot}/usr/bin/containerd" \
    "${sysextroot}/usr/bin/containerd-shim-runc-v2" \
    "${sysextroot}/usr/bin/ctr" \
    "${sysextroot}/usr/bin/runc"
```

**What was removed:**
- The entire conditional logic for `--without docker` or `--without containerd` options
- The if-elif block that allowed flexible builds

**Merge Rule:**
- If upstream modifies `populate_sysext_root()`, ensure the Docker-only logic is preserved
- NEVER reintroduce the conditional `--without` logic
- The function should ALWAYS remove containerd/runc binaries

---

### 3. Deleted Containerd Files

The following files were **permanently deleted** and should NEVER be restored:

**Systemd Service Files:**
- `docker.sysext/files/usr/lib/systemd/system/containerd.service`
- `docker.sysext/files/usr/lib/systemd/system/multi-user.target.d/10-containerd-service.conf`

**Containerd Configuration Files:**
- `docker.sysext/files/usr/share/containerd/config.toml`
- `docker.sysext/files/usr/share/containerd/config-cgroupfs.toml`

**Merge Rule:**
- If these files appear in an upstream merge, **DELETE THEM** after the merge
- Do NOT keep containerd as a standalone service in this fork

---

### 4. Default Format: EROFS

**File: `lib/generate.sh`**

The default filesystem format has been changed from `squashfs` to `erofs`:

```bash
local format="$(get_optional_param "format" "erofs" "${@}")"
```

**Merge Rule:**
- If upstream modifies the `generate_sysext()` function, ensure the default format remains `erofs`
- Original upstream value was `squashfs` - do NOT revert to this

---

### 5. Custom Release Versions

**File: `release_build_versions.txt`**

Additional versions added to the build manifest:

```
docker 28.2.1
tailscale v1.84.0
```

**Merge Rule:**
- When merging upstream changes to this file, preserve these specific version entries
- If upstream adds newer versions of docker/tailscale, keep both the fork-specific versions AND the upstream versions
- These versions may be unique to this fork's needs

---

## Merge Workflow Instructions

When merging from upstream, follow this procedure:

### Step 1: Pre-Merge Checklist
```bash
# Verify current fork customizations are in place
git show 939ef0ac6144eeb90e1ae357d00aed3d560c118f
cat .env
grep -A5 "populate_sysext_root" docker.sysext/create.sh
grep "format" lib/generate.sh
```

### Step 2: Perform Merge
```bash
# Fetch and merge upstream
git fetch upstream main
git merge upstream/main
```

### Step 3: Post-Merge Verification

After resolving conflicts, verify each protected change:

#### Check 1: .env exists and is correct
```bash
if [[ ! -f .env ]]; then
  echo 'bakery="darkspadez/sysext-bakery"' > .env
  echo 'bakery_hub="sysext.darkspadez.me"' >> .env
fi
```

#### Check 2: Docker-only logic in create.sh
```bash
# Ensure the file contains the Docker-only removal code
grep -q "Removing containerd / runc from sysext as requested (shipping docker only)" docker.sysext/create.sh || echo "WARNING: Docker-only logic missing!"
```

#### Check 3: Containerd files are deleted
```bash
# These should all fail (files should not exist)
test -f docker.sysext/files/usr/lib/systemd/system/containerd.service && echo "ERROR: containerd.service exists!"
test -f docker.sysext/files/usr/share/containerd/config.toml && echo "ERROR: config.toml exists!"
```

#### Check 4: Default format is erofs
```bash
grep 'format="$(get_optional_param "format" "erofs"' lib/generate.sh || echo "WARNING: Default format is not erofs!"
```

#### Check 5: Custom versions present
```bash
grep "docker 28.2.1" release_build_versions.txt || echo "WARNING: docker 28.2.1 missing!"
grep "tailscale v1.84.0" release_build_versions.txt || echo "WARNING: tailscale v1.84.0 missing!"
```

### Step 4: Fix Any Violations

If any checks fail, manually restore the fork customizations before committing the merge.

---

## Conflict Resolution Guidelines

### If Upstream Modified .env
1. Accept upstream changes
2. Add/modify to include fork-specific variables
3. Final file must contain: `bakery="darkspadez/sysext-bakery"` and `bakery_hub="sysext.darkspadez.me"`

### If Upstream Modified docker.sysext/create.sh
1. Review upstream changes for security/bug fixes
2. Apply those fixes but KEEP the Docker-only logic
3. Do NOT reintroduce conditional containerd/docker build options
4. The function must always remove: containerd, containerd-shim-runc-v2, ctr, runc

### If Upstream Re-Added Containerd Files
1. Accept the merge
2. Delete the containerd service and config files afterward
3. Commit with message: "Remove containerd files (fork ships Docker only)"

### If Upstream Changed Default Format
1. Review why upstream changed the format
2. Evaluate if erofs should remain the default for this fork
3. Unless there's a compelling reason, KEEP erofs as default

### If Upstream Modified release_build_versions.txt
1. Accept upstream additions
2. Ensure fork-specific versions (docker 28.2.1, tailscale v1.84.0) are preserved
3. Sort the file appropriately with both upstream and fork versions

---

## Commit Message Format

When committing a merge that preserves fork customizations:

```
Merge upstream/main while preserving fork customizations

- Kept .env with darkspadez/sysext-bakery identity
- Preserved Docker-only build in docker.sysext/create.sh
- Removed reintroduced containerd service files
- Maintained erofs as default format
- Preserved custom release versions

Fork customizations from: 939ef0ac6144eeb90e1ae357d00aed3d560c118f
```

---

## Emergency Recovery

If fork customizations are accidentally lost, restore from the original commit:

```bash
# Restore .env
git show 939ef0ac6144eeb90e1ae357d00aed3d560c118f:.env > .env

# Restore docker.sysext/create.sh changes
git show 939ef0ac6144eeb90e1ae357d00aed3d560c118f:docker.sysext/create.sh > docker.sysext/create.sh

# Restore lib/generate.sh format change
git show 939ef0ac6144eeb90e1ae357d00aed3d560c118f:lib/generate.sh > lib/generate.sh

# Remove containerd files if they were restored
rm -f docker.sysext/files/usr/lib/systemd/system/containerd.service
rm -f docker.sysext/files/usr/lib/systemd/system/multi-user.target.d/10-containerd-service.conf
rm -f docker.sysext/files/usr/share/containerd/config.toml
rm -f docker.sysext/files/usr/share/containerd/config-cgroupfs.toml
```

---

## Testing After Merge

Before pushing merged changes, verify the build works:

```bash
# Test a build with the fork configuration
./build.sh docker latest

# Verify erofs format is used
# Verify containerd is not included in output
```

---

## Questions?

If uncertain about a merge conflict or whether to preserve a customization:

1. Consult this document first
2. Check commit 939ef0ac6144eeb90e1ae357d00aed3d560c118f
3. When in doubt, preserve the fork customization
4. The fork's purpose is to ship **Docker-only with EROFS format** under the darkspadez identity

**Always prefer preserving fork customizations over blindly accepting upstream changes.**
