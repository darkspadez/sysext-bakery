#!/bin/bash
#
# Build a bakery release of all sysexts.
#
# The release will include all sysexts from the "latest" release
# (these will be downloaded). Sysexts listed in release_build_versions.txt
# and _not_ included in the "latest" release will be built.

set -euo pipefail

echo
echo "Fetching previous 'latest' release sysexts"
echo "=========================================="
curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
         --retry-max-time 60 --connect-timeout 20  \
         https://api.github.com/repos/darkspadez/sysext-bakery/releases/latest \
    | jq -r '.assets[] | "\(.name)\t\(.browser_download_url)"' | { grep -E '\.raw$' || true; } | tee prev_release_sysexts.txt

while IFS=$'\t' read -r name url; do
    echo
    echo "  ## Fetching ${name} <-- ${url}"
    curl -o "${name}" -fsSL --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 --connect-timeout 20  "${url}"
done <prev_release_sysexts.txt

streams=()

echo
echo "Building sysexts"
echo "================"

mapfile -t images < <( awk '{ content=sub("[[:space:]]*#.*", ""); if ($0) print $0; }' \
                       release_build_versions.txt )

echo "building: ${images[@]}"

echo "# Release $(date '+%Y-%m-%d %R')" > Release.md
echo "The release adds the following sysexts:" >> Release.md

for image in "${images[@]}"; do
  component="${image%-*}"
  version="${image#*-}"
  for arch in x86-64 arm64; do
    target="${image}-${arch}.raw"
    if [ -f "${target}" ] ; then
        echo "  ## Skipping ${target} because it already exists (asset from previous release)"
        continue
    fi
    echo "  ## Building ${target}."
    ARCH="${arch}" "./create_${component}_sysext.sh" "${version}" "${component}"
    mv "${component}.raw" "${target}"
    echo "* ${target}" >> Release.md
  done
  streams+=("${component}:-@v")
  if [ "${component}" = "kubernetes" ] || [ "${component}" = "crio" ]; then
    streams+=("${component}-${version%.*}:.@v")
    # Should give, e.g., v1.28 for v1.28.2 (use ${version#*.*.} to get 2)
  fi
done
  
echo "" >> Release.md
echo "The release includes the following sysexts from previous releases:" >> Release.md
awk '{ print "* ["$1"]("$2")" }' prev_release_sysexts.txt >>Release.md

echo
echo "Generating systemd-sysupdate configurations and SHA256SUM."
echo "=========================================================="

for stream in "${streams[@]}"; do
  component="${stream%:*}"
  pattern="${stream#*:}"
  cat << EOF > "${component}.conf"
[Transfer]
Verify=false
[Source]
Type=url-file
Path=https://github.com/darkspadez/sysext-bakery/releases/latest/download/
MatchPattern=${component}${pattern}-%a.raw
[Target]
InstancesMax=3
Type=regular-file
Path=/opt/extensions/${component%-*}
CurrentSymlink=/etc/extensions/${component%-*}.raw
EOF
done

cat << EOF > "noop.conf"
[Source]
Type=regular-file
Path=/
MatchPattern=invalid@v.raw
[Target]
Type=regular-file
Path=/
EOF

# Generate new SHA256SUMS from all assets
sha256sum *.raw | tee SHA256SUMS
