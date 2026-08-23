require "music/NMTrackCatalog"
require "contracts/NMMediaContract"

print("[MyLastTape] Registering cassette")

NMMediaContract.registerMediaTypeAlias(
    "LastTape",
    "nm_carrier_cassette"
)

NMTrackCatalog.registerEntry(
    "MyLastTape.LastTape",
    "nm_carrier_cassette",
    {
        {
            sound = "NMZomboidTheme2",
            label = "My Last Tape - Test Track",
            trackNumber = 1
        }
    }
)

print("[MyLastTape] Cassette registered successfully")
