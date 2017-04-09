local modpath = minetest.get_modpath(minetest.get_current_modname())

smart_inventory = {}
smart_inventory.skins_mod = minetest.get_modpath("skins")
smart_inventory.armor_mod = minetest.get_modpath("3d_armor")
smart_inventory.doc_items_mod = minetest.get_modpath("doc_items")
smart_inventory.registered_pages = {}
smart_inventory.smartfs = dofile(modpath.."/smartfs.lua")
smart_inventory.smartfs_elements = dofile(modpath.."/smartfs-elements.lua")
smartfs = smart_inventory.smartfs


-- start with empty group items replacement table.
-- Will be filled at runtime with used items. partially independend on user

local inventory_form = smartfs.create("smart_inventory:main", function(state)
	-- tabbed view controller
	local tab_controller = {
		_tabs = {},
		active_name = nil,
		set_active = function(self, tabname)
			for name, def in pairs(self._tabs) do
				if name == tabname then
					def.button:setBackground("halo.png")
					def.view:setVisible(true)
				else
					def.button:setBackground(nil)
					def.view:setVisible(false)
				end
			end
			self.active_name = tabname
		end,
		tab_add = function(self, name, def)
			def.viewstate:size(20,10) --size of tab view
			self._tabs[name] = def
		end,
		get_active_name = function(self)
			return self.active_name
		end,
	}

	--set screen size
	state:size(20,12)
	state:label(1,0.2,"header","Smart Inventory")
	state:image(0,0,1,1,"header_logo", "logo.png")
--	state:image_button(19,0,1,1,"exit", "Exit","???.png", true)
	state:button(19,0,1,1,"exit", "Exit", true)
	local button_x = 0.1
	table.sort(smart_inventory.registered_pages, function(a,b)
		if not a.sequence then
			return false
		elseif not b.sequence then
			return true
		elseif a.sequence > b.sequence then
			return false
		else
			return true
		end
	end)
	for _, def in ipairs(smart_inventory.registered_pages) do
		assert(def.smartfs_callback, "Callback function needed")
		assert(def.name, "Name is needed")
		local tabdef = {}
		local label
		if not def.label then
			label = ""
		else
			label = def.label
		end
		tabdef.button = state:button(button_x,11.2,1,1,def.name.."_button",label)
		if def.icon then
			tabdef.button:setImage(def.icon)
		end
		tabdef.button:setTooltip(def.tooltip)
		tabdef.button:onClick(function(self)
			tab_controller:set_active(def.name)
			if def.on_button_click then
				def.on_button_click(tabdef.viewstate)
			end
		end)
		tabdef.view = state:container(0,1,def.name.."_container")
		tabdef.viewstate = tabdef.view:getContainerState()
		def.smartfs_callback(tabdef.viewstate)
		tab_controller:tab_add(def.name, tabdef)
		button_x = button_x + 1
	end
	tab_controller:set_active(smart_inventory.registered_pages[1].name)
end)

smartfs.set_player_inventory(inventory_form)


function smart_inventory.register_page(def)
	table.insert(smart_inventory.registered_pages, def)
end

function smart_inventory.get_page_state(pagename, playername)
	local rootstate = smart_inventory.smartfs.inv[playername]
	if not rootstate then
		return
	end
	local view = rootstate:get(pagename.."_container")
	if not view then
		return
	end
	return view:getContainerState()
end

function smart_inventory.get_registered_page(pagename)
	for _, registred_page in ipairs(smart_inventory.registered_pages) do
		if registred_page.name == pagename then
			return registred_page
		end
	end
end

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

smart_inventory.filter = dofile(modpath.."/filter.lua")
smart_inventory.doc_addon = dofile(modpath.."/doc_addon.lua")
smart_inventory.cache = dofile(modpath.."/cache.lua")
smart_inventory.ui_tools = dofile(modpath.."/ui_tools.lua")

-- register pages
dofile(modpath.."/pages/crafting.lua")
dofile(modpath.."/pages/creative.lua")
dofile(modpath.."/pages/player.lua")
