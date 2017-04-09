smart_inventory = {}
smart_inventory.modpath = minetest.get_modpath(minetest.get_current_modname())
local modpath = smart_inventory.modpath

-- get settings and optional mods support
smart_inventory.skins_mod = minetest.get_modpath("skins")
smart_inventory.armor_mod = minetest.get_modpath("3d_armor")
smart_inventory.doc_items_mod = minetest.get_modpath("doc_items")

-- load libs
smart_inventory.txt = dofile(modpath.."/txt/classify_txt.lua")
smart_inventory.smartfs = dofile(modpath.."/libs/smartfs.lua")
smart_inventory.smartfs_elements = dofile(modpath.."/libs/smartfs-elements.lua")

smart_inventory.doc_addon = dofile(modpath.."/doc_addon.lua")
smart_inventory.ui_tools = dofile(modpath.."/ui_tools.lua")

smart_inventory.filter = dofile(modpath.."/libs/filter.lua")
smart_inventory.cache = dofile(modpath.."/libs/cache.lua")

-- register pages
dofile(modpath.."/inventory_framework.lua")
dofile(modpath.."/pages/crafting.lua")
dofile(modpath.."/pages/creative.lua")
dofile(modpath.."/pages/player.lua")
