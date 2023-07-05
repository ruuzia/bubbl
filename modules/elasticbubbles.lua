Title "Elastic Bubbles (Press to create or pop a bubble!)"

bubbles = bubbles or {}
pop_effects = pop_effects or {}
cursor_bubble = cursor_bubble or false
if movement_enabled == nil then movement_enabled = true end
local BGSHADER_MAX_ELEMS = 10

local RandomVelocity = function()
    local Dimension = function()
        return random.sign() * random.vary(ELASTIC.BUBBLE_SPEED_BASE, ELASTIC.BUBBLE_SPEED_VARY)
    end
    return Vector2(Dimension(), Dimension())
end

local RandomRadius = function()
    return random.vary(ELASTIC.BUBBLE_RAD_BASE, ELASTIC.BUBBLE_RAD_VARY)
end

local RandomPosition = function()
    return Vector2(math.random()*window_width, math.random()*window_height)
end

local RandomColor = function()
    return Color.hsl(math.random()*360, ELASTIC.BUBBLE_HUE, ELASTIC.BUBBLE_LIGHTNESS)
end

local BgShaderLoader = function()
    local contents = ReadEntireFile("shaders/elasticbubbles_bg.frag")
    return string.format("#version 330\n#define MAX_ELEMENTS %d\n%s", BGSHADER_MAX_ELEMS, contents)
end

local Particle = {
    New = function (Self, velocity, pos)
        local p = setmetatable({}, Self)
        p.velocity = velocity
        p.pos = pos
        return p
    end;
}

local CreatePopEffect = function (center, color, size)
    local pop = {
        pt_radius = ELASTIC.POP_PT_RADIUS,
        color = color,

        -- Center bubble
        [1] = Particle:New(Vector2(0,0), center)
    }

    local distance = 0
    local num_particles_in_layer = 0
    while distance < size - ELASTIC.POP_PT_RADIUS do
        distance = distance + ELASTIC.POP_LAYER_WIDTH
        num_particles_in_layer = num_particles_in_layer + ELASTIC.POP_PARTICLE_LAYOUT
        for i = 1, num_particles_in_layer do
            local theta = 2*PI / num_particles_in_layer * i
            local dir = Vector2(math.cos(theta), math.sin(theta))
            local velocity = dir * (ELASTIC.POP_EXPAND_MULT * distance / ELASTIC.POP_LIFETIME)
            table.insert(pop, Particle:New(velocity, dir * distance + center))
        end
    end
    pop.start_time = Seconds()
    return pop
end

local PopEffectFromBubble = function (bubble)
    table.insert(pop_effects, CreatePopEffect(bubble.position, bubble.color, bubble.radius))
end

local PopBubble = function(i)
    local bubble = table.remove(bubbles, i)
    PopEffectFromBubble(bubble)
end

local IsCollision = function (a, b)
    local mindist = a.radius + b.radius
    return a ~= b and Vector2.distsq(a.position, b.position) < mindist*mindist
end

local SwapVelocities = function (a, b)
    a.velocity, b.velocity = b.velocity, a.velocity
end

local SeparateBubbles = function (a, b)
    -- Push back bubble a so it is no longer colliding with b
    local dir_b_to_a = Vector2.normalize(a.position - b.position)
    local mindist = a.radius + b.radius
    a.position = b.position + dir_b_to_a * mindist
end

local EnsureBubbleInBounds = function (bubble)
    bubble.position.x = math.clamp(bubble.position.x, bubble.radius, window_width  - bubble.radius)
    bubble.position.y = math.clamp(bubble.position.y, bubble.radius, window_height - bubble.radius)
end

local CollectAllBubbles = function ()
    local all_bubbles = {}
    if cursor_bubble then table.insert(all_bubbles, cursor_bubble) end
    for _, b in ipairs(bubbles) do table.insert(all_bubbles, b) end
    return all_bubbles
end


local MoveBubble = function (bubble, dt)
    local next = bubble.position + bubble.velocity * dt
    local max_y = window_height - bubble.radius
    local max_x = window_width - bubble.radius
    if next.x < bubble.radius or next.x > max_x then
        bubble.velocity.x = -bubble.velocity.x
    else
        bubble.position.x = next.x
    end
    if next.y < bubble.radius or next.y > max_y then
        bubble.velocity.y = -bubble.velocity.y
    else
        bubble.position.y = next.y
    end
end

OnUpdate = function(dt)
    local time = Seconds()

    --- Grow bubble under mouse ---
    if cursor_bubble then
        local percent_complete = cursor_bubble.radius / ELASTIC.MAX_GROWTH
        local growth_rate = percent_complete * (ELASTIC.MAX_GROWTH_RATE - ELASTIC.MIN_GROWTH_RATE) + ELASTIC.MIN_GROWTH_RATE
        cursor_bubble.radius = cursor_bubble.radius + growth_rate * dt
        EnsureBubbleInBounds(cursor_bubble)
        if cursor_bubble.radius > ELASTIC.MAX_GROWTH then
            PopEffectFromBubble(cursor_bubble)
            cursor_bubble = false
        end
    end

    --- Move bubbles ---
    for _, bubble in ipairs(bubbles) do
        assert(bubble ~= cursor_bubble)
        if movement_enabled and not bubble.trans_starttime then
            MoveBubble(bubble, dt)
        end
        EnsureBubbleInBounds(bubble)
    end

    --- Handle collisions ---
    for _, a in ipairs(bubbles) do
        for _, b in ipairs(bubbles) do
            if IsCollision(a, b) then
                SwapVelocities(a, b)
                SeparateBubbles(a, b)
            end
        end
        if cursor_bubble and IsCollision(a, cursor_bubble) then
            -- TODO: Should bubbles that collide with cursor bubble bounce backwards?
            SeparateBubbles(a, cursor_bubble)
        end
    end

    --- Render bubbles ---
    for _, bubble in ipairs(bubbles) do RenderBubble(bubble) end
    if cursor_bubble then RenderBubble(cursor_bubble) end

    --- Update pop effect particles ---
    for _, pop in ipairs(pop_effects) do
        pop.pt_radius = pop.pt_radius + ELASTIC.POP_PT_RADIUS_DELTA * dt
        pop.age = time - pop.start_time
        for _, pt in ipairs(pop) do
            pt.pos = pt.pos + pt.velocity * dt
            RenderPop(pt.pos, pop.color, pop.pt_radius, pop.age)
        end
    end
    -- Pop effects are hopefully in chronological order
    for i = #pop_effects, 1, -1 do
        if time - pop_effects[i].start_time < ELASTIC.POP_LIFETIME then
            break
        end
        pop_effects[i] = nil
    end

    --- Draw background ---
    local bubbles = CollectAllBubbles()
    if #bubbles > 0 then
        table.sort(bubbles, function(a, b) return a.radius > b.radius end)
        local colors, positions = {}, {}
        for i=1, math.min(BGSHADER_MAX_ELEMS, #bubbles) do
            local bub = bubbles[i]
            colors[i] = bub.color
            positions[i] = bub.position
        end
        RunBgShader("elastic", BgShaderLoader, {
            resolution = Vector2(window_width, window_height),
            num_elements = #bubbles,
            colors = colors,
            positions = positions,
        })
    end
end

local BubbleAtPoint = function (pos)
    for i, b in ipairs(bubbles) do
        if pos:dist(b.position) < b.radius then
            return i, b
        end
    end
end

local Press = function ()
    if cursor_bubble then return end
    local i = BubbleAtPoint(MousePosition())
    if i then
        PopBubble(i)
    else
        cursor_bubble = Bubble:New(RandomColor(), MousePosition(), RandomVelocity(), ELASTIC.BUBBLE_RAD_BASE)
    end
end

local Release = function ()
    if not cursor_bubble then return end
    table.insert(bubbles, cursor_bubble)
    cursor_bubble = false
end

OnMouseDown = function(x, y) Press() end
OnMouseUp = function(x, y) Release() end

OnMouseMove = function(x, y)
    if cursor_bubble then cursor_bubble.position = Vector2(x, y) end
end

OnKey = function(key, down)
    if down and key == "Space" then
        movement_enabled = not movement_enabled
    elseif down and key == "Backspace" then
        for i = #bubbles, 1, -1 do
            PopBubble(i)
        end
    elseif key == "Return" then
        if down then Press() else Release() end
    end
end

OnStart = function()
    if #bubbles == 0 then
        -- Create starting bubbles
        for i=1, ELASTIC.STARTING_BUBBLE_COUNT do
            table.insert(bubbles, Bubble:New(RandomColor(), RandomPosition(), RandomVelocity(), RandomRadius()))
        end
    end
end

LockTable(_G)
