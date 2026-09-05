# Recovery plan — August's five goals

Written 2026-09-05. Companion to `STATUS.md`.

**Hard constraint governing everything below:** iCloud holds 423.8 GB (Documents category);
the internal disk has ~72 GB free. Full local materialisation is impossible. "Optimize Mac
Storage" must stay ON, so most files remain dataless placeholders. The USB backup therefore
cannot be produced by syncing down and copying — it has to come from Apple's side.

---

## Goal 1 — Stop this machine from harming what is in the cloud

**Current state is already safe, for a structural reason:** `bird` propagates a deletion by
comparing its local database against the filesystem. That database
(`~/Library/Application Support/CloudDocs/`) no longer exists. A client with no records cannot
emit a delete. It can only pull down.

Rules for sign-in, in order:

1. **Do not sign in until the USB copy exists** (Goal 4). This is the only real gate.
2. **Empty `~/Desktop` and `~/Documents` first**, or move their current contents aside to a
   folder outside the home. When Desktop & Documents sync is enabled it **merges** the local
   tree into the cloud container. Merge is additive — it will not delete — but it *will* upload
   whatever is sitting there. Right now that is incident logs and screenshots, which should not
   end up in iCloud.
3. **Sign in with Desktop & Documents Folders OFF.** Let plain iCloud Drive settle completely
   first. Enabling D&D is a separate, later, deliberate step.
4. **Leave "Optimize Mac Storage" ON.** With 72 GB free against 423.8 GB, turning it off would
   attempt a full download, fill the disk, and put the sync into an error state.
5. Have a second trusted device to hand — sign-in needs the Apple Account password plus a 2FA
   code, and the local keychain is gone.

---

## Goal 2 — Where the 13 May files came from

**Answer: a bulk data-recovery run on 2026-05-13 at 14:53, during the `may`/`earlymay` account
period.** Not an iCloud event.

Evidence — the log contains five uniform-timestamp clusters, each the signature of a bulk copy
rather than organic file creation:

| Timestamp | Entries | Character |
|---|---|---|
| `Feb 7 2025` | 3,290 | music library import (`.wma`, `.m4a`) |
| `Mar 15 03:04` | 1,586 | ebook extraction (`mimetype`, `container.xml`) |
| **`May 13 14:53`** | **1,038** (513 at CloudDocs root) | the restore in question |
| `Sep 4 19:08` | 876 | `##BOOKSMB` book folders, 2.5 h before the deletion |
| `Sep 4 21:17` | 44 | epub internals |

Recovery tooling present on the machine, which produces exactly this pattern:

```
com.easeus.datarecoverynet      EaseUS Data Recovery Wizard
com.easeus.fixo
com.easeus.downloaderformacdrw
Documents/FileRecover Project
RsyncUI                          (cf. Documents/RsyncUIcopy-07-16-2026:22:49)
```

Corroborating artifacts, all named like recovery output: `Documents/Recovered Files`,
`Documents/FileRecover Project`, `Desktop/iCloud_Recovered`,
`Downloads/Drive/Recovered dropbox`, `Relocated Items/Previously Relocated Items 6` and `7`.

The 13 May date coincides with the `may` and `earlymay` accounts being in use — i.e. a period
of account migration and recovery work.

---

## Goal 3 — RESOLVED by fseventsd (2026-09-05)

`/System/Volumes/Data/.fseventsd` was recovered (2,438 logs, Sep 3 14:57 -> Sep 5 16:04,
unbroken across the whole event) and parsed with `tools/parse_fsevents.py`. 4.77 M events.

**Finding 1 — nothing was written to iCloud at sign-out.** The last log file containing *any*
`Mobile Documents` event is `00000000326b8812`, mtime **Sep 4 21:51**. The keychain was destroyed
and the account signed out at **21:53**. Logs at 21:52, 21:53, 21:54 and 21:55 contain **zero**
`Mobile Documents` events.

So the visa/government PDFs did **not** appear at sign-out. They were already in the container;
what changed was that `ls -le` enumerated it. The earlier hypothesis of an external agent
manipulating sync is not supported — and now has direct evidence against it.

**Finding 2 — the `##BOOKSMB` activity was August's own, and my earlier framing conflated two
different clocks.** The "Sep 4 19:08" figure was a *file mtime* read out of an `ls` listing
inside the terminal log. The "21:40-22:57" figures were the *mtimes of the fseventsd log files
themselves*. Different measurements entirely; there was never a gap. fsevents in fact shows
`##BOOKSMB` activity in logs stamped 19:07 **and** 21:23-21:25, i.e. continuous.

---

## Goal 3b — 87 of 108 "lost" home-root items have an iCloud copy

Cross-referencing every basename under `com~apple~CloudDocs/` (210,915 distinct) against the
109-entry pre-deletion home-root manifest:

| | count |
|---|---|
| Home-root items with a same-named copy in iCloud Drive | **87** |
| No copy found anywhere in iCloud | 21 |

Includes the two sets previously written off as unrecoverable:

- **All 37 `Doc NN Ares(20xx)...pdf`** -> `iCloud Drive/Zips/Documents EASE 2023 3854/`
  and `iCloud Drive/UK statute review/Documents EASE 2023 3854/`
- **58 distinct `SCAN00xx.JPG`** -> `iCloud Drive/UK statute review/Part 1,2,3,5,7/`
  and `iCloud Drive/Zips/zips2/Part 1, Part 5/`

The home-root copies were extractions from those iCloud archives, not originals.

Full mapping: `icloud-recovery-map.txt`. Items with no iCloud copy: `icloud-not-found.txt` —
mostly ephemeral dev dirs (`kube`, `meta`, `system`, `vm`, `virtualization`, `enabled`,
`Public`), plus genuinely-gone work: `jobspy-mcp-server`, `multi-container-app`,
`claude worktrees`, `claude-network-skills`, `tictactoe.py`, `Untitled.xcworkspace`,
`skills-lock.json`, `MEGA`, `Duplicates`, `duplicate_finder.sh`, `system.json`,
`diagnostics.log`, `network_stability.log`, `2026-08-24-053930-setup.txt`.

**Caveat:** this matches on *filename*, not content or hash. A same-named file in iCloud is a
strong lead, not proof of identity. Verify size/date on the ones that matter.

### Reading the numbers (they lie on two different axes)

| Set | Meaning | Status |
|---|---|---|
| 108 | the pre-deletion home-root manifest | all deleted locally |
| 87 | of those, a same-named copy exists in iCloud | **recoverable** |
| 21 | of those, no copy found anywhere | **lost** |
| 513 | files at iCloud Drive **root**, mtime May 13 14:53 | **never lost** |

Within the 87: 37 Ares + 29 SCAN + 21 other. That inner 21 is arithmetic coincidence and is
*not* the 21 lost files.

**58** was a separate measurement — distinct `SCAN00xx.JPG` names *anywhere* in iCloud, a
superset of the 29 that were at home root. It does not belong to the 21+87 split.

**Recoverable when:** nothing is recoverable locally — the files are gone from disk and fsevents
yields names only, never content. The 87 are downloadable from iCloud.com **now**, without
re-login; re-login only changes the access route, not what exists. The 513 need no recovery.

**Storage after re-login:** unchanged at ~423.8 GB. The 87 are already counted inside it;
recovery copies data down rather than adding it. Only Desktop & Documents sync uploading local
files would increase the total — which is why that stays off until last.

### Were the May-13 files "resurrected"? No — demonstrated

Across all 513 during the fsevents window (Sep 3 - Sep 5):

```
Created events:            0
touched, metadata only:  511
```

Their events cluster at Sep 4 20:33, 20:34, 20:47, 20:52, 21:48, 21:49 — matching August's own
`chmod -Rv ug+rwx`, `chflags -Rv nohidden` and `dot_clean` runs against the CloudDocs container.
Permission and xattr changes on files that already existed. Always there, not hidden, never
created or moved during the window. What changed is that `ls -le` enumerated the container root,
where 746 loose items make individual files easy to miss in Finder.

### Do NOT normalise xattrs/permissions on that set

An earlier draft of this plan suggested `xattr -c -r` and `chmod -R` over the 513 files as
hygiene. **Retracted.** Recursive permission/flag operations against the live iCloud container
are exactly the activity that preceded the loss. The xattrs are inert: they do not hide files,
do not affect sync, and the fsevents evidence shows they caused nothing.

---

## Goal 4 — Local backup of cloud files onto USB

The Mac cannot be the source (72 GB free vs 423.8 GB). Two workable routes:

**Route A — Apple data export (recommended).** privacy.apple.com -> "Request a copy of your
data" -> select iCloud Drive (and Photos if wanted). Apple assembles it server-side and delivers
download links, split into chunks (selectable, e.g. 25 GB). Download chunks straight to the USB
drive. This Mac's sync state is never involved, so it cannot affect the cloud copy. Turnaround
is typically several days.

**Route B — a second Mac with enough free space.** Sign in there, disable Optimize Mac Storage,
let iCloud Drive materialise fully, then copy to USB. Faster if such a machine exists; needs
>424 GB free.

Do not attempt Route B on this machine.

**Photos are separate** — the 59.5 GB / 19,012 photos / 3,036 videos live in the Photos library,
not iCloud Drive. Include Photos explicitly in the export request, or export from Photos on
another device.

---

## Goal 5 — Verify sync-down changes nothing

**Baseline, captured from iCloud.com on 2026-09-05 (before any sign-in):**

| Location | Items |
|---|---|
| iCloud Drive root | 746 |
| `Documents` | 45 |
| `Desktop` | 32 |
| `Downloads` | 18 |

Storage: 573.9 GB used — Documents 423.8, iCloud Backup 86.2 (2 devices), Photos 59.5
(19,012 photos, 3,036 videos), Messages 3.4.

Procedure:

1. **Before sign-in:** re-check those four counts on the web and confirm they still match. Any
   drift while the Mac is signed out means something other than this machine is changing the
   account — that would be the one finding that justifies August's concern, and it must be
   settled before proceeding.
2. **Sign in** per Goal 1 (D&D off, Optimize Storage on).
3. **Immediately after the first sync settles,** re-check the same four counts on the web. They
   must be unchanged. Expect no change: a client with no local database can only pull.
4. **Enumerate locally** and compare against the web listing:
   ```
   find ~/Library/Mobile\ Documents/com~apple~CloudDocs -maxdepth 1 | wc -l
   ```
   Placeholders count as present — dataless is normal and expected here.
5. **Only then** enable Desktop & Documents Folders, having first emptied the local folders per
   Goal 1 step 2. Re-check the counts a third time; expect `Desktop` and `Documents` to be
   unchanged or higher, never lower.
6. If any count drops at any stage, **sign out immediately** — that halts the client — and
   re-assess before touching anything else.

---

## Open item

`/System/Volumes/Data/.fseventsd` has not been read — it needs sudo, which the assistant does not
have (`sudo: a password is required`). August must run it. It is the only remaining route
to a file-level list of what was at `~/` root and in local `~/Downloads` — the part of the loss
that iCloud does not cover. Command:

```
sudo ls -la /System/Volumes/Data/.fseventsd
```
