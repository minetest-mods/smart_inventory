local filter = smart_inventory.filter
local cache = smart_inventory.cache
local creative = minetest.setting_getbool("creative_mode")

local function update_grid(state, listname)
-- Update the users inventory grid
	local list = {}
	state.param["armor_"..listname.."_list"] = list
	local name = state.location.rootState.location.player
	local inventory = minetest.get_player_by_name(name):get_inventory()
	local invlist = inventory:get_list(listname)

	for stack_index, stack in ipairs(invlist) do
		local itemname = stack:get_name()
		local itemdef
		local is_armor = false
		if filter.get("armor"):check_item_by_name(itemname) then
			itemdef = minetest.registered_items[itemname]
			table.insert(list, {
					itemdef = itemdef,
					stack_index = stack_index,
					-- buttons_grid related
					item = itemdef.name,
					is_button = true
				})
		end
	end
	table.sort(list, function(a,b)
		return a.item < b.item
	end)
	local grid = state:get(listname.."_grid")
	grid:setList(list)
end

local function update_selected_item(state, listentry)
	if listentry then
		state.param.armor_selected_item = listentry
	else
		listentry = state.param.armor_selected_item
	end
	if not listentry then
		return
	end
	local level = 0
	local elements = {}
	for _,v in ipairs(armor.elements) do
		elements[v] = false
	end
	for k, v in pairs(elements) do
		if listentry.itemdef.groups["armor_"..k] then
			level = level + listentry.itemdef.groups["armor_"..k]
		end
	end
	if minetest.get_modpath("shields") then
		level = level * 0.9
	end
	local heal = listentry.itemdef.groups.armor_heal or 0
	local fire = listentry.itemdef.groups.armor_fire or 0
	local radiation = listentry.itemdef.groups.armor_radiation or 0

	state:get("item_name"):setText(listentry.itemdef.description)
	state:get("item_level"):setText("Level: "..level)
	state:get("item_heal"):setText("Heal:  "..heal)
	state:get("item_fire"):setText("Fire:  "..fire)
	state:get("item_radiation"):setText("Radiation:  "..radiation)
	state:get("item_image"):setImage(listentry.item)
end

local function update_page(state)
	local name = state.location.rootState.location.player
	if smart_inventory.armor_mod then
		if creative == false then
			update_grid(state, "main")
		end
		update_grid(state, "armor")
		state:get("preview"):setImage(armor.textures[name].preview)
		state.location.parentState:get("player_button"):setImage(armor.textures[name].preview)
		state:get("level"):setText("Level: "..armor.def[name].level)
		state:get("heal"):setText("Heal:  "..armor.def[name].heal)
		state:get("fire"):setText("Fire:  "..armor.def[name].fire)
		state:get("radiation"):setText("Radiation:  "..armor.def[name].radiation)
		update_selected_item(state)
	elseif smart_inventory.skins_mod then
		state.location.parentState:get("player_button"):setImage(skins.skins[name].."_preview.png")
		state:get("preview"):setImage(skins.skins[name].."_preview.png")
	end

	if smart_inventory.skins_mod then
		local skin = skins.skins[name]
		if skin and skins.meta[skin] then
			state:get("skinname"):setText("Skin name: "..(skins.meta[skin].name or ""))
			state:get("skinauthor"):setText("Author: "..(skins.meta[skin].author or ""))
			state:get("skinlicense"):setText("License: "..(skins.meta[skin].license or ""))
		else
			state:get("skinname"):setText("")
			state:get("skinauthor"):setText("")
			state:get("skinlicense"):setText("")
		end
	end
end

local function move_item_to_armor(state, item)
	local name = state.location.rootState.location.player
	local inventory = minetest.get_player_by_name(name):get_inventory()
	if creative == true then
		inventory:add_item("armor", item.item)
	else
		local itemstack = inventory:get_stack("main", item.stack_index)
		itemstack = inventory:add_item("armor", itemstack)
		inventory:set_stack("main", item.stack_index, itemstack)
	end
	armor:set_player_armor(minetest.get_player_by_name(name))
end

local function move_item_to_inv(state, item)
	local name = state.location.rootState.location.player
	local inventory = minetest.get_player_by_name(name):get_inventory()
	if creative == true then
		inventory:set_stack("armor", item.stack_index, {})
	else
		local itemstack = inventory:get_stack("armor", item.stack_index)
		itemstack = inventory:add_item("main", itemstack)
		inventory:set_stack("armor", item.stack_index, itemstack)
	end
	armor:set_player_armor(minetest.get_player_by_name(name))
end

local function player_callback(state)
	local name = state.location.rootState.location.player
	state:background(0, 2.3, 6, 4.6, "it_bg", "minimap_overlay_square.png")
	state:label(0.1,2.5,"item_name", "")
	state:label(0.1,3.0,"item_level", "")
	state:label(0.1,3.5,"item_heal","")
	state:label(0.1,4.0,"item_fire", "")
	state:label(0.1,4.5, "item_radiation", "")
	state:item_image(0,5.0,2,2,"item_image","")

	state:background(6.7, 2.3, 6, 4.6, "pl_bg", "minimap_overlay_square.png")
	state:image(7,3.0,2,4,"preview","")
	state:label(9,2.5,"level", "")
	state:label(9,3.0,"heal","")
	state:label(9,3.5,"fire", "")
	state:label(9,4.0, "radiation", "")

	state:label(9,5.0,"skinname","")
	state:label(9,5.5,"skinauthor", "")
	state:label(9,6.0, "skinlicense", "")

	state:background(0, 0, 20, 1, "top_bg", "halo.png")
	state:background(0, 8, 20, 2, "bottom_bg", "halo.png")
	if smart_inventory.armor_mod then
		local grid_armor = smart_inventory.smartfs_elements.buttons_grid(state, 0, 0, 8, 1, "armor_grid")

		grid_armor:onClick(function(self, state, index, player)
			update_selected_item(state, state.param.armor_armor_list[index])
			move_item_to_inv(state, state.param.armor_armor_list[index])
			update_page(state)
		end)

		local grid_main = smart_inventory.smartfs_elements.buttons_grid(state, 0, 8, 20, 2, "main_grid")
		grid_main:onClick(function(self, state, index, player)
			update_selected_item(state, state.param.armor_main_list[index])
			move_item_to_armor(state, state.param.armor_main_list[index])
			update_page(state)
		end)
		armor:set_player_armor(minetest.get_player_by_name(name))

		if creative == true then
			-- fill creative list once, not each page update
			local list = {}
			for _, itemdef in pairs(cache.cgroups["armor"].items) do
				table.insert(list, {
						itemdef = itemdef,
						-- buttons_grid related
						item = itemdef.name,
						is_button = true
					})
			end
			table.sort(list, function(a,b)
				return a.item < b.item
			end)
			grid_main:setList(list)
			state.param.armor_main_list = list
		end
	end

	if smart_inventory.skins_mod then
		-- Skins Grid
		local grid_skins = smart_inventory.smartfs_elements.buttons_grid(state, 13.1, 1.3, 7 , 7, "skins_grid", 0.87, 1.30)
		state:background(13, 1, 7 , 7, "bg_skins", "minimap_overlay_square.png")
		grid_skins:onClick(function(self, state, index, player)
			local skin = skins.list[index]
			local player_obj = minetest.get_player_by_name(name)
			skins.skins[player] = skin
			skins.file_save = true
			skins.update_player_skin(player_obj)
			if smart_inventory.armor_mod then
				armor.textures[name].skin = skin..".png"
				armor:set_player_armor(player_obj)
			end
			update_page(state)
		end)

		local skins_grid_data = {}
		for idx, skin in pairs(skins.list) do
			table.insert(skins_grid_data, {
					image = skin.."_preview.png",
					tooltip = skins.meta[skin].name,
					is_button = true,
					size = { w = 0.87, h = 1.30 }
			})
			if skin == skins.skins[name] then
				grid_skins:setFirstVisible(idx - 19) --8x5 (grid size) / 2 -1
			end
		end
		grid_skins:setList(skins_grid_data)
	end

	-- not visible update plugin for updates from outsite (API)
	state:element("code", { name = "update_hook" }):onSubmit(function(self, state)
		update_page(state)
		state.location.rootState:show()
	end)

	update_page(state)
end

smart_inventory.register_page({
	name = "player",
	icon = "player.png",
	tooltip = "Customize yourself",
	smartfs_callback = player_callback,
	sequence = 20,
	on_button_click = update_page
})


if smart_inventory.armor_mod then
	-- Armor filter
	smart_inventory.filter.register_filter({
			name = "armor", 
			shortdesc = "Armor",
			filter_func = function(def)
				for _, v in pairs(armor.elements) do
					if def.groups["armor_"..v] then
						return true
					end
				end
			end
		})
end
