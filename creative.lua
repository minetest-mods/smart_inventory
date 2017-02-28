local cache = smart_inventory.cache
local filter = smart_inventory.filter
local ui_tools = smart_inventory.ui_tools

local function on_item_select(state, entry)
	local player = minetest.get_player_by_name(state.location.rootState.location.player)
	local pinv = player:get_inventory()
	pinv:add_item("main", entry.item)
end

local function get_all_items(state)
	local outtab = {}
	local outtab_material = {}
	for itemname, citem in pairs(cache.citems) do
		local entry = {
			citem = citem,
			-- buttons_grid related
			item = itemname,
			is_button = true
		}
		if cache.citems[itemname].cgroups["filter:material"] then
			table.insert(outtab_material, entry)
		else
			table.insert(outtab, entry)
		end
	end
	return outtab, outtab_material
end


local function update_group_selection(state, changed_group)

	local grouped = state.param.creative_grouped_items
	local groups_sel1 = state:get("groups_sel1")
	local groups_sel2 = state:get("groups_sel2")
	local groups_sel3 = state:get("groups_sel3")
	local grid = state:get("buttons_grid")
	local outlist


	if state.param.creative_grouped_material_items and
			next(state.param.creative_grouped_material_items) then
		local group_info = {}
		group_info.name = "filter:material"
		group_info.cgroup = cache.cgroups["filter:material"]
		group_info.group_desc = group_info.cgroup.group_desc
		group_info.items = state.param.creative_grouped_material_items
		grouped["filter:material"] = group_info
	end

	-- Group 1
	if changed_group < 1 or not state.param.creative_group_list1 then
		state.param.creative_group_list1 = ui_tools.update_group_selection(grouped, groups_sel1, state.param.creative_group_list1)
	end

	local sel_id = groups_sel1:getSelected()
	if state.param.creative_group_list1[sel_id] == "all" or not state.param.creative_group_list1[sel_id] then
		outlist = grouped["all"].items
		groups_sel2:clearItems()
		groups_sel3:clearItems()
	else
		local is_material_selected = ( state.param.creative_group_list1[sel_id] == "filter:material" )
		-- Group 2
		grouped = cache.get_list_grouped(grouped[state.param.creative_group_list1[sel_id]].items)
		if changed_group < 2 or not state.param.creative_group_list2 then
			state.param.creative_group_list2 = ui_tools.update_group_selection(grouped, groups_sel2, state.param.creative_group_list2)
		end

		sel_id = groups_sel2:getSelected()
		if state.param.creative_group_list2[sel_id] == "all" or not state.param.creative_group_list2[sel_id] then
			outlist = grouped["all"].items
			groups_sel3:clearItems()
		else
			-- Group 3
--			if is_material_selected then
--				grouped = cache.get_list_grouped_by_base_material(grouped[state.param.creative_group_list2[sel_id]].items)
--			else
				grouped = cache.get_list_grouped(grouped[state.param.creative_group_list2[sel_id]].items)
--			end
			if changed_group < 3 or not state.param.creative_group_list3 then
				state.param.creative_group_list3 = ui_tools.update_group_selection(grouped, groups_sel3, state.param.creative_group_list3)
			end
			sel_id = groups_sel3:getSelected()
			outlist = grouped[state.param.creative_group_list3[sel_id]].items
		end
	end

	-- TODO: other selections
	local grid = state:get("buttons_grid")
	if outlist then
		-- sort selected items
		table.sort(outlist, function(a,b)
			return a.item < b.item
		end)
		grid:setList(outlist)
		state.param.creative_outlist = outlist
	else
		grid:setList({})
	end
end

local function creative_callback(state)
	local player = state.location.rootState.location.player

	local group_sel1 = state:listbox(1, 0.15, 5.6, 3, "groups_sel1",nil, false)
	group_sel1:onClick(function(self, state, player)
		local selected = self:getSelectedItem()
		if selected then
			state:get("groups_sel2"):setSelected(1)
			state:get("groups_sel3"):setSelected(1)
			update_group_selection(state, 1)
		end
	end)

	local group_sel2 = state:listbox(7, 0.15, 5.6, 3, "groups_sel2",nil, false)
	group_sel2:onClick(function(self, state, player)
		local selected = self:getSelectedItem()
		if selected then
			state:get("groups_sel3"):setSelected(1)
			update_group_selection(state, 2)
		end
	end)

	local group_sel3 = state:listbox(13, 0.15, 5.6, 3, "groups_sel3",nil, false)
	group_sel3:onClick(function(self, state, player)
		local selected = self:getSelectedItem()
		if selected then
			update_group_selection(state, 3)
		end
	end)

	state:field(7.5, 4, 4, 0.5, "search"):setCloseOnEnter(false)

	-- craftable items grid
	state:background(0.9, 4.5, 18, 3.5, "buttons_grid_bg", "minimap_overlay_square.png")
	local grid = smart_inventory.smartfs_elements.buttons_grid(state, 1.25, 4.75, 17.5 , 3.5, "buttons_grid", 0.75,0.75)
	grid:onClick(function(self, state, index, player)
		local listentry = state.param.creative_outlist[index]
		on_item_select(state, listentry)
	end)

	state:inventory(1.4, 8, 16, 2,"main")
	ui_tools.create_trash_inv(state, player)
	state:image(17.6,8,1,1,"trash_icon","creative_trash_icon.png")
	state:element("code", {name = "trash_bg_code", code = "listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"})
	state:inventory(17.6, 8, 1, 1, "trash"):useDetached(player.."_trash_inv")

	-- filter on input
	state:onInput(function(state, fields, player)
		local search_string = state:get("search"):getText()
		if search_string ~= (state.param.creative_search_string or "") then
			local filtered_list = {}
			state.param.creative_search_string = search_string:lower()
			for _, entry in ipairs(state.param.creative_grouped_items_all) do
				local def = minetest.registered_items[entry.item]
				if string.find(def.description:lower(), search_string) or
					string.find(def.name:lower(), search_string) then
					table.insert(filtered_list, entry)
				else
					for _, cgroup in pairs(entry.citem.cgroups) do
						if string.find(cgroup.name:lower(), search_string) then
							table.insert(filtered_list, entry)
							break
						end
					end
				end
			end
			state.param.creative_grouped_items = cache.get_list_grouped(filtered_list)

			filtered_list = {}
			for _, entry in ipairs(state.param.creative_grouped_items_material_all) do
				local def = minetest.registered_items[entry.item]
				if string.find(def.description, search_string) or
					string.find(def.name, search_string) then
					table.insert(filtered_list, entry)
				else
					for _, cgroup in ipairs(entry.citem.cgroups) do
						if string.find(cgroup.name, search_string) then
							table.insert(filtered_list, entry)
							break
						end
					end
				end
			end
			state.param.creative_grouped_material_items = filtered_list
			update_group_selection(state, 0)
		end
	end)

	-- fill with data
	state.param.creative_grouped_items_all, state.param.creative_grouped_items_material_all  = get_all_items(state)
	state.param.creative_grouped_items = cache.get_list_grouped(state.param.creative_grouped_items_all)
	state.param.creative_grouped_material_items = state.param.creative_grouped_items_material_all
	update_group_selection(state, 0)

end


smart_inventory.register_page({
	name = "creative",
	tooltip = "The creative way to get items",
	icon = "default_chest_front.png",
	smartfs_callback = creative_callback,
	sequence = 15
})
