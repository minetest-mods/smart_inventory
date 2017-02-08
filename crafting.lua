local cache = smart_inventory.cache


local function on_item_select(state, itemdef, recipe)
	if itemdef then
		state:get("info1"):setText(itemdef.description)
		state:get("info2"):setText("("..itemdef.name..")")
		state:get("info3"):setText("crafting type: "..recipe.type)
		state:get("craft_preview"):setCraft(recipe)
	else
		state:get("info1"):setText("")
		state:get("info2"):setText("")
		state:get("info3"):setText("")
		state:get("craft_preview"):setCraft(nil)
	end
end

local function update_craftable_list(state)
	local player = state.location.rootState.location.player
	local craftable = cache:get_recipes_craftable(player)
	local duplicate_index_tmp = {}
	state.param.craftable_list = {}
	for recipe, _ in pairs(craftable) do
		local def = minetest.registered_items[recipe.output]
		if not def then
			recipe.output:gsub("[^%s]+", function(z)
				if minetest.registered_items[z] then
					def = minetest.registered_items[z]
				end
			end)
		end
		if def then
			if duplicate_index_tmp[def] then
				table.insert(duplicate_index_tmp[def].recipes, recipe)
			else
				local entry = {
					itemdef=def,
					recipes = {},
					-- buttons_grid related
					item = def.name,
					is_button = true
				}
				table.insert(entry.recipes, recipe)
				table.insert(state.param.craftable_list, entry)
				duplicate_index_tmp[def] = entry
			end
		end
	end
	table.sort(state.param.craftable_list, function(a,b)
		return a.item > b.item
	end)
end


local function crafting_callback(state)
	local player = state.location.rootState.location.player
	--Inventorys / left site
	state:inventory(0, 4, 8, 4,"main")
	state:inventory(0.2, 0.5, 3, 3,"craft")
	state:inventory(3.4, 2.5, 1, 1,"craftpreview")
	state:background(0.1, 0.1, 4.7, 3.8, "img1", "menu_bg.png")
	local grid = smart_inventory.smartfs_elements.buttons_grid(state, 8, 0.5, 6 , 7, "buttons_grid")
	grid:onClick(function(self, state, index, player)
		local listentry = state.param.craftable_list[index]
		on_item_select(state, listentry.itemdef, listentry.recipes[1]) --TODO: recipes paging
	end)
	local refresh_button = state:button(12, 7.2, 2, 0.5, "refresh", "Refresh")
	refresh_button:onClick(function(self, state, player)
		update_craftable_list(state)
		grid = state:get("buttons_grid")
		grid:setList(state.param.craftable_list)
	end)

	-- preview part
	state:background(4.9, 0.1, 3, 3.8, "craft_img1", "minimap_overlay_square.png")
	state:label(5,0,"info1", "")
	state:label(5,0.5,"info2", "")
	state:label(5,1,"info3", "")
	smart_inventory.smartfs_elements.craft_preview(state, 5, 2, "craft_preview")

	-- initial values
	update_craftable_list(state)
	grid:setList(state.param.craftable_list)
end

smart_inventory.register_page("crafting", {
	icon = "inventory_btn.png",
	smartfs_callback = crafting_callback
})
