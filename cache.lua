local filter = smart_inventory.filter
local doc_addon = smart_inventory.doc_addon

local cache = {}
cache.cgroups = {}
cache.citems = {}


--+++++++++++++++++++++++++++++++++++++++++++++++++--
-- cached recipes object
--+++++++++++++++++++++++++++++++++++++++++++++++++--
local crecipes = {}
cache.crecipes = crecipes

-----------------------------------------------------
-- Get all revealed recipes with at least one item in reference_items table
-----------------------------------------------------
function crecipes.get_revealed_recipes_with_items(playername, reference_items)
	local recipelist = {}
	for itemname, _ in pairs(reference_items) do
		if cache.citems[itemname] and cache.citems[itemname].in_craft_recipe then
			for _, recipe in ipairs(cache.citems[itemname].in_craft_recipe) do
				local crecipe = cache.crecipes[recipe]
				if crecipe and crecipe:is_revealed(playername) then
					recipelist[recipe] = crecipe
				end
			end
		end
	end
	return recipelist
end

-----------------------------------------------------
-- Get all recipes with all required items in reference items
-----------------------------------------------------
function crecipes.get_recipes_craftable(playername, reference_items)
	local all = crecipes.get_revealed_recipes_with_items(playername, reference_items)
	local craftable = {}
	for recipe, crecipe in pairs(all) do
		local item_ok = false
		for _, entry in pairs(crecipe._items) do
			item_ok = false
			for _, itemdef in pairs(entry.items) do
				if reference_items[itemdef.name] then
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
	return craftable
end

-----------------------------------------------------
-- Recipe object Constructor
-----------------------------------------------------
function crecipes.new(recipe)
	local self = {}
	self.out_item = nil
	self._recipe = recipe
	self.recipe_type = recipe.type
	self._items = {}
	self.recipe_items = self._items --???

	-----------------------------------------------------
	-- analyze all data. Return false if invalid recipe. true on success
	-----------------------------------------------------
	function self:analyze()
		-- check recipe output
		if self._recipe.output ~= "" then
			self.out_item = minetest.registered_items[self._recipe.output]
			if not self.out_item then
				recipe.output:gsub("[^%s]+", function(z)
					if minetest.registered_items[z] then
						self.out_item = minetest.registered_items[z]
					end
				end)
			end
		end
		if not self.out_item or not self.out_item.name or not cache.citems[self.out_item.name] then
			minetest.log("[smartfs_inventory] unknown recipe result "..recipe.output)
			return false
		end
		-- check recipe items/groups
		for idx, recipe_item in pairs(self._recipe.items) do
			if self._items[recipe_item] then
				self._items[recipe_item].count = self._items[recipe_item].count + 1
			else
				self._items[recipe_item]  = {count = 1}
				if recipe_item:sub(1, 6) ~= "group:" then
					self._items[recipe_item]  = {count = 1}
					if minetest.registered_items[recipe_item] then
						self._items[recipe_item].items = {[recipe_item] = minetest.registered_items[recipe_item]}
					else
						minetest.log("[smartfs_inventory] unknown item in recipe: "..recipe_item)
						return false
					end
				else
					if cache.cgroups[recipe_item] then
						self._items[recipe_item].items = cache.cgroups[recipe_item].items
					else
						local retitems
						for groupname in string.gmatch(recipe_item:sub(7), '([^,]+)') do
							if not retitems then --first entry
								if cache.cgroups["group:"..groupname] then
									retitems = table.copy(cache.cgroups["group:"..groupname].items)
								else
									minetest.log("[smartfs_inventory] unknown group description in recipe: "..recipe_item, groupname)
								end
							else
								for itemname, itemdef in pairs(retitems) do
									local item_in_group = false
									for _, item_group in pairs(cache.citems[itemname].cgroups) do
										if item_group.name == "group:"..groupname then
											item_in_group = true
											break
										end
									end
									if item_in_group == false then
										retitems[itemname] = nil
									end
								end
							end
						end
						if not retitems or not next(retitems) then
							minetest.log("[smartfs_inventory] no items matches group: "..recipe_item)
							return false
						else
							self._items[recipe_item].items = retitems
						end
					end
				end
			end
		end
		-- invalid recipe
		if not self._items then
			minetest.log("[smartfs_inventory] skip recipe for: "..recipe_item)
			return false
		else
			return true
		end
	end

	-----------------------------------------------------
	-- Check if the recipe is revealed to the player
	-----------------------------------------------------
	function self:is_revealed(playername)
		local recipe_valid = true
		for _, entry in pairs(self._items) do
			recipe_valid = false
			for _, itemdef in pairs(entry.items) do
				if doc_addon.is_revealed_item(itemdef.name, playername) then
					recipe_valid = true
					break
				end
			end
			if recipe_valid == false then
				return false
			end
		end
		return true
	end

	-----------------------------------------------------
	-- Returns recipe without groups, with replacements
	-----------------------------------------------------
	function self:get_with_placeholder(player, inventory_tab)
		local recipe = table.copy(self._recipe)
		recipe.items = table.copy(recipe.items)
		for key, recipe_item in pairs(recipe.items) do
			local item
			for _, item_in_list in pairs(self._items[recipe_item].items) do
				if inventory_tab and inventory_tab[item_in_list.name] then
					item = item_in_list.name
					break
				elseif doc_addon.is_revealed_item(item_in_list.name, player) then
					item = item_in_list.name
				elseif item == nil then
					item = item_in_list.name
				end
			end
			if item then
				recipe.items[key] = item
			end
		end
		return recipe
	end

	-----------------------------------------------------
	-- return constructed object
	return self
end

-----------------------------------------------------
-- Group labels
-----------------------------------------------------
cache.group_info = {
	all = {shortdesc = "All items" },
	other = {shortdesc = "Other items" },
}


-----------------------------------------------------
-- Add a item to cache group
-----------------------------------------------------
function cache.add_to_cache_group(group_name, itemdef, flt)
	if not cache.cgroups[group_name] then
		local group = {
			name = group_name,
			items = {}
			}
		if flt then
			group.group_desc = flt:get_group_description(group_name)
		elseif cache.group_info[group_name] then
			group.group_desc = cache.group_info[group_name].shortdesc
		else
			group.group_desc = group_name
		end
		if group.group_desc == "" or group.group_desc == "nogroup" then
			return
		end
		cache.cgroups[group_name] = group
	end
	cache.cgroups[group_name].items[itemdef.name] = itemdef

	if not cache.citems[itemdef.name] then
		local entry = {
			name = itemdef.name,
			in_output_recipe = {},
			in_craft_recipe = {},
			cgroups = {}
		}
		cache.citems[itemdef.name] = entry
	end
	cache.citems[itemdef.name].cgroups[group_name] = cache.cgroups[group_name]
end

-----------------------------------------------------
-- Fill the cache at init
-----------------------------------------------------
function cache.fill_cache()
	for name, def in pairs(minetest.registered_items) do
		-- build groups and items cache
		if def.description and def.description ~= "" and
				(not def.groups.not_in_creative_inventory or def.base_material) then

			-- extended registred filters
			for _, flt in pairs(filter.registered_filter) do
				local filter_result = flt:check_item_by_def(def)
				if filter_result then
					if filter_result == true then
						cache.add_to_cache_group(flt.name, def, flt)
					else
						if type(filter_result) ~= "table" then
							filter_result = {[filter_result] = true}
						end
						for key, val in pairs(filter_result) do
							local filter_entry = key
							if val ~= true then
								filter_entry = filter_entry..":"..tostring(val)
							end
							local filtername = flt.name
							cache.add_to_cache_group(filtername, def, flt)
							filter_entry:gsub("[^:]+", function(z)
								filtername = filtername..":"..z
								cache.add_to_cache_group(filtername, def, flt)
							end)
						end
					end
				end
			end
		end
	end
	minetest.after(0, cache.fill_recipe_cache) --fill in second step
end

-----------------------------------------------------
-- Fill the recipes cache at init
-----------------------------------------------------
function cache.fill_recipe_cache()
	for itemname, _ in pairs(cache.citems) do
		local recipelist = minetest.get_all_craft_recipes(itemname)
		if recipelist then
			for _, recipe in ipairs(recipelist) do
				local recipe_obj = crecipes.new(recipe)
				if recipe_obj:analyze() then
					table.insert(cache.citems[recipe_obj.out_item.name].in_output_recipe, recipe)
					cache.crecipes[recipe] = recipe_obj
					if recipe_obj.recipe_type ~= "normal" then
						cache.add_to_cache_group("recipetype:"..recipe_obj.recipe_type, recipe_obj.out_item)
					end
					for _, entry in pairs(recipe_obj._items) do
						for itemname, itemdef in pairs(entry.items) do
							if cache.citems[itemname] then -- in case of"not_in_inventory" the item is not in citems
								table.insert(cache.citems[itemname].in_craft_recipe, recipe)
							end
							cache.add_to_cache_group("ingredient:"..itemname, recipe_obj.out_item)
						end
					end
				end
			end
		end
	end
end

-----------------------------------------------------
-- Sort items to groups and decide which groups should be displayed
-----------------------------------------------------
function cache.get_list_grouped(itemtable)
	local grouped = {}
	-- sort the entries to groups
	for _, entry in ipairs(itemtable) do
		if cache.citems[entry.item] then
			for _, group in pairs(cache.citems[entry.item].cgroups) do
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
	local best_group_count = itemcount ^(1/3)
	local best_group_size = (itemcount / best_group_count) * 1.5
	best_group_count = math.floor(best_group_count)
	local sorttab = {}

	for k,v in pairs(grouped) do
		v.group_size = #v.items
		v.unique_count = #v.items
		v.best_group_size = best_group_size
		v.diff = math.abs(v.group_size - v.best_group_size)
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

			local sel = sorttab[1]

			if not sel then
				break
			end
			outtab[sel.name] = {
				name = sel.name,
				group_desc = sel.cgroup.group_desc,
				items = sel.items
			}
			table.remove(sorttab, 1)


			for _, item in ipairs(sel.items) do
				assigned_items[item.item] = true
			-- update the not selected groups
				for _, group in pairs(cache.citems[item.item].cgroups) do
					if group.name ~= sel.name then
						local u = grouped[group.name]
						if u and u.unique_count and u.group_size > 0 then
							u.unique_count = u.unique_count-1
							if (u.group_size < u.best_group_size) or
									(u.group_size - u.best_group_size) < (u.best_group_size - u.unique_count) then
								sel.diff = u.best_group_size - u.unique_count
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
-- Sort items to groups by base material
-----------------------------------------------------
function cache.get_list_grouped_by_base_material(itemtable)
	local grouped = {}
	-- sort the entries to groups
	for _, entry in ipairs(itemtable) do
		local flt = filter.get("shape")
		local groupname = flt:check_item_by_name(entry.item)
		if groupname then
			groupname = "shape"..groupname
			if not grouped[groupname] then
				local group_info = {}
				group_info.name = groupname
				group_info.group_desc = flt:get_group_description(groupname)
				group_info.items = {}
				grouped[groupname] = group_info
			end
			table.insert(grouped[groupname].items, entry)
		end
	end
	return grouped
end

-----------------------------------------------------
-- Get all items available
-----------------------------------------------------
function cache.get_all_items()
	local outtab = {}
	local outtab_material = {}
	for itemname, citem in pairs(cache.citems) do
		local entry = {
			citem = citem,
			-- buttons_grid related
			item = itemname,
			is_button = true
		}
		if cache.citems[itemname].cgroups["shape"] then
			table.insert(outtab_material, entry)
		else
			table.insert(outtab, entry)
		end
	end
	return outtab, outtab_material
end


-----------------------------------------------------
-- Get all revealed items available
-----------------------------------------------------
function cache.get_revealed_items(player)
	local outtab = {}
	for itemname, citem in pairs(cache.citems) do
		if doc_addon.is_revealed_item(itemname, player) then
			local entry = {
				citem = citem,
				itemdef = minetest.registered_items[itemname],
				recipes = cache.citems[itemname].in_output_recipe,
				-- buttons_grid related
				item = itemname,
				is_button = true
			}
			table.insert(outtab, entry)
		end
	end
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
