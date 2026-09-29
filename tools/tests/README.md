# Offline tests (Luau CLI + a small Roblox mock)

Install once: Luau CLI from https://github.com/luau-lang/luau/releases (`luau-ubuntu.zip` -> /opt/luau),
luau-lsp from https://github.com/JohnnyMorganz/luau-lsp/releases (+ `scripts/globalTypes.None.d.luau`).

- `roblox.luau` - minimal Roblox runtime mock (Instances, signals, Vector3/CFrame, task scheduler).
- `bundle.py OUT name=path ...` - packs real script sources as strings so tests can `loadstring` them with the mock env.
- `test_installer.luau` - runs a built paste installer end to end (install, re-paste, undo, redo, refusals, rollback,
  added scripts). Data: `python3 tools/installer_testdata.py <installer.lua> inst_bundle.luau <BackupName> [base]`.
- `test_tutorial.luau` - smoke-runs BeginnerTutorial with the real BeginnerGuide/HudLayout (bundle them as tut_bundle.luau).
- `test_guide_layout.luau`, `hud_overlap_harness.luau` - card placement / HUD overlap checks over 26 screen sizes
  (require copies of the modules named as in the file headers).

Run from a scratch folder that holds the bundles; paths inside the tests are relative (`./roblox`, `./inst_bundle`).
