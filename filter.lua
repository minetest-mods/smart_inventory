local filter = {}
filter.registered_filter = {}

--[[- API

* Filter definition

filter.register_filter(filterdef) -- register a new filter

filterdef.name - unique filter name
filterdef.filter_func(itemdef) - function to check the item classify by item definition
	returns values:
		true            -> 1 group
		string          -> dimension, steps splitted by ":" (a:b:c:d results in a, a:b, a:b:c, a:b:c:d)
		key/value table -> multiple groups assignment. Values could be dimensions

* Filter useage

filter.get(name)                      get filter object by name
filter:check_item_by_name(itemname)   classify by itemname
filter:check_item_by_def(def)         classify by item definition
filter:get_group_description(group)   get group description. Empty ("") or "nogroup" means the group should be ignored. Usefull so skip some dimension characteristics
]]


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
			return self.filter_func(minetest.registered_items[itemname])
		end
	end
	function self:check_item_by_def(def)
		return self.filter_func(def)
	end
	function self:get_group_description(group)
		local rela_group = group:sub(string.len(self.name)+2)
		local descr
		if self.shortdesc_func then
			descr = self.shortdesc_func(rela_group)
		end
		if not descr and self.shortdesc then
			return self.shortdesc
		else
			return group
		end
	end

	filter.registered_filter[self.name] = self
end

--[[	level = { shortdesc = "Uses level information" },
	dig_immediate = { shortdesc = "Fast removable" },
	disable_jump = { shortdesc = "Not jumpable" },
	less_damage  = { shortdesc = "Less damage" },
	more_damage  = { shortdesc = "More damage" },
	bouncy = { shortdesc = "Bouncy" },
	falling_node = { shortdesc = "Falling" },
	attached_node = { shortdesc = "Attachable" },
	connect_to_raillike = { shortdesc = "Rail-like" },
	-- TODO: http://dev.minetest.net/Groups/Custom_groups

	armor_use = { shortdesc = "Armor" },
	armor_heal = { shortdesc = "Armor" },
	cracky = { shortdesc = "Cracky" },
	flammable = { shortdesc = "Flammable" },
	snappy = { shortdesc = "Snappy" },
	choppy = { shortdesc = "Choppy" },
	oddly_breakable_by_hand = { shortdesc = "Oddly breakable" },

	tool = { shortdesc = "Tools" },
	type_node = { shortdesc = "Nodes" },
	type_craft = { shortdesc = "Craft Items" },
]]

filter.register_filter({
		name = "group",
		filter_func = function(def)
			return def.groups
		end
	})

filter.register_filter({
		name = "type",
		filter_func = function(def)
			return def.type
		end
	})

filter.register_filter({
		name = "mod",
		filter_func = function(def)
			return def.mod_origin
		end
	})

filter.register_filter({
		name = "transluc",
		shortdesc = "Translucent blocks",
		filter_func = function(def)
			return def.sunlight_propagates
		end
	})

filter.register_filter({
		name = "vessel",
		shortdesc = "Vessel",
		filter_func = function(def)
			if def.allow_metadata_inventory_move or
					def.allow_metadata_inventory_take or
					def.on_metadata_inventory_put then
				return true
			end
		end
	})

filter.register_filter({
		name = "drawtype",
		filter_func = function(def)
			return def.drawtype
		end
	})

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

----------------
return filter

