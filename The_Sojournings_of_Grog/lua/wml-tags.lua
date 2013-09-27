local helper = wesnoth.require "lua/helper.lua"

wml_actions = wesnoth.wml_actions

local function flash(red, green, blue)
	wml_actions.color_adjust { red = red * 0.67, green = green * 0.67, blue = blue * 0.67 }
	wml_actions.color_adjust { red = red, green = green, blue = blue }
	wml_actions.color_adjust { red = red * 0.33, green = green * 0.33, blue = blue * 0.33}
	wml_actions.color_adjust { red = 0, green = 0, blue = 0}
end

function wml_actions.flash_screen(cfg) -- this function must not be local

	local color = cfg.color or helper.wml_error("[flash_screen] is missing required color= attribute")

	-- basically, this is a somewhat reduced version of the tag that I posted in my Lua thread.

	if color == "white" then flash(100, 100, 100)
	elseif color == "red" then flash(100, 0, 0)
	elseif color == "green" then flash(0, 100, 0)
	elseif color == "blue" then flash(0, 0, 100)
	elseif color == "magenta" then flash(100, 0, 100)
	elseif color == "yellow" then flash(100, 100, 0)
	elseif color == "cyan" then flash(0, 100, 100)
	elseif color == "black" then flash(-100, -100, -100)
	else helper.wml_error("Unsupported color in [flash_screen]")
	end

end

-- [nearest_unit]; converted as Lua tag to move some workload
-- from the WML preprocessor and engine to the Lua interpreter.

function wml_actions.nearest_unit(cfg)
	local starting_x = tonumber(cfg.starting_x) or helper.wml_error("Missing required starting_x in [nearest_unit]")
	local starting_y = tonumber(cfg.starting_y) or helper.wml_error("Missing required starting_y in [nearest_unit]")
	local filter = (helper.get_child(cfg, "filter")) or helper.wml_error("Missing required [filter] in [nearest_unit]")
	local variable = cfg.variable or "nearest_unit" -- default

	local current_distance = math.huge -- feed it the biggest value possible
	local nearest_unit_found

	for index,unit in ipairs(wesnoth.get_units(filter)) do
		local distance = helper.distance_between( starting_x, starting_y, unit.x, unit.y )
		if distance < current_distance then
			current_distance = distance
			nearest_unit_found = unit
		end
	end

	if nearest_unit_found then
		wml_actions.store_unit( { variable = variable, { "filter", { id = nearest_unit_found.id } } } )
	else wesnoth.message( "WML", "No suitable unit found by [nearest_unit]" )
	end
end

local T = helper.set_wml_tag_metatable {}

-- support for translatable strings, custom textdomain
local _ = wesnoth.textdomain "wesnoth-The_Sojournings_of_Grog"
-- #textdomain wesnoth-The_Sojournings_of_Grog

-- [item_dialog]
-- an alternative interface to pick items
-- could be used in place of [message] with [option] tags
function wml_actions.item_dialog( cfg )
	local image_and_description = T.grid { T.row { T.column { vertical_alignment = "center",
								  horizontal_alignment = "center",
								  border = "all",
								  border_size = 5,
								  T.image { id = "image_name" } },
						       T.column { horizontal_alignment = "left",
								  border = "all",
								  border_size = 5,
								  T.scroll_label { id = "item_description" } }
		                              } }

	local buttonbox = T.grid { T.row { T.column { T.button { id = "take_button", return_value = 1 } },
					   T.column { T.spacer { width = 10 } },
					   T.column { T.button { id = "leave_button", return_value = 2 } }
				  } }

	local item_dialog = { T.helptip { id="tooltip_large" }, -- mandatory field
			      T.tooltip { id="tooltip_large" }, -- mandatory field
			      maximum_height = 320,
			      maximum_width = 480,
			      T.grid { -- Title, will be the object name
				      T.row { T.column { horizontal_alignment = "left",
							  grow_factor = 1, -- this one makes the title bigger and golden
							  border = "all",
							  border_size = 5,
							  T.label { definition = "title", id = "item_name" } } },
				      -- Image and item description
				      T.row { T.column { image_and_description } }, -- grid teminator
				      -- Effect description
				      T.row { T.column { horizontal_alignment = "left",
							  border = "all",
							  border_size = 5,
							  T.label { wrap = true, id = "item_effect" } } }, -- how to format?
				      -- button box
				      T.row { T.column { buttonbox } }
				    }
			    }

	local function item_preshow()
		-- here set all widget starting values
		wesnoth.set_dialog_value ( cfg.name, "item_name" )
		wesnoth.set_dialog_value ( cfg.image or "", "image_name" )
		wesnoth.set_dialog_value ( cfg.description, "item_description" )
		wesnoth.set_dialog_value ( cfg.effect, "item_effect" )
		wesnoth.set_dialog_value ( cfg.take_string or tostring( _"Take it" ), "take_button" )
		wesnoth.set_dialog_value ( cfg.leave_string or tostring( _"Leave it" ), "leave_button" )
	end

	local function sync()
		local function item_postshow()
			-- here get all widget values
		end

		local return_value = wesnoth.show_dialog( item_dialog, item_preshow, item_postshow )

		return { return_value = return_value }
	end

	local return_table = wesnoth.synchronize_choice(sync)
	if return_table.return_value == 1 or return_table.return_value == -1 then
		wesnoth.set_variable ( cfg.variable or "item_picked", "yes" )
	else wesnoth.set_variable ( cfg.variable or "item_picked", "no" )
	end
end

-- for use by multihex attack
function wesnoth.wml_actions.get_unit_defense(cfg)
	local filter = wesnoth.get_units(cfg)
	local variable = cfg.variable or "defense"

	for index, unit in ipairs(filter) do
		local terrain = wesnoth.get_terrain ( unit.x, unit.y )
		-- it is WML defense: the lower, the better. Converted to normal defense with 100 -
		local defense = 100 - wesnoth.unit_defense ( unit, terrain )
		wesnoth.set_variable ( string.format ( "%s[%d]", variable, index - 1 ), { id = unit.id, x = unit.x, y = unit.y, terrain = terrain, defense = defense } )
	end
end

terrain_table = {}
-- the following structure is necessary because
-- * and ^ are math operators in Lua
terrain_table["Wo"]       = "Ww" --deep to shallow water
terrain_table["Ss"]       = "Gs" --swamp to savannah
terrain_table["Gg"]       = "Re" --grass,savannah,flowers,farmland to dirt
terrain_table["Gg^Efm"]   = "Re"
terrain_table["Gs"]       = "Re"
terrain_table["Re^Gvs"]   = "Re"
terrain_table["Ww^Bw*"]   = "Ww" --water bridge to water
terrain_table["Ss^Bw*"]   = "Ss" --swamp bridge to swamp
terrain_table["*^Bw*"]    = "Ww" --any other bridge to water
terrain_table["Ds"]       = "Dd^Dc" --desert,sand,desert hills,oasis to desert crater
terrain_table["Dd"]       = "Dd^Dc"
terrain_table["Hd"]       = "Dd^Dc"
terrain_table["Dd^Do"]    = "Dd^Dc"
terrain_table["Gs^F*"]    = "Gs" --savannah based forest to savannah
terrain_table["Gg^F*"]    = "Gg" --forest to grass
terrain_table["Hh^F*"]    = "Hh" --forested hills to hills
terrain_table["Aa^F*"]    = "Aa" --snow forest to grass
terrain_table["Ha^F*"]    = "Ha" --Snow forested hills to hills
terrain_table["Aa"]       = "Ai" --snow to ice (looks good!)
terrain_table["Rr^Vhc"]   = "Rp^Vhcr" --various villages to their ruined counterparts
terrain_table["Gs^Vh"]    = "Gd^Vhr"
terrain_table["Hh^Vhh"]   = "Hhd^Vhhr"
terrain_table["Ha^Vhha"]  = "Hh^Vh" --village snow hills to normal hills
terrain_table["Ms^Vhha"]  = "Mm^Vhh" --village snow mountains to normal mountains
terrain_table["Ha^Vca"]   = "Hh^Vc" --village snow hills (orc) to normal hills
terrain_table["Ha^Voa"]   = "Hh^Vo" --orcish snow hills village to orcish hills village
terrain_table["Aa^Voa"]   = "Gg^Vo" --orcish snow village to orcish village
terrain_table["Ss^Vhs"]   = "Gs^Vht" --village swamp to savvanah
terrain_table["Aa^Vha"]   = "Gg^Vh" --village snow to normal
terrain_table["Aa^Vea"]   = "Gg^Ve" --village snow to normal
terrain_table["Uh"]       = "Uu" --cave path,rough,mushrooms to cave
terrain_table["Ur"]       = "Uu"
terrain_table["Uu^Uf"]    = "Uu"
terrain_table["Uu"]       = "Uu^Dr" --cave to rubble
terrain_table["Ch"]       = "Chr" --castle to ruin
terrain_table["Kh"]       = "Khr" --keep to ruin
terrain_table["Ha"]       = "Hh" --snow hills to hills
terrain_table["Ms"]       = "Mm" --snow mountains to mountains
terrain_table["Rrc^Vhca"] = "Rr^Vhc" --Snowy Human City Village -> Human City Village
--Snowy Castle, Fort or Keep -> Castle, Fort or Keep
terrain_table["Kha"]      = "Kh" --Snowy Human Keep
terrain_table["Cha"]      = "Chr" --Snowy Human Castle
terrain_table["Kea"]      = "Ke" --Snowy Encampment Keep
terrain_table["Cea"]      = "Ce" --Snowy Encampment Keep
terrain_table["Coa"]      = "Co" --Snowy Orcish Fort
terrain_table["Koa"]      = "Ko" --Snowy Orcish Keep
terrain_table["Gd"]       = "Rd" --Dead Grass -> Dry dirt
terrain_table["Gll"]      = "Rd" --Leaf Litter -> Dry dirt
-- Mine Rails on cave, cave path, cave hills, water and earth-toned cave -> debris
terrain_table["Uu^Br*"]   = "Uu^Dr"
terrain_table["Ur^Br*"]   = "Ur^Dr"
terrain_table["Uh^Br*"]   = "Uh^Dr"
terrain_table["Ww^Br*"]   = "Ww" --this one becomes water
terrain_table["Uue^Br*"]  = "Uue^Dr"
terrain_table["Iwr"]      = "Iwr^Dr" --Wooden Floor -> Debris
terrain_table["Uu^Emf"]   = "Uu" --Mushroom Farm on cave -> cave
terrain_table["Uue^Emf"]  = "Uue" --Mushroom Farm on earth-toned cave -> earth-toned cave
terrain_table["Uue"]      = "Uue^Dr" --Earth-toned cave -> debris
terrain_table["W*^Bsb*"]  = "Ww" --stone bridge on water to water

function wml_actions.elyssa_terrain_substitution( cfg )
	local x = wesnoth.current.event_context.x1
	local y = wesnoth.current.event_context.y1
	
	for key, value in pairs( terrain_table ) do
		if wesnoth.match_location( x, y, { terrain = key } ) then
			wesnoth.set_terrain( x, y, value )
			wml_actions.redraw {}
			break -- exit on first match
		end
	end
end
