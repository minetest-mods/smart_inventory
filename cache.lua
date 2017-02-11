local filter = smart_inventory.filter

local cache = {}
cache.groups = {}
cache.items = {}
cache.recipes = {}

cache.group_placeholder = {}

cache.group_info = {
	group_level = { shortdesc = "Uses level information" },
	group_dig_immediate = { shortdesc = "Fast removable" },
	group_disable_jump = { shortdesc = "Not jumpable" },
	group_less_damage  = { shortdesc = "Less damage" },
	group_more_damage  = { shortdesc = "More damage" },
	group_bouncy = { shortdesc = "Bouncy" },
	group_falling_node = { shortdesc = "Falling" },
	group_attached_node = { shortdesc = "Attachable" },
	group_connect_to_raillike = { shortdesc = "Rail-like" },
	-- TODO: http://dev.minetest.net/Groups/Custom_groups

	type_tool = { shortdesc = "Tools" },
	type_node = { shortdesc = "Node" },

	-- custom
	transluc = { shortdesc = "Translucent blocks" },
	inventory = { shortdesc = "Chestlike vessels" },

	-- list specific
	all = {shortdesc = "All items" },
	other = {shortdesc = "Other items" }
}

local function add_to_cache(group_name, def, shortdesc)
	if not cache.groups[group_name] then
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
		cache.groups[group_name] = group
	end
	table.insert(cache.groups[group_name].items,def)

	if not cache.items[def.name] then
		local item = {
			groups = {}
		}
		cache.items[def.name] = item
	end
	table.insert(cache.items[def.name].groups,cache.groups[group_name])
end

-- build cache at start
function cache.fill_cache()
	for name, def in pairs(minetest.registered_items) do
		-- cache groups
		if def.description and def.description ~= "" and not def.groups.not_in_creative_inventory then
			for group, grval in pairs(def.groups) do
				local group_name = "group_"..group
				if group == "fall_damage_add_percent" and grval < 0 then
					group_name = "group_less_damage"
				elseif group == "fall_damage_add_percent" and grval > 0 then
					group_name = "group_more_damage"
				else
					group_name = "group_"..group
				end
				add_to_cache(group_name, def)
			end
			add_to_cache("type_"..def.type, def)
			add_to_cache("mod_"..def.mod_origin, def) -- TODO: get mod description and add it to shortdesc

			-- extended registred filters
			for _, flt in pairs(filter.registered_filter) do
				if flt:check_item_by_def(def) == true then
					add_to_cache("filter_"..flt.name, def, flt.shortdesc)
				end
			end
		end

		local recipelist = minetest.get_all_craft_recipes(name)
		if recipelist then
			for _, recipe in ipairs(recipelist) do
				if recipe.output ~= "" then
					for idx, recipe_item in pairs(recipe.items) do
						if not cache.recipes[recipe_item] then
							cache.recipes[recipe_item] = {}
						end
						if not cache.recipes[recipe_item][name] then
							cache.recipes[recipe_item][name] = {}
						end
						 -- "recipe_item" is in recipe of item "name". Multiple recipes possible
						table.insert(cache.recipes[recipe_item][name], recipe)
					end
				end
			end
		end
	end
end

-- Get all recipes with at least one item existing in players inventory
function cache.get_recipes_craftable_atnext(player)
	local inventory = minetest.get_player_by_name(player):get_inventory()
	local invlist = inventory:get_list("main")
	local items_in_inventory = {}
	local recipe_with_one_item_in_inventory = {}
	local outtab = {}
	for _, stack in ipairs(invlist) do
		local itemname = stack:get_name()
		items_in_inventory[itemname] = true 
	end

	for recipe_item, recipe_item_data in pairs(cache.recipes) do
		-- prepare current stack for crafting simulation
		local item_ok = false
		if items_in_inventory[recipe_item] then
			item_ok = true
		elseif recipe_item:sub(1, 6) == "group:" then
			local group_name = recipe_item:sub(7)
			if cache.group_placeholder[group_name] then
				for group_item, def in pairs(cache.group_placeholder[group_name]) do
					if items_in_inventory[group_item] then
						item_ok = true
					end
				end
			end
		end
		if item_ok == true then
			for name, recipetab in pairs(recipe_item_data) do
				for _, recipe in ipairs(recipetab) do
					recipe_with_one_item_in_inventory[recipe] = true
				end
			end
		end
	end
	return recipe_with_one_item_in_inventory, items_in_inventory
end

-- Get all recipes with all required items in players inventory. Without count match
function cache.get_recipes_craftable(player)
	local all, items_in_inventory = cache.get_recipes_craftable_atnext(player)
	local craftable = {}
	for recipe, _ in pairs(all) do
		local out_recipe = table.copy(recipe)
		out_recipe.items = table.copy(recipe.items) --deep copy
		local item_ok = true
		for idx, item in pairs(out_recipe.items) do
			local in_inventory = false
			if item:sub(1, 6) == "group:" then
				local group_name = item:sub(7)
				if cache.group_placeholder[group_name] then
					for group_item, def in ipairs(cache.group_placeholder[group_name].items) do
						if items_in_inventory[group_item] then
							in_inventory = true
							out_recipe.items[idx] = group_item
						end
					end
				end
			elseif items_in_inventory[item] then
				in_inventory = true
			end
			if in_inventory ~= true then
				item_ok = false
				break
			end
		end
		if item_ok == true then
			craftable[out_recipe] = true
		end
	end
	return craftable, items_in_inventory
end

function cache.get_list_grouped(itemtable)
	local grouped = {}
	local other = {}
	-- sort the entries to groups
	for _, entry in ipairs(itemtable) do
		local assigned = false
		if cache.items[entry.item] then
			for _, group in ipairs(cache.items[entry.item].groups) do
				if not grouped[group.name] then
					local group_info = table.copy(cache.groups[group.name])
					group_info.items = {}
					grouped[group.name] = group_info
				end
				table.insert(grouped[group.name].items, entry)
				assigned = true
			end
		end
		if assigned == false then
			table.insert(other, entry)
		end
	end
	-- TODO: magic to calculate relevant groups


	-- default groups
	grouped.all = {}
	grouped.all.name = "all"
	grouped.all.group_desc = cache.group_info[grouped.all.name].shortdesc
	grouped.all.items = itemtable

	grouped.other = {}
	grouped.other.name = "other"
	grouped.other.group_desc = cache.group_info[grouped.all.name].shortdesc
	grouped.other.items = other

	return grouped
end


-- fill the cache after all mods loaded
minetest.after(0, cache.fill_cache)

-- return the reference to the mod
return cache
