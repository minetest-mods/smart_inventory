local modpath = minetest.get_modpath(minetest.get_current_modname()).."/txt"

local LANG = minetest.setting_get("language")
if not (LANG and (LANG ~= "")) then LANG = os.getenv("LANG") end
if not (LANG and (LANG ~= "")) then LANG = "en" end
local txtfile = modpath.."/classify_description_"..LANG:sub(1,2)..".lua"
-- build up caches
local f=io.open(txtfile,"r")
if f~=nil then
	io.close(f)
	return dofile(txtfile)
else
	return dofile(modpath.."/classify_description_en.lua")
end
