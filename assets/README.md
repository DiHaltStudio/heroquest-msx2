# Editable port assets

These files supply the MSX2 presentation and translations. Original game media and reconstructed original program images are not included; see [Building](../docs/BUILDING.md) for the separate inputs.

| Files | Purpose |
|---|---|
| `palette.json` | Shared sixteen-colour game palette |
| `floor.png`, `walls_doors.png` | Dungeon surfaces and doors |
| `heroes.png`, `monsters.png`, `furniture.png` | Characters and room objects |
| `frame.png`, `hud_icons.png`, `cursor.png` | Game frame, interface and pointer |
| `font.png`, `font_alt.png` | Gothic and plain lettering |
| `map_*.png` | Overview-map tiles and symbols |
| `pictures.png` | Combat illustrations |
| `scrolls.json`, `scrolls.png`, `parchment.png` | Dialog backgrounds and styles |
| `intro/` | Adapted introduction pictures, animation data and narrative text |
| `lang/` | English strings and original-adventure briefings |
| `expansion/` | English and Spanish expansion text |
| `sound/` | Port sound data and DiHalt fanfares |
| `dihalt_logo.png` | Studio logo |

Keep image dimensions and indexed-colour conventions when editing sheets: the packing tools use their existing layout to address individual tiles and frames. `tools/pack_assets.py` and `tools/build_intro.py` describe the packed layouts. The normal build reads the editable assets and creates the ROM's graphic tables.

The PC and Amiga artwork and other original HeroQuest material retain their original rights. The adapted assets are included as part of this unofficial homage and do not imply a transfer of ownership. Refer to the repository's credits and manuals.
