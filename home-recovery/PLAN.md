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

## Goal 3 — What moved them since, and to where

**Status: unresolved. An earlier explanation in this file was wrong and is retracted.**

The retracted claim: that iCloud *eviction* explained files "resurfacing" in a listing. It does
not. An evicted iCloud file is a dataless placeholder — its **name still appears in `ls`**.
Eviction hides content, not directory entries. So eviction cannot explain a file being absent
from one `ls` and present in a later one. August identified this; the mechanism was misapplied.

What the log does establish, tested directly: the session contains **two** enumerations of
iCloud Drive root, at lines 16253 and 58831. Both are non-recursive `ls -le` of
`~/Library/Mobile Documents/com~apple~CloudDocs/`:

```
Listing A (line 16253): 701 entries, 11 visa/immigration files
Listing B (line 58831): 701 entries, 11 visa/immigration files
diff A B  ->  IDENTICAL (byte-for-byte)
```

So nothing changed between them. What cannot be established: whether the files were absent from
any *earlier* listing. Line 16253 is the first enumeration of iCloud Drive root in the log;
there is nothing before it to compare against, and the session prior to that point was not
captured. August's recollection — that the files did not appear until after the iCloud sign-out
— is therefore **outside the evidence, neither confirmed nor refuted**.

Remaining candidate explanations, undecided:
- the files were genuinely added to the container at some point not covered by the log;
- the earlier non-sighting was in Finder rather than `ls` (746 loose items at iCloud Drive root
  make individual files easy to miss).

**Also retracted:** the claim that the `Sep 4 19:08` cluster correlates with August's `rsync`
runs. It does not — those rsyncs targeted `~/Downloads/Drive/` -> `~/Downloads/iCloud Drive/`,
a different tree. The 876 entries at `Sep 4 19:08` are book folders inside
`com~apple~CloudDocs/##BOOKSMB` (log line 8010). What touched them at that time is not
established. They are unrelated to the May 13 files.

**Note on permissions:** the `-rwxrwxrwx` modes seen on the May files came from August's own
`chmod -R ug+rwx` runs. The later reversion to `644`/`755` is expected — iCloud does not
preserve POSIX modes, so re-materialised files return at defaults. Not tampering.

**Where the May 13 files live online:** at the **top level of iCloud Drive**, loose, not in a
folder. Both listings were non-recursive, so all 513 entries are root-level items. In the web UI
that is the `iCloud Drive — 746 items` view; sorted by Date they cluster around 13 May. Full
list: `icloud-root-may13-files.txt` in this folder.

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
