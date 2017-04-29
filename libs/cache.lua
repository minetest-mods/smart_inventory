local filter = smart_inventory.filter
local doc_addon = smart_inventory.doc_addon
local txt = smart_inventory.txt

local cache = {}
cache.cgroups = {}
cache.citems = {}


-- cached recipes object
local crecipe_class = {}
crecipe_class.__index = crecipe_class

-----------------------------------------------------
-- crecipes: analyze all data. Return false if invalid recipe. true on success
-----------------------------------------------------
function crecipe_class:analyze()
	-- check recipe output
	if self._recipe.output ~= "" then
		local out_itemname = self._recipe.output:gsub('"','')
		self.out_item = minetest.registered_items[out_itemname]
		if not self.out_item then
			out_itemname:gsub("[^%s]+", function(z)
				if minetest.registered_items[z] then
					self.out_item = minetest.registered_items[z]
				end
			end)
		end
	end
	if not self.out_item or not self.out_item.name then
		minetest.log("[smartfs_inventory] unknown recipe result "..self._recipe.output)
		return false
	end

	-- probably hidden therefore not indexed previous. But Items with recipe should be allways visible
	cache.add_item(minetest.registered_items[self.out_item.name])

	-- check recipe items/groups
	for _, recipe_item in pairs(self._recipe.items) do
		if recipe_item ~= "" then
			if self._items[recipe_item] then
				self._items[recipe_item].count = self._items[recipe_item].count + 1
			else
				self._items[recipe_item]  = {count = 1}
			end
		end
		for recipe_item, iteminfo in pairs(self._items) do
			if recipe_item:sub(1, 6) ~= "group:" then
				if minetest.registered_items[recipe_item] then
					iteminfo.items = {[recipe_item] = minetest.registered_items[recipe_item]}
				else
					minetest.log("[smartfs_inventory] unknown item in recipe: "..recipe_item.." for result "..self.out_item.name)
					return false
				end
			else
				if cache.cgroups[recipe_item] then
					iteminfo.items = cache.cgroups[recipe_item].items
				else
					local retitems
					for groupname in string.gmatch(recipe_item:sub(7), '([^,]+)') do
						if not retitems then --first entry
							if cache.cgroups[groupname] then
								retitems = table.copy(cache.cgroups[groupname].items)
							else
								groupname = groupname:gsub("_", ":")
								if cache.cgroups[groupname] then
									retitems = table.copy(cache.cgroups[groupname].items)
								else
									minetest.log("[smartfs_inventory] unknown group description in recipe: "..recipe_item.." / "..groupname.." for result "..self.out_item.name)
								end
							end
						else
							for itemname, itemdef in pairs(retitems) do
								local item_in_group = false
								for _, item_group in pairs(cache.citems[itemname].cgroups) do
									if item_group.name == groupname or
											item_group.name == groupname:gsub("_", ":")
									then
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
						minetest.log("[smartfs_inventory] no items matches group: "..recipe_item.." for result "..self.out_item.name)
						return false
					else
						iteminfo.items = retitems
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
-- crecipes: Check if the recipe is revealed to the player
-----------------------------------------------------
function crecipe_class:is_revealed(playername)
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
-- crecipes: Returns recipe without groups, with replacements
-----------------------------------------------------
function crecipe_class:get_with_placeholder(player, inventory_tab)
	local recipe = table.copy(self._recipe)
	recipe.items = table.copy(recipe.items)
	for key, recipe_item in pairs(recipe.items) do
		local item

		-- Check for matching item in inventory
		if inventory_tab then
			local itemcount = 0
			for _, item_in_list in pairs(self._items[recipe_item].items) do
				local in_inventory = inventory_tab[item_in_list.name]
				if in_inventory == true then
					item = item_in_list.name
					break
				elseif in_inventory and in_inventory > itemcount then
					item = item_in_list.name
					itemcount = in_inventory
				end
			end
		end

		-- second try, get any revealed item
		if not item then
			for _, item_in_list in pairs(self._items[recipe_item].items) do
				if doc_addon.is_revealed_item(item_in_list.name, player) then
					item = item_in_list.name
					break
				end
			end
		end

		-- third try, just get one item
		if not item and self._items[recipe_item].items[1] then
			item = self._items[recipe_item].items[1].name
		end

		-- set recipe item
		if item then
			recipe.items[key] = item
		end
	end
	return recipe
end

-----------------------------------------------------
-- Recipe class functions
-----------------------------------------------------
local crecipes = {}
cache.crecipes = crecipes
crecipes._proto = crecipe_class

-----------------------------------------------------
-- Recipe object Constructor
-----------------------------------------------------
function crecipes.new(recipe)
	local def = {}
	def.out_item = nil
	def._recipe = recipe
	def.recipe_type = recipe.type
	def._items = {}
	setmetatable(def, crecipe_class)
	def.__index = crecipe_class
	print(dump(def))
	return def
end

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
-- Add an Item to the cache
-----------------------------------------------------
function cache.add_item(def)

	-- special handling for doors. In inventory the item should be displayed instead of the node_a/node_b
	local item_def
	if def.groups.door then
		if def.door then
			item_def = minetest.registered_items[def.door.name]
		elseif def.drop and type(def.drop) == "string" then
			item_def = minetest.registered_items[def.drop]
		else
			item_def = def
		end
		if not item_def then
			minetest.log("[smart_inventory] Buggy door found: "..def.name)
			item_def = def
		end
	else
		item_def = def
	end

	-- already in cache. Skip duplicate processing
	if cache.citems[item_def.name] then
		return
	end

	local entry = {
		name = item_def.name,
		in_output_recipe = {},
		in_craft_recipe = {},
		cgroups = {}
	}
	cache.citems[item_def.name] = entry
	-- classify the item
	for _, flt in pairs(filter.registered_filter) do
		local filter_result = flt:check_item_by_def(def)
		if filter_result then
			if filter_result == true then
				cache.assign_to_group(flt.name, item_def, flt)
			else
				if type(filter_result) ~= "table" then
					if tonumber(filter_result) ~= nil then
						filter_result = {[flt.name..":"..filter_result] = true}
					else
						filter_result = {[filter_result] = true}
					end
				end
				for key, val in pairs(filter_result) do
					local filter_entry = tostring(key)
					if val ~= true then
						filter_entry = filter_entry..":"..tostring(val)
					end
					cache.assign_to_group(filter_entry, item_def, flt)
				end
			end
		end
	end
end


-----------------------------------------------------
-- Add a item to cache group
-----------------------------------------------------
function cache.assign_to_group(group_name, itemdef, flt)

-- check and build filter chain
	local abs_group
	local parent_ref
	local parent_stringpos

	for rel_group in group_name:gmatch("[^:]+") do
		-- get parent relation and absolute path
		if abs_group then
			parent_ref = cache.cgroups[abs_group]
			parent_stringpos = string.len(abs_group)+2
			abs_group = abs_group..":"..rel_group
		else
			abs_group = rel_group
		end

		-- check if group is new, create it
		if not cache.cgroups[abs_group] then
			if parent_ref then
				parent_ref.childs[abs_group] = string.sub(group_name, parent_stringpos)
			end
			local group = {
					name = abs_group,
					items = {},
					parent = parent_ref,
					childs = {},
				}
			group.group_desc = flt:get_description(group)
			group.keyword = flt:get_keyword(group)
			cache.cgroups[abs_group] = group
		end

		-- set relation
		cache.cgroups[abs_group].items[itemdef.name] = itemdef
		cache.citems[itemdef.name].cgroups[abs_group] = cache.cgroups[abs_group]
	end
end

-----------------------------------------------------
-- Hook / Event for further initializations of the cache is filled
-----------------------------------------------------
cache.registered_on_cache_filled = {}
function cache.register_on_cache_filled(func, ...)
	assert(type(func) == "function", "register_on_cache_filled needs a function")
	table.insert(cache.registered_on_cache_filled, { func = func, opt = {...}})
end

local function process_on_cache_filled()
	for _, hook in ipairs(cache.registered_on_cache_filled) do
		hook.func(unpack(hook.opt))
	end
end


-----------------------------------------------------
-- Fill the cache at init
-----------------------------------------------------
local function fill_cache()
	local shape_filter = filter.get("shape")
	for _, def in pairs(minetest.registered_items) do

		-- build groups and items cache
		if def.description and def.description ~= "" and
				(not def.groups.not_in_creative_inventory or shape_filter:check_item_by_def(def)) then
			cache.add_item(def)
		end
	end

	-- call hooks
	minetest.after(0, process_on_cache_filled)
end
minetest.after(0, fill_cache)


-----------------------------------------------------
-- Fill the recipes cache at init
-----------------------------------------------------
local function fill_recipe_cache()
	for itemname, _ in pairs(minetest.registered_items) do
		local recipelist = minetest.get_all_craft_recipes(itemname)
		if recipelist then
			for _, recipe in ipairs(recipelist) do
				local recipe_obj = crecipes.new(recipe)
				if recipe_obj:analyze() then
					table.insert(cache.citems[recipe_obj.out_item.name].in_output_recipe, recipe)
					cache.crecipes[recipe] = recipe_obj
					if recipe_obj.recipe_type ~= "normal" then
						cache.assign_to_group("recipetype:"..recipe_obj.recipe_type, recipe_obj.out_item, filter.get("recipetype"))
					end
					for _, entry in pairs(recipe_obj._items) do
						for itemname, itemdef in pairs(entry.items) do
							if cache.citems[itemname] then -- in case of"not_in_inventory" the item is not in citems
								table.insert(cache.citems[itemname].in_craft_recipe, recipe)
							end
							cache.assign_to_group("ingredient:"..itemname, recipe_obj.out_item, filter.get("ingredient"))
						end
					end
				end
			end
		end
	end
end
-- register to process after cache is filled
cache.register_on_cache_filled(fill_recipe_cache)


-----------------------------------------------------
-- return the reference to the mod
-----------------------------------------------------
return cache
