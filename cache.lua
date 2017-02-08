local cache = {}
cache.groups = {}    --cache.groups[group][itemname] = itemdef
cache.in_recipe = {} --table.insert(cache.in_recipe[recipe_item][itemname], info)

-- build cache at start
function cache:fill_cache()
	for name, def in pairs(minetest.registered_items) do
		-- cache groups
		if def.description and def.description ~= "" and not def.groups.not_in_creative_inventory then
			for group, grval in pairs(def.groups) do
				if not self.groups[group] then
					self.groups[group] = {}
				end
				self.groups[group][name] = def
			end
		end

		local recipelist = minetest.get_all_craft_recipes(name)
		if recipelist then
			for _, recipe in ipairs(recipelist) do
				if recipe.output ~= "" then
					for idx, recipe_item in pairs(recipe.items) do
						if not self.in_recipe[recipe_item] then
							self.in_recipe[recipe_item] = {}
						end
						if not self.in_recipe[recipe_item][name] then
							self.in_recipe[recipe_item][name] = {}
						end
						 -- "recipe_item" is in recipe of item "name". Multiple recipes possible
						table.insert(self.in_recipe[recipe_item][name], recipe)
					end
				end
			end
		end
	end
end

-- Get all recipes with at least one item existing in players inventory
function cache:get_recipes_craftable_atnext(player)
	local inventory = minetest.get_player_by_name(player):get_inventory()
	local invlist = inventory:get_list("main")
	local items_in_inventory = {}
	local recipe_with_one_item_in_inventory = {}
	local outtab = {}
	for _, stack in ipairs(invlist) do
		local itemname = stack:get_name()
		items_in_inventory[itemname] = true 
	end

	for recipe_item, recipe_item_data in pairs(self.in_recipe) do
		-- prepare current stack for crafting simulation
		local item_ok = false
		if items_in_inventory[recipe_item] then
			item_ok = true
		elseif recipe_item:sub(1, 6) == "group:" then
			local group_name = recipe_item:sub(7)
			if self.groups[group_name] then
				for group_item, def in pairs(self.groups[group_name]) do
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
function cache:get_recipes_craftable(player)
	local all, items_in_inventory = self:get_recipes_craftable_atnext(player)
	local craftable = {}
	for recipe, _ in pairs(all) do
		local out_recipe = table.copy(recipe)
		out_recipe.items = table.copy(recipe.items) --deep copy
		local item_ok = true
		for idx, item in pairs(out_recipe.items) do
			local in_inventory = false
			if item:sub(1, 6) == "group:" then
				local group_name = item:sub(7)
				if self.groups[group_name] then
					for group_item, def in pairs(self.groups[group_name]) do
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

-- fill the cache after all mods loaded
minetest.after(0, cache.fill_cache, cache)

-- return the reference to the mod
return cache
