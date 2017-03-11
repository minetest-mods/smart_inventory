# smart_inventory

## Overview
Minetest inventory with focus on very much items.

The mod is organized in multiple pages, each page does have own focus. There is a cached classification system implented that allow fast searching and browsing trough available items.

## Crafting page
![Screenshot](https://github.com/bell07/minetest-smart_inventory/blob/master/screenshot.png)
The vision is to not affect the gameplay trough crafting helpers. The helper should display currently relevant craft recipes only.
- Contains the usual player-, and crafting inventory
- Additional view of "craftable items" based on players inventory content
- Dynamic grouping of craftable items for better overview
- Lookup field to get all recipes with item in it - with filter for revealed items if the doc system is used
- Search field - with filter for revealed items if the doc system is used
- Compress - use the stack max size in inventory
- Sweep - move content of crafting inventory back to the main inventory

### Optional support for other mods
doc_items - if the doc system is found the crafting page shows only items craftable by known (revealed) items.
A lookup button is available on already known items to jump to the documntation entry


## Creative page
The vision is to get items fast searchable and gettable
- 3 dynamic filters + text search field for fast items search
- cleanup of inventory trough "delete" field
- just click to the item to get it in inventory
- Grouping out mass-generated shaped nodes to own group to keep klarity. "shape_type" enhancement required.
  "shape_type" is implemented already in ![lib_node_shapes modpack](https://forum.minetest.net/viewtopic.php?f=9&t=16740),[carpets](https://github.com/bell07/minetest-carpets). Prepared (locally, not pulled yet till mtg patch is clarified): ts_doors. [minetest_game patch](https://github.com/minetest/minetest_game/pull/1594)

## Player page
The vision is to get all skins and player customizations visual exposed

### 3d_armor
In creative mode there are all armor items available for 3d_armor support. The players inventory is not used in this mode. In survival only the armor from players inventory is shown

### skins
tested with my fork https://github.com/bell07/minetest-skinsdb
But it should be work with any fork that uses skins.skins[] and have *_preview.png files

License: [LGPL-3](https://github.com/bell07/minetest-smart_inventory/blob/master/LICENSE)
