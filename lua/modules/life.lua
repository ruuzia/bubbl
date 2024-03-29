local COLOR_DEAD = Color.Hsl(0, 1.0, 0.9)
local COLOR_ALIVE = Color.Hsl(120, 0.5, 0.5)
local ROWS = 40
local COLS = 60
local DENSITY = 0.3
local VAR = {
    INTERVAL = 0.1,
}

local CountNeighbors = function (field, row, col, state)
    local count = 0
    for r=row-1, row+1 do
        for c=col-1, col+1 do
            if (r ~= row or c ~= col) and field[r] and field[r][c] == state then
                count = count + 1
            end
        end
    end
    return count
end

local NextGeneration = function (current_field)
    local next_field = {}
    for row=1, ROWS do
        next_field[row] = {}
        for col=1, COLS do
            local state = current_field[row][col]
            local neighbors = CountNeighbors(current_field, row, col, "alive")
            if neighbors == 3 or state == "alive" and neighbors == 2 then
                next_field[row][col] = "alive"
            else
                next_field[row][col] = "dead"
            end

        end
    end
    return next_field
end

local field = {}

return {
    title = "Game of Life",

    OnStart = function()
        for row=1, ROWS do
            field[row] = {}
            for col=1, COLS do
                field[row][col] = math.random() < 0.3 and "alive" or "dead"
            end
        end
        while true do
            Suspend(VAR.INTERVAL)
            field = NextGeneration(field)
        end
    end,

    Draw = function(dt)
        local spacing_x = resolution.x / COLS
        local spacing_y = resolution.y / ROWS
        local size = math.min(spacing_x, spacing_y) / 2
        for row=1, ROWS do
            for col=1, COLS do
                local x = col * spacing_x - size
                local y = row * spacing_y - size
                local color = field[row][col] == "alive" and COLOR_ALIVE or COLOR_DEAD
                RenderBubble(Vector2(x, y), color, size)
            end
        end
    end,

    tweak = {
        vars = VAR,
        { id="INTERVAL", name="Interval", type="range", min=0.01, max=0.3 },
    }
}
