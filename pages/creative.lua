if not minetest.setting_getbool("creative_mode") then
	return
end

local cache = smart_inventory.cache
local ui_tools = smart_inventory.ui_tools

-----------------------------------------------------
-- Update on group selection change
-----------------------------------------------------
local function update_group_selection(state, changed_group)
	local grouped = state.param.creative_grouped_items
	local groups_sel1 = state:get("groups_sel1")
	local groups_sel2 = state:get("groups_sel2")
	local groups_sel3 = state:get("groups_sel3")
	local grid = state:get("buttons_grid")
	local outlist

	if state.param.creative_grouped_shape_items and
			next(state.param.creative_grouped_shape_items) then
		local group_info = {}
		group_info.name = "shape"
		group_info.cgroup = cache.cgroups["shape"]
		group_info.group_desc = "#01DF74> "..group_info.cgroup.group_desc
		group_info.items = state.param.creative_grouped_shape_items
		grouped["shape"] = group_info
	end

	-- update group 1
	if changed_group < 1 or not state.param.creative_group_list1 then
		state.param.creative_group_list1 = ui_tools.update_group_selection(grouped, groups_sel1, state.param.creative_group_list1)
	end

	local sel_id = groups_sel1:getSelected()
	if state.param.creative_group_list1[sel_id] == "all"
			or not state.param.creative_group_list1[sel_id]
			or not grouped[state.param.creative_group_list1[sel_id]] then
		outlist = grouped["all"].items
		groups_sel2:clearItems()
		groups_sel3:clearItems()
	else
		-- update group 2
		grouped = ui_tools.get_list_grouped(grouped[state.param.creative_group_list1[sel_id]].items)
		if changed_group < 2 or not state.param.creative_group_list2 then
			state.param.creative_group_list2 = ui_tools.update_group_selection(grouped, groups_sel2, state.param.creative_group_list2)
		end

		sel_id = groups_sel2:getSelected()
		if state.param.creative_group_list2[sel_id] == "all"
				or not state.param.creative_group_list2[sel_id]
				or not grouped[state.param.creative_group_list2[sel_id]] then
			outlist = grouped["all"].items
			groups_sel3:clearItems()
		else
			-- update group 3
			grouped = ui_tools.get_list_grouped(grouped[state.param.creative_group_list2[sel_id]].items)
			if changed_group < 3 or not state.param.creative_group_list3 then
				state.param.creative_group_list3 = ui_tools.update_group_selection(grouped, groups_sel3, state.param.creative_group_list3)
			end
			sel_id = groups_sel3:getSelected()
			outlist = grouped[state.param.creative_group_list3[sel_id]].items
		end
	end

	-- update grid list
	if outlist then
		table.sort(outlist, function(a,b)
			return a.item < b.item
		end)
		grid:setList(outlist)
		state.param.creative_outlist = outlist
	else
		grid:setList({})
	end
end

-----------------------------------------------------
-- Page layout definition
-----------------------------------------------------
local function creative_callback(state)
	local player = state.location.rootState.location.player

	-- groups 1-3
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

	-- functions
	local searchfield = state:field(5.3, 4.2, 4, 0.5, "search")
	searchfield:setCloseOnEnter(false)
	searchfield:onKeyEnter(function(self, state, player)
		local search_string = self:getText()
		local filtered_list = ui_tools.filter_by_searchstring(ui_tools.root_list, search_string)
		state.param.creative_grouped_items = ui_tools.get_list_grouped(filtered_list)
		filtered_list = ui_tools.filter_by_searchstring(ui_tools.root_list_shape, search_string)
		state.param.creative_grouped_shape_items = filtered_list
		update_group_selection(state, 0)
	end)

	-- craftable items grid
	state:background(9.2, 3.5, 9.5, 6.5, "buttons_grid_bg", "minimap_overlay_square.png")
	local grid = smart_inventory.smartfs_elements.buttons_grid(state, 9.55, 3.75, 9.0 , 6.5, "buttons_grid", 0.75,0.75)
	grid:onClick(function(self, state, index, player)
		state.param.invobj:add_item(state.param.creative_outlist[index].item)
	end)

	-- inventory
	state:inventory(1, 5, 8, 4,"main")
	ui_tools.create_trash_inv(state, player)
	state:image(8,9,1,1,"trash_icon","creative_trash_icon.png")
	state:element("code", {name = "trash_bg_code", code = "listcolors[#00000069;#5A5A5A;#141318;#30434C;#FFF]"})
	state:inventory(8,9,1,1, "trash"):useDetached(player.."_trash_inv")

	-- swap slots buttons
	state:button(0, 6, 1, 1, "swap1", ">"):onClick(function(self, state, player)
		state.param.invobj:swap_row_to_top(2)
	end)
	state:button(0, 7, 1, 1, "swap2", ">"):onClick(function(self, state, player)
		state.param.invobj:swap_row_to_top(3)
	end)
	state:button(0, 8, 1, 1, "swap3", ">"):onClick(function(self, state, player)
		state.param.invobj:swap_row_to_top(4)
	end)

	-- trash button
	local trash_all = state:button(7,9,1,1, "trash_all", "Trash all")
	trash_all:setImage("creative_trash_icon.png")
	trash_all:onClick(function(self, state, player)
		state.param.invobj:remove_all()
	end)

	-- save/restore buttons
	state:button(1,9,1,1, "save1", "Save 1"):onClick(function(self, state, player)
		state.param.invobj:save_to_slot(1)
	end)
	state:button(1.9,9,1,1, "save2", "Save 2"):onClick(function(self, state, player)
		state.param.invobj:save_to_slot(2)
	end)
	state:button(2.8,9,1,1, "save3", "Save 3"):onClick(function(self, state, player)
		state.param.invobj:save_to_slot(3)
	end)
	state:button(4,9,1,1, "restore1", "Get 1"):onClick(function(self, state, player)
		state.param.invobj:restore_from_slot(1)
	end)
	state:button(4.9,9,1,1, "restore2", "Get 2"):onClick(function(self, state, player)
		state.param.invobj:restore_from_slot(2)
	end)
	state:button(5.8,9,1,1, "restore3", "Get 3"):onClick(function(self, state, player)
		state.param.invobj:restore_from_slot(3)
	end)

	-- fill with data
	state.param.creative_grouped_items = ui_tools.get_list_grouped(ui_tools.root_list)
	state.param.creative_grouped_shape_items = ui_tools.root_list_shape
	update_group_selection(state, 0)
end

-----------------------------------------------------
-- Register page in smart_inventory
-----------------------------------------------------
smart_inventory.register_page({
	name = "creative",
	tooltip = "The creative way to get items",
	icon = "default_chest_front.png",
	smartfs_callback = creative_callback,
	sequence = 15
})
