local modpath = minetest.get_modpath(minetest.get_current_modname())

smart_inventory = {}
smart_inventory.registered_pages = {}
smart_inventory.smartfs = dofile(modpath.."/smartfs.lua")
smart_inventory.smartfs_elements = dofile(modpath.."/smartfs-elements.lua")
smartfs = smart_inventory.smartfs


-- start with empty group items replacement table.
-- Will be filled at runtime with used items. partially independend on user
smart_inventory.group_items = {}

local inventory_form = smartfs.create("smart_inventory:main", function(state)
	-- tabbed view controller
	local tab_controller = {
		_tabs = {},
		active_name = nil,
		set_active = function(self, tabname)
			for name, def in pairs(self._tabs) do
				if name == tabname then
					def.button:setBackground("halo.png")
					def.view:setIsHidden(false)
				else
					def.button:setBackground(nil)
					def.view:setIsHidden(true)
				end
			end
			self.active_name = tabname
		end,
		tab_add = function(self, name, def)
			def.viewstate:size(12,8) --size of tab view
			self._tabs[name] = def
		end,
		get_active_name = function(self)
			return self.active_name
		end,
	}

	--set screen size
	state:size(14,10)
	state:label(1,0.2,"header","Smart Inventory")
	state:image(0,0,1,1,"header_logo", "logo.png")
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
		tabdef.button = state:button(button_x,9.2,1,1,def.name.."_button",label)
		if def.icon then
			tabdef.button:setImage(def.icon)
		end
		tabdef.button:onClick(function(self)
			tab_controller:set_active(def.name)
		end)
		tabdef.view = state:container(0,1,def.name.."_container")
		tabdef.viewstate = tabdef.view:getContainerState()
		tabdef.viewstate:loadTemplate(def.smartfs_callback)
		tab_controller:tab_add(def.name, tabdef)
		button_x = button_x + 1
	end
	tab_controller:set_active(smart_inventory.registered_pages[1].name)
end)

smartfs.set_player_inventory(inventory_form)


function smart_inventory.register_page(def)
	--[[ API:
	smart_inventory.register_page({
		name         = name
		icon | label = *.png|text
		check_active = (optional: function to check if active) (TODO)
		smartfs_callback = smartfs callback function
		sequence = number
	})
	]]
	table.insert(smart_inventory.registered_pages, def)
end


-- build up caches
smart_inventory.cache = dofile(modpath.."/cache.lua")

-- register pages
dofile(modpath.."/crafting.lua")
