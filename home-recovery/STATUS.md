# Home folder loss — status brief

**Machine:** MacBook Air (Apple Silicon), user `august`, home created by migration 2026-08-20.
**Loss:** night of 2026-09-04. **Brief:** 2026-09-05.
**Scope constraint (user):** backups older than two weeks are not of interest.

---

## 1. The consequence of the two-week rule

Nothing on any attached drive falls inside the window (on/after ~2026-08-22):

| Source | Newest data | In window? |
|---|---|---|
| APFS local snapshots, internal disk | none exist | — |
| `mayTM` (disk7s3) | 2026-05-14 | no |
| `marchTM` (disk11s1) | 2026-04-10 | no |
| `blackTMsonoma` (disk11s2) | 2023-era | no |
| `Backups of 0$Smacpain` (disk10s1) | 2024-01, all `.interrupted` | no |

None of them contains a `/Users/august` home in any case — they hold the earlier accounts
`december`, `may`, `earlymay`. **Time Machine is not a recovery path here.** The drives are
free to repartition; the `diskutil`/`gpt`/`fdisk` work in your shell history isn't putting
anything you want at risk.

**That leaves one live source: iCloud, server-side.**

---

## 2. What iCloud can and cannot cover

Signed out on this Mac (the delete destroyed the login keychain, macOS dropped the account,
and that severed sync before the empty state could propagate — which is why the server copy
survived). Nothing local can push a deletion right now.

**Covered:** whatever was in `~/Library/Mobile Documents/com~apple~CloudDocs`, plus Photos,
Notes, Contacts. Each has its own 30-day **Recently Deleted** bin — check all three.

**Not covered — and this is the part that matters:** files sitting loose at `~/` root. No
iCloud feature syncs those. Not iCloud Drive, not Desktop & Documents Folders. From the
pre-deletion manifest, that includes:

- 37 × `Doc NN Ares(2022|2023)… .pdf` — EU Commission GDPR-procedure meeting documents
- `SCAN0009`–`SCAN0029`, `SCAN0058`–`SCAN0065` `.JPG` (29 scans)
- `app/`, `backend/`, `docker/`, `jobspy-mcp-server/`, `multi-container-app/`,
  `virtualization/`, `vm/`, `network/`, `system/`, `kube/`, `meta/`, `mutagen/`, `profile/`
- `claude worktrees/`, `claude-network-skills/`, `#AI/`, `Index/`, `Duplicates/`,
  `Part 3/`, `MEGA/`
- `tictactoe.py`, `duplicate_finder.sh`, `Untitled.xcworkspace/`, `package.json` +
  `package-lock.json` + `node_modules/`, `skills-lock.json`, `system.json`,
  `diagnostics.log`, `network_stability.log`, `2026-08-24-053930-setup.txt`

Anything in that list created after the 2026-08-20 migration has no copy anywhere. Anything
older may have arrived with the migration and could still exist in an older backup — but by
your rule those are out of scope, so treat the list as lost unless you say otherwise.

**Open question that changes the size of the loss:** was "Desktop & Documents Folders" sync
switched on? Weak evidence says no — `~/Documents` contained `com~apple~CloudDocs` and
`com~apple~CloudDocs 2` as *subdirectories*, which is not how the folder looks when it is
itself the synced target. If sync was off, everything under `~/Desktop` and `~/Documents`
(`Obsidian Vault`, `FileRecover Project`, `Recovered Files`, `Lenovo Desktop`,
`Documents - may - 1`, `bruno`, `MuseScore4`, `RsyncUIcopy-07-16-2026:22:49`) is in the same
position as the home-root files. If it was on, that whole tree comes back.

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

1. **Answer the Desktop & Documents sync question** — it decides whether the loss is
   "home-root loose files" or "home-root plus all of Desktop and Documents."
2. **Attach an external drive** as the download target. Not `Restore` (disk7s1): it shares
   an APFS container with `mayTM` and has ~33 GiB free between them, not the 201 GiB `df` implies.
3. **Pull iCloud Drive down from another device**, not this one. Check Recently Deleted in
   iCloud Drive, Photos and Notes while you're there.
4. **Reconcile against `manifest-home-root.txt`** — 109 entries; tick each one off and see
   what's left unaccounted for.
5. **Then** sign back into iCloud here, with Desktop & Documents sync left off until iCloud
   Drive has populated and looks correct. Needs the Apple Account password plus a 2FA code and
   the local keychain is gone — have a second trusted device ready before starting.
6. Set up a fresh Time Machine destination once this settles. If macOS offers to adopt one of
   the existing backup drives, that's now your call rather than a hazard.

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
`rm` normally refuses a `..` basename — and it doesn't change anything downstream.

The later `rm -rWv` did nothing: `-W` undeletes whiteout entries, a union-filesystem concept
that doesn't exist on APFS.

Local carving is closed — Apple Silicon, hardware-encrypted SSD, aggressive TRIM, and no APFS
snapshots ever existed on any `disk3` slice.

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
