
local registered_group_items = {
	mesecon_conductor_craftable = "mesecons:wire_00000000_off",
	stone = "default:cobble",
	wood = "default:wood",
	book = "default:book",
	sand = "default:sand",
	leaves = "default:leaves",
	tree = "default:tree",
	vessel = "vessels:glass_bottle",
	wool = "wool:white",
}

local function craft_preview(state)
	for x = 1, 3 do
		for y = 1, 3 do
			state:item_image((x-1)/2,(y-1)/2,0.5,0.5,"craft:"..x..":"..y,nil):setIsHidden(true)
		end
	end
end

local function update_craft_preview(state, craft)
	local prevstate = state:get("craft_preview"):getContainerState()
	for x = 1, 3 do
		for y = 1, 3 do
			local item = nil
			if craft then
				if not craft.width or craft.width == 0 then
					item = craft.items[(y-1)*3+x]
				elseif x <= craft.width then
					item = craft.items[(y-1)*craft.width+x]
				end
			end
			local img = prevstate:get("craft:"..x..":"..y)
			if item then
				if item:sub(1, 6) == "group:" then
					local group_name = item:sub(7)
					item = registered_group_items[item:sub(7)]
					if not item then
						for name, def in pairs(minetest.registered_items) do
							if def.groups[group_name] or 0 ~= 0 then
								registered_group_items[group_name] = name
								item = name
							end
						end
					end
				end
				img:setImage(item)
				img:setIsHidden(false)
			else
				img:setIsHidden(true)
			end
		end
	end
end

local function update_listview(state)
	local listbox = state:get("list")
	local filtermode = state:get("filtermode")

	local inventory = minetest.get_player_by_name(state.location.rootState.location.player):get_inventory()
	local invlist = inventory:get_list("main")
	local selection = listbox:getSelectedItem()
	listbox:clearItems()
	listbox:setSelected(1)
	state.param.list = {}
	for name, def in pairs(minetest.registered_items) do
		if def.description and def.description ~= "" then
			local recipelist = minetest.get_all_craft_recipes(name)
			if recipelist then
				local one_item = false
				local all_items = false
				local selected_info
				for _, info in ipairs(recipelist) do
					all_items = true
					for idx, item in pairs(info.items) do
						local in_inventory = false
						if item:sub(1, 6) == "group:" then
							local group_name = item:sub(7)
							for _, stack in ipairs(invlist) do
								local stackitemname = stack:get_name()
								if minetest.registered_items[stackitemname] and
										(minetest.registered_items[stackitemname].groups[group_name] or 0 ~= 0) then
									in_inventory = true
									info.items[idx] = stackitemname
									registered_group_items[group_name] = stackitemname
								end
							end
						elseif minetest.registered_items[item] and inventory:contains_item("main", item) then
							in_inventory = true
						end
						if in_inventory == true then
							one_item = true
							selected_info = info
						else
							all_items = false
						end
					end
					if all_items == true then
						selected_info = info
						break
					end
				end
				if all_items == true or 
						( one_item == true and filtermode:getText() == "next" ) then
					local text = def.description.." ("..name..")"
					local id = listbox:addItem(text)
					state.param.list[id] = {info = selected_info, name = name, def = def}
					if selection == text then
						listbox:setSelected(id)
					end
				end
			end
		end
	end
end

local function update_icons_list(state)
	local selected_id = state:get("list"):getSelected()
	local liststate = state:get("iconslist"):getContainerState()

	if selected_id and selected_id > 18 then
		selected_id = selected_id - 18
	else
		selected_id = 1
	end
	state.param.icons_list_start = selected_id

	for id = selected_id, selected_id+41 do
		local info = state.param.list[id]
		local button = liststate:get(tostring(id-selected_id+1))
		if info then
			button:setIsHidden(false)
			button:setItem(info.name)
		else
			button:setIsHidden(true)
		end
	end

	if selected_id > 1 then
		local button = liststate:get("1")
		button:setIsHidden(false)
		button:setImage("left_arrow.png")
	end

	if state.param.list[selected_id+41] then
		local button = liststate:get("42")
		button:setIsHidden(false)
		button:setImage("right_arrow.png")
	end
	
end


local function crafting_callback(state)
	--Inventorys / left site
	state:inventory(0, 4, 8, 4,"main")
	state:inventory(0.2, 0.5, 3, 3,"craft")
	state:inventory(3.4, 2.5, 1, 1,"craftpreview")
	state:background(0.1, 0.1, 4.7, 3.8, "img1", "menu_bg.png")

	local listbox = state:listbox(8,0,5.8,6.9,"list")
	listbox:onClick(function(self, state, index, playername)
		local selected = state.param.list[index]
		if selected then
			state:get("info1"):setText(selected.def.description)
			state:get("info2"):setText("("..selected.name..")")
			state:get("info3"):setText("crafting type: "..selected.info.type)
			local res = state:get("craft_result")
			res:setImage(selected.name)
			res:setIsHidden(false)
			state:get("craft_preview"):setIsHidden(false)
			update_craft_preview(state, selected.info)
		else
			state:get("info1"):setText("")
			state:get("info2"):setText("")
			state:get("info3"):setText("")
			state:get("craft_preview"):setIsHidden(true)
			state:get("craft_result"):setIsHidden(true)
			update_craft_preview(state, nil)
		end
	end)
	listbox:setIsHidden(true)
	local iconslist = state:container(8,0.5,"iconslist")
	local liststate = iconslist:getContainerState()
	for x = 1,6 do
		for y=1,7 do
			local button = liststate:item_image_button(x-1,y-1,1,1,tostring(x+(y-1)*6),"","")
			button:setIsHidden(true)
			button:onClick(function(self, state, player)
				local newsel = tonumber(self.name)
				local listbox = state.location.parentState:get("list")
				local selection = listbox:getSelected()
				if newsel == 1 and state.param.icons_list_start > 1 then
					selection = state.param.icons_list_start
					listbox:setSelected(selection)
					update_icons_list(state.location.parentState)
				elseif newsel == 42 and state.param.list[state.param.icons_list_start+41] then
					selection = state.param.icons_list_start + 36
					listbox:setSelected(selection)
					update_icons_list(state.location.parentState)
				else
					selection = state.param.icons_list_start+newsel-1
					listbox:setSelected(selection)
					listbox:_click(listbox.root, selection, player)
				end
			end)
		end
	end

	--buttons above list / or icons view
	state:toggle(8, 7.2, 2, 0.5,"filtermode",{"current", "next"}):onToggle(function(self, state, playername)
		update_listview(state)
		if state:get("viewmode"):getText() == "icons" then
			update_icons_list(state)
		end
	end)
	state:toggle(10,7.2, 2, 0.5,"viewmode",{"icons", "list"}):onToggle(function(self, state, playername)
		local list = state:get("list")
		local iconslist = state:get("iconslist")
		if self:getText() == "icons" then
			list:setIsHidden(true)
			iconslist:setIsHidden(false)
			update_icons_list(state)
		else
			list:setIsHidden(false)
			iconslist:setIsHidden(true)
		end
	end)

	local refresh_button = state:button(12, 7.2, 2, 0.5, "refresh", "Refresh")
	refresh_button:onClick(function(self, state, player)
		update_listview(state)
		if state:get("viewmode"):getText() == "icons" then
			update_icons_list(state)
		end
	end)

	-- preview part
	state:label(5,0,"info1", "")
	state:label(5,0.5,"info2", "")
	state:label(5,1,"info3", "")

	local preview = state:container(5,2,"craft_preview")
	state:background(4.9, 0.1, 3, 3.8, "craft_img1", "minimap_overlay_square.png")
	craft_preview(preview:getContainerState())
	state:item_image(7,2.5,0.8,0.8,"craft_result",nil):setIsHidden(true)
	update_listview(state)
	update_icons_list(state)
end


smart_inventory.register_page("crafting", {
	icon = "inventory_btn.png",
	smartfs_callback = crafting_callback
})
