#!/usr/bin/env bash
# fix-susfs-namespace.sh — anchor-based, idempotent re-insertion of the susfs
# SUS_MOUNT include + declaration block into fs/namespace.c.
#
# Why this exists:
#   50_add_susfs_in_gki-android14-6.1.patch is shared across every 6.1.x sublevel
#   (the path carries no sublevel). On newer ACK snapshots the top include list of
#   fs/namespace.c drifted, so Hunk #1 (only) rejects even at fuzz-3 (observed on
#   android14-6.1.157). Hunks #2..#9 of the SAME patch still apply and *reference*
#   susfs_ksu_mounts / CL_COPY_MNT_NS / susfs_is_current_ksu_domain(), so this block
#   is mandatory for the tree to compile — it is not optional cosmetics.
#
#   Rather than fork the patch per sublevel, we re-insert the identical block keyed
#   on two anchors that are present in every 6.1.x namespace.c:
#     - "#include <linux/mnt_idmapping.h>"  → include block goes right after
#     - "#include \"internal.h\""            → declaration block goes right after
#
# Idempotent: if susfs_ksu_mounts already exists (patch applied cleanly on this
# sublevel), it is a no-op. Fails loud on a missing anchor.
set -euo pipefail

F="${1:?usage: fix-susfs-namespace.sh <path/to/fs/namespace.c>}"
[ -f "$F" ] || { echo "fix-susfs-namespace: $F not found" >&2; exit 1; }

if grep -q 'susfs_ksu_mounts' "$F"; then
  echo "fix-susfs-namespace: block already present in $F — skip (idempotent)"
  exit 0
fi

python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
src = open(p).read()

inc_anchor = '#include <linux/mnt_idmapping.h>\n'
inc_block = (
    '#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n'
    '#include <linux/susfs_def.h>\n'
    '#endif // #ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n'
)

decl_anchor = '#include "internal.h"\n'
decl_block = (
    '\n'
    '#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n'
    'extern bool susfs_is_current_ksu_domain(void);\n'
    'extern bool susfs_is_sdcard_android_data_decrypted __read_mostly;\n'
    '\n'
    'static atomic64_t susfs_ksu_mounts = ATOMIC64_INIT(0);\n'
    '\n'
    '#define CL_COPY_MNT_NS BIT(25) /* used by copy_mnt_ns() */\n'
    '#endif // #ifdef CONFIG_KSU_SUSFS_SUS_MOUNT\n'
)

if inc_anchor not in src:
    sys.exit("fix-susfs-namespace: include anchor not found (mnt_idmapping.h)")
if decl_anchor not in src:
    sys.exit('fix-susfs-namespace: decl anchor not found (#include "internal.h")')

# First occurrence only — both anchors are unique in fs/namespace.c.
src = src.replace(inc_anchor, inc_anchor + inc_block, 1)
src = src.replace(decl_anchor, decl_anchor + decl_block, 1)

open(p, 'w').write(src)
print("fix-susfs-namespace: inserted susfs SUS_MOUNT block into", p)
PY

grep -q 'susfs_ksu_mounts' "$F" \
  || { echo "fix-susfs-namespace: post-check failed — block not inserted" >&2; exit 1; }
echo "fix-susfs-namespace: OK ($F)"
