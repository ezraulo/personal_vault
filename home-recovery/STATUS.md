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

**Desktop & Documents Folders sync — RESOLVED: it was ON.** (2026-09-05, from iCloud.com)

An earlier reading of this brief said the evidence pointed to "off", because `Desktop` and
`Documents` were absent from the pre-deletion listing of
`~/Library/Mobile Documents/com~apple~CloudDocs/`. **That inference was wrong.** Since macOS 13
iCloud Drive runs on the File Provider architecture and the Desktop & Documents sync roots
stay at `~/Desktop` and `~/Documents`; they are not subfolders of the legacy `com~apple~CloudDocs`
path. Their absence there proves nothing. (`Downloads` *was* in that listing because it is an
ordinary user folder, not a sync root.)

Proof from the web UI: iCloud Drive's `Documents` folder contains
`bruno`, `com~apple~CloudDocs`, `com~apple~CloudDocs 2`, `Desktop`, `Documents - may - 1`,
`FileRecover Project`, `Lenovo Desktop`, `MuseScore4`, `Obsidian Vault`, `Recovered Files`,
`RsyncUIcopy-07-16-2026:22:49` — a 100% match with the `~/Documents` subdirectories in
`manifest-userdata-dirs.txt`, including the colon-bearing name.

**Consequences:**

- `~/Desktop` and `~/Documents` are **intact and current** server-side. Web Desktop holds
  `IMG_6056`–`IMG_6176` dated 2026-09-04 05:31, hours before the deletion.
- **The deletion never propagated.** Empty Recently Deleted + intact deletion-day content
  confirms from the server side that `bird`'s database died with the keychain before it could
  emit a delete.
- Remaining loss is narrower than previously stated: **files loose at `~/` root**, and
  **local `~/Downloads`** (`Drive`, the Apple/Facebook/Instagram SARs, `iCloud Notes`, the
  Logic session). The web `Downloads` is a different folder — 18 items, none of that content.

**Note on Recently Deleted:** reported empty for months, which August suspects is a stuck
recovery area worth raising with Apple. Independently of that fault, nothing was expected in
it here.

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

**Resolved (2026-09-05):** the files August recalled "resurfacing" are the UK/Spanish
visa and government documents. They were not resurrected — they arrived in a **bulk restore on
13 May 2026**. Of ~701 entries at the CloudDocs top level, **513 carry the identical mtime
`May 13 14:53`**, the signature of a mass copy rather than organic creation. Examples:

```
-rwxrwxrwx  May 13 14:53  $RESOLUCION-NACIONALIDAD-ESPANOLA-DOBLE-NACIONALIDAD.pdf
-rwxrwxrwx  May 13 14:53  Exemption from immigration control (Non armed forces) - GOV.UK.pdf
-rwxrwxrwx  May 13 14:53  Immigration Rules part 5: working in the UK - GOV.UK.webarchive
-rwxrwxrwx  May 13 14:53  concesiones-de-nacionalidad-espanola-*.csv   (4 files)
-rwxrwxrwx  May 13 14:53  20250319_Pre-action_Protocol_for_Judicial_Review.odt
```

13 May is the `may`/`earlymay` account era. The files have sat in CloudDocs since and only
became visible when `ls -le` enumerated the container. **They are on iCloud now and not at
risk.** The 513-file May restore is a distinct corpus worth reviewing on its own.

**On permissions:** the `-rwxrwxrwx` seen on those files is loose, not strict, and came from
August's own `chmod -R ug+rwx` runs. The later reversion to `644`/`755` is normal — iCloud does
not preserve POSIX modes, so re-materialised files return at defaults. Not damage.
