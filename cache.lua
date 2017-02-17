local filter = smart_inventory.filter

local cache = {}
cache.cgroups = {}
cache.citems = {}
cache.crecipes = {}

-----------------------------------------------------
-- Group labels
-----------------------------------------------------
cache.group_info = {
--[[	group_level = { shortdesc = "Uses level information" },
	group_dig_immediate = { shortdesc = "Fast removable" },
	group_disable_jump = { shortdesc = "Not jumpable" },
	group_less_damage  = { shortdesc = "Less damage" },
	group_more_damage  = { shortdesc = "More damage" },
	group_bouncy = { shortdesc = "Bouncy" },
	group_falling_node = { shortdesc = "Falling" },
	group_attached_node = { shortdesc = "Attachable" },
	group_connect_to_raillike = { shortdesc = "Rail-like" },
	-- TODO: http://dev.minetest.net/Groups/Custom_groups

	group_armor_use = { shortdesc = "Armor" },
	group_armor_heal = { shortdesc = "Armor" },
	group_cracky = { shortdesc = "Cracky" },
	group_flammable = { shortdesc = "Flammable" },
	group_snappy = { shortdesc = "Snappy" },
	group_choppy = { shortdesc = "Choppy" },
	group_oddly_breakable_by_hand = { shortdesc = "Oddly breakable" },
	type_tool = { shortdesc = "Tools" },
	type_node = { shortdesc = "Nodes" },
	type_craft = { shortdesc = "Craft Items" },

	-- custom
	transluc = { shortdesc = "Translucent blocks" },
	inventory = { shortdesc = "Chestlike vessels" },
]]
	-- list specific
	all = {shortdesc = "All items" },
	other = {shortdesc = "Other items" }
}


-----------------------------------------------------
-- Add a item to cache group
-----------------------------------------------------
function cache.add_to_cache_group(group_name, itemdef, shortdesc)
	if not cache.cgroups[group_name] then
		local group = {
			name = group_name,
			group_desc = shortdesc,
			items = {}
			}
		if not group.group_desc and cache.group_info[group_name] then
			group.group_desc = cache.group_info[group_name].shortdesc
		end
		if not group.group_desc then
			group.group_desc = group_name
		end
		cache.cgroups[group_name] = group
	end
	table.insert(cache.cgroups[group_name].items,itemdef)

	if not cache.citems[itemdef.name] then
		local entry = {
			name = itemdef.name,
			in_output_recipe = {},
			in_craft_recipe = {},
			cgroups = {}
		}
		cache.citems[itemdef.name] = entry
	end
	table.insert(cache.citems[itemdef.name].cgroups,cache.cgroups[group_name])
end

-----------------------------------------------------
-- Resolve item in recipe described by groups to items list
-----------------------------------------------------
function cache.recipe_items_resolve_group(group_item)
	local retitems = cache.cgroups[group_item]
	if retitems then
		return retitems.items
	end

	for groupname in string.gmatch(group_item:sub(7), '([^,]+)') do
		if not retitems then --first entry
			if cache.cgroups["group:"..groupname] then
				retitems = table.copy(cache.cgroups["group:"..groupname].items)
			else
				minetest.log("verbose", "[smartfs_inventory] unknown group description in recipe: "..group_item, groupname)
			end
		else
			for i = #retitems, 1, -1 do
				local item_in_group = false
				for _, item_group in pairs(cache.citems[retitems[i].name].cgroups) do
					if item_group.name == "group:"..groupname then
						item_in_group = true
						break
					end
				end
				if item_in_group == false then
					table.remove(retitems,i)
				end
			end
		end
		if not retitems or not next(retitems) then
			minetest.log("verbose", "[smartfs_inventory] no items matches group: "..group_item)
			return nil
		end
	end
	--create new group
	if retitems then
		for _, itemdef in ipairs(retitems) do
			cache.add_to_cache_group(group_item, itemdef)
		end
	end
	return retitems
end


function cache.fill_recipe_cache()
	for itemname, _ in pairs(cache.citems) do
		local recipelist = minetest.get_all_craft_recipes(itemname)
		if recipelist then
			for _, recipe in ipairs(recipelist) do
				-- apply recipe output
				if recipe.output ~= "" then
					local outdef = minetest.registered_items[recipe.output]
					if not outdef then
						recipe.output:gsub("[^%s]+", function(z)
							if minetest.registered_items[z] then
								outdef = minetest.registered_items[z]
							end
						end)
					end
					if not outdef then
						minetest.log("verbose", "[smartfs_inventory] unknown recipe result "..recipe.output.." for item "..itemname)
					else
						table.insert(cache.citems[outdef.name].in_output_recipe, recipe)
						cache.crecipes[recipe] = {
							recipe_items = {},
							out_item = outdef.name
						}
						for idx, recipe_item in pairs(recipe.items) do
							local itemlist = {}
							if recipe_item:sub(1, 6) == "group:" then
								local groupitems = cache.recipe_items_resolve_group(recipe_item)
								if not groupitems then
									minetest.log("verbose", "[smartfs_inventory] skip recipe for: "..itemname)
								else
									for _, item in ipairs(cache.recipe_items_resolve_group(recipe_item)) do
										table.insert(itemlist, item.name)
									end
								end
							else
								table.insert(itemlist,recipe_item)
							end
							cache.crecipes[recipe].recipe_items[recipe_item] = {}
							for _, itemname in ipairs(itemlist) do
								if cache.citems[itemname] then
									table.insert(cache.citems[itemname].in_craft_recipe, recipe)
									table.insert(cache.crecipes[recipe].recipe_items[recipe_item], itemname)
								end
							end
						end
					end
				end
			end
		end
	end
end

-----------------------------------------------------
-- Fill the cache at start
-----------------------------------------------------
function cache.fill_cache()
	for name, def in pairs(minetest.registered_items) do
		-- build groups and items cache
		if def.description and def.description ~= "" and not def.groups.not_in_creative_inventory then
			for group, grval in pairs(def.groups) do
				local group_name = "group:"..group
				cache.add_to_cache_group(group_name, def)
			end
			cache.add_to_cache_group("type:"..def.type, def)
			cache.add_to_cache_group("mod:"..def.mod_origin, def) -- TODO: get mod description and add it to shortdesc

			-- extended registred filters
			for _, flt in pairs(filter.registered_filter) do
				if flt:check_item_by_def(def) == true then
					cache.add_to_cache_group("filter:"..flt.name, def, flt.shortdesc)
				end
			end
		end
	end
	minetest.after(0, cache.fill_recipe_cache) --fill in second step
end

-----------------------------------------------------
-- Get all recipes with at least one item existing in players inventory
-----------------------------------------------------
function cache.get_recipes_craftable_atnext(player, item)
	local inventory = minetest.get_player_by_name(player):get_inventory()
	local invlist = inventory:get_list("main")
	local items_in_inventory = {}
	local recipe_with_one_item_in_inventory = {}
	if item then
		items_in_inventory[item] = true
	else
		for _, stack in ipairs(invlist) do
			local itemname = stack:get_name()
			if itemname and itemname ~= "" then
				items_in_inventory[itemname] = true
			end
		end
	end
	for itemname, _ in pairs(items_in_inventory) do
		for _, recipe in ipairs(cache.citems[itemname].in_craft_recipe) do
			local def = minetest.registered_items[recipe.output]
			if not def then
				recipe.output:gsub("[^%s]+", function(z)
					if minetest.registered_items[z] then
						def = minetest.registered_items[z]
					end
				end)
			end
			if def then
				for recipe_item, itemtab in pairs(cache.crecipes[recipe].recipe_items) do
					for _, itemname in ipairs(itemtab) do
						if filter.is_revealed_item(itemname, player) then
							recipe_with_one_item_in_inventory[recipe] = true
							break
						end
					end
					if recipe_with_one_item_in_inventory[recipe] == true then
						break
					end
				end
			end
		end
	end
	return recipe_with_one_item_in_inventory, items_in_inventory
end

-----------------------------------------------------
-- Get all recipes with all required items in players inventory. Without count match
-----------------------------------------------------
function cache.get_recipes_craftable(player)
	local all, items_in_inventory = cache.get_recipes_craftable_atnext(player)
	local craftable = {}
	for recipe, _ in pairs(all) do
		local item_ok = false
		for _, itemtab in pairs(cache.crecipes[recipe].recipe_items) do
			item_ok = false
			for _, itemname in ipairs(itemtab) do
				if items_in_inventory[itemname] then
					item_ok = true
				end
			end
			if item_ok == false then
				break
			end
		end
		if item_ok == true then
			craftable[recipe] = true
		end
	end
	return craftable, items_in_inventory
end

-----------------------------------------------------
-- Sort items to groups and decide which groups should be displayed
-----------------------------------------------------
function cache.get_list_grouped(itemtable)
	local grouped = {}
	-- sort the entries to groups
	for _, entry in ipairs(itemtable) do
		if cache.citems[entry.item] then
			for _, group in ipairs(cache.citems[entry.item].cgroups) do
				if not grouped[group.name] then
					local group_info = {}
					group_info.name = group.name
					group_info.cgroup = cache.cgroups[group.name]
					group_info.items = {}
					grouped[group.name] = group_info
				end
				table.insert(grouped[group.name].items, entry)
			end
		end
	end

	-- magic to calculate relevant groups
	local itemcount = #itemtable
--	local best_group_count = itemcount ^(1/3)
	local best_group_count = math.sqrt(itemcount/2)
	local best_group_size = (itemcount / best_group_count) * 1.5
	best_group_count = math.floor(best_group_count)
	local sorttab = {}

	for k,v in pairs(grouped) do
		v.group_size = #v.items
		v.unique_count = #v.items
		v.diff = math.abs(v.group_size - best_group_size)
		table.insert(sorttab, v)
	end

	local outtab = {}
	local assigned_items = {}
	if best_group_count > 0 then
		for i = 1, best_group_count do
			-- sort by best size
			table.sort(sorttab, function(a,b)
				return a.diff < b.diff
			end)

			-- select the best
			local sel = sorttab[1]
			if not sel then
				break
			end
			outtab[sel.name] = {
				name = sel.name,
				group_desc = sel.cgroup.group_desc,
				items = sel.items
			}
			table.remove(sorttab,1)

			for _, item in ipairs(sel.items) do
				assigned_items[item.item] = true
			-- update the not selected groups
				for _, group in ipairs(cache.citems[item.item].cgroups) do
					if group.name ~= sel.name then
						local u = grouped[group.name]
						if u and u.unique_count then
							u.unique_count = u.unique_count-1
							if (u.group_size < best_group_size) or
									(u.group_size - best_group_size) < (best_group_size - u.unique_count) then
								sel.diff = best_group_size - u.unique_count
							end
						end
					end
				end
			end
			for idx = #sorttab, 1, -1 do
				if sorttab[idx].unique_count <= 1 then
					table.remove(sorttab, idx)
				end
			end
		end
	end

	-- fill other group
	local other = {}
	for _, item in ipairs(itemtable) do
		if not assigned_items[item.item] then
			table.insert(other, item)
		end
	end

	-- default groups
	outtab.all = {}
	outtab.all.name = "all"
	outtab.all.group_desc = cache.group_info[outtab.all.name].shortdesc
	outtab.all.items = itemtable

	outtab.other = {}
	outtab.other.name = "other"
	outtab.other.group_desc = cache.group_info[outtab.other.name].shortdesc
	outtab.other.items = other

	return outtab
end

-----------------------------------------------------
-- fill the cache after all mods loaded
-----------------------------------------------------
minetest.after(0, cache.fill_cache)

-----------------------------------------------------
-- return the reference to the mod
-----------------------------------------------------
return cache
