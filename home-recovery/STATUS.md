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

**The open question that sizes everything else:** was "Desktop & Documents Folders" sync on?
Weak evidence says no — `~/Documents` contained `com~apple~CloudDocs` and
`com~apple~CloudDocs 2` as *subdirectories*, which is not how that folder looks when it is
itself the sync target. If sync was off, the whole Desktop and Documents tree
(`Obsidian Vault`, `FileRecover Project`, `Recovered Files`, `Lenovo Desktop`,
`Documents - may - 1`, `bruno`, `MuseScore4`, `RsyncUIcopy-07-16-2026:22:49`) sits in the same
position as the home-root files.

Other places copies may exist, worth a pass: git remotes; Dropbox / Google Drive / OneDrive
30-day server-side trash; IMAP mail, which re-downloads.

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
