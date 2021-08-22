stoneworld_player_spawns = {}

stoneworld_player_spawns.pos_pool = {}
stoneworld_player_spawns.new_players = {}

-- Need to modify beds!
-- Remove spawnS when bed is removed.

if _G["beds"] and not _G["bed_lives"] then
    local remove_bed_spawn = function(pos)
        for key, val in pairs(beds.spawn) do
            local v = vector.round(val)
            if vector.equals(v, pos) then
                beds.spawn[key] = nil
            end
        end
    end
    local old_on_destruct = minetest.registered_nodes['beds:fancy_bed_bottom'].on_destruct
    minetest.registered_nodes['beds:fancy_bed_bottom'].on_destruct = function(pos)
        old_on_destruct(pos)
        remove_bed_spawn(pos)
    end

    local old_on_destruct2 = minetest.registered_nodes['beds:fancy_bed_top'].on_destruct
    minetest.registered_nodes['beds:fancy_bed_top'].on_destruct = function(pos)
        old_on_destruct2(pos)
        remove_bed_spawn(pos)
    end

    local old_on_destruct3 = minetest.registered_nodes['beds:bed_bottom'].on_destruct
    minetest.registered_nodes['beds:bed_bottom'].on_destruct = function(pos)
        old_on_destruct3(pos)
        remove_bed_spawn(pos)
    end

    local old_on_destruct4 = minetest.registered_nodes['beds:bed_top'].on_destruct
    minetest.registered_nodes['beds:bed_top'].on_destruct = function(pos)
        old_on_destruct4(pos)
        remove_bed_spawn(pos)
    end
end


-- Cannot redeclare "drop", so copy big part of beds mod 2020.

local reverse = true

local function destruct_bed(pos, n)
	local node = minetest.get_node(pos)
	local other

	if n == 2 then
		local dir = minetest.facedir_to_dir(node.param2)
		other = vector.subtract(pos, dir)
	elseif n == 1 then
		local dir = minetest.facedir_to_dir(node.param2)
		other = vector.add(pos, dir)
	end

	if reverse then
		reverse = not reverse
		minetest.remove_node(other)
		minetest.check_for_falling(other)
	else
		reverse = not reverse
	end

    -- remove respawn when bed is removed
    for key, val in pairs(beds.spawn) do
        local v = vector.round(val)
        if vector.equals(v, pos) or vector.equals(v, other) then
            beds.spawn[key] = nil
        end
    end

end

stoneworld_player_spawns.register_bed = function(name, def)
	minetest.register_node(name .. "_bottom", {
		description = def.description,
		inventory_image = def.inventory_image,
		wield_image = def.wield_image,
		drawtype = "nodebox",
		tiles = def.tiles.bottom,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		stack_max = 1,
		groups = {choppy = 1, flammable = 3, bed = 1},
		sounds = def.sounds or default.node_sound_wood_defaults(),
		node_box = {
			type = "fixed",
			fixed = def.nodebox.bottom,
		},
		selection_box = {
			type = "fixed",
			fixed = def.selectionbox,
		},
        drop = "",

		on_place = function(itemstack, placer, pointed_thing)
			local under = pointed_thing.under
			local node = minetest.get_node(under)
			local udef = minetest.registered_nodes[node.name]
			if udef and udef.on_rightclick and
					not (placer and placer:is_player() and
					placer:get_player_control().sneak) then
				return udef.on_rightclick(under, node, placer, itemstack,
					pointed_thing) or itemstack
			end

			local pos
			if udef and udef.buildable_to then
				pos = under
			else
				pos = pointed_thing.above
			end

			local player_name = placer and placer:get_player_name() or ""

			if minetest.is_protected(pos, player_name) and
					not minetest.check_player_privs(player_name, "protection_bypass") then
				minetest.record_protection_violation(pos, player_name)
				return itemstack
			end

			local node_def = minetest.registered_nodes[minetest.get_node(pos).name]
			if not node_def or not node_def.buildable_to then
				return itemstack
			end

			local dir = placer and placer:get_look_dir() and
				minetest.dir_to_facedir(placer:get_look_dir()) or 0
			local botpos = vector.add(pos, minetest.facedir_to_dir(dir))

			if minetest.is_protected(botpos, player_name) and
					not minetest.check_player_privs(player_name, "protection_bypass") then
				minetest.record_protection_violation(botpos, player_name)
				return itemstack
			end

			local botdef = minetest.registered_nodes[minetest.get_node(botpos).name]
			if not botdef or not botdef.buildable_to then
				return itemstack
			end

			minetest.set_node(pos, {name = name .. "_bottom", param2 = dir})
			minetest.set_node(botpos, {name = name .. "_top", param2 = dir})

			if not (creative and creative.is_enabled_for
					and creative.is_enabled_for(player_name)) then
				itemstack:take_item()
			end
			return itemstack
		end,

		on_destruct = function(pos)
			destruct_bed(pos, 1)
		end,

		on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			beds.on_rightclick(pos, clicker)
			return itemstack
		end,

		on_rotate = function(pos, node, user, _, new_param2)
			local dir = minetest.facedir_to_dir(node.param2)
			local p = vector.add(pos, dir)
			local node2 = minetest.get_node_or_nil(p)
			if not node2 or not minetest.get_item_group(node2.name, "bed") == 2 or
					not node.param2 == node2.param2 then
				return false
			end
			if minetest.is_protected(p, user:get_player_name()) then
				minetest.record_protection_violation(p, user:get_player_name())
				return false
			end
			if new_param2 % 32 > 3 then
				return false
			end
			local newp = vector.add(pos, minetest.facedir_to_dir(new_param2))
			local node3 = minetest.get_node_or_nil(newp)
			local node_def = node3 and minetest.registered_nodes[node3.name]
			if not node_def or not node_def.buildable_to then
				return false
			end
			if minetest.is_protected(newp, user:get_player_name()) then
				minetest.record_protection_violation(newp, user:get_player_name())
				return false
			end
			node.param2 = new_param2
			-- do not remove_node here - it will trigger destroy_bed()
			minetest.set_node(p, {name = "air"})
			minetest.set_node(pos, node)
			minetest.set_node(newp, {name = name .. "_top", param2 = new_param2})
			return true
		end,
		can_dig = function(pos, player)
			return beds.can_dig(pos)
		end,
	})

	minetest.register_node(name .. "_top", {
		drawtype = "nodebox",
		tiles = def.tiles.top,
		paramtype = "light",
		paramtype2 = "facedir",
		is_ground_content = false,
		pointable = false,
		groups = {choppy = 1, flammable = 3, bed = 2},
		sounds = def.sounds or default.node_sound_wood_defaults(),
		drop = "",
		node_box = {
			type = "fixed",
			fixed = def.nodebox.top,
		},
		on_destruct = function(pos)
			destruct_bed(pos, 2)
		end,
		can_dig = function(pos, player)
			local node = minetest.get_node(pos)
			local dir = minetest.facedir_to_dir(node.param2)
			local p = vector.add(pos, dir)
			return beds.can_dig(p)
		end,
	})

	minetest.register_alias(name, name .. "_bottom")

    if def.recipe then
    	minetest.register_craft({
    		output = name,
    		recipe = def.recipe
    	})
    end
end


-- Special start bed
stoneworld_player_spawns.register_bed("stoneworld_player_spawns:leaves_bed", {
	description = "Temporary Bed",
	inventory_image = "default_leaves.png",
	wield_image = "default_leaves.png",
	tiles = {
		bottom = {
			"default_leaves.png"
		},
		top = {
			"default_leaves.png",
		}
	},
	nodebox = {
		bottom = {-0.5, -0.5, -0.5, 0.5, 0.06, 0.5},
		top = {-0.5, -0.5, -0.5, 0.5, 0.06, 0.5},
	},
	selectionbox = {-0.5, -0.5, -0.5, 0.5, 0.06, 1.5},
    recipe = false,
})


-- around spawn
stoneworld_player_spawns.random_test_pos = function()
    local test_pos = {
        x=math.random(1000, 2000),
        y=math.random(0, 32),
        z=math.random(1000, 2000)};

    -- -- debug
    -- local test_pos = {
    --     x=math.random(0, 500),
    --     y=math.random(0, 32),
    --     z=math.random(0, 500)};

    local neg = math.random(1, 4)
    if neg == 2 then
        test_pos.x = -test_pos.x
    elseif neg == 3 then
        test_pos.z = -test_pos.z
    elseif neg == 4 then
        test_pos.x = -test_pos.x
        test_pos.z = -test_pos.z
    end

    -- 2021 forceload_block loads not exactly block containing node because of "floor"? Ok, then this should always work...
    local basep = vector.multiply(vector.floor(vector.divide(test_pos, 16)), 16);
    local stable_test_pos = {x=basep.x+1, y=basep.y+1, z=basep.z+1}

    return stable_test_pos
end

--Forceload far blocks, wait, then check content and unload. Copy from cursed_world mod 2021
--recursion
stoneworld_player_spawns.search_better_place_after_forceload = function(parameters)
    local player_name, test_pos, n = parameters[1], parameters[2], parameters[3];

    -- 2021 forceload_block loads not exactly block containing node because of "floor". Account for this...
    local basep = vector.multiply(vector.floor(vector.divide(test_pos, 16)), 16);
    local minp = {x=basep.x, y=basep.y, z=basep.z}
    local maxp = {x=basep.x+16, y=basep.y+16, z=basep.z+16}

    local unloaded_block = false
    local some_name = minetest.get_node(test_pos).name;
    local good_places = minetest.find_nodes_in_area_under_air(minp, maxp, {"default:stone"})

    -- -- debug
    -- local debug1 = minetest.find_nodes_in_area(minp, maxp, {"default:stone"})
    -- local debug2 = minetest.find_nodes_in_area(minp, maxp, {"air"})
    --
    -- -- debug
    -- if test_pos.y < minp.y or test_pos.y > maxp.y then
    --     minetest.chat_send_all("OH NO Y ")
    -- end
    --
    -- if test_pos.x < minp.x or test_pos.x > maxp.x then
    --     minetest.chat_send_all("OH NO X ")
    -- end
    --
    -- if test_pos.z < minp.z or test_pos.z > maxp.z then
    --     minetest.chat_send_all("OH NO Z ")
    -- end
    --
    -- -- debug
    -- minetest.chat_send_all(basep.x..","..basep.y..","..basep.z.." - "..minp.x..","..minp.y..","..minp.z.." - "..maxp.x..","..maxp.y..","..maxp.z)
    -- minetest.chat_send_all(some_name.." at "..minetest.serialize(test_pos).." "..n.." gp"..#good_places.." stone"..#debug1.." air"..#debug2)

    minetest.forceload_free_block(test_pos, true);

    -- Use special function for not yet generated
    if #good_places > 2 then
        -- all good!
    elseif some_name == "ignore" then
        unloaded_block = true
        local spawn_candidate = minetest.get_spawn_level(test_pos.x, test_pos.z)
        if spawn_candidate then
            local sp = {x=test_pos.x, y=spawn_candidate, z=test_pos.z}
            good_places[1] = sp
            good_places[2] = sp
            good_places[3] = sp
        end
    elseif some_name == "air" and n < 10 and math.random(0, 100) > 25 then
        n = n + 1;
        test_pos.y = test_pos.y - 16
        if minetest.forceload_block(test_pos, true) then
            minetest.after(2.2, stoneworld_player_spawns.search_better_place_after_forceload, {player_name, test_pos, n});
            return
        else
            minetest.chat_send_all("No1 ".." at "..minetest.serialize(test_pos).." "..n);
        end
    elseif some_name == "default:stone" and n < 10 and math.random(0, 100) > 25 then
        n = n + 1;
        test_pos.y = test_pos.y + 16
        if minetest.forceload_block(test_pos, true) then
            minetest.after(2.2, stoneworld_player_spawns.search_better_place_after_forceload, {player_name, test_pos, n});
            return
        else
            minetest.chat_send_all("No2 ".." at "..minetest.serialize(test_pos).." "..n);
        end
    end

    if #good_places > 2 then
        local num_place = math.random(1, #good_places-1)
        local pos_target = good_places[num_place];

        if unloaded_block then
            pos_target.y = pos_target.y - 1 -- get_spawn_level is two node above stone
        else
            pos_target.y = pos_target.y + 1 -- we need to be above stone
        end

        table.insert(stoneworld_player_spawns.pos_pool, pos_target)

        -- minetest.chat_send_all("Ok ".." at "..pos_target.x..","..pos_target.y..","..pos_target.z.." "..n);
        return
    else
        if n < 10 then
            n = n + 1;
            test_pos = stoneworld_player_spawns.random_test_pos()
            if minetest.forceload_block(test_pos, true) then
                minetest.after(2.2, stoneworld_player_spawns.search_better_place_after_forceload, {player_name, test_pos, n});
            else
                minetest.chat_send_all("No3 ".." at "..minetest.serialize(test_pos).." "..n);
            end
        else
            -- minetest.chat_send_all("No final "..n);
        end
    end
end
--start recursion from here
stoneworld_player_spawns.slovly_search_target_location = function(player_name)

    local n = 0;
    local test_pos = stoneworld_player_spawns.random_test_pos()
    --forceload blocks and check nodes after some delay
    if minetest.forceload_block(test_pos, true) then
        minetest.after(5.5, stoneworld_player_spawns.search_better_place_after_forceload, {player_name, test_pos, n});
    end
end


stoneworld_player_spawns.create_personal_spawn = function(parameters)
    local player_name, pos = parameters[1], parameters[2];
    local player = minetest.get_player_by_name(player_name)
    if not player then
        return
    end
    minetest.set_node({x=pos.x, y=pos.y+1, z=pos.z}, {name="air"})
    minetest.set_node({x=pos.x+1, y=pos.y, z=pos.z}, {name="air"})
    minetest.set_node({x=pos.x-1, y=pos.y, z=pos.z}, {name="air"})
    minetest.set_node({x=pos.x, y=pos.y, z=pos.z+1}, {name="air"})
    minetest.set_node({x=pos.x, y=pos.y, z=pos.z-1}, {name="air"})
    minetest.place_node(pos, {name="stoneworld_player_spawns:leaves_bed"})
    beds.spawn[player_name] = pos   -- set without save should be enough?
end

-- Every minute check spawn pool to be more then 10 entries
local timer = 0
minetest.register_globalstep(function(dtime)
	timer = timer + dtime;
	if timer >= 2 then
        if #stoneworld_player_spawns.pos_pool < 10 then
            stoneworld_player_spawns.slovly_search_target_location(nil, nil)
        end
		timer = 0
	end
end)

minetest.register_on_newplayer(function(player)
    local player_name = player:get_player_name()
    stoneworld_player_spawns.new_players[player_name] = player_name
    -- minetest.chat_send_all("New "..player_name);
end)

minetest.register_on_joinplayer(function(player)
    local player_name = player:get_player_name()
    -- minetest.chat_send_all("Test "..player_name)
    if stoneworld_player_spawns.new_players[player_name] then
        -- minetest.chat_send_all("Test2 "..player_name)
        if #stoneworld_player_spawns.pos_pool > 0 then
            local pos = table.remove(stoneworld_player_spawns.pos_pool, #stoneworld_player_spawns.pos_pool)
            -- need spawn player to load area first.
            player:set_pos(pos)
            minetest.after(1.0, stoneworld_player_spawns.create_personal_spawn, {player_name, pos});
            -- minetest.chat_send_all("First RESpawning ".." at "..pos.x..","..pos.y..","..pos.z);
        end
        stoneworld_player_spawns.new_players[player_name] = nil
        return true
    end
end)

-- Debug ...
minetest.register_chatcommand("sme", {
	description = "Test random spawn",
    params = "Optional player",
    privs = {server=true},
	func = function(name, text)
        local me_name = name
        if text and #text > 0 then
            name = text
        end

        if #stoneworld_player_spawns.pos_pool > 0 then
            local pos = table.remove(stoneworld_player_spawns.pos_pool, #stoneworld_player_spawns.pos_pool)

            local player = minetest.get_player_by_name(name)
            minetest.chat_send_player(me_name, "Spawning "..name.." at "..pos.x..","..pos.y..","..pos.z);

            if player then
                -- need spawn player to load area first.
                player:set_pos(pos)
                minetest.after(1.0, stoneworld_player_spawns.create_personal_spawn, {name, pos});
            end
        end
		return true
	end,
})
