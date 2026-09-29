# Chest Chase

Roblox game. The game itself lives in a Studio place file (`sap_F.rbxl`); this repo holds a
read-only **export of its live scripts** so changes can be tracked and diffed.

- `src/` — every Script / LocalScript / ModuleScript outside `ServerStorage` (the backup archive is skipped),
  laid out by place hierarchy. Extensions follow Rojo naming: `.server.lua`, `.client.lua`, `.lua` (module),
  `init.*` when a script has script children. Sources are written byte-for-byte (LF, UTF-8 emoji kept).
- `src/MANIFEST.tsv` — class, in-place path and file for each exported script.
- `tools/rbxl.py`, `tools/export.py` — binary `.rbxl` reader (zstd/LZ4 via system libs through ctypes) and exporter.
  Re-export: `python3 tools/export.py path/to/place.rbxl src` (delete `src` first).
- `docs/HANDOFF.md` — project state, map geometry, known bugs, install/undo scripts.

Studio is still the source of truth. Editing files here does **not** change the game;
changes still go in via a Command Bar installer (with backup + undo), per `docs/HANDOFF.md`.

Current export: `Config.Version = 'V149 R107'`, R109 pack fix applied, R108 not applied.
