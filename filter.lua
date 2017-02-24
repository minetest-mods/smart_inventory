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

function filter.is_revealed_item(itemname, playername)
	local cache = smart_inventory.cache
	if minetest.registered_items[itemname] == nil then
		return false
	end

	if smart_inventory.doc_items_mod then
		local category_id
		if not cache.citems[itemname] then
			-- not in creative or something like
			return false
		else
			for _, group in pairs(cache.citems[itemname].cgroups) do
				if group.name == "type:node" then
					category_id = "nodes"
				elseif group.name == "type:tool" then
					category_id = "tools"
				elseif group.name == "type:craft" then
					category_id = "craftitems"
				end
			end
			if category_id then
				return doc.entry_revealed(playername, category_id, itemname)
			else
				-- unknown item
				return false
			end
		end
	end
	return true
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
		exclusive = true,
		filter_func = function(def, name)
			return def.material
		end
	})

filter.register_filter({
		name = "formation",
		exclusive = true,
		filter_func = function(def, name)
			return def.formation
		end
	})

----------------
return filter

