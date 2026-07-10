#!/usr/bin/env bash
# fix-susfs-namespace-51.sh — recover 51_enhanced_susfs's fs/namespace.c
# declaration-block hunk when it rejects on drifted ACK snapshots (e.g. 6.1.157).
#
# 51_ transforms the SUS_MOUNT decl block that 50_ inserts (via
# fix-susfs-namespace.sh):
#   + add    extern bool susfs_is_current_zygote_domain(void);
#   - remove static atomic64_t susfs_ksu_mounts = ATOMIC64_INIT(0);  (+ its blank)
#
# 51_'s OTHER namespace.c hunks delete the susfs_ksu_mounts *usages* and apply
# cleanly; only this block hunk fuzz-rejects. Recovering it keeps the file
# self-consistent — otherwise susfs_ksu_mounts is an unused static and -Werror
# (unused-variable) trips the build. Idempotent; fails loud on a missing anchor.
set -euo pipefail

F="${1:?usage: fix-susfs-namespace-51.sh <path/to/fs/namespace.c>}"
[ -f "$F" ] || { echo "fix-susfs-namespace-51: $F not found" >&2; exit 1; }

if grep -q 'susfs_is_current_zygote_domain' "$F" && ! grep -q 'susfs_ksu_mounts = ATOMIC64_INIT' "$F"; then
  echo "fix-susfs-namespace-51: already applied to $F — skip (idempotent)"
  exit 0
fi

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()

anchor = 'extern bool susfs_is_current_ksu_domain(void);\n'
add    = 'extern bool susfs_is_current_zygote_domain(void);\n'
if anchor not in s:
    sys.exit("fix-susfs-namespace-51: ksu_domain extern anchor not found")

if 'susfs_is_current_zygote_domain' not in s:
    s = s.replace(anchor, anchor + add, 1)

# Drop the susfs_ksu_mounts declaration and the blank line that follows it.
decl_with_blank = 'static atomic64_t susfs_ksu_mounts = ATOMIC64_INIT(0);\n\n'
decl_only       = 'static atomic64_t susfs_ksu_mounts = ATOMIC64_INIT(0);\n'
if decl_with_blank in s:
    s = s.replace(decl_with_blank, '', 1)
elif decl_only in s:
    s = s.replace(decl_only, '', 1)

open(p, 'w').write(s)
print("fix-susfs-namespace-51: transformed decl block in", p)
PY

grep -q 'susfs_is_current_zygote_domain' "$F" \
  || { echo "fix-susfs-namespace-51: zygote extern not added" >&2; exit 1; }
if grep -q 'susfs_ksu_mounts' "$F"; then
  echo "fix-susfs-namespace-51: susfs_ksu_mounts still referenced after 51_ — usages not cleanly removed" >&2
  exit 1
fi
echo "fix-susfs-namespace-51: OK ($F)"
