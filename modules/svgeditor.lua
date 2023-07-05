Title "SVG Editor"

SVGEDITOR = {
    FILE = NextArg() or "img.svg",
    COLOR = WEBCOLORS.PURPLE,
}

local scale = 1

circles = {}
local is_shift_down = false
local is_ctrl_down = false
local selection_start
local drag_start
local rotate = nil

local selected = {}

local BASE_SIZE = 20
local KEY_MOVEMENT = 20
local KEY_LITTLE_MOVEMENT = 5

local TextRenderer = require "textrenderer"
local Draw = require "draw"

local get_draw_box_base_position = function ()
    local center = Vector2(window_width/2, window_height/2)
    local width = SVG_WIDTH * scale
    local height = SVG_HEIGHT * scale
    return Vector2(center.x - width/2, center.y - height/2)
end

local NormalPosition = function (pos)
    local base = get_draw_box_base_position()
    return (pos - base) * (1/scale)
end

local AbsolutePosition = function (pos)
    local base = get_draw_box_base_position()
    return base + pos * scale
end

local Circle = {
    New = function (self, pos, radius, is_focused)
        local c = setmetatable({}, self)
        c.pos = pos
        c.radius = radius
        c.focused = is_focused
        return c
    end,
    absolute_position = function (self, absolute)
        if absolute then self.pos = NormalPosition(absolute) end
        return AbsolutePosition(self.pos)
    end,
    absolute_radius = function (self, absolute)
        if absolute then self.radius = absolute / scale end
        return self.radius * scale
    end,
}
Circle.__index = Circle

local GetSelection = function()
    local mouse = NormalPosition(MousePosition())
    local x1, y1 = selection_start:unpack()
    local x2, y2 = mouse:unpack()
    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end
    -- x1, y1 is bottom right
    -- x2, y2 is top left
    return x1, y1, x2, y2
end

OnUpdate = function(dt)
    -- Render circles
    for _,pt in ipairs(circles) do
        local alpha = selected[pt] and 0.5 or 0
        RenderPop(pt:absolute_position(), SVGEDITOR.COLOR, pt.radius * scale, alpha)
    end

    local base = get_draw_box_base_position()
    Draw.rect_outline(base.x, base.y, SVG_WIDTH*scale, SVG_HEIGHT*scale, WEBCOLORS.BLACK)

    if selection_start then
        local x1, y1, x2, y2 = GetSelection()
        local botleft = AbsolutePosition(Vector2(x1, y1))
        local topright = AbsolutePosition(Vector2(x2, y2))
        Draw.rect_outline(botleft.x, botleft.y, topright.x - botleft.x, topright.y - botleft.y, SVGEDITOR.COLOR)
    end

     if rotate then
         local axis = AbsolutePosition(rotate.axis_position)
         local mouse = MousePosition()
         Draw.line(axis.x, axis.y, mouse.x, mouse.y, SVGEDITOR.COLOR)
     end

    -- Testing text
    local y = 0
    for _,str in ipairs{"over the lazy dog", "the quick brown fox jumps"} do
        local height = TextRenderer.put_string_with_width(Vector2(0,y), str, window_width, SVGEDITOR.COLOR)
        y = y + height
    end
end

OnMouseMove = function(x, y)
    local mouse = NormalPosition(Vector2(x, y))
    if selection_start then
        local x1, y1, x2, y2 = GetSelection()
        selected = {}
        for _,circle in ipairs(circles) do
            local x, y = circle.pos:unpack()
            local r = circle.radius
            if x1 < x + r and x - r < x2 and y1 < y + r and y - r < y2 then
                selected[circle] = true
            end
        end
    elseif drag_start then
        for circle in pairs(selected) do
            local diff = mouse - drag_start
            circle.pos = circle.pos + diff
        end
        drag_start = mouse
    elseif rotate then
        local relative_start = rotate.start_position - rotate.axis_position
        local start_angle = math.atan2(relative_start.y, relative_start.x)
        local relative_cur = mouse - rotate.axis_position
        local new_angle = math.atan2(relative_cur.y, relative_cur.x)
        local angle_delta = new_angle - start_angle
        rotate.start_position = mouse
        for circle in pairs(selected) do
            local pos = circle.pos - rotate.axis_position
            local mag = pos:length()
            local theta = math.atan2(pos.y, pos.x)
            local new_theta = theta + angle_delta
            circle.pos = Vector2(math.cos(new_theta), math.sin(new_theta)) * mag + rotate.axis_position
        end
    end
end

local fmt = string.format
local SaveToSVG = function(file_path)
    local f = assert(io.open(file_path, 'w'))
    f:write("<?xml version=\"1.0\"?>\n")
    f:write(fmt("<svg width=\"%d\" height=\"%d\">\n", SVG_WIDTH, SVG_HEIGHT))
    
    for i,circle in ipairs(circles) do
        local x, y = circle.pos:unpack()
        if x > 0 and x < SVG_WIDTH and y > 0 and y < SVG_HEIGHT then
            f:write(fmt("  <circle cx=\"%d\" cy=\"%d\" r=\"%d\" fill=\"%s\" />\n",
                    x, SVG_HEIGHT - y, circle.radius, SVGEDITOR.COLOR:to_hex_string()))
        end
    end

    f:write("</svg>")
    f:close()
end

local circle_at_position = function(pos)
    -- We iterate backwards to get the front circle
    for i = #circles, 1, -1 do
        if circles[i].pos:dist(pos) < circles[i].radius then
            return circles[i]
        end
    end
    return nil
end

FindSelectionCenterPoint = function()
    local right = 0
    local left = window_width
    local top = 0
    local bottom = window_height
    for circle in pairs(selected) do
        local pos = circle:absolute_position()
        left = math.min(left, pos.x)
        right = math.max(right, pos.x)
        top = math.max(top, pos.y)
        bottom = math.min(bottom, pos.y)
    end
    local x = (left + right) / 2
    local y = (bottom + top) / 2
    return NormalPosition(Vector2(x, y))
end

OnMouseDown = function(x, y)
    local pos = NormalPosition(Vector2(x, y))
    if is_shift_down then
        selection_start = pos
    elseif is_ctrl_down and next(selected) then
        -- Start rotation
        rotate = { start_position = pos, axis_position = FindSelectionCenterPoint() }
    else
        local found = circle_at_position(pos)
        if found and selected[found] then
            -- Start dragging selected circles
            drag_start = pos
        elseif found then
            -- Select circle
            selected[found] = true
        elseif not next(selected) then
            -- Creating new cicle
            local circle = Circle:New(pos, BASE_SIZE, true)
            table.insert(circles, circle)
            selected = {}
        else
            selected = {}
        end
    end
end

OnMouseUp = function(x, y)
    if selection_start then
        selection_start = nil
    elseif drag_start then
        -- Finished dragging
        drag_start = nil
    elseif rotate then
        rotate = nil
    end
end

local MIN_CIRCLE_RADIUS = 5

local circle_delta_radius = function(circle, delta)
    local new_radius = circle.radius + delta
    circle.radius = math.max(MIN_CIRCLE_RADIUS, new_radius)
end

OnKey = function(key, is_down)
    if key == "Return" and is_down then
        SaveToSVG(SVGEDITOR.FILE)
    elseif key == "Backspace" and is_down then
        for v in pairs(selected) do
            local i = assert(ArrayFind(circles, v))
            table.remove(circles, i)
        end
        selected = {}
    elseif key == "Left Shift" or key == "Right Shift" then
        is_shift_down = is_down
    elseif key == "Left Ctrl" or key == "Right Ctrl" then
        is_ctrl_down = is_down
    elseif key == "C" and is_down then
        local new_selected = {}
        local OFFSET = Vector2(BASE_SIZE, BASE_SIZE)
        for v in pairs(selected) do
            local new_circle = Circle:New(v.pos + OFFSET, v.radius, true)
            table.insert(circles, new_circle)
            new_selected[new_circle] = true
        end
        selected = new_selected
    elseif is_down and next(selected) and key == "Up" then
        for circle in pairs(selected) do
            circle.pos.y = circle.pos.y + KEY_MOVEMENT
        end
    elseif is_down and next(selected) and key == "Down" then
        for circle in pairs(selected) do
            circle.pos.y = circle.pos.y - KEY_MOVEMENT
        end
    elseif is_down and next(selected) and key == "Left" then
        for circle in pairs(selected) do
            circle.pos.x = circle.pos.x - KEY_MOVEMENT
        end
    elseif is_down and next(selected) and key == "Right" then
        for circle in pairs(selected) do
            circle.pos.x = circle.pos.x + KEY_MOVEMENT
        end
    end
end

local ZOOM_SPEED = 0.2
local ZOOM_MIN = 0.1
local ZOOM_MAX = 10
OnMouseWheel = function(x_scroll, y_scroll)
    scale = math.clamp(scale + ZOOM_SPEED * y_scroll, ZOOM_MIN, ZOOM_MAX)
end

try_load_file = function(path)
    local f = io.open(path)
    if not f then return false end
    local center = Vector2(window_width/2, window_height/2);
    for pos, radius in TextRenderer.svg_iter_circles(assert(f:read("*a"))) do
        table.insert(circles, Circle:New(pos, radius))
    end
    f:close()
    return true
end

try_load_file(SVGEDITOR.FILE)

LockTable(_G)
