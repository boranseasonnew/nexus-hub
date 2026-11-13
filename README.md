# ✨ Nexus Hub

**Nexus Hub** is a community-developed Roblox hub with game-specific tools for Murder Mystery 2, DOORS, and Blade Ball, plus a universal module for other experiences.

> 🔓 Free, open source, and keyless in the official distribution.

## 🎮 Features

### 🔪 Murder Mystery 2

- Role and player ESP, dropped-gun markers, and player spectating.
- Gun pickup, auto shoot, selectable shot-prediction modes, and optional aim assist.
- Murderer controls for knife attacks, throwing, and kill aura.
- Fly, noclip, anti-fling, anti-void, coin collection, fullbright, FOV, emotes, and server controls.

### 🚪 DOORS

- Door, key, object, and entity highlights, with optional alerts.
- Speed boost, Rush / Ambush evasion, fullbright, FOV, noclip, and anti-AFK controls.
- Local speed and movement diagnostics to help investigate problems.

### ⚔️ Blade Ball

- Auto-parry controls, ball and player ESP, and adjustable combat options.

### 🌐 Universal

- Player ESP, fullbright, speed, jump, infinite jump, fly, noclip, and player teleport controls.

Availability and results may change when games update. Some features depend on the client environment and are experimental.

## 🚀 Getting started

Run the loader below in a compatible environment:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/boranseasonnew/nexus-hub/main/dist/nexus-local-test.client.luau"))()
```

The default menu shortcut is **Right Control**; it can be changed in Settings.

The generated client bundle is built locally with:

```sh
node scripts/build-test-bundle.mjs
```

The output is `dist/nexus-local-test.client.luau`. Review scripts and their dependencies before running remotely downloaded code.

## 🛠️ Development

- `client/` — Luau game modules, shared logic, and interface components.
- `scripts/build-test-bundle.mjs` — builds the standalone client bundle.
- `tests/client/` — Luau unit tests.
The standalone bundle requires Node.js to build. The separate site/backend is not part of this client release.

## 🤝 Contributing

Contributions are welcome! Fork the repository, create a branch, explain and test your changes, and open a pull request. Please include relevant credits and license notices for third-party code.

**Project policy:** the official Nexus Hub distribution should remain free to use without a key system. Pull requests introducing key-gated access to the official project will not be accepted. This policy does not override the rights granted by applicable open-source licenses to downstream users.

## 🙌 Credits and references

- [Joystickplays / YARHM](https://github.com/Joystickplays/psychic-octo-invention) — the fling implementation includes adapted code. YARHM is GPL-3.0 licensed.
- [overthcode2011-stack / HHB](https://github.com/overthcode2011-stack/HHB) — reference for MM2 mechanics and prediction.
- [RabbitCoreHub / MM2](https://github.com/RabbitCoreHub/MM2), [tontov / NewMM2](https://github.com/tontov/NewMM2), [xv3gasx / Murder-Mystery-2](https://github.com/xv3gasx/Murder-Mystery-2), and [rbxluau / script-hub](https://github.com/rbxluau/script-hub) — repositories reviewed as references.

Credits do not imply endorsement. Each upstream project retains its own license and rights.

## 📜 Licensing status

The combined client is distributed under [GNU GPL version 3](LICENSE) and includes code adapted from YARHM. Original Nexus Hub code was made available under the [MIT License](LICENSE-MIT). The GPL applies to the combined distribution; the project policy above is not an additional restriction on GPL rights.

