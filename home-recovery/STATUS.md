# Home folder loss — status brief

**Machine:** MacBook Air (Apple Silicon), user `august`, home created by migration 2026-08-20.
**Loss:** night of 2026-09-04. **Brief:** 2026-09-05.

Out of scope: the backup drives attached to the machine. Nothing below depends on them.

---

## 1. What the recovery picture actually is

- **No APFS local snapshots** ever existed on the internal disk — every `disk3` slice came
  back clean. That route was never open.
- **Carving is closed.** Apple Silicon, hardware-encrypted SSD, aggressive TRIM.
- **iCloud server-side is the only live source.**

The account was signed out on this Mac when the delete destroyed the login keychain — macOS
lost the credentials and dropped the session. That severed sync before the empty local state
could propagate, which is why the server copy survived. Nothing local can push a deletion
right now.

---

## 2. What iCloud covers, and what it doesn't

**Covered:** whatever lived in `~/Library/Mobile Documents/com~apple~CloudDocs`, plus Photos,
Notes and Contacts. Each keeps its own 30-day **Recently Deleted** bin — check all three.

**Not covered:** files sitting loose at `~/` root. No iCloud feature syncs those — not iCloud
Drive, not Desktop & Documents Folders. From the manifest, that's:

- 37 × `Doc NN Ares(2022|2023)… .pdf` — EU Commission GDPR-procedure meeting documents
- `SCAN0009`–`SCAN0029`, `SCAN0058`–`SCAN0065` `.JPG` (29 scans)
- `app/`, `backend/`, `docker/`, `jobspy-mcp-server/`, `multi-container-app/`,
  `virtualization/`, `vm/`, `network/`, `system/`, `kube/`, `meta/`, `mutagen/`, `profile/`
- `claude worktrees/`, `claude-network-skills/`, `#AI/`, `Index/`, `Duplicates/`,
  `Part 3/`, `MEGA/`
- `tictactoe.py`, `duplicate_finder.sh`, `Untitled.xcworkspace/`, `package.json` +
  `package-lock.json` + `node_modules/`, `skills-lock.json`, `system.json`,
  `diagnostics.log`, `network_stability.log`, `2026-08-24-053930-setup.txt`

**Desktop & Documents Folders sync — unresolved conflict (2026-09-05).**

August states the toggle was ON before the deletion. The log evidence points the other way:

- With D&D sync on, macOS creates `Desktop` and `Documents` *inside* the iCloud container.
  The pre-deletion listing of `~/Library/Mobile Documents/com~apple~CloudDocs/`
  (log line 58831, 701 entries) contains neither. It has `Desktop - 0$Smacannoy`,
  `DEVICE IDS`, `docs`, `Downloads` — but no `Desktop` and no `Documents`.
- Post-deletion, `~/Desktop` and `~/Documents` were real directories
  (`drwxrwx--- 2 … 64`), not redirects.

**Resolve it with one check:** open iCloud Drive on iCloud.com. Are there `Desktop` and
`Documents` folders at the top level?

- Yes -> sync was on, that content is server-side, and it is the bulk of the loss recovered.
- No -> the toggle may have been set but the container never materialised on this machine
  (this home was built by the 2026-08-20 migration); Desktop and Documents were local-only.

A reconciliation in which both are true: if sync was on earlier and later switched off, macOS
moves the cloud copies out to local folders and **leaves the server-side `Desktop`/`Documents`
in place**. The web would still hold them. Worth looking for specifically.

Either way the top action is the same — **check Recently Deleted first**. If sync was live,
the `rm -rf` hit synced folders with the daemon running, so deletions could have propagated
during the ~9 minutes before the keychain died. That is what the 30-day bin would hold.

Other places copies may exist, worth a pass: git remotes; Dropbox / Google Drive / OneDrive
30-day server-side trash; IMAP mail, which re-downloads.

---

## 2a. Re-signing into iCloud — why it is safe, and the one gate

**Verified on 2026-09-05, machine still signed out:**

```
~/Library/Application Support/CloudDocs/   ->  No such file or directory   (bird session db)
~/Library/Mobile Documents/                ->  No such file or directory
com.apple.bird among Daemon Containers     ->  absent (14 containers, none is bird)
MobileMeAccounts domain                    ->  does not exist
ckksctl                                    ->  "no account"
otctl                                      ->  "User is not signed into iCloud"
```

`bird` propagates a deletion because its local database holds a record for an item and sees
that record's target vanish. With no database there is no record, so no delete can be
generated. On sign-in the client bootstraps from the server and pulls down. Sync is
bidirectional and, with an empty local slate, the server wins.

**The exception:** "Desktop & Documents Folders" is not plain sync — enabling it *merges* the
current local tree into the cloud container. Leave it off until a verified off-device copy
exists. Not until iCloud Drive "looks right" — until a copy exists.

**Running clock:** anything pushed server-side in the ~9 minutes between the delete (≈21:44)
and the sign-out (≈21:53) sits in Recently Deleted until ≈2026-10-04. Three separate bins:
iCloud Drive, Photos, Notes. Checking them is also the server-side confirmation of the above —
if they hold none of the lost Desktop/Documents content, nothing propagated.

**Off-device copy without needing USB space:** privacy.apple.com -> Request a copy of your
data. Server-side archives delivered as download links; this Mac's sync state is not involved.

---

## 2b. Local metadata — what it can and cannot do

Content blocks are unrecoverable (Apple Silicon, hardware encryption, TRIM). **Metadata
recovery is not undelete.** What it buys is a file-level checklist, which is precisely what is
missing — there is no file-level inventory of Desktop, Documents or Downloads. That turns
"unknown loss" into targeted re-acquisition: re-clone from git remotes, re-request the Ares
documents from source, re-download what is re-downloadable.

| Lead | Status |
|---|---|
| `/System/Volumes/Data/.fseventsd` | **Live.** Path-level create/delete event log. Needs sudo. Best remaining lead. |
| `QuarantineEventsV2` | Dead. 33 events, earliest 2026-09-04 21:16 — rebuilt after the loss. |
| Spotlight index, Data volume | Dead. Was in an error state before the loss. |
| `otctl` / `ckksctl` | Not applicable. Octagon = device-trust circle; CKKS = keychain sync. Neither indexes file records. |
| `brctl` | Unusable until sign-in; fails on both Full Disk Access and no-account. |

**No reason to stay powered on.** The CloudDocs db is already gone and deleted-but-open file
handles were checked at ~0 GB. `.fseventsd` survives reboot.

---

## 3. Current state — nothing has been restored

`~` is 39 GB, which reads like progress. It isn't:

| Path | Size | What |
|---|---|---|
| `Library` | 24 G | rebuilt system/app support |
| `lmstudio-community` | 6.4 G | LLM models pulled today |
| `Applications`, `Claude.app` | 1.6 G | apps installed today |
| `Downloads` | 827 M | two Claude `.dmg`, foundationdb, `lit.macos_arm64` — all today |
| `Documents` | 93 M | the incident logs, nothing else |
| `Desktop` | 292 K | two screenshots + `MyPlayground.playground` |

Zero recovered user files.

---

## 4. Order of operations

1. **Settle the Desktop & Documents sync question** — it decides whether the loss is
   "home-root loose files" or "home-root plus all of Desktop and Documents."
2. **Attach an external drive** as the download target.
3. **Pull iCloud Drive down from another device**, not this one. Check Recently Deleted in
   iCloud Drive, Photos and Notes while you're in there.
4. **Reconcile against `manifest-home-root.txt`** — 109 entries; tick each off and see what
   is left unaccounted for.
5. **Then** sign back in here, with Desktop & Documents sync left off until iCloud Drive has
   populated and looks right. Sign-in needs the Apple Account password plus a 2FA code and the
   local keychain is gone — have a second trusted device ready before you start.

---

## 5. What happened

`~/Documents/Terminal Saved Output.txt` (1.25 M lines) is the session that ran up to the loss:
hours of `sudo chmod -R` / `chflags -R` / `dot_clean` against
`~/Library/Mobile Documents/com~apple~CloudDocs`, trying to clear a stuck
`Nextcloud-…@icloud.com` folder that refused to delete ("Directory not empty",
`ls: fts_read: Operation timed out`). At line 1240861:

```
sudo rm -rf /Users/august/.Trash/../
```

Home had 165 entries at 21:44 and ~22 by 22:31. The exact command isn't definitively
isolatable from the log — the output region is overwritten by a zsh completion menu, and BSD
`rm` normally refuses a `..` basename — and it changes nothing downstream.

The later `rm -rWv` did nothing: `-W` undeletes whiteout entries, a union-filesystem concept
that does not exist on APFS.

---

## 6. Manifests in this folder

Extracted from the pre-deletion log. These are what make a restore verifiable.

| File | Source | Contents |
|---|---|---|
| `manifest-home-root.txt` | zsh completion listing, log line 1240861 | 109 top-level entries of `~` minutes before the loss |
| `manifest-userdata-dirs.txt` | `chflags -Rv` output | 603 dirs under Desktop/Documents/Downloads/Movies/Music/Pictures/Public |
| `manifest-directories.txt` | same | 2,372 dirs across all of `~` |
| `manifest-library-tree.txt` | `ls -leR` headers | 3,159 paths under `~/Library` |

Completeness caveat: `chflags -v` prints only entries whose flags actually changed, so those
two files are **directory**-level, not file-level. The only file-level listings in the logs
cover `~/Library`. There is no file-level inventory of Desktop, Documents or Downloads —
`manifest-home-root.txt` is the one exact list.

---

## 7. Source files in `~/Documents`

| File | Note |
|---|---|
| `Terminal Saved Output.txt` (84 MB) | pre-loss session; source of the manifests. Keep. |
| `Terminal Saved Output part 2.txt` (1 MB) | post-loss session from 22:31; documents the empty home |
| `access https:claude.ai:share:d7b217e5….md` | transcript of the first recovery conversation |
| `MacBook Air.spx` (8 MB) | System Profiler dump, 23:11 |
| `shared-2-CnGcyoGR.pdf` | failed print-to-PDF of a claude.ai share page — captured the JS bundle, not the conversation. No value. |

These exist only on the damaged machine. Copy them to the external drive too.

---

## 8. "Root-owned mystery files" — what was checked

August raised files appearing at home root with unexplained origin. Findings, 2026-09-05:

- **No root-owned entries exist anywhere in the pre-deletion home listings.** Everything was
  `august staff`. The only root-owned files in the home now are `.lesshst` and
  `anthropic_ip_fix.sh`, both created 2026-09-05 by August's own `sudo` use.
- **`/Users/Shared/Relocated Items/`** (root:wheel, 2026-08-20 08:32) **survived the deletion**
  — it sits outside the home. This is the genuine mechanism by which root-owned files appear
  unexplained: macOS parks files it cannot place during migration or OS upgrade there.
  Contents here are only OS ssh config defaults (`ssh.system_default/`), no user data.
- The mechanism has clearly fired repeatedly on this machine's lineage. Related artifacts in
  the manifests: `Desktop/iCloud_Recovered`, `Documents/Recovered Files`,
  `Documents/FileRecover Project`, `Downloads/Drive/Recovered dropbox`, and
  `Relocated Items/Previously Relocated Items 6` and `7` nested inside `Drive MB`.

**Open:** which files August means is not yet identified — candidates are the 37 Ares GDPR
PDFs and the 29 `SCAN*.JPG` at home root. Origin tracing is possible from the manifests once
the target is named.
