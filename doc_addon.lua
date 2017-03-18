local filter = smart_inventory.filter
local doc_addon = {}

function doc_addon.is_revealed_item(itemname, playername)
	local cache = smart_inventory.cache
	itemname = minetest.registered_aliases[itemname] or itemname
	local itemdef = minetest.registered_items[itemname]
	if not itemdef then
		return false
	end

	if smart_inventory.doc_items_mod then
		local category_id
		if itemdef.type == "node" then
			category_id = "nodes"
		elseif itemdef.type == "tool" then
			category_id = "tools"
		elseif itemdef.type == "craft" then
			category_id = "craftitems"
		end
		if category_id then
			return doc.entry_revealed(playername, category_id, itemname)
		else
			-- unknown item
			return false
		end
	end
	return true
end


function doc_addon.show(itemname, playername)
	local cache = smart_inventory.cache
	if smart_inventory.doc_items_mod then
		local category_id
		if cache.citems[itemname] then
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
				doc.show_entry(playername, category_id, itemname, true)
			end
		end
	end
	return true
end

-------------------------
return doc_addon
