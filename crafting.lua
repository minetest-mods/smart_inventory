local cache = smart_inventory.cache

local function on_item_select(state, itemdef, recipe)
	local inf_state = state:get("inf_area"):getContainerState()
	if itemdef then
		inf_state:get("info1"):setText(itemdef.description)
		inf_state:get("info2"):setText("("..itemdef.name..")")
		if itemdef._doc_items_longdesc then
			inf_state:get("info3"):setText(itemdef._doc_items_longdesc)
		else
			inf_state:get("info3"):setText("")
		end
		if recipe.type ~="normal" then
			inf_state:get("cr_type"):setText(recipe.type)
		else
			inf_state:get("cr_type"):setText("")
		end
		inf_state:get("craft_result"):setImage(recipe.output)
		inf_state:get("craft_result"):setIsHidden(false)
		state:get("craft_preview"):setCraft(recipe)
	else
		inf_state:get("info1"):setText("")
		inf_state:get("info2"):setText("")
		inf_state:get("info3"):setText("")
		inf_state:get("cr_type"):setText("")
		inf_state:get("craft_result"):setIsHidden(true)
		state:get("craft_preview"):setCraft(nil)
	end
end

local function update_group_selection(state)
	local grouped = state.param.crafting_grouped_items
	local groups_sel = state:get("groups_sel")
	-- save old selection
	local sel_id = groups_sel:getSelected()
	local sel_grp
	if sel_id then
		sel_grp = state.param.crafting_group_list[sel_id]
	end
	groups_sel:clearItems()
	local group_sorted = {}
	for _, group in pairs(grouped) do
		table.insert(group_sorted, group)
	end

	table.sort(group_sorted, function(a,b)
		if a.name == "all" then
			return true
		elseif a.name == "other" then
			return false
		elseif b.name == "all" then
			return false
		elseif b.name == "other" then
			return true
		else
			return a.name < b.name
		end
	end)

	state.param.crafting_group_list = {}
	for _, group in ipairs(group_sorted) do
		if #group.items > 0 then
			local idx = groups_sel:addItem(group.group_desc.." ("..#group.items..")")
			state.param.crafting_group_list[idx] = group.name
			if sel_grp == group.name then
				sel_id = idx
			end
		end
	end

	-- restore selection
	if not state.param.crafting_group_list[sel_id] then
		sel_id = 1
	end
	groups_sel:setSelected(sel_id)

	local grid = state:get("buttons_grid")
	local btn = state:get("groups_btn")
	if state.param.crafting_group_list[sel_id] then
		state.param.crafting_craftable_list = grouped[state.param.crafting_group_list[sel_id]].items
		-- sort selected items
		table.sort(state.param.crafting_craftable_list, function(a,b)
			return a.item < b.item
		end)
		grid:setList(state.param.crafting_craftable_list)
		btn:setText(groups_sel:getSelectedItem())
	else
		btn:setText("Empty List")
		grid:setList({})
	end
end

local function update_craftable_list(state)
	local player = state.location.rootState.location.player
	local craftable = cache.get_recipes_craftable(player)
	local duplicate_index_tmp = {}
	local craftable_itemlist = {}

	-- get the full list of craftable
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
			if duplicate_index_tmp[def.name] then
				table.insert(duplicate_index_tmp[def.name].recipes, recipe)
			else
				local entry = {
					itemdef = def,
					recipes = {},
					-- buttons_grid related
					item = def.name,
					is_button = true
				}
				duplicate_index_tmp[def.name] = entry
				table.insert(entry.recipes, recipe)
				table.insert(craftable_itemlist, entry)
			end
		end
	end
	state.param.crafting_grouped_items = cache.get_list_grouped(craftable_itemlist)
	update_group_selection(state)
end

local function crafting_callback(state)
	local player = state.location.rootState.location.player
	--Inventorys / left site
	state:inventory(1, 5, 8, 4,"main")
	state:inventory(1.2, 0.2, 3, 3,"craft")
	state:inventory(4.2, 2.2, 1, 1,"craftpreview")
	state:background(1, 0, 4.5, 3.5, "img1", "menu_bg.png")

	-- functional buttons right site
	local refresh_button = state:button(16, 4.3, 2, 0.5, "refresh", "Refresh")
	refresh_button:onClick(function(self, state, player)
		update_craftable_list(state)
	end)

	-- functional buttons right site
	local groups_button = state:button(10, 4.3, 6, 0.5, "groups_btn", "All items")
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
--	state:background(5.4, 0.1, 3.5, 3.8, "craft_img1", "menu_bg.png")
	state:background(10.0, 0.1, 8, 3.8, "craft_img2", "minimap_overlay_square.png")
	local inf_area = state:container(6.4, 0.1, "inf_area", true)
	local inf_state = inf_area:getContainerState()
	inf_state:label(11.5,0.5,"info1", "")
	inf_state:label(11.5,1.0,"info2", "")
	inf_state:label(11.5,1.5,"info3", "")
	smart_inventory.smartfs_elements.craft_preview(state, 6, 0, "craft_preview")
	inf_state:label(6.7,3,"cr_type", "")
	inf_state:item_image(10.2,0.3, 1, 1, "craft_result",nil):setIsHidden(true)
	inf_area:setIsHidden(true)

	local group_sel = state:listbox(10.2, 0.15, 7.6, 3.6, "groups_sel",nil, true)
	group_sel:onClick(function(self, state, player)
		local selected = self:getSelectedItem()
		if selected then
			update_group_selection(state)
		end
	end)

	-- craftable items grid
	local grid = smart_inventory.smartfs_elements.buttons_grid(state, 10, 5.5, 8 , 4, "buttons_grid")
	grid:onClick(function(self, state, index, player)
		local listentry = state.param.crafting_craftable_list[index]
		on_item_select(state, listentry.itemdef, listentry.recipes[1]) --TODO: recipes paging
		if state:get("inf_area"):getIsHidden() == true then
			state:get("groups_btn"):submit()
		end
	end)

	-- initial values
	update_craftable_list(state)
	group_sel:setSelected(1)
	if group_sel:getSelectedItem() then
		state:get("groups_btn"):setText(group_sel:getSelectedItem())
	end
end

smart_inventory.register_page({
	name = "crafting",
	icon = "inventory_btn.png",
	smartfs_callback = crafting_callback,
	sequence = 10
})
