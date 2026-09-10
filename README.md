# My Last Tape

**My Last Tape** is a cassette-recording and AutoDJ addon for
[Tali's New Music](https://steamcommunity.com/workshop/filedetails/?id=3739256725)
on **Project Zomboid Build 42.20.3**.

It adds one physical cassette type, `MyLastTape.LastTape`. A blank tape can be
found in the world or received once in single-player, then recorded from
compatible cassettes available to the player. Each physical tape retains its
own playlist, name and recording state across ejection, device changes and
save/load.

## Status

`main` currently contains **MVP 0.6**. The **0.7 pre-release** is being
developed separately and is not part of the published `main` code yet.

## Features in MVP 0.6

- Blank, physical My Last Tape cassettes.
- Low-weight loot distribution in plausible residential, desk, shelf and
  garage containers.
- One blank starter cassette per single-player character.
- Per-cassette recording with tracks resolved through Tali's public music APIs.
- Source scanning limited to the player inventory and currently open loot
  containers.
- Track copying, sound-level deduplication and shuffled recordings.
- Persistent playlist and custom name per physical cassette instance.
- `Rename`, `Record`, `Re-record`, `View Playlist` and `Erase` in Tali's own
  `Cassette` context submenu.
- Tali Fancy UI-compatible cassette visual and insertion animation, using
  references to Tali's existing assets without copying them.

## Requirements and local installation

Enable **Tali's New Music** and **My Last Tape** together. For local testing,
copy the complete `MyLastTape` directory to:

```text
C:\Users\<USER>\Zomboid\mods\MyLastTape\
```

The Build 42 layout is:

```text
MyLastTape/
├── common/
└── 42/
    ├── mod.info
    └── media/
        ├── scripts/
        │   └── MyLastTape_Items.txt
        └── lua/
            ├── client/
            ├── server/
            └── shared/
```

## Known limitations

- MVP 0.6 is single-player/local only. Multiplayer authority and state
  synchronization are not part of the released mod.
- New Music resolves a playlist globally by `MyLastTape.LastTape`. Two My Last
  Tape cassettes inserted simultaneously can temporarily project the same
  tracks, although each cassette's saved playlist remains independent and is
  restored when reinserted.
- Loot only affects containers that generate after the mod is enabled; already
  generated or looted containers are not rerolled.
- A boombox must be placed in the world to emit sound. Tali's boombox shuffle
  works with recorded playlists; its Walkman UI does not expose that control.

## Development history

### Pre-release 0.7 — in development, not yet published

The next pre-release focuses on editing a recorded playlist before saving it
back to the physical cassette: a dedicated playlist editor with reordering,
track removal, shuffle and undo. Its work-in-progress code and the separate MP
test harness are intentionally excluded from `main` until review and testing
are complete.

### MVP 0.6 — Blank cassettes and acquisition

New cassettes are blank: they contain no playlist, do not scan sources during
insertion and cannot play until explicitly recorded. `Record` creates the
playlist and `Re-record` replaces it. The old temporary `NMZomboidTheme2`
fallback is no longer registered for blank tapes.

My Last Tape is injected at low weight into bedroom dressers and side tables,
living-room shelves and side tables, generic desks and shelves, and garage
tools. In single-player, `OnGameStart` grants one blank starter cassette; its
player `ModData` marker prevents duplicates across saves and loads.

### MVP 0.5.2 — Cassette actions

Added `Record`, `Re-record`, `View Playlist` and confirmed `Erase` actions to
Tali's existing `Cassette` context submenu. Recording scans visible sources,
deduplicates and shuffles tracks, then saves the result to the selected
physical cassette. Erase asks for confirmation and preserves a custom name.

### MVP 0.5.1 — Rename

Added per-instance cassette renaming inside Tali's own cassette submenu.
Names are stored under `item:getModData().MyLastTape.name`, reflected in the
inventory and preserved through insertion, ejection and save/load.

### MVP 0.4.1 — Visible source scope

Restricted recording sources to the player inventory and containers currently
open in the loot UI. Closed nearby furniture, vehicles, world containers and
corpses are not scanned.

### MVP 0.4 — Persistent physical playlists

Moved playlist ownership from the playback device to each physical
`InventoryItem`. Tali recreates the cassette when it is ejected; My Last Tape
transfers its state to the newly produced object so the same tape retains its
playlist across device changes and save/load.

### MVP 0.3.1 — Playback lifecycle

Insertion prepares a recorded cassette without reshuffling. Play resumes the
existing playlist and Stop preserves its playlist and current track position.

### MVP 0.3 — Fancy UI visual integration

Reused the visual references from Tali's native `NewMusic.CassettePZOSTA`:

```text
Icon = NM_Cassette_Zomboid
WorldStaticModel = NewMusic.CassetteZomboid
```

This lets Tali's Fancy UI show the cassette and insertion animation without
copying or modifying Tali assets.

### MVP 0.2 — AutoDJ

Established the music discovery pipeline. Compatible source cassettes are
identified through `NMMediaContract.resolveMediaCarrier()` and resolved through
`NMMusic.resolveTracks()`. My Last Tape copies valid tracks, deduplicates by
sound and registers an independent playlist without modifying source catalogs
or assuming `NMTrackCatalog.entries` is universal.

### MVP 0.1 — First working cassette integration

Created `MyLastTape.LastTape`, registered its cassette carrier and track
catalog entry, and verified insertion and playback through Tali's New Music.
