local utils = require("core.utils")
local menu = require("ui.menu")
local explorer = require("core.explorer")

local hearts = {
    seen_boss_dead = false,
    seen_boss_dead_time = 0,
    heart_inserted_since_last_boss = false,
    altar_interaction_cooldown = 3.0,
    last_altar_interaction_time = 0,
    found_altars = {}
}

local activated_altars = {}

function hearts.check_new_boss_cycle()
    if hearts.heart_inserted_since_last_boss and hearts.seen_boss_dead then
        hearts.heart_inserted_since_last_boss = false
        hearts.seen_boss_dead = false
        return true
    end
    return false
end

function hearts.reset()
    hearts.seen_boss_dead = false
    hearts.seen_boss_dead_time = 0
    activated_altars = {}  -- Reset activated altars
    hearts.last_altar_interaction_time = 0
    hearts.found_altars = {}
end

function hearts.has_available_hearts()
    return get_helltide_coin_hearts() > 0
end

function hearts.check_players_in_range()
    local maiden_position = utils.maiden_position()
    if not maiden_position then return 0 end

    local player_check_radius = menu.player_check_distance:get()
    local player_actors = actors_manager.get_all_actors()
    local count_players_near = 0
    
    for _, obj in ipairs(player_actors) do
        local position = obj:get_position()
        local obj_class = obj:get_character_class_id()
        local distance_maidenposcenter_to_player = position:squared_dist_to_ignore_z(maiden_position)
        if obj_class > -1 and distance_maidenposcenter_to_player <= (player_check_radius * player_check_radius) then
            count_players_near = count_players_near + 1
        end
    end
    
    return count_players_near - 1
end

function hearts.check_boss_dead(current_time)
    if current_time - hearts.seen_boss_dead_time > 30.0 then
        local enemies = actors_manager.get_all_actors()
        for _, obj in ipairs(enemies) do
            local name = string.lower(obj:get_skin_name())
            if obj:is_dead() and obj:is_enemy() and name == "s04_demon_succubus_miniboss" then
                hearts.seen_boss_dead = true
                console.print("Heart Task: Recognised Dead Boss, Re-Enabling Hearts Insert Logic")
                hearts.seen_boss_dead_time = current_time
                return true
            end
        end
    end
    return false
end

function hearts.start_insert_process(current_time)
    console.print("Heart Task: Process Triggered - Inserting Heart")
    local maiden_position = utils.maiden_position()
    if maiden_position then
        explorer:set_custom_target(maiden_position)
        explorer:move_to_target()
    else
        console.print("Heart task: Error - Cannot insert heart, maiden position unknown")
        return false
    end
    hearts.last_waiter_time = current_time
    hearts.waiter_elapsed = hearts.waiter_interval
    return true
end

local interaction_time = 3  -- 3 Sekunden Interaktionszeit
local current_altar_index = 1
local interaction_start_time = 0
local is_interacting = false

function hearts.try_insert_heart()
    local current_time = os.clock()
    local current_hearts = get_helltide_coin_hearts()

    if current_hearts > 0 and not hearts.heart_inserted_since_last_boss then
        -- Finde Altäre, wenn wir es noch nicht getan haben
        if #hearts.found_altars == 0 or current_altar_index > #hearts.found_altars then
            hearts.found_altars = {}
            current_altar_index = 1
            local actors = actors_manager.get_all_actors()

            for _, actor in ipairs(actors) do
                local name = string.lower(actor:get_skin_name())
                if name == "s04_smp_succuboss_altar_a_dyn" then
                    table.insert(hearts.found_altars, actor)
                end
            end

            table.sort(hearts.found_altars, function(a, b)
                return utils.distance_to(a) < utils.distance_to(b)
            end)
        end
        
        if current_altar_index <= #hearts.found_altars then
            local altar = hearts.found_altars[current_altar_index]
            local distance_to_altar = utils.distance_to(altar)
            
            if distance_to_altar > 2 then
                local altar_position = altar:get_position()
                pathfinder.force_move_raw(altar_position)
                
                is_interacting = false
                interaction_start_time = 0
                explorer:start()
                return false
            elseif distance_to_altar <= 2 then
                explorer:stop()
                if not is_interacting then
                    is_interacting = true
                    interaction_start_time = current_time
                    console.print("Heart Task: Starting interaction with Altar " .. current_altar_index)
                    interact_object(altar)
                elseif current_time - interaction_start_time >= interaction_time then
                    console.print("Heart Task: Completed interaction with Altar " .. current_altar_index)
                    current_altar_index = current_altar_index + 1
                    interaction_start_time = 0
                    is_interacting = false
                    
                    if current_altar_index > #hearts.found_altars then
                        console.print("Heart Task: All altars activated. Waiting for boss to spawn.")
                        -- hearts.heart_inserted_since_last_boss = true
                        hearts.found_altars = {}
                        current_altar_index = 1
                    end
                end
            else
                -- Wenn der Abstand zwischen 1 und 2 ist, bewegen wir uns weiter zum Altar
                local altar_position = altar:get_position()
                pathfinder.force_move_raw(altar_position)
                
                is_interacting = false
                interaction_start_time = 0
            end
        end
    else
        if hearts.heart_inserted_since_last_boss then
            console.print("Heart Task: Heart already inserted for this boss cycle. Waiting for next boss.")
        else
            console.print("Heart Task: No hearts available, stopping insertion process")
        end
        hearts.found_altars = {}
        current_altar_index = 1
    end
    return true
end
return hearts