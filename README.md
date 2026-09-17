# GM Helper

GM Helper is an Ashita v4 addon that turns the usual wall of `!` commands into a small panel you can search, fill in, favorite, and fire off without juggling chat macros.

<img width="704" height="460" alt="Image" src="https://github.com/user-attachments/assets/53819a00-372a-4e0f-834a-0b34f46254ad" />

## Features

- **Commands** — GM commands grouped and searchable, with field helpers and database lookups
- **Favorites** — Save commands or presets into your own tabs, drag to reorder, and run them in one click
- **Scripts** — Stack several lines with waits, then edit, rename, move, or stop a run whenever you need
- **Presets** — Ready-made packs such as Judge's Armor, with a live countdown while they execute
- **History** — Keep a trail of what you sent and send it again from the list
- **Settings** — GM tier visibility, preset pacing, history size/format, plus a built-in command cheat sheet
- **Chat Shortcuts** — Kick off favorites, scripts, and presets from chat, or halt whatever is mid-run

## Install

1. Download the latest release from the [releases page](https://github.com/NerfOnline/GMHelper/releases)
2. Extract the zip and copy the `gmhelper` folder into your Ashita `addons` directory
3. In-game: `/addon load gmhelper`
4. Open the panel: `/gmh` or `/gmhelper`

To auto-load on startup, add `/addon load gmhelper` to your Ashita script or profile.

## Commands

- **`/gmh`** / **`/gmhelper`** — Opens or closes the GM Helper window
- **`/gmh favorites <tab> <number>`** — Runs a favorite from that tab by its row number
- **`/gmh scripts <tab> <number>`** — Runs a script from that tab by its row number
- **`/gmh presets <number>`** — Runs a preset by its row number
- **`/gmh scripts stop`** — Stops the script that is currently running
- **`/gmh presets stop`** — Stops the preset that is currently running
