--[[
Start a local HTTP server.
Tweaking can be done on a web browser over the network!
]]

local server = {}

local config_html = ""
local tweak

local index = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bubbl</title>
  <script src="main.js" defer></script>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <button id="reload">Hot Reload</button>
  <div id="module-tweaks">
    %s
  </div>
</body>
</html>
]]

local port = 3636

local http_server = require "http.server"
local http_headers = require "http.headers"

local BuildHeaders = function (stream, status, content_type, close)
    if close == nil then close = false end

    local res_headers = http_headers.new()
    res_headers:append(":status", tostring(status))
    res_headers:append("content-type", content_type)

    assert(stream:write_headers(res_headers, close))
end

local BuildConfigItem = function (var)
    if var.type == "range" then
        return (string.gsub([[<div>
            <label for="$id">$name</label></div>
            <input type="range" id="$id" name="$id" min="$min" max="$max" value="$value" step="$step" class="config">
        ]], "%$(%w+)", {
            id=var.id,
            min=var.min,
            max=var.max,
            name=var.name,
            value=var.default or tweak.vars[var.id],
            step=var.step or "any",
        }))

    elseif var.type == "action" then
        return (string.gsub([[<div>
            <button type="button" id="$id" class="config">$name</button>
        ]], "%$(%w+)", var))
    end
    return "??"
end

local ConfigHtml = function ()
    local items = {}
    for i,v in ipairs(tweak) do
        table.insert(items, BuildConfigItem(v))
    end
    return table.concat(items)
end

local function reply(myserver, stream) -- luacheck: ignore 212
    -- Read in headers
    local req_headers = assert(stream:get_headers())
    local req_method = req_headers:get ":method"

    local path = req_headers:get(":path") or ""
    if false then
        -- Log request to stdout
        assert(io.stdout:write(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s"\n',
        os.date("%d/%b/%Y:%H:%M:%S %z"),
        req_method or "",
        path,
        stream.connection.version,
        req_headers:get("referer") or "-",
        req_headers:get("user-agent") or "-"
        )))
    end

    if path == "/" then
        BuildHeaders(stream, 200, "text/html")
        local content = string.format(index, ConfigHtml())
        assert(stream:write_chunk(content, true))

    elseif path == "/main.js" then
        BuildHeaders(stream, 200, "text/javascript")
        assert(stream:write_body_from_file(assert(io.open("./web"..path))))

    elseif path == "/style.css" then
        BuildHeaders(stream, 200, "text/css")
        assert(stream:write_body_from_file(assert(io.open("./web"..path))))


    elseif path == "/api/tweak" and req_method == "POST" then
        -- Get data
        local body = stream:get_body_as_string(0.01)

        local id, value = body:match("^([_%w]+)=(.+)$")
        if not id then
            BuildHeaders(stream, 300, "text/plain", true)
            error("could not parse body format")
        end

        local number = tonumber(value)
        if number then
            BuildHeaders(stream, 200, "text/plain", true)
            assert(tweak[id], "received unknown config var id")
            if tweak.vars[id] then
                tweak.vars[id] = number
            end
            if tweak[id].callback then
                tweak[id].callback(number)
            end
        end

    elseif path == "/api/action" and req_method == "POST" then
        BuildHeaders(stream, 200, "text/plain", true)
        local loader = require "loader"
        local id = stream:get_body_as_string(0.01)
        assert(tweak[id], "received unknown action var id")
        local callback = assert(tweak[id].callback, "action missing callback")
        callback()

    elseif path == "/action/reload" and req_method == "POST" then
        BuildHeaders(stream, 200, "text/plain", true)
        local loader = require "loader"
        loader.HotReload()

    else
        BuildHeaders(stream, 404, "text/html")
        assert(stream:write_chunk("Error 404"))
    end

end

local myserver = assert(http_server.listen {
    host = "0.0.0.0";
    port = port;
    onstream = reply;
    onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
        local msg = op .. " on " .. tostring(context) .. " failed"
        if err then
            msg = msg .. ": " .. tostring(err)
        end
        assert(io.stderr:write(msg, "\n"))
    end;
})

local onstart = function ()
    local bound_port = select(3, myserver:localname())
    assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end
local started = false

function server:update()
    myserver:step(0.01)
    if not started then
        started = true
        onstart()
    end
end

function server:close()
    myserver:close()
end

function server:MakeConfig(_tweak)
    tweak = _tweak
    for i,v in ipairs(tweak) do
        -- use tweak as hash map too
        tweak[v.id] = v
    end
end

return server
