local txt = smart_inventory.txt
local txt_usage = minetest.setting_get("smart_inventory_friendly_group_names") or false

local filter = {}
filter.registered_filter = {}

function filter.get(name)
	return filter.registered_filter[name]
end

function filter.register_filter(def)
	assert(def.name, "filter needs a name")
	assert(def.filter_func, "filter function required")
	assert(not filter.registered_filter[def.name], "filter already exists")

	local self = def

	function self:check_item_by_name(itemname)
		if minetest.registered_items[itemname] then
			return self.filteget_group_descriptionr_func(minetest.registered_items[itemname])
		end
	end
	function self:check_item_by_def(def)
		return self.filter_func(def)
	end
	function self:get_description(group)
		local ret_desc
		if self.shortdesc_func then
			ret_desc = self:shortdesc_func(group)
		elseif txt[group.name] then
			ret_desc = txt[group.name].label
		elseif group.parent and group.parent.childs[group.name] and txt[group.parent.name] then
			ret_desc = txt[group.parent.name].label.." "..group.parent.childs[group.name]
		else
			ret_desc = group.name
		end
		if not txt_usage or ret_desc == false then
			return ret_desc
		else
			return group.name
		end
	end

	filter.registered_filter[self.name] = self
end

filter.register_filter({
		name = "group",
		filter_func = function(def)
			local ret = {}
			for k, v in pairs(def.groups) do
				local mk, mv
				-- dimension groups. replace _ by :
				if k:sub(1,5) == "armor" or
						k:sub(1, 7) == "physics" or
						k:sub(1, 9) == "basecolor" or
						k:sub(1, 7) == "excolor" or
						k:sub(1, 5) == "color" or
						k:sub(1, 8) == "unicolor" or
						k:sub(1, 4) == "food" then
					mk = string.gsub(k, "_", ":")
				else
					mk = k
				end
				-- stack wear related value
				if k == "armor_use" then
					mv = tostring(math.floor(v / 65535 * 10000 + 0.5)/100).." %"
				-- value-expandable groups
				elseif v ~= 1 or k == "oddly_breakable_by_hand" then
					mv = v
				else
					mv = true
				end

				if v ~= 0 then
					ret[mk] = mv
				end
			end
			return ret
		end,
	})

filter.register_filter({
		name = "type",
		filter_func = function(def)
			return def.type
		end,
	})

filter.register_filter({
		name = "mod",
		filter_func = function(def)
			return def.mod_origin
		end,
	})

filter.register_filter({
		name = "transluc",
		filter_func = function(def)
			return def.sunlight_propagates
		end
	})

filter.register_filter({
		name = "light",
		filter_func = function(def)
			if def.light_source and def.light_source ~= 0 then
				return def.light_source
			end
		end
	})

filter.register_filter({
		name = "vessel",
		filter_func = function(def)
			if def.allow_metadata_inventory_move or
					def.allow_metadata_inventory_take or
					def.on_metadata_inventory_put then
				return true
			end
		end
	})

--[[ does it sense to filter them? I cannot define the human readable groups for them
filter.register_filter({
		name = "drawtype",
		filter_func = function(def)
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
		filter_func = function(def)
			for k, v in pairs(def.groups) do
				if shaped_groups[k] then
					return true
				end
			end
		end
	})

filter.register_filter({
		name = "eatable",
		filter_func = function(def)
			if def.on_use then
				local name,change=debug.getupvalue(def.on_use, 1)
				if name~=nil and name=="hp_change" and change > 0 then
					return tostring(change)
				end
			end
		end
	})

filter.register_filter({
		name = "toxic",
		filter_func = function(def)
			if def.on_use then
				local name,change=debug.getupvalue(def.on_use, 1)
				if name~=nil and name=="hp_change" and change < 0 then
					return tostring(change)
				end
			end
		end
	})

filter.register_filter({
		name = "tool",
		filter_func = function(def)
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
		shortdesc_func = function(self, group)
			if group.name == "max_drop_level" or group.name == "full_punch_interval" or group.name == "damage" then
				return false
			elseif txt[group.name] then
				return txt[group.name].label
			elseif group.parent and group.parent.childs[group.name] and txt[group.parent.name] then
				return txt[group.parent.name].label.." "..group.parent.childs[group.name]
			else
				return group.name
			end
		end
	})

filter.register_filter({
		name = "armor",
		filter_func = function(def)
			return def.armor_groups
		end
	})

-- Group assignment done in cache framework internally
filter.register_filter({
		name = "recipetype",
		filter_func = function(def) end,
})

-- Group assignment done in cache framework internally
filter.register_filter({
		name = "ingredient",
		filter_func = function(def) end,
		shortdesc_func = function(self, group)
			local itemname = group.name:sub(12)
			if txt["ingredient"] and txt["ingredient"].label and
					minetest.registered_items[itemname] and minetest.registered_items[itemname].description then
				return txt["ingredient"].label .." "..minetest.registered_items[itemname].description
			else
				return group.name
			end
		end
})

----------------
return filter

