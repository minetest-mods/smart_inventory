# API definition to working together with smart_inventory

## Register new page
To get own page in smart_inventory the next register method should be used
```
smart_inventory.register_page({
                name             = string,
                icon             = string,
                label            = string,
                tooltip          = string,
                smartfs_callback = function,
                sequence         = number,
                on_button_click  = function,
        })
```
- name - unique short name, used for identification
- icon - Image displayed on page button. Optional
- label - Label displayed on page button. Optional
- tooltip - Text displayed at mouseover on the page button. Optional
- smartfs_callback(state) - smartfs callback function See [smartfs documentation](https://github.com/minetest-mods/smartfs/blob/master/docs) and existing pages implementations for reference.
- sequence - The buttons are sorted by this number (crafting=10, creative=15, player=20)
- on_button_click(state) - function called each page button click

## Filter framework
Smart_inventory uses a filter-framework for dynamic grouping in creative and crafting page. The filter framework allow to register additional classify filters for beter dynamic grouping results.
Maybe the framework will be moved to own mod in the feature if needed. Please note the smart_inventory caches all results at init time so static groups only allowed. The groups will not be re-checked at runtime.

### Register new filter
```
smart_inventory.filter.register_filter({
                name             = string,
                filter_func      = function,
                shortdesc        = string,
                shortdesc_func   = function,
        })
```
  - name - unique filter name
  - filter_func(itemdef) - function to check the item classify by item definition. Item definition is the reference to minetest.registered_items[item] entry
    next return values allowed:
    - true -> direct (belongs to) assignment to the classify group named by filtername
    - string -> dimension, steps splitted by ":" (`a:b:c:d results in filtername, filtername:a, filtername:a:b, filtername:a:b:c, filtername:a:b:c:d`)
    - key/value table -> multiple groups assignment. Values could be dimensions as above (`{a,b} results in filtername, filtername:a, filtername:b`)
    - nil -> no group assingment by this filter
  - shortdesc_func(filterstring) - optional - get human readable description for the dimension string (`filtername:a:b:c`). Empty ("") or "nogroup" means the group should be ignored. Usefull so skip some dimension characteristics
  - shortdesc - optional - static human readable description. Should be used only with boalean return values
 
### Filter Object methods

smart_inventory.filter.get(name)       get filter object by registered name. Returns filter object fltobj
  - fltobj:check_item_by_name(itemname)   classify by itemname
  - fltobj:check_item_by_def(def)         classify by item definition
  - fltobj:get_group_description(group)   get group description
