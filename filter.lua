local filter = {}
filter.registered_filter = {}

--- API
function filter.get(name)
	return filter.registered_filter[name]
end

function filter.register_filter(def)
	assert(def.name, "filter needs a name")
	assert(def.filter_func, "filter function required")
	assert(not filter.registered_filter[def.name], "filter already exists")

	local self = def
	function self:check_item_by_name(itemname)
		return self.filter_func(minetest.registered_items[itemname], itemname)
	end
	function self:check_item_by_def(def)
		if def then
			return self.filter_func(def, def.name)
		end
	end
	filter.registered_filter[self.name] = self
end

filter.register_filter({
		name = "transluc",
		shortdesc = "Translucent blocks",
		filter_func = function(def, name)
			return def.sunlight_propagates
		end
	})

filter.register_filter({
		name = "vessel",
		shortdesc = "Vessel",
		filter_func = function(def, name)
			if def.allow_metadata_inventory_move or
					def.allow_metadata_inventory_take or
					def.on_metadata_inventory_put then
				return true
			end
		end
	})

filter.register_filter({
		name = "drawtype",
		filter_func = function(def, name)
			return def.drawtype
		end
	})


filter.register_filter({
		name = "material",
		filter_func = function(def, name)
			return def.base_material
		end
	})

filter.register_filter({
		name = "shape",
		filter_func = function(def, name)
			return def.shape_type
		end
	})

filter.register_filter({
		name = "eatable",
		filter_func = function(def, name)
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
		filter_func = function(def, name)
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

