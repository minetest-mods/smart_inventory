local ui_tools = {}

-----------------------------------------------------
-- Group item list and prepare for output
-----------------------------------------------------
-- Parameters:
-- grouped: grouped items list (result of cache.get_list_grouped)
-- groups_sel: smartfs Element (table) that should contain the groups
-- groups_tab: shadow table that with items per group that will be updated in this method
-- Return: updated groups_tab

function ui_tools.update_group_selection(grouped, groups_sel, groups_tab)
	-- save old selection
	local sel_id = groups_sel:getSelected()
	local sel_grp
	if sel_id and groups_tab then
		sel_grp = groups_tab[sel_id]
	end

	-- sort the groups
	local group_sorted = {}
	for _, group in pairs(grouped) do
		table.insert(group_sorted, group)
	end

	table.sort(group_sorted, function(a,b)
		local sort_fixed_order = {
			["all"] = "  ",    -- at the begin
			["other"] = "ZZ1", -- at the end
			["shape"] = "ZZ2", --at the end
		}
		local aval = sort_fixed_order[a.name] or a.name
		local bval = sort_fixed_order[b.name] or b.name
		return aval < bval
	end)

	-- apply groups to the groups_sel table and to the new groups_tab
	groups_sel:clearItems()
	groups_tab = {}
	for _, group in ipairs(group_sorted) do
		if #group.items > 0 then
			local idx = groups_sel:addItem(group.group_desc.." ("..#group.items..")")
			groups_tab[idx] = group.name
			if sel_grp == group.name then
				sel_id = idx
			end
		end
	end

	-- restore selection
	if not groups_tab[sel_id] then
		sel_id = 1
	end
	groups_sel:setSelected(sel_id)

	return groups_tab
end

function ui_tools.create_trash_inv(state, name)
	local player = minetest.get_player_by_name(name)
	local invname = name.."_trash_inv"
	local listname = "trash"
	local inv = minetest.get_inventory({type="detached", name=invname})
	if not inv then
		inv = minetest.create_detached_inventory(invname, {
			allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
				return 0
			end,
			allow_put = function(inv, listname, index, stack, player)
				return 99
			end,
			allow_take = function(inv, listname, index, stack, player)
				return 99
			end,
			on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
			end,
			on_put = function(inv, listname, index, stack, player)
				minetest.after(1, function(stack)
					inv:set_stack(listname, index, nil)
				end)
			end,
			on_take = function(inv, listname, index, stack, player)
				inv:set_stack(listname, index, nil)
			end,
		}, name)
	end
	inv:set_size(listname, 1)
end

function ui_tools.search_in_list(list, search_string, playername)
local cache = smart_inventory.cache
	local filtered_list = {}
	search_string = search_string:lower()
	for _, entry in ipairs(list) do
		local def = minetest.registered_items[entry.item]
		if string.find(def.description:lower(), search_string) or
			string.find(def.name:lower(), search_string) then
			table.insert(filtered_list, entry)
		else
			for _, cgroup in pairs(entry.citem.cgroups) do
				local prefix_end_pos = cgroup.name:find(":")
				if string.find(cgroup.name:lower(), search_string, prefix_end_pos) then
					table.insert(filtered_list, entry)
					break
				elseif string.find(cgroup.group_desc:lower(), search_string) then
					table.insert(filtered_list, entry)
					break
				end
			end
		end
	end
	if smart_inventory.doc_items_mod and playername then
		for _, entry in ipairs(filtered_list) do
			if entry.recipes then
				local valid_recipes = {}
				for _, recipe in ipairs(entry.recipes) do
					if cache.crecipes[recipe]:is_revealed(playername) then
						table.insert(valid_recipes, recipe)
					end
				end
				entry.recipes = valid_recipes
			end
		end
	end
	return filtered_list
end


function ui_tools.get_tight_groups(cgroups)
	local out_list = {}
	for group1, groupdef1 in pairs(cgroups) do
		if not string.find(group1, "ingredient:") then
			out_list[group1] = groupdef1
			for group2, groupdef2 in pairs(out_list) do
				if string.len(group1) > string.len(group2) and
						string.sub(group1,1,string.len(group2)) == group2 then
						-- group2 is top-group of group1. Remove the group2
					out_list[group2] = nil
				elseif string.len(group1) < string.len(group2) and
						string.sub(group2,1,string.len(group1)) == group1 then
						-- group2 is top-group of group1. Remove the group2
					out_list[group1] = nil
				end
			end
		end
	end
	local out_list_sorted = {}
	for group, groupdef in pairs(out_list) do
		table.insert(out_list_sorted, groupdef)
	end
	table.sort(out_list_sorted, function(a,b)
		return a.group_desc < b.group_desc
	end)
	return out_list_sorted
end

--------------------------------
return ui_tools
