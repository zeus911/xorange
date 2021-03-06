local type = type
local string_format = string.format
local string_find = string.find
local string_lower = string.lower
local ngx_re_find = ngx.re.find
local re_gmatch = ngx.re.gmatch

local function assert_condition(real, operator, expected)
    if not real then
        ngx.log(ngx.ERR, string_format("assert_condition error: %s %s %s", real, operator, expected))
        return false
    end

    if operator == 'match' then
        if ngx_re_find(real, expected, 'isjo') ~= nil then
            return true
        end
    elseif operator == 'not_match' then
        if ngx_re_find(real, expected, 'isjo') == nil then
            return true
        end
    elseif operator == "=" then
        if real == expected then
            return true
        end
    elseif operator == "!=" then
        if real ~= expected then
            return true
        end
    elseif operator == '>' then
        if real ~= nil and expected ~= nil then
            expected = tonumber(expected)
            real = tonumber(real)
            if real and expected and real > expected then
                return true
            end
        end
    elseif operator == '>=' then
        if real ~= nil and expected ~= nil then
            expected = tonumber(expected)
            real = tonumber(real)
            if real and expected and real >= expected then
                return true
            end
        end
    elseif operator == '<' then
        if real ~= nil and expected ~= nil then
            expected = tonumber(expected)
            real = tonumber(real)
            if real and expected and real < expected then
                return true
            end
        end
    elseif operator == '<=' then
        if real ~= nil and expected ~= nil then
            expected = tonumber(expected)
            real = tonumber(real)
            if real and expected and real <= expected then
                return true
            end
        end
    elseif operator == '%' then
        local mod_num = 0;
        local value = {}
        local idx = 1
        --expected like: 50|1,2,3
        local matchs = re_gmatch(expected, "(\\d+)", "jsio")
        for i in matchs do
            if idx == 1 then
                mod_num = tonumber(i[1])
            else
                value[i[1]] = true
            end
            idx = idx + 1
        end
        local mod_value = math.fmod(tonumber(real), mod_num)
        return value[tostring(mod_value)] == true;
    end

    return false
end


local _M = {}

function _M.judge(condition)
    local condition_type = condition and condition.type
    if not condition_type then
        return false
    end

    local operator = condition.operator
    local expected = condition.value
    if not operator or not expected then
        return false
    end

    local real

    if condition_type == "URI" then
        real = ngx.var.uri
    elseif condition_type == "Query" then
        local query = ngx.req.get_uri_args()
        real = query[condition.name]
    elseif condition_type == "Header" then
        local headers = ngx.req.get_headers()
        real = headers[condition.name]
    elseif condition_type == "Cookie" then
        local cookies = ngx.ctx.__cookies__
        if cookies then
            real = cookies:get(condition.name)
        end
    elseif condition_type == "IP" then
        real =  ngx.var.remote_addr
    elseif condition_type == "Random" then
        real = ngx.now() * 1000 % 100
    elseif condition_type == "UserAgent" then
        real =  ngx.var.http_user_agent
    elseif condition_type == "Method" then
        local method = ngx.req.get_method()
        method = string_lower(method)
        if not expected or type(expected) ~= "string" then
            expected = ""
        end
        expected = string_lower(expected)
        real = method
    elseif condition_type == "PostParams" then
        local headers = ngx.req.get_headers()
        local header = headers['Content-Type']
        if header then
            local is_multipart = string_find(header, "multipart")
            if is_multipart and is_multipart > 0 then
                return false
            end
        end

        ngx.req.read_body()
        local post_params, err = ngx.req.get_post_args()
        if not post_params or err then
            ngx.log(ngx.ERR, "[Condition Judge]failed to get post args: ", err)
            return false
        end

        real = post_params[condition.name]
    elseif condition_type == "Referer" then
        real =  ngx.var.http_referer
    elseif condition_type == "Host" then
        real =  ngx.var.host
    end

    return assert_condition(real, operator, expected)
end


return _M
