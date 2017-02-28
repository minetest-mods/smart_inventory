local cache = smart_inventory.cache
local filter = smart_inventory.filter
local ui_tools = smart_inventory.ui_tools

-----------------------------------------------------
-- Update item informations about the selected item
-----------------------------------------------------
local function update_preview(state)
	-- adjust selected and enable preview paging buttons
	local player = state.location.rootState.location.player
	local listentry = state.param.crafting_recipes_preivew_listentry
	local selected = state.param.crafting_recipes_preivew_selected
	if not listentry.recipes[selected] then
		selected = 1
	end
	state.param.crafting_recipes_preivew_selected = selected
	if listentry.recipes[selected-1] then
		state:get("preview_prev"):setVisible(true)
	else
		state:get("preview_prev"):setVisible(false)
	end
	if listentry.recipes[selected+1] then
		state:get("preview_next"):setVisible(true)
	else
		state:get("preview_next"):setVisible(false)
	end

	-- create the recipe preview, set right items for groups
	local itemdef = listentry.itemdef
	local recipe
	if listentry.recipes[selected] then
		recipe = table.copy(listentry.recipes[selected])
		recipe.items = table.copy(recipe.items)
		for key, recipe_item in pairs(recipe.items) do
			local item = nil
			if recipe_item:sub(1, 6) == "group:" then
				local itemslist = cache.recipe_items_resolve_group(recipe_item)
				for _, item_in_list in pairs(itemslist) do
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
			if item then
				recipe.items[key] = item
			end
		end
	end

	-- update info area
	local inf_state = state:get("inf_area"):getContainerState()
	if itemdef then
		inf_state:get("info1"):setText(itemdef.description)
		inf_state:get("info2"):setText("("..itemdef.name..")")
		if itemdef._doc_items_longdesc then
			inf_state:get("info3"):setText(itemdef._doc_items_longdesc)
		else
			inf_state:get("info3"):setText("")
		end
	else
		inf_state:get("info1"):setText("")
		inf_state:get("info2"):setText("")
		inf_state:get("info3"):setText("")
		inf_state:get("cr_type"):setText("")
	end

	if recipe then
		if recipe.type ~="normal" then
			inf_state:get("cr_type"):setText(recipe.type)
		else
			inf_state:get("cr_type"):setText("")
		end
		inf_state:get("craft_result"):setImage(recipe.output)
		inf_state:get("craft_result"):setVisible()
		state:get("craft_preview"):setCraft(recipe)
	else
		inf_state:get("cr_type"):setText("")
		if itemdef then
			inf_state:get("craft_result"):setVisible(true)
			inf_state:get("craft_result"):setImage(itemdef.name)
		else
			state:get("craft_preview"):setCraft(nil)
		end
	end
end

-----------------------------------------------------
-- Update the group selection table
-----------------------------------------------------
local function update_group_selection(state, rebuild)
	local grouped = state.param.crafting_grouped_items
	local groups_sel = state:get("groups_sel")
	local grid = state:get("buttons_grid")
	local btn = state:get("groups_btn")
	-- prepare
	if rebuild then
		state.param.crafting_group_list = ui_tools.update_group_selection(grouped, groups_sel, state.param.crafting_group_list)
	end

	-- apply
	local sel_id = groups_sel:getSelected()
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

-----------------------------------------------------
-- Update the items list
-----------------------------------------------------
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
	update_group_selection(state, true)
end

-----------------------------------------------------
-- Lookup inventory
-----------------------------------------------------
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
				local lookup_item = stack:get_name()
				local recipes, ciii = cache.get_recipes_craftable_atnext(name, lookup_item)
				-- add recipes of lookup item to get more info about them
				if cache.citems[lookup_item] and cache.citems[lookup_item].in_output_recipe then
					for _, recipe in ipairs(cache.citems[lookup_item].in_output_recipe) do
						recipes[recipe] = true
					end
				end
				local state = smart_inventory.get_page_state("crafting", player:get_player_name())
				state.param.crafting_items_in_inventory = ciii
				update_craftable_list(state, recipes)

				-- show lookup item in preview
				state.param.crafting_recipes_preivew_selected = 1
				state.param.crafting_recipes_preivew_listentry = {
					itemdef = minetest.registered_items[lookup_item],
					recipes = cache.citems[lookup_item].in_output_recipe,
					item = lookup_item
				}
				update_preview(state)
				if state:get("inf_area"):getVisible() == false then
					state:get("groups_btn"):submit()
				end

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

-----------------------------------------------------
-- Page layout definition
-----------------------------------------------------
local function crafting_callback(state)
	local player = state.location.rootState.location.player

	--Inventorys / left site
	state:inventory(1, 5, 8, 4,"main")
	state:inventory(1.2, 0.2, 3, 3,"craft")
	state:inventory(4.2, 2.2, 1, 1,"craftpreview")
	state:background(1, 0, 4.5, 3.5, "img1", "menu_bg.png")

	ui_tools.create_trash_inv(state, player)
	state:element("code", {name = "inventory_bg_code", code = "listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"})
	state:image(8,9,1,1,"trash_icon","creative_trash_icon.png")
	state:inventory(8, 9, 1, 1, "trash"):useDetached(player.."_trash_inv")

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
	state:image(10, 4, 1, 1,"lookup_icon", "default_bookshelf_slot.png")
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

	local pr_prev_btn = state:button(6, 3, 1, 0.5, "preview_prev", "<<")
	pr_prev_btn:onClick(function(self, state, player)
		state.param.crafting_recipes_preivew_selected = state.param.crafting_recipes_preivew_selected -1
		update_preview(state)
	end)
	pr_prev_btn:setVisible(false)

	local pr_next_btn = state:button(8, 3, 1, 0.5, "preview_next", ">>")
	pr_next_btn:onClick(function(self, state, player)
		state.param.crafting_recipes_preivew_selected = state.param.crafting_recipes_preivew_selected +1
		update_preview(state)
	end)
	pr_next_btn:setVisible(false)

	local group_sel = state:listbox(10.2, 0.15, 7.6, 3.6, "groups_sel",nil, true)
	group_sel:onClick(function(self, state, player)
		local selected = self:getSelectedItem()
		if selected then
			update_group_selection(state, false)
		end
	end)

	-- craftable items grid
	state:background(10, 5, 8, 4, "buttons_grid_Bg", "minimap_overlay_square.png")
	local grid = smart_inventory.smartfs_elements.buttons_grid(state, 10.25, 5.15, 8 , 4, "buttons_grid", 0.75,0.75)
	grid:onClick(function(self, state, index, player)
		local listentry = state.param.crafting_craftable_list[index]
		state.param.crafting_recipes_preivew_selected = 1
		state.param.crafting_recipes_preivew_listentry = listentry
		update_preview(state)
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
