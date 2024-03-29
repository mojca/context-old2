if not modules then modules = { } end modules ['l-lua'] = {
    version   = 1.001,
    comment   = "companion to luat-lib.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- potential issues with 5.3:

-- i'm not sure yet if the int/float change is good for luatex

-- math.min
-- math.max
-- tostring
-- tonumber
-- utf.*
-- bit32

-- compatibility hacksand helpers

local major, minor = string.match(_VERSION,"^[^%d]+(%d+)%.(%d+).*$")

_MAJORVERSION = tonumber(major) or 5
_MINORVERSION = tonumber(minor) or 1
_LUAVERSION   = _MAJORVERSION + _MINORVERSION/10

-- lpeg

if not lpeg then
    lpeg = require("lpeg")
end

-- basics:

if loadstring then

    local loadnormal = load

    function load(first,...)
        if type(first) == "string" then
            return loadstring(first,...)
        else
            return loadnormal(first,...)
        end
    end

else

    loadstring = load

end

-- table:

-- At some point it was announced that i[pairs would be dropped, which makes
-- sense. As we already used the for loop and # in most places the impact on
-- ConTeXt was not that large; the remaining ipairs already have been replaced.
-- Hm, actually ipairs was retained, but we no longer use it anyway (nor
-- pairs).
--
-- Just in case, we provide the fallbacks as discussed in Programming
-- in Lua (http://www.lua.org/pil/7.3.html):

if not ipairs then

    -- for k, v in ipairs(t) do                ... end
    -- for k=1,#t            do local v = t[k] ... end

    local function iterate(a,i)
        i = i + 1
        local v = a[i]
        if v ~= nil then
            return i, v --, nil
        end
    end

    function ipairs(a)
        return iterate, a, 0
    end

end

if not pairs then

    -- for k, v in pairs(t) do ... end
    -- for k, v in next, t  do ... end

    function pairs(t)
        return next, t -- , nil
    end

end

-- The unpack function has been moved to the table table, and for compatiility
-- reasons we provide both now.

if not table.unpack then

    table.unpack = _G.unpack

elseif not unpack then

    _G.unpack = table.unpack

end

-- package:

-- if not package.seachers then
--
--     package.searchers = package.loaders -- 5.2
--
-- elseif not package.loaders then
--
--     package.loaders = package.searchers
--
-- end

if not package.loaders then -- brr, searchers is a special "loadlib function" userdata type

    package.loaders = package.searchers

end

-- moved from util-deb to here:

local print, select, tostring = print, select, tostring

local inspectors = { }

function setinspector(inspector) -- global function
    inspectors[#inspectors+1] = inspector
end

function inspect(...) -- global function
    for s=1,select("#",...) do
        local value = select(s,...)
        local done = false
        for i=1,#inspectors do
            done = inspectors[i](value)
            if done then
                break
            end
        end
        if not done then
            print(tostring(value))
        end
    end
end

--

local dummy = function() end

function optionalrequire(...)
    local ok, result = xpcall(require,dummy,...)
    if ok then
        return result
    end
end

-- nice for non ascii scripts (this might move):

if lua then
    lua.mask = load([[τεχ = 1]]) and "utf" or "ascii"
end
