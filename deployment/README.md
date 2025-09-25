# Farming Simulator 2025 Mod Packaging Guide

This document explains how to package and distribute a Farming Simulator 2025 (FS25) mod.

## FILE STRUCTURE

Every FS25 mod must follow this structure:

```

MyModName/
├── modDesc.xml
├── icon.dds
├── textures/
├── scripts/
├── sounds/
└── storeItems.xml

````

- `modDesc.xml`: Required. Defines mod metadata (title, description, author, version, supported FS version).
- `icon.dds`: Required. 512x512 DDS icon for mod selection menu.
- `textures/`: Store DDS texture files here.
- `scripts/`: Lua scripts. Must follow FS25 API.
- `sounds/`: Audio files in `.ogg` format.
- `storeItems.xml`: Defines vehicles, tools, or placeables.


## PACKAGING

1. Place your mod folder (`MyModName/`) in a clean working directory.
2. Ensure **no nested folders** inside the ZIP (top-level must contain `modDesc.xml`).
3. Create a ZIP file:

   ```
   MyModName.zip
   ```
4. Place the ZIP in the FS25 mods directory:

    * Windows: `Documents/My Games/FarmingSimulator2025/mods`
    * Linux/macOS (Proton/Steam): `~/.local/share/FarmingSimulator2025/mods`