local utils = require "core.utils"
local settings = require "settings"
local menu = require "ui.menu"
local explorer = require "core.explorer"

local stuck_position = nil
local last_execution_time = 0
local execution_cooldown = 3 -- 3 Sekunden Cooldown

local task = {
    name = "Fight Monsters",
    should_execute = function()
        local current_time = os.time()
        return (utils.is_in_helltide_zone() and utils.get_closest_enemy() ~= nil) or
               (current_time - last_execution_time < execution_cooldown)
    end,
    
    execute = function()
    local current_time = os.time()
    if current_time - last_execution_time < execution_cooldown then
        return true -- Der Task läuft weiter, auch wenn kein Gegner in der Nähe ist
    end

    local enemy = utils.get_closest_enemy()
    if not enemy then 
        explorer:clear_path_and_target()
        return false 
    end

    local player_pos = get_player_position()
    
    if explorer.check_if_stuck() then
        explorer:handle_stuck_state()
        stuck_position = player_pos
        return false
    end

    if stuck_position and utils.distance_to(stuck_position) < 25 then
        return false
    else
        stuck_position = nil
    end
    
    local enemy_pos = enemy:get_position()
    local distance_to_enemy = utils.distance_to(enemy)

    local combat_distance = menu.combat_distance:get()
    local distance_check = settings.melee_logic and 2 or 6.5

    if distance_to_enemy > combat_distance then
        last_execution_time = current_time
        return true
    end

    if distance_to_enemy < distance_check then
        if settings.melee_logic then
            local target_pos = enemy_pos:get_extended(player_pos, -1.0)
            explorer:clear_path_and_target()
            explorer:set_custom_target(target_pos)
            explorer:move_to_target()
        else
            --console.print("Within ranged attack distance, no movement needed")
        end
    else
        explorer:clear_path_and_target()
        explorer:set_custom_target(enemy_pos)
        explorer:move_to_target()
    end

    last_execution_time = current_time
    return true
end
}

return task