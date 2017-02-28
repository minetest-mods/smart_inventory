local ui_tools = {}

local cache = smart_inventory.cache

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
			["filter:material"] = "ZZZ2",
			["all"] = "__1",
			["other"] = "ZZZ1",
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
				inv:set_stack(listname, index, nil)
			end,
			on_take = function(inv, listname, index, stack, player)
				inv:set_stack(listname, index, nil)
			end,
		}, name)
	end
	inv:set_size(listname, 1)
end

--------------------------------
return ui_tools
