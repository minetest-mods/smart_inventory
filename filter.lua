local txt = smart_inventory.txt

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
		if self.shortdesc_func then
			return self:shortdesc_func(group)
		elseif txt[group.name] then
			return txt[group.name].label
		elseif group.parent and group.parent.childs[group.name] and txt[group.parent.name] then
			return txt[group.parent.name].label.." "..group.parent.childs[group.name]
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

				-- value-expandable groups
				if v ~= 1 or k == "oddly_breakable_by_hand" then
					mv = v
				else
					mv = true
				end
				ret[mk] = mv
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

filter.register_filter({
		name = "material",
		filter_func = function(def)
			return def.base_material
		end
	})

filter.register_filter({
		name = "shape",
		filter_func = function(def)
			return def.shape_type
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
			if group == "max_drop_level" or group == "full_punch_interval" or group == "damage" then
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

-- dummy, used internal
filter.register_filter({
		name = "recipetype",
		filter_func = function(def) end,
})

----------------
return filter

