local cache = smart_inventory.cache

local function on_item_select(state, itemdef, recipe)
	local inf_state = state:get("inf_area"):getContainerState()
	if itemdef then
		inf_state:get("info1"):setText(itemdef.description)
		inf_state:get("info2"):setText("("..itemdef.name..")")
		inf_state:get("info3"):setText("")
		if recipe.type ~="normal" then
			inf_state:get("cr_type"):setText(recipe.type)
		else
			inf_state:get("cr_type"):setText("")
		end
		inf_state:get("craft_preview"):setCraft(recipe)
	else
		inf_state:get("info1"):setText("")
		inf_state:get("info2"):setText("")
		inf_state:get("info3"):setText("")
		inf_state:get("cr_type"):setText("")
		inf_state:get("craft_preview"):setCraft(nil)
	end
end

local function update_craftable_list(state)
	state.param.craftable_list = {}
	state.param.group_list_labels = {}
	local player = state.location.rootState.location.player
	local craftable = cache:get_recipes_craftable(player)
	local duplicate_index_tmp = {}
	local group_list = {}
	for recipe, _ in pairs(craftable) do
		local def = minetest.registered_items[recipe.output]
		if not def then
			recipe.output:gsub("[^%s]+", function(z)
				if minetest.registered_items[z] then
					def = minetest.registered_items[z]
				end
			end)
		end
		if def then
			if duplicate_index_tmp[def] then
				table.insert(duplicate_index_tmp[def].recipes, recipe)
			else
				local entry = {
					itemdef=def,
					recipes = {},
					-- buttons_grid related
					item = def.name,
					is_button = true
				}
				duplicate_index_tmp[def] = entry
				for group, _ in pairs(def.groups) do
					if group_list[group] then
						group_list[group] = group_list[group] + 1
					else
						group_list[group] = 1
					end
				end

				if not state.param.selected_group or
						state.param.selected_group == "all" or
						def.groups[state.param.selected_group] then
					table.insert(entry.recipes, recipe)
					table.insert(state.param.craftable_list, entry)
				end
			end
		end
	end
	table.sort(state.param.craftable_list, function(a,b)
		return a.item < b.item
	end)
	local grid = state:get("buttons_grid")
	grid:setList(state.param.craftable_list)

	-- set group dropdown list

	local groups_sel = state:get("groups_sel")
	groups_sel:clearItems()
	local group_tmp = {}
	for group, count in pairs(group_list) do
		if count > 1 then
			table.insert(group_tmp, {group = group, label = group.." ("..count..")"})
		end
	end
	table.sort(group_tmp, function(a,b)
		return a.label < b.label
	end)

	groups_sel:addItem("all")
	for _, group in ipairs(group_tmp) do
		local idx = groups_sel:addItem(group.label)
		state.param.group_list_labels[idx] = group.group
	end
end

local function crafting_callback(state)
	local player = state.location.rootState.location.player
	--Inventorys / left site
	state:inventory(0.7, 6, 8, 4,"main")
	state:inventory(0.7, 0.5, 3, 3,"craft")
	state:inventory(4.1, 2.5, 1, 1,"craftpreview")
	state:background(0.6, 0.1, 4.6, 3.8, "img1", "menu_bg.png")

	-- functional buttons right site
	local refresh_button = state:button(17, 4.3, 2, 0.5, "refresh", "Refresh")
	refresh_button:onClick(function(self, state, player)
		update_craftable_list(state)
	end)

	-- functional buttons right site
	local groups_button = state:button(9, 4.3, 4, 0.5, "groups_btn", "All items")
	groups_button:onClick(function(self, state, player)
		if state:get("groups_sel"):getIsHidden() == true then
			state:get("inf_area"):setIsHidden(true)
			state:get("groups_sel"):setIsHidden(false)
		else
			state:get("inf_area"):setIsHidden(false)
			state:get("groups_sel"):setIsHidden(true)
		end
	end)

	-- preview area / multifunctional
	state:background(5.4, 0.1, 3.5, 3.8, "craft_img1", "menu_bg.png")
	state:background(9.0, 0.1, 10, 3.8, "craft_img2", "minimap_overlay_square.png")
	local inf_area = state:container(5.4, 0.1, "inf_area", true)
	local inf_state = inf_area:getContainerState()
	inf_state:label(10.5,0.5,"info1", "")
	inf_state:label(10.5,1.0,"info2", "")
	inf_state:label(10.5,1.5,"info3", "")
	smart_inventory.smartfs_elements.craft_preview(inf_state, 5.5, 0.5, "craft_preview")
	inf_state:label(5.7,3,"cr_type", "")

	local group_sel = state:listbox(9.2, 0.1, 9.6, 3.5, "groups_sel",nil, true)
	group_sel:onClick(function(self, state, index, player)
		state.param.selected_group = state.param.group_list_labels[index]
		print("selected", index, state.param.selected_group)
		update_craftable_list(state)
		if state.param.selected_group then
			state:get("groups_btn"):setText(state.param.selected_group)
		else
			state:get("groups_btn"):setText("All items")
		end
	end)
	group_sel:setIsHidden(true)

	-- craftable items grid
	local grid = smart_inventory.smartfs_elements.buttons_grid(state, 9, 5.5, 10 , 5, "buttons_grid")
	grid:onClick(function(self, state, index, player)
		local listentry = state.param.craftable_list[index]
		print(dump(listentry.itemdef)) --DEBUG
		on_item_select(state, listentry.itemdef, listentry.recipes[1]) --TODO: recipes paging
	end)



	-- initial values
	update_craftable_list(state)
end

smart_inventory.register_page({
	name = "crafting",
	icon = "inventory_btn.png",
	smartfs_callback = crafting_callback,
	sequence = 10,
	on_button_click = update_craftable_list
})
