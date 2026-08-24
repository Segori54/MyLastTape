# My Last Tape

Minimal cassette addon for Tali's New Music on Project Zomboid Build 42.20.x.

## MVP-0.2: AutoDJ

When `MyLastTape.LastTape` is inserted, My Last Tape scans the player's accessible source inventories, finds cassette items through `NMMediaContract.resolveMediaCarrier()`, resolves each cassette through `NMMusic.resolveTracks()`, copies valid tracks, deduplicates by sound, shuffles the independent list, and registers it as its own playlist. It does not use `NMTrackCatalog.entries` as the universal source and never modifies source catalogs.

The playlist is rebuilt before insertion and before playing a cassette that was already inserted. It is not rebuilt every frame or at track changes; Tali's normal `next_track` and track-finished progression advance through the shuffled list.

MVP-0.2 is intentionally single-player only. The AutoDJ rebuild is disabled for multiplayer because dynamic client-side catalog entries are not synchronized by this prototype.

## Local testing

Copy the complete `MyLastTape` folder to:

```text
C:\Users\<USER>\Zomboid\mods\MyLastTape\
```

The required Build 42 layout is:

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
            │   └── MyLastTape_AutoDJClient.lua
            └── shared/
                └── MyLastTape_Register.lua
```

Enable Tali's New Music and My Last Tape in the Project Zomboid launcher before testing.

For MVP-0.2, insert `My Last Tape` in a New Music-compatible player and start playback. The console should report the generated AutoDJ playlist and its track count.
