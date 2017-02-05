local modpath = minetest.get_modpath(minetest.get_current_modname())

smart_inventory = {}
smart_inventory.registered_pages = {}
smart_inventory.smartfs = dofile(modpath.."/smartfs.lua")
smartfs = smart_inventory.smartfs

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
	for name, def in pairs(smart_inventory.registered_pages) do
		assert(def.smartfs_callback, "Callback function needed")
		local tabdef = {}
		local label
		if not def.label then
			label = ""
		else
			label = def.label
		end
		tabdef.button = state:button(button_x,9.2,1,1,name.."_button",label)
		if def.icon then
			tabdef.button:setImage(def.icon)
		end
		tabdef.button:onClick(function(self)
			tab_controller:set_active(name)
		end)
		tabdef.view = state:container(0,1,name.."_container")
		tabdef.viewstate = tabdef.view:getContainerState()
		tabdef.viewstate:loadTemplate(def.smartfs_callback)
		tab_controller:tab_add(name, tabdef)
		if button_x < 1 then
			tab_controller:set_active(name)
		end
		button_x = button_x + 2
	end

end)

smartfs.set_player_inventory(inventory_form)


function smart_inventory.register_page(name, def)
	smart_inventory.registered_pages[name] = def
end
--[[
API: 
smart_inventory.register_page(name, {
	icon | label = 
	check_active = (optional: function to check if active)
	smartfs_callback = 
})

]]


dofile(modpath.."/crafting.lua")
