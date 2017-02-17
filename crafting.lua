local cache = smart_inventory.cache
local filter = smart_inventory.filter

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
		inf_state:get("craft_result"):setVisible()
		state:get("craft_preview"):setCraft(recipe)
	else
		inf_state:get("info1"):setText("")
		inf_state:get("info2"):setText("")
		inf_state:get("info3"):setText("")
		inf_state:get("cr_type"):setText("")
		inf_state:get("craft_result"):setVisible(false)
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

local function update_craftable_list(state, recipelist)
	local duplicate_index_tmp = {}
	local craftable_itemlist = {}

	for recipe, _ in pairs(recipelist) do
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

local function create_lookup_inv(state, name)
	local player = minetest.get_player_by_name(name)
	local invname = name.."_crafting_inv"
	local plistname = "crafting_inv_lookup"
	local listname = "lookup"
	local pinv = player:get_inventory()
	local inv = minetest.get_inventory({type="detached", name=invname})
	if not inv then
		inv = minetest.create_detached_inventory(invname, {
			allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
				return 0
			end,
			allow_put = function(inv, listname, index, stack, player)
				if pinv:is_empty(plistname) then
					return 99
				else
					return 0
				end
			end,
			allow_take = function(inv, listname, index, stack, player)
				return 99
			end,
			on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			end,
			on_put = function(inv, listname, index, stack, player)
				pinv:set_stack(plistname, index, stack)
				-- get the recipes with the item. Filter for visible in docs
				local recipes
				local recipes, ciii = cache.get_recipes_craftable_atnext(name, stack:get_name())
				state.param.crafting_items_in_inventory = ciii
				update_craftable_list(state, recipes)
				smartfs.inv[name]:show() -- we are outsite of usual smartfs processing. So trigger the formspec update byself
				-- put back
				minetest.after(1, function(stack)
					local applied = pinv:add_item("main", stack)
					pinv:set_stack(plistname, 1, applied)
					inv:set_stack(listname, 1, applied)
				end, stack)
			end,
			on_take = function(inv, listname, index, stack, player)
				pinv:set_stack(plistname, index, nil)
			end,
		}, name)
	end
	-- copy the item from player:listname inventory to the detached
	inv:set_size(listname, 1)
	pinv:set_size(plistname, 1)
	local stack = pinv:get_stack(plistname, 1)
	inv:set_stack(listname, 1, stack)
end

local function crafting_callback(state)
	local player = state.location.rootState.location.player

	--Inventorys / left site
	state:inventory(1, 5, 8, 4,"main")
	state:inventory(1.2, 0.2, 3, 3,"craft")
	state:inventory(4.2, 2.2, 1, 1,"craftpreview")
	state:background(1, 0, 4.5, 3.5, "img1", "menu_bg.png")

	state:button(1, 4.2, 2.5, 0.5, "compress", "Compress"):onClick(function(self, state, player)
		local name = state.location.rootState.location.player
		local inventory = minetest.get_player_by_name(name):get_inventory()
		local invsize = inventory:get_size("main")
		for idx1 = invsize, 1, -1 do
			local stack1 = inventory:get_stack("main", idx1)
			if not stack1:is_empty() then
				for idx2 = 1, idx1 do
					local stack2 = inventory:get_stack("main", idx2)
					if idx1 ~= idx2  and stack1:get_name() == stack2:get_name() then
						stack1 = stack2:add_item(stack1)
						inventory:set_stack("main", idx1, stack1)
						inventory:set_stack("main", idx2, stack2)
						if stack1:is_empty() then
							break
						end
					end
				end
			end
		end
	end)

	create_lookup_inv(state, player)
	state:inventory(10, 4.0, 1, 1,"lookup"):useDetached(player.."_crafting_inv")

	-- functional buttons right site
	local refresh_button = state:button(11, 4.2, 2, 0.5, "refresh", "Read inventory ")
	refresh_button:onClick(function(self, state, player)
		local craftable, ciii = cache.get_recipes_craftable(player)
		state.param.crafting_items_in_inventory = ciii
		update_craftable_list(state, craftable)
		state:get("inf_area"):setVisible(false)
		state:get("groups_sel"):setVisible(true)
	end)

	-- functional buttons right site
	local groups_button = state:button(13, 4.2, 5, 0.5, "groups_btn", "All items")
	groups_button:onClick(function(self, state, player)
		if state:get("groups_sel"):getVisible() == true then
			state:get("inf_area"):setVisible(true)
			state:get("groups_sel"):setVisible(false)
		else
			state:get("inf_area"):setVisible(false)
			state:get("groups_sel"):setVisible(true)
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
	inf_state:item_image(10.2,0.3, 1, 1, "craft_result",nil):setVisible(false)
	inf_area:setVisible(false)

	local group_sel = state:listbox(10.2, 0.15, 7.6, 3.6, "groups_sel",nil, true)
	group_sel:onClick(function(self, state, player)
		local selected = self:getSelectedItem()
		if selected then
			update_group_selection(state)
		end
	end)

	-- craftable items grid
	state:background(10, 5, 8, 4, "buttons_grid_Bg", "minimap_overlay_square.png")
	local grid = smart_inventory.smartfs_elements.buttons_grid(state, 10.25, 5.15, 8 , 4, "buttons_grid", 0.75,0.75)
	grid:onClick(function(self, state, index, player)
		local listentry = state.param.crafting_craftable_list[index]
		local recipe = table.copy(listentry.recipes[1])
		recipe.items = table.copy(listentry.recipes[1].items)
		for key, recipe_item in pairs(recipe.items) do
			local item = nil
			if recipe_item:sub(1, 6) == "group:" then
				local itemslist = cache.recipe_items_resolve_group(recipe_item)
				if itemslist[2] == nil then
					item = itemslist[1].name
				else
					for _, item_in_list in ipairs(itemslist) do
						if state.param.crafting_items_in_inventory[item_in_list.name] then
							item = item_in_list.name
							break
						elseif filter.is_revealed_item(item_in_list.name, player) then
							item = item_in_list.name
						elseif item == nil then
							item = item_in_list.name
						end
					end
				end
			end
			if item then
				recipe.items[key] = item
			end
		end
		on_item_select(state, listentry.itemdef, recipe)
		if state:get("inf_area"):getVisible() == false then
			state:get("groups_btn"):submit()
		end
	end)

	-- initial values
	local player = state.location.rootState.location.player

	local craftable, ciii = cache.get_recipes_craftable(player)
	state.param.crafting_items_in_inventory  = ciii
	update_craftable_list(state, craftable)
	group_sel:setSelected(1)
	if group_sel:getSelectedItem() then
		state:get("groups_btn"):setText(group_sel:getSelectedItem())
	end
end

smart_inventory.register_page({
	name = "crafting",
	tooltip = "Craft new items",
	icon = "inventory_btn.png",
	smartfs_callback = crafting_callback,
	sequence = 10
})
