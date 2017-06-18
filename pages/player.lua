if not smart_inventory.skins_mod and not smart_inventory.armor_mod then
	return
end

local filter = smart_inventory.filter
local cache = smart_inventory.cache
local ui_tools = smart_inventory.ui_tools
local txt = smart_inventory.txt
local creative = minetest.setting_getbool("creative_mode")

local armor_type = {}
if smart_inventory.armor_mod then
	for _,v in ipairs(armor.elements) do
		armor_type["armor:"..v] = true
	end
end

local function update_grid(state, listname)
-- Update the users inventory grid
	local list = {}
	state.param["armor_"..listname.."_list"] = list
	local name = state.location.rootState.location.player
	local inventory = minetest.get_player_by_name(name):get_inventory()
	local invlist = inventory:get_list(listname)

	for stack_index, stack in ipairs(invlist) do
		local itemdef = stack:get_definition()
		local is_armor = false
		if itemdef and cache.citems[itemdef.name] then
			for groupname, groupinfo in pairs(cache.citems[itemdef.name].cgroups) do
				if armor_type[groupname] then
					local wear = stack:get_wear()

					local entry = {
							itemdef = itemdef,
							stack_index = stack_index,
							-- buttons_grid related
							item = itemdef.name,
							is_button = true
						}
					if wear > 0 then
						entry.text = tostring(math.floor((1 - wear / 65535) * 100 + 0.5)).." %"
					end
					table.insert(list, entry)
					break
				end
			end
		end
	end
	table.sort(list, function(a,b)
		return a.item < b.item
	end)
	local grid = state:get(listname.."_grid")
	grid:setList(list)
end

local function update_selected_item(state, listentry)
	local name = state.location.rootState.location.player
	state.param.armor_selected_item = listentry or state.param.armor_selected_item
	listentry = state.param.armor_selected_item
	if not listentry then
		return
	end
	local i_list = state:get("i_list")
	i_list:clearItems()
	for _, groupdef in ipairs(ui_tools.get_tight_groups(cache.citems[listentry.itemdef.name].cgroups)) do
		i_list:addItem(groupdef.group_desc)
	end
	state:get("item_name"):setText(listentry.itemdef.description)
	state:get("item_image"):setImage(listentry.item)
end

local function update_page(state)
	local name = state.location.rootState.location.player
	local player_obj = minetest.get_player_by_name(name)
	local skin_obj
	if smart_inventory.skins_mod then
		skin_obj = skins.get_player_skin(player_obj)
	end
	if smart_inventory.armor_mod then
		if creative == false then
			update_grid(state, "main")
		end
		update_grid(state, "armor")
		state:get("preview"):setImage(armor.textures[name].preview)
		state.location.parentState:get("player_button"):setImage(armor.textures[name].preview)
		local a_list = state:get("a_list")
		a_list:clearItems()
		for k, v in pairs(armor.def[name]) do
			local grouptext
			if k == "groups" then
				for gn, gv in pairs(v) do
					if txt and txt["armor:"..gn] then
						grouptext = txt["armor:"..gn]
					else
						grouptext = "armor:"..gn
					end
					if grouptext and gv ~= 0 then
						a_list:addItem(grouptext..": "..gv)
					end
				end
			else
				local is_physics = false
				for _, group in ipairs(armor.physics) do
					if group == k then
						is_physics = true
						break
					end
				end
				if is_physics then
					if txt and txt["physics:"..k] then
						grouptext = txt["physics:"..k]
					else
						grouptext = "physics:"..k
					end
					if grouptext and v ~= 1 then
						a_list:addItem(grouptext..": "..v)
					end
				else
					if txt and txt["armor:"..k] then
						grouptext = txt["armor:"..k]
					else
						grouptext = "armor:"..k
					end
					if grouptext and v ~= 0 then
						if k == "state" then
							a_list:addItem(grouptext..": "..tostring(math.floor((1 - v / armor.def[name].count / 65535) * 100 + 0.5)).." %")
						else
							a_list:addItem(grouptext..": "..v)
						end
					end
				end
			end
		end
		update_selected_item(state)
	elseif skin_obj then
		local skin_preview = skin_obj:get_preview()
		state.location.parentState:get("player_button"):setImage(skin_preview)
		state:get("preview"):setImage(skin_preview)
	end
	if skin_obj then
		local m_name = skin_obj:get_meta_string("name")
		local m_author = skin_obj:get_meta_string("author")
		local m_license = skin_obj:get_meta_string("license")
		if m_name then
			state:get("skinname"):setText("Skin name: "..(skin_obj:get_meta_string("name")))
		else
			state:get("skinname"):setText("")
		end
		if m_author then
			state:get("skinauthor"):setText("Author: "..(skin_obj:get_meta_string("author")))
		else
			state:get("skinauthor"):setText("")
		end
		if m_license then
			state:get("skinlicense"):setText("License: "..(skin_obj:get_meta_string("license")))
		else
			state:get("skinlicense"):setText("")
		end
	end
	state.param.skins_list = skins.get_skinlist("player:"..name, true)
	local cur_skin = skins.get_player_skin(player_obj)
	local skins_grid_data = {}
	local grid_skins = state:get("skins_grid")
	for idx, skin in ipairs(state.param.skins_list) do
		table.insert(skins_grid_data, {
				image = skin:get_preview(),
				tooltip = skin:get_meta_string("name"),
				is_button = true,
				size = { w = 0.87, h = 1.30 }
		})
		if skin:get_meta("_key") == cur_skin:get_meta("_key") then
			grid_skins:setFirstVisible(idx - 19) --8x5 (grid size) / 2 -1
		end
	end
	grid_skins:setList(skins_grid_data)
end

local function move_item_to_armor(state, item)
	local name = state.location.rootState.location.player
	local inventory = minetest.get_player_by_name(name):get_inventory()

	-- get item to be moved to armor inventory
	local itemstack, itemname, itemdef
	if creative == true then
		itemstack = ItemStack(item.item)
		itemname = item.item
	else
		itemstack = inventory:get_stack("main", item.stack_index)
		itemname = itemstack:get_name()
	end
	itemdef = minetest.registered_items[itemname]
	local new_groups = {}
	for _, element in ipairs(armor.elements) do
		if itemdef.groups["armor_"..element] then
			new_groups["armor_"..element] = true
		end
	end

	-- remove all items with the same group
	local removed_items = {}
	for stack_index, stack in ipairs(inventory:get_list("armor")) do
		local old_def = stack:get_definition()
		if old_def then
			for groupname, groupdef in pairs(old_def.groups) do
				if new_groups[groupname] then
					table.insert(removed_items, stack)
					stack = inventory:set_stack("armor", stack_index, {})
				end
			end
		end
	end

	-- move the new item to the armor inventory
	itemstack = inventory:add_item("armor", itemstack)

	-- handle put backs in non-creative to not lost items
	if creative == false then
		inventory:set_stack("main", item.stack_index, itemstack)
		for _, stack in ipairs(removed_items) do
			stack = inventory:add_item("main", stack)
			stack = inventory:add_item("armor", stack)
		end
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
	state:label(2,5,"item_name", "")
	state:listbox(2.2,2.5,3.2,2.5,"i_list", nil, true)
	state:item_image(0,3.5,2,2,"item_image","")

	state:background(6.7, 2.3, 6, 4.6, "pl_bg", "minimap_overlay_square.png")
	state:image(7,3.0,2,4,"preview","")
	state:listbox(9.2,2.5,3.2,2.5,"a_list", nil, true)
	state:label(9,5.0,"skinname","")
	state:label(9,5.5,"skinauthor", "")
	state:label(9,6.0, "skinlicense", "")

	state:background(0, 0, 20, 1, "top_bg", "halo.png")
	state:background(0, 8, 20, 2, "bottom_bg", "halo.png")
	if smart_inventory.armor_mod then
		local grid_armor = smart_inventory.smartfs_elements.buttons_grid(state, 0, 0, 8, 1, "armor_grid")

		grid_armor:onClick(function(self, state, index, player)
			if state.param.armor_armor_list[index] then
				update_selected_item(state, state.param.armor_armor_list[index])
				move_item_to_inv(state, state.param.armor_armor_list[index])
				update_page(state)
			end
		end)

		local grid_main = smart_inventory.smartfs_elements.buttons_grid(state, 0, 8, 20, 2, "main_grid")
		grid_main:onClick(function(self, state, index, player)
			update_selected_item(state, state.param.armor_main_list[index])
			move_item_to_armor(state, state.param.armor_main_list[index])
			update_page(state)
		end)

		if creative == true then
			-- fill creative list once, not each page update
			local list = {}
			local list_dedup = {}
			for armor_group, _ in pairs(armor_type) do
				for _, itemdef in pairs(cache.cgroups[armor_group].items) do
					list_dedup[itemdef.name] = itemdef
				end
			end
			for _, itemdef in pairs(list_dedup) do
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
		local player_obj = minetest.get_player_by_name(name)
		-- Skins Grid
		local grid_skins = smart_inventory.smartfs_elements.buttons_grid(state, 13.1, 1.3, 7 , 7, "skins_grid", 0.87, 1.30)
		state:background(13, 1, 7 , 7, "bg_skins", "minimap_overlay_square.png")
		grid_skins:onClick(function(self, state, index, player)
			local cur_skin = state.param.skins_list[index]
			skins.set_player_skin(player_obj, cur_skin)
			if smart_inventory.armor_mod then
				armor.textures[name].skin = cur_skin:get_texture()
				armor:set_player_armor(player_obj)
			end
			update_page(state)
		end)
	end

	-- not visible update plugin for updates from outsite (API)
	state:element("code", { name = "update_hook" }):onSubmit(function(self, state)
		update_page(state)
		state.location.rootState:show()
	end)

	-- in case of armor mod the page is updated trough the hook call
	if not smart_inventory.armor_mod then
		update_page(state)
	end
end

smart_inventory.register_page({
	name = "player",
	icon = "player.png",
	tooltip = "Customize yourself",
	smartfs_callback = player_callback,
	sequence = 20,
	on_button_click = update_page
})

-- register callback in 3d_armor for updates
if smart_inventory.armor_mod and armor.register_on_update then

	local function submit_update_hook(player)
		local name = player:get_player_name()
		local state = smart_inventory.get_page_state("player", name)
		if state then
			state:get("update_hook"):submit()
		end
	end

	armor:register_on_update(submit_update_hook)

	-- There is no callback in 3d_armor for wear change in on_hpchange implementation
	minetest.register_on_player_hpchange(function(player, hp_change)
		minetest.after(0, submit_update_hook, player)
	end)
end
