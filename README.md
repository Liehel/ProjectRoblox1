Copyright (c) 2025 Sam (Liehel)
Hey everyone, if you want to use the code, feel free to do so; copying it is no problem at all, provided that I retain the code and the original post regarding it within my game. If, however, I were to one day transfer that authority and those rights to someone else, the situation might change.

This is extra for the moment...

This project is licensed under CC BY-NC-ND 4.0.
You may view and study this code freely.
You may NOT distribute, sell, or modify this work
without explicit written permission from the author.

Full license: https://creativecommons.org/licenses/by-nc-nd/4.0/

---
## What is this project?

**Project Arcade Roblox** is a game world built inside Roblox Studio where the player can find and play **10 different arcade games**, 7 of them are classic 2D games recreated inside a 3D engine, and the last 3 are original 3D games with multiplayer support.

The main goal of this project is simple: **keep the player inside the world for at least 8 minutes**, moving from game to game instead of leaving after just one. Each game is a mini-arcade machine the player can walk up to and interact with.

---

## Current state

Every one of the ten games is roughly **90% complete on the logic side**. They all run end to end: they score, they save to DataStore, they feed the analytics boards, and the three multiplayer ones handle rooms, lobbies and match flow.

The **artistic side sits at about 20%**, and that includes the main world. So what you will find here is a project that already plays correctly but still looks unfinished. Models, textures, lighting polish and the visual identity of each arcade machine are the work that remains.

---

## The 10 games

Seven classic 2D arcade games rebuilt inside a 3D engine:

| # | Game | Technical focus |
|---|------|-----------------|
| 1 | Oxybelis | Circular buffer, O(1) movement logic |
| 2 | Avis Toucan | Gravity tuning and game feel |
| 3 | Resilio | Vector reflection, power-ups |
| 4 | Foxy Fruit | BFS ghost AI with four distinct behaviours |
| 5 | Firmament Defender | Swarm logic, shields |
| 6 | Firmament Siege | Inertia physics, 360 degree movement |
| 7 | Juice Cutter | Recipe system, line-segment collision |

Three original 3D games, all with multiplayer support:

| # | Game | Technical focus |
|---|------|-----------------|
| 8 | Turris Casei | Block slicing math, multiplayer |
| 9 | Tap And Hold | Parabolic jump physics, multiplayer |
| 10 | ImNotASphere | Moving platforms, power-ups, multiplayer |

Beyond the games themselves the project also includes a shared score table system, a universal controller that covers PC, touch, and gamepad, a private-room multiplayer lobby, an in-game data analytics system rendered on physical boards, and a fireworks system with nineteen different fireworks.

---

## Where to find things

**The complete game is in the file `ññññññ.rbxl`.** Open it in Roblox Studio to see everything assembled: the island, the ten arcade machines, and every system running together. The rest of the repository is the source that feeds it.

**The documentation is in the `latex` folder, in the file `main.pdf`.** It is close to complete and it is the right place to start if you want to understand how any of this works: it walks through the architecture, the logic of each of the ten games one by one, the shared systems, the analytics system, and the fireworks system.

The Luau source lives in `src/`, mapped into Roblox Studio through Rojo:

- `src/client` runs on each player's machine
- `src/server` holds the authoritative game logic
- `src/shared` holds the modules both sides require
