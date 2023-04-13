require("util")

---@type LuaPlayer | nil
local player

---@type uint
local task = 0

---@type string?
local tas_name
---@type string?
local tas_timestamp

---@diagnostic disable: assign-type-mismatch
---@type boolean
local reset_file = settings.global["tas-s-p-reset"].value
---@type string
local file_setting = settings.global["tas-s-p-filename"].value
---@type string
local filename = "tas_state/" .. file_setting .. ".txt"
---@type uint
local frequency = settings.global["tas-s-p-frequency"].value

local print = {}
---@type boolean
print.position = settings.global["tas-s-p-position"].value
---@type boolean
print.inventory = settings.global["tas-s-p-inventory"].value
---@type boolean
print.tech = settings.global["tas-s-p-tech"].value
---@type boolean
print.craft = settings.global["tas-s-p-craft"].value
---@diagnostic enable: assign-type-mismatch

local format = string.format
local sub = string.sub

---Converts item name to human readable string
---@param str string
---@return string, integer
local function format_name(str)
    return str:gsub("^%l", string.upper):gsub("-", " ")
end

local function player_inventory()
    local inventory_s = "\t\"Inventory\": {\n%s\t},\n"
    if player and print.inventory and player.get_main_inventory() and player.get_main_inventory().get_contents() then
        local content = ""
        for key, value in pairs(player.get_main_inventory().get_contents()) do
            content = content .. "\t\t\"" .. format_name(key) .. "\": " .. value .. ",\n"
        end
        return format(inventory_s, sub(content, 0, -3) .. "\n")
    else
        return ""
    end
end

local function player_crafting_queue()
    local craft_s = "\t\"Crafting queue\": {\n%s\t},\n"
    if player and print.craft and player.crafting_queue then
        local content = ""
        for _, value in pairs(player.crafting_queue) do
            content = content .. "\t\t\"" .. format_name(value.recipe) .. "\": " .. value.count .. ",\n"
        end
        return format(craft_s, sub(content, 0, -3) .. "\n") .. player_inventory()
    else
        return player_inventory()
    end
end

local function player_position()
    local position_s = "\t\"Player position\": { \"x\":%.2f, \"y\":%.2f },\n"
    if player and print.position then
        return format(position_s, player.position.x, player.position.y) .. player_crafting_queue()
    else
        return player_crafting_queue()
    end
end

local function tech()
    local str = "\t\"Research-queue\": [\n"
    if player and print.tech and player.force and player.force.research_queue and #player.force.research_queue > 0 then
        for _, t in pairs(player.force.research_queue) do
            str = str .. "\t\t\"" .. format_name(t.name) .. "\",\n"
        end
        str = sub(str, 0, -3) ..  "\n\t],\n"

        return player_position() .. str
    elseif player then
        return player_position()
    else
        return ""
    end
end

local function print_state()
    if game then
        local _filename = tas_name and tas_timestamp and "tas_state/"..tas_name.."/"..file_setting.."_"..tas_timestamp:gsub("%.", "_"):gsub(":", "-")..".txt" or filename
        if reset_file then
            reset_file = false
            game.write_file(_filename, "" , false)
        end
        player = player or game.connected_players[1]
        if not player or player.controller_type ~= defines.controllers.character then return end
        if global.state_c then global.state_c = global.state_c + 1
        else global.state_c = 0 end
        game.write_file(
            _filename,
            "\"State-".. global.state_c .."\": {\n\t\"Tick\": " .. game.tick .. ",\n\t\"Step\": ".. task ..",\n".. sub(tech(), 0, -3) .. "\n},\n",
            true --append
        )
    end
end

local function handle_task_change(data)
    if game and data and data.task then
        task = data.task
    elseif game and data and data.step then
        task = data.step
    end
end

local function listen_to_tas_interface()
    if remote.interfaces["DunRaider-TAS"] then
        --setup event to fire on step change
        script.on_event(
            remote.call("DunRaider-TAS", "get_tas_step_change_id"),
            handle_task_change
        )
        if remote.interfaces["DunRaider-TAS"].tas_name then tas_name = remote.call("DunRaider-TAS", "get_tas_name") end
        if remote.interfaces["DunRaider-TAS"].get_tas_timestamp then tas_timestamp = remote.call("DunRaider-TAS", "get_tas_timestamp") end
    end
end

local function update_settings()
    ---@diagnostic disable: assign-type-mismatch
    file_setting = settings.global["tas-s-p-filename"].value --[[@as string]]
    filename = "tas_state/" .. file_setting .. ".txt"
    frequency = settings.global["tas-s-p-frequency"].value --[[@as uint]]
    print = {}
    print.position = settings.global["tas-s-p-position"].value
    print.inventory = settings.global["tas-s-p-inventory"].value
    print.tech = settings.global["tas-s-p-tech"].value
    print.craft = settings.global["tas-s-p-craft"].value
    ---@diagnostic enable: assign-type-mismatch

    script.on_nth_tick(nil)
    if frequency > 0 then
        script.on_nth_tick(frequency, print_state)
    end
end

local function change_setting(setting)
    ---@diagnostic disable: assign-type-mismatch
    if (setting == "tas-s-p-filename") then
        file_setting = settings.global["tas-s-p-filename"].value --[[@as string]]
        filename = "tas_state/" .. file_setting .. ".txt"
    elseif setting == "tas-s-p-frequency" then
        frequency = settings.global["tas-s-p-frequency"].value --[[@as uint]]
        script.on_nth_tick(nil)
        if frequency > 0 then
            script.on_nth_tick(frequency, print_state)
        end
    elseif setting == "tas-s-p-position" then
        print.position = settings.global["tas-s-p-position"].value
    elseif setting == "tas-s-p-inventory" then
        print.inventory = settings.global["tas-s-p-inventory"].value
    elseif setting == "tas-s-p-tech" then
        print.tech = settings.global["tas-s-p-tech"].value
    elseif setting == "tas-s-p-craft" then
        print.craft = settings.global["tas-s-p-craft"].value
    end
    ---@diagnostic enable: assign-type-mismatch
end

script.on_init(function ()
    listen_to_tas_interface()
    player = game.player or game.players and game.players[1]
    global.player = player
end)

script.on_load(function ()
    update_settings()
    reset_file = settings.global["tas-s-p-reset"].value --[[@as boolean]]
    listen_to_tas_interface()
    player = global.player
end)

script.on_event(defines.events.on_player_created, function(event)
    player = game.players[event.player_index]
    global.player = player
end)

script.on_event(defines.events.on_pre_player_removed, function(event)
    if player and player.index == event.player_index then player = nil end
    global.player = player
end)

if frequency > 0 then
    script.on_nth_tick(frequency, print_state)
end

script.on_event(defines.events.on_runtime_mod_setting_changed , function(event)
    local setting = event.setting
    change_setting(setting)
end)

script.on_configuration_changed(function (param1)
    --update_settings()
    --reset_file = true
    listen_to_tas_interface()
end)
