local txt = smart_inventory.txt
local txt_usage = minetest.setting_get("smart_inventory_friendly_group_names") or true

--------------------------------------------------------------
-- Filter class
--------------------------------------------------------------
local filter_class = {}
filter_class.__index = filter_class

function filter_class:check_item_by_name(itemname)
	if minetest.registered_items[itemname] then
		return self:check_item_by_def(minetest.registered_items[itemname])
	end
end

function filter_class:check_item_by_def(def)
	error("check_item_by_def needs redefinition:"..debug.traceback())
end

function filter_class:_get_description(group)
	local ret_desc
	if txt[group.name] then
		ret_desc = txt[group.name].label
	elseif group.parent and group.parent.childs[group.name] and txt[group.parent.name] then
		ret_desc = txt[group.parent.name].label.." "..group.parent.childs[group.name]
	else
		ret_desc = group.name
	end
	if txt_usage then
		return ret_desc
	else
		return group.name
	end
end
filter_class.get_description = filter_class._get_description


function filter_class:_get_keyword(group)
	-- parent exists - return the top-level information only
	if group.parent and group.parent.childs[group.name] and tonumber(group.parent.childs[group.name]) == nil then
		return group.parent.childs[group.name]
	end
end

function filter_class:_get_keyword_groupname(group) -- a variant for get_keyword, can be assigned in filter definition
	if txt_usage then
		return group.name.." "..group.group_desc
	else
		return group.name
	end
end

filter_class.get_keyword = filter_class._get_keyword


local filter = {}
filter.registered_filter = {}

function filter.get(name)
	return filter.registered_filter[name]
end

function filter.register_filter(def)
	assert(def.name, "filter needs a name")
	assert(def.check_item_by_def, "filter function check_item_by_def required")
	assert(not filter.registered_filter[def.name], "filter already exists")
	setmetatable(def, filter_class)
	def.__index = filter_class
	filter.registered_filter[def.name] = def
end


-- rename groups for beter consistency
filter.group_rename = {
	customnode_default = "customnode",
}

-- group configurations per basename
--   true means is dimension
--   false means hide all groups with this base
filter.base_group_config = {
	armor = true,
	physics = true,
	basecolor = true,
	excolor = true,
	color = true,
	unicolor = true,
	food = true,
	customnode = true,
	leafdecay = false,
}

-- hide this groups
filter.group_hide_config = {
	armor_count = true,
	not_in_creative_inventory = false,
}

-- value of this group will be recalculated to %
filter.group_wear_config = {
	armor_use = true,
}

-- Ususally 1 means true for group values. This is an exceptions table for this rule
filter.group_with_value_1_config = {
	oddly_breakable_by_hand = true,
}

--------------------------------------------------------------
-- Filter group
--------------------------------------------------------------
filter.register_filter({
		name = "group",
		check_item_by_def = function(self, def)
			local ret = {}
			for k_orig, v in pairs(def.groups) do
				local k = filter.group_rename[k_orig] or k_orig
				local mk, mv

				-- Check group base
				local basename
				for z in k:gmatch("[^_]+") do
					basename = z
					break
				end
				local basegroup_config = filter.base_group_config[basename]
				if basegroup_config == true then
					mk = string.gsub(k, "_", ":")
				elseif basegroup_config == false then
					mk = nil
				else
					mk = k
				end

				-- stack wear related value
				if filter.group_wear_config[k] then
					mv = tostring(math.floor(v / 65535 * 10000 + 0.5)/100).." %"
				-- value-expandable groups
				elseif v ~= 1 or k == filter.group_with_value_1_config[k] then
					mv = v
				else
					mv = true
				end

				if v ~= 0 and mk and not filter.group_hide_config[k] then
					ret[mk] = mv
				end
			end
			return ret
		end,
		get_keyword = function(self, group)
			local keyword = self:_get_keyword(group)
			if txt_usage and keyword and txt[group.name] then
				return keyword.." "..group.group_desc
			else
				return keyword
			end
		end
	})

filter.register_filter({
		name = "type",
		check_item_by_def = function(self, def)
			return def.type
		end,
	})

filter.register_filter({
		name = "mod",
		check_item_by_def = function(self, def)
			return def.mod_origin
		end,
	})

filter.register_filter({
		name = "transluc",
		check_item_by_def = function(self, def)
			return def.sunlight_propagates
		end,
		get_keyword = filter_class._get_keyword_groupname
	})

filter.register_filter({
		name = "light",
		check_item_by_def = function(self, def)
			if def.light_source and def.light_source ~= 0 then
				return def.light_source
			end
		end,
		get_keyword = filter_class._get_keyword_groupname
	})

filter.register_filter({
		name = "vessel",
		check_item_by_def = function(self, def)
			if def.allow_metadata_inventory_move or
					def.allow_metadata_inventory_take or
					def.on_metadata_inventory_put then
				return true
			end
		end,
		get_keyword = filter_class._get_keyword_groupname
	})

--[[ does it sense to filter them? I cannot define the human readable groups for them
filter.register_filter({
		name = "drawtype",
		check_item_by_def = function(self, def)
			if def.drawtype ~= "normal" then
				return def.drawtype
			end
		end,
	})
]]

local shaped_groups = {}
local shaped_list = minetest.setting_get("smart_inventory_shaped_groups") or "carpet,door,fence,stair,slab,wall,micro,panel,slope"
if shaped_list then
	shaped_list:gsub("[^,]+", function(z)
		shaped_groups[z] = true
	end)
end

filter.register_filter({
		name = "shape",
		check_item_by_def = function(self, def)
			for k, v in pairs(def.groups) do
				if shaped_groups[k] then
					return true
				end
			end
		end,
		get_keyword = filter_class._get_keyword_groupname
	})

filter.register_filter({
		name = "food",
		check_item_by_def = function(self, def)
			if def.on_use then
				local name,change=debug.getupvalue(def.on_use, 1)
				if name~=nil and name=="hp_change" and change > 0 then
					return tostring(change)
				end
			end
		end,
		get_keyword = filter_class._get_keyword_groupname
	})

filter.register_filter({
		name = "toxic",
		check_item_by_def = function(self, def)
			if def.on_use then
				local name,change=debug.getupvalue(def.on_use, 1)
				if name~=nil and name=="hp_change" and change < 0 then
					return tostring(change)
				end
			end
		end,
		get_keyword = filter_class._get_keyword_groupname
	})

filter.register_filter({
		name = "tool",
		check_item_by_def = function(self, def)
			if not def.tool_capabilities then
				return
			end
			local rettab = {}
			for k, v in pairs(def.tool_capabilities) do
				if type(v) ~= "table" then
					rettab[k] = v
				end
			end
			if def.tool_capabilities.damage_groups then
				for k, v in pairs(def.tool_capabilities.damage_groups) do
					rettab["damage:"..k] = v
				end
			end
--[[ disabled, I cannot find right human readable interpretation for this
			if def.tool_capabilities.groupcaps then
				for groupcap, gdef in pairs(def.tool_capabilities.groupcaps) do
					for k, v in pairs(gdef) do
						if type(v) ~= "table" then
							rettab["groupcaps:"..groupcap..":"..k] = v
						end
					end
				end
			end
]]
			return rettab
		end,
		get_keyword = function(self, group)
			if group.name == "max_drop_level" or group.name == "full_punch_interval" or group.name == "damage" then
				return nil
			else
				return self:_get_keyword(group)
			end
		end
	})

filter.register_filter({
		name = "armor",
		check_item_by_def = function(self, def)
			return def.armor_groups
		end,
		get_keyword = filter_class._get_keyword_groupname
	})

-- Group assignment done in cache framework internally
filter.register_filter({
		name = "recipetype",
		check_item_by_def = function(self, def) end,
})

-- Group assignment done in cache framework internally
filter.register_filter({
		name = "ingredient",
		check_item_by_def = function(self, def) end,
		get_description = function(self, group)
			local itemname = group.name:sub(12)
			if txt["ingredient"] and txt["ingredient"].label and
					minetest.registered_items[itemname] and minetest.registered_items[itemname].description then
				return txt["ingredient"].label .." "..minetest.registered_items[itemname].description
			else
				return group.name
			end
		end,
		get_keyword = function(self, group)
			local itemname = group.name:sub(12)
			if minetest.registered_items[itemname] then
				return minetest.registered_items[itemname].description
			end
		end

})

----------------
return filter

