local VAR = {
    EFFECT_TYPE = "rain",
    COLORING = "solid",
    COLOR = Color.Hex "#99c1f1",
    TEXT = "bubbl",
    FONT = "Lora-VariableFont",
}

local Text = require "text"

local Get = function (value, ...)
    if type(value) == "function" then
        return value(...)
    end
    return value
end

local Transition = function (definition)
    return {
        Build = function (colorer, text)
            local effect = {}
            local stages = { {}, {}, {} }
            effect.dimensions = resolution
            local text_particles = Text.BuildParticlesWithWidth(text, effect.dimensions.x)
            local final_position = Vector2(0, (effect.dimensions.y - text_particles.height) / 2)

            for i, particle in ipairs(text_particles) do
                local position = final_position + particle.offset
                local color = Get(colorer, effect.dimensions, final_position + particle.offset)
                stages[1][i], stages[2][i], stages[3][i] =
                    definition.Particle(effect.dimensions, position, color, particle.radius)
            end

            effect.stages = stages
            return effect
        end,
        Draw = function (effect)
            local initial = effect.stages[effect.current_stage]
            local final = effect.stages[effect.current_stage + 1]
            local finished_count = 0
            local time_passed = Seconds() - initial.start_time

            for i=1, #initial do
                local t = math.max(0, math.min(1, (time_passed - initial[i].hold_time) / final[i].transition_length))
                finished_count = finished_count + math.floor(t)
                local position = Lerp(initial[i].position, final[i].position, t)
                local color = Lerp(initial[i].color, final[i].color, t)
                local radius = Lerp(initial[i].radius, final[i].radius, t)
                RenderPop(position, color, radius)
            end
            if finished_count == #final then
                effect.current_stage = effect.current_stage + 1
                if effect.current_stage >= #effect.stages then
                    return false -- finished all stages
                end
                effect.stages[effect.current_stage].start_time = Seconds()
            end
            return true -- not finished
        end,
    }
end

local effect_types = {
    ["tumble"] = Transition {
        Particle = function (dimensions, target_position, target_color, target_radius)
            local SPEED = dimensions.x / 2
            local COLLAPSED_WIDTH = 0.5
            local TIME_TO_TARGET = 2.0
            local TUMBLE_HOLD_TIME = 0.3

            local initial_position = Vector2(dimensions.x * (-COLLAPSED_WIDTH * math.random()), target_position.y)
            local dispersed_position = Vector2(dimensions.x * (1 + COLLAPSED_WIDTH * math.random()), target_position.y)

            return {
                position = initial_position,
                color = target_color,
                radius = 0,
                hold_time = 0,
            }, {
                position = target_position,
                color = target_color,
                radius = target_radius,
                transition_length = TIME_TO_TARGET,
                hold_time = TUMBLE_HOLD_TIME,
            },{
                position = dispersed_position,
                color = target_color,
                radius = 0,
                transition_length = TIME_TO_TARGET,
            }
        end,
    },

    ["wind"] = Transition {
        Particle = function (dimensions, target_position, target_color, target_radius)
            local SPEED = dimensions.x / 2

            local initial_position = Vector2(math.random() * -0.1, math.random()):Scale(dimensions)
            local dispersed_position = Vector2(1 + math.random() * 0.1, math.random()):Scale(dimensions)
            local time_to_target = initial_position:Dist(target_position) / SPEED

            return {
                position = initial_position,
                color = target_color,
                radius = 0,
                hold_time = 0,
            }, {
                position = target_position,
                color = target_color,
                radius = target_radius,
                transition_length = time_to_target,
                hold_time = time_to_target,
            },{
                position = dispersed_position,
                color = target_color,
                radius = 0,
                transition_length = target_position:Dist(dispersed_position) / SPEED,
            }
        end,
    },

    ["rain"] = Transition {
        Particle = function (dimensions, target_position, target_color, target_radius)
            local SPEED = dimensions.y
            local STRETCH_Y = 2
            local HOLD_TIME = 0.2
            local DISPERSE_TIME = 1.5

            local initial_position = Vector2(target_position.x, target_position.y * STRETCH_Y + target_position.x)
            local dispersed_position = Vector2(target_position.x, -STRETCH_Y * (dimensions.y - target_position.y))
            local time_to_target = initial_position:Dist(target_position) / SPEED

            return {
                position = initial_position,
                color = target_color,
                radius = target_radius,
                hold_time = 0,
            }, {
                position = target_position,
                color = target_color,
                radius = target_radius,
                transition_length = time_to_target,
                hold_time = (target_position.x / dimensions.x),
            },{
                position = dispersed_position,
                color = target_color,
                radius = 0,
                transition_length = DISPERSE_TIME
            }
        end,
    },

    ["coalesce"] = Transition {
        Particle = function (dimensions, target_position, target_color, target_radius)
            local HOLD_TIME = 0.3
            local SPEED = dimensions:Length() / 2

            local initial_position = Vector2(math.random(), math.random()):Scale(dimensions)
            local time_to_target = initial_position:Dist(target_position) / SPEED
            return {
                position = initial_position,
                color = target_color,
                radius = 0,
                hold_time = 0,
            }, {
                position = target_position,
                color = target_color,
                radius = target_radius,
                transition_length = time_to_target,
                hold_time = HOLD_TIME,
            }, {
                position = initial_position,
                color = target_color,
                radius = 0,
                transition_length = time_to_target,
            }
        end,
    }
}

local Rainbow = function (dimensions, position)
    local t = position.x / dimensions.x
    return Color.Hsl(t*360, 1.0, 0.5)
end

local background = CreateCanvas { { Color.Hsl(0, 1, 0.01) } }
local effect
local Start, NextStage

NextStage = function ()
    if effect.current_stage+1 >= #effect.stages then
        return Start()
    end
    effect.current_stage = effect.current_stage + 1
    effect.stages[effect.current_stage].start_time = Seconds()
end

Start = function ()
    Text.SetFont(VAR.FONT)
    local effect_builder = effect_types[VAR.EFFECT_TYPE]

    local coloring = VAR.COLORING == "solid" and VAR.COLOR
        or VAR.COLORING == "rainbow" and Rainbow

    effect = effect_builder.Build(coloring, VAR.TEXT)
    effect.current_stage = 0
    NextStage()
end

local Draw = function ()
    background:draw()
    local running = effect_types[VAR.EFFECT_TYPE].Draw(effect)
    if not running then
        -- Restart
        Start()
    end
end

return {
    title = "Text Effect Playground",

    OnStart = Start,

    Draw = Draw,

    tweak = {
        vars = VAR,
        { id="TEXT", name="Text", type="string", callback=Start },
        { id="EFFECT_TYPE", name="Effect", type="options", options = TableKeys(effect_types), callback=Start },
        { id="COLORING", name="Coloring", type="options", options = { "solid", "rainbow" }, callback=Start },
        { id="COLOR", name="Solid Color", type="color", callback=Start },
        { id="FONT", name="Font", type="options", options = {
            "Lora-VariableFont", "LiberationSans-Regular", "LiberationMono-Regular",
            "LiberationMono-cluster", "funky",
        }, callback=Start },
    },
}