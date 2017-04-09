local modpath = minetest.get_modpath(minetest.get_current_modname())

smart_inventory = {}
smart_inventory.skins_mod = minetest.get_modpath("skins")
smart_inventory.armor_mod = minetest.get_modpath("3d_armor")
smart_inventory.doc_items_mod = minetest.get_modpath("doc_items")
smart_inventory.registered_pages = {}
smart_inventory.smartfs = dofile(modpath.."/libs/smartfs.lua")
smart_inventory.smartfs_elements = dofile(modpath.."/libs/smartfs-elements.lua")


dofile(modpath.."/inventory_framework.lua")

-- get language for texts
local LANG = minetest.setting_get("language")
if not (LANG and (LANG ~= "")) then LANG = os.getenv("LANG") end
if not (LANG and (LANG ~= "")) then LANG = "en" end
local txtfile = modpath.."/classify_description_"..LANG:sub(1,2)..".lua"
-- build up caches
local f=io.open(txtfile,"r")
if f~=nil then
	io.close(f)
	smart_inventory.txt = dofile(txtfile)
else
	smart_inventory.txt = dofile(modpath.."/classify_description_en.lua")
end

smart_inventory.filter = dofile(modpath.."/libs/filter.lua")
smart_inventory.doc_addon = dofile(modpath.."/doc_addon.lua")
smart_inventory.cache = dofile(modpath.."/libs/cache.lua")
smart_inventory.ui_tools = dofile(modpath.."/ui_tools.lua")

-- register pages
dofile(modpath.."/pages/crafting.lua")
dofile(modpath.."/pages/creative.lua")
dofile(modpath.."/pages/player.lua")
