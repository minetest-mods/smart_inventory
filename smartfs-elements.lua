local smartfs = smart_inventory.smartfs

local elements = {}
-----------------------------------------------------
--- Crafting Preview applet
-----------------------------------------------------
-- enhanced / prepared container
-- Additional method craft_preview:setCraft(craft)
-- if craft=nil, the view will be initialized

local craft_preview = table.copy(smartfs._edef.container)
function craft_preview:onCreate()
	smartfs._edef.container.onCreate(self)
	for x = 1, 3 do
		for y = 1, 3 do
			self._state:item_image(
					(x-1)*self.data.zoom+self.data.pos.x,
					(y-1)*self.data.zoom+self.data.pos.y,
					self.data.zoom, self.data.zoom,
					"craft:"..x..":"..y,nil):setIsHidden(true)
		end
	end
	self._state:item_image(
			self.data.pos.x+(4*self.data.zoom),
			self.data.pos.y+self.data.zoom,
			self.data.zoom, self.data.zoom,
			"craft_result",nil):setIsHidden(true)
	if self.data.recipe then
		self:setCraft(self.data.recipe)
	end
end

-- Update fields
function craft_preview:setCraft(craft)
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
			local img = self._state:get("craft:"..x..":"..y)
			if item then
				if item:sub(1, 6) == "group:" then
					local group_name = item:sub(7)
					item = smart_inventory.group_items[item:sub(7)]
					if not item then
						for name, def in pairs(minetest.registered_items) do
							if def.groups[group_name] or 0 ~= 0 then
								smart_inventory.group_items[group_name] = name
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
	local res = self._state:get("craft_result")
	if craft then 
		res:setImage(craft.output)
		res:setIsHidden(false)
	else
		res:setIsHidden(true)
	end
end

	-- redefinition without container[] to be able move with less steps as 1
function craft_preview:build()
	return self:getBackgroundString()..self:getContainerState():_buildFormspec_(false)
end


smartfs.element("craft_preview", craft_preview)

function elements:craft_preview(x, y, name, zoom, recipe)
	return self:element("craft_preview", { 
		pos  = {x=x, y=y},
		name = name,
		recipe = recipe,
		zoom = zoom or 1
	})
end


-----------------------------------------------------
--- Pagable grid buttons
-----------------------------------------------------
--[[ enhanced / prepared container
  Additional methods
     buttons_grid:setList(craft)
     buttons_grid:onClick(function(state, index, player)...end)
     buttons_grid:setList(iconlist)
     buttons_grid:getFirstVisible()
     buttons_grid:setFirstVisible(index)
]]
local buttons_grid = table.copy(smartfs._edef.container)
function buttons_grid:onCreate()
	assert(self.data.size and self.data.size.w and self.data.size.h, "button needs valid size")
	smartfs._edef.container.onCreate(self)

	self:setSize(self.data.size.w, self.data.size.h) -- view size for background

	self.data.list_start = 1
	self.data.list = {}
	for x = 1, self.data.size.w do
		for y=1, self.data.size.h do
			local button = self._state:item_image_button(x-1,y-1,1,1,tostring((y-1)*self.data.size.w+x),"","")
			button:onClick(function(self, state, player)
				local rel = tonumber(self.name)
				local parent_element = state.location.containerElement
				local idx = rel
				if parent_element.data.list_start > 1  then
					idx = parent_element.data.list_start + rel - 2
				end
				if rel == 1 and parent_element.data.list_start > 1 then
					-- page back
					local full_pagesize = parent_element.data.size.w * parent_element.data.size.h
					if parent_element.data.list_start <= full_pagesize then
						parent_element.data.list_start = 1
					else
						--prev page use allways 2x navigation buttons at list_start > 1 and the next page (we navigate from) exists
						parent_element.data.list_start = parent_element.data.list_start - (full_pagesize-2)
					end
					parent_element:update()
				elseif rel == (parent_element.data.size.w * parent_element.data.size.h) and 
						parent_element.data.list[parent_element.data.list_start+parent_element.data.pagesize] then
					-- page forward
					parent_element.data.list_start = parent_element.data.list_start+parent_element.data.pagesize
					parent_element:update()
				else
					-- pass call to the button function
					if parent_element._click then
						parent_element:_click(parent_element.root, idx, player)
					end
				end
			end)
			button:setIsHidden(true)
		end
	end
end
function buttons_grid:onClick(func)
	self._click = func
end
function buttons_grid:getFirstVisible()
	return self.data.list_start
end
function buttons_grid:setFirstVisible(idx)
	self.data.list_start = idx
end
function buttons_grid:setList(iconlist)
	self.data.list = iconlist or {}
	self:update()
end

function buttons_grid:update()
	--init pagesize
	self.data.pagesize = self.data.size.w * self.data.size.h
	--adjust start position
	if self.data.list_start > #self.data.list then
		self.data.list_start = #self.data.list - self.data.pagesize
	end
	if self.data.list_start < 1 then
		self.data.list_start = 1
	end

	local itemindex = self.data.list_start
	for btnid = 1, self.data.size.w * self.data.size.h do
		local button = self._state:get(tostring(btnid))
		if btnid == 1 and self.data.list_start > 1 then
			-- setup back button
			button:setIsHidden(false)
			button:setImage("left_arrow.png")
			button:setText(tostring(self.data.list_start-1))
			self.data.pagesize = self.data.pagesize - 1
		elseif btnid == self.data.size.w * self.data.size.h and self.data.list[itemindex+1] then
			-- setup next button
			button:setIsHidden(false)
			button:setImage("right_arrow.png")
			self.data.pagesize = self.data.pagesize - 1
			button:setText(tostring(#self.data.list-self.data.list_start-self.data.pagesize+1))
		else
			-- functional button
			local entry = self.data.list[itemindex]
			-- TODO: support for list[]
			if entry then
				if entry.item and entry.is_button == true then
					button:setIsHidden(false)
					button:setItem(entry.item)
					button:setText("")
				else
				-- TODO 1: entry.image to display *.png 
				-- TODO 2: entry.text to display label on button
				-- TODO 3,4,5: is_button == false to get just pic or label without button
				end
			else
				button:setIsHidden(true)
			end
			itemindex = itemindex + 1
		end
	end
end


smartfs.element("buttons_grid", buttons_grid)

function elements:buttons_grid(x, y, w, h, name)
	return self:element("buttons_grid", { 
		pos  = {x=x, y=y},
		size = {w=w, h=h},
		name = name
	})
end


-------------------------
return elements
