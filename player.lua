local filter = smart_inventory.filter

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
		if filter.get("armor"):check_item_by_name(itemname) == true then
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

	state:get("item_level"):setText("Level: "..level)
	state:get("item_heal"):setText("Heal:  "..heal)
	state:get("item_fire"):setText("Fire:  "..fire)
	state:get("item_radiation"):setText("Radiation:  "..radiation)
	state:get("item_image"):setImage(listentry.item)
end

local function update_page(state)
	local name = state.location.rootState.location.player

	if smart_inventory.armor_mod then
		update_grid(state, "main")
		update_grid(state, "armor")
		state:get("preview"):setImage(armor.textures[name].preview)
		state.location.parentState:get("player_button"):setImage(armor.textures[name].preview)
		state:get("level"):setText("Level: "..armor.def[name].level)
		state:get("heal"):setText("Heal:  "..armor.def[name].heal)
		state:get("fire"):setText("Fire:  "..armor.def[name].fire)
		state:get("radiation"):setText("Radiation:  "..armor.def[name].radiation)
		update_selected_item(state)
	elseif smart_inventory.skins_mod  then
		state.location.parentState:get("player_button"):setImage(skins.skins[name].."_preview.png")
		state:get("preview"):setImage(skins.skins[name].."_preview.png")
	end

	if smart_inventory.skins_mod then

	end
end

local function move_item_to_armor(state, item)
	local name = state.location.rootState.location.player
	local inventory = minetest.get_player_by_name(name):get_inventory()
	local itemstack = inventory:get_stack("main", item.stack_index)
	itemstack = inventory:add_item("armor", itemstack)
	inventory:set_stack("main", item.stack_index, itemstack)
	armor:set_player_armor(minetest.get_player_by_name(name))
end

local function move_item_to_inv(state, item)
	local name = state.location.rootState.location.player
	local inventory = minetest.get_player_by_name(name):get_inventory()
	local itemstack = inventory:get_stack("armor", item.stack_index)
	itemstack = inventory:add_item("main", itemstack)
	inventory:set_stack("armor", item.stack_index, itemstack)
	armor:set_player_armor(minetest.get_player_by_name(name))
end

local function player_callback(state)
	local name = state.location.rootState.location.player
	state:image(3.5,1.5,2,4,"preview","")
	state:label(5.5,1.5,"level", "")
	state:label(5.5,2.0,"heal","")
	state:label(5.5,2.5,"fire", "")
	state:label(5.5,3.0, "radiation", "")
	state:background(3.2, 1.3, 4.8, 4.6, "pl_bg", "minimap_overlay_square.png")

	state:label(0.1,1.5,"item_level", "")
	state:label(0.1,2.0,"item_heal","")
	state:label(0.1,2.5,"item_fire", "")
	state:label(0.1,3.0, "item_radiation", "")
	state:item_image(0,3.5,2,2,"item_image","")
	state:background(0, 1.3, 3, 4.6, "it_bg", "minimap_overlay_square.png")	

	if smart_inventory.armor_mod then
		local grid_armor = smart_inventory.smartfs_elements.buttons_grid(state, 0, 0, 8, 1, "armor_grid")
		grid_armor:setBackground("halo.png")
		grid_armor:onClick(function(self, state, index, player)
			update_selected_item(state, state.param.armor_armor_list[index])
			move_item_to_inv(state, state.param.armor_armor_list[index])
			update_page(state)
		end)

		local grid_main = smart_inventory.smartfs_elements.buttons_grid(state, 0, 6, 8, 2, "main_grid")
		grid_main:setBackground("halo.png")
		grid_main:onClick(function(self, state, index, player)
			update_selected_item(state, state.param.armor_main_list[index])
			move_item_to_armor(state, state.param.armor_main_list[index])
			update_page(state)
		end)
		armor:set_player_armor(minetest.get_player_by_name(name))
	end


	update_page(state)
end

smart_inventory.register_page({
	name = "player",
	icon = "player.png",
	smartfs_callback = player_callback,
	sequence = 20,
	on_button_click = update_page
})


	if smart_inventory.armor_mod then
	-- Armor filter
	smart_inventory.filter.register_filter({
			name = "armor", 
			shortdesc = "Armor",
			filter_func = function(def, name)
				if not def or not name then
					return false
				end
				for _, v in pairs(armor.elements) do
					if def.groups["armor_"..v] then
						return true
					end
				end
				return false
			end
		})
end
