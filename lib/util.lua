local http = require("http")
local html = require("html")

local util = {}

util.__index = util
local utilSingleton = setmetatable({}, util)

utilSingleton.BASE_URL = "https://cmake.org/files/"
utilSingleton.RELEASES ={}

function util:compare_versions(v1o, v2o)
    local v1 = v1o.version
    local v2 = v2o.version
    local v1_parts = {}
    for part in string.gmatch(v1, "[^.]+") do
        table.insert(v1_parts, tonumber(part))
    end

    local v2_parts = {}
    for part in string.gmatch(v2, "[^.]+") do
        table.insert(v2_parts, tonumber(part))
    end

    for i = 1, math.max(#v1_parts, #v2_parts) do
        local v1_part = v1_parts[i] or 0
        local v2_part = v2_parts[i] or 0
        if v1_part > v2_part then
            return true
        elseif v1_part < v2_part then
            return false
        end
    end

    return false
end

function util:getInfo()
    local resp, err = http.get({
        url = utilSingleton.BASE_URL
    })
    if err ~= nil or resp.status_code ~= 200 then
        error("paring release info failed." .. err)
    end
    local bigVersionUrl = {}
    html.parse(resp.body):find("a"):each(function(i, selection)
        local href = selection:attr("href")
        local sn = string.match(href, "^v%d")
        local es = string.match(href, "/$")
        local version = string.sub(href, 1, -2)
        if sn and es then
            if util:compare_versions({version=string.gsub(version, "^v", "")},{version="3.0"}) then
                table.insert(bigVersionUrl, utilSingleton.BASE_URL..version)
            end
        end
    end)

    local pattern = "cmake%-(%d+%.%d+%.?%d*%-?%a*%d*)%-([%a%d]+)%-([%a%d_%-]+)"
    local result = {}
    for _, url in ipairs(bigVersionUrl) do
        local resp, err = http.get({
            url = url
        })
        if err ~= nil or resp.status_code ~= 200 then
            error("paring release info failed." .. err)
        end

        html.parse(resp.body):find("a"):each(function(i, selection)
            local href = selection:attr("href")
            local sn = string.match(href, "^cmake")
            local es = string.match(href, "txt$")
            if sn and es then
                local resp, err = http.get({
                    url = url.."/"..href
                })
                if err ~= nil or resp.status_code ~= 200 then
                    error("paring release info failed." .. err)
                end
                local sha256Files = {}

                for line in resp.body:gmatch("[^\n]+") do
                    table.insert(sha256Files, line)
                end

                for _, str in ipairs(sha256Files) do
                    if util:isMatched(str) then
                    local sha256, filename = string.match(str, "(%w+)%s+(%S+)")
                    local version, os, arch = string.match(filename, pattern)
                    if version and os and arch then
                        os = string.lower(os)
                        arch = string.lower(arch)
                        local downloadUrl = url.."/"..filename
                       
                        if RUNTIME.osType=="darwin" then
                            if RUNTIME.archType=="amd64" and (arch=="x86_64" or arch=="x64") then
                                table.insert(result,{version=version,note=""})
                                table.insert(utilSingleton.RELEASES,{version=version,url=downloadUrl,sha256=sha256})
                            elseif arch=="universal" then
                                table.insert(result,{version=version,note=""})
                                table.insert(utilSingleton.RELEASES,{version=version,url=downloadUrl,sha256=sha256})
                            end
                        elseif RUNTIME.osType == "windows"  then
                            if RUNTIME.archType=="amd64" and (arch =="x64" or arch =="x86_64")then
                                table.insert(result,{version=version,note=""})
                                table.insert(utilSingleton.RELEASES,{version=version,url=downloadUrl,sha256=sha256})
                            elseif RUNTIME.archType=="386" and (arch =="i386" or arch =="x86") then
                                table.insert(result,{version=version,note=""})
                                table.insert(utilSingleton.RELEASES,{version=version,url=downloadUrl,sha256=sha256})
                            elseif RUNTIME.archType=="arm64" then
                                table.insert(result,{version=version,note=""})
                                table.insert(utilSingleton.RELEASES,{version=version,url=downloadUrl,sha256=sha256})
                            end
                        elseif RUNTIME.osType == "linux" then
                            if RUNTIME.archType=="386" and (arch =="i386" or arch =="aarch64") then
                                table.insert(result,{version=version,note=""})
                                table.insert(utilSingleton.RELEASES,{version=version,url=downloadUrl,sha256=sha256})
                            elseif RUNTIME.archType=="amd64" and arch =="x86_64" then
                                table.insert(result,{version=version,note=""})
                                table.insert(utilSingleton.RELEASES,{version=version,url=downloadUrl,sha256=sha256})
                              end
                        end
                    end
                    end
                end
            end
        end)
    end
    table.sort(result, function(a, b)
        return util:compare_versions(a,b)
    end)
    return result
end

function util:isMatched(str)
    str =  string.lower(str)
    if RUNTIME.osType == "windows" then
        return (string.find(str, "windows") or
                string.find(str, "win32") or
                string.find(str, "win64") ) and
                (string.find(str, "%.zip$"))
    elseif RUNTIME.osType == "linux" then
        return string.find(str, "linux") and string.find(str, "%.tar%.gz$")

    elseif  RUNTIME.osType == "darwin" then
        return (string.find(str, "macos") or string.find(str, "darwin")) and string.find(str, "%.tar%.gz$")
    end
end

return utilSingleton