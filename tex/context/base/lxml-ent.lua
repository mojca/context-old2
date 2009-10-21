if not modules then modules = { } end modules ['lxml-ent'] = {
    version   = 1.001,
    comment   = "this module is the basis for the lxml-* ones",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local type, next, tonumber =  type, next, tonumber
local texsprint, ctxcatcodes = tex.sprint, tex.ctxcatcodes
local utf = unicode.utf8
local byte, format = string.byte, string.format
local utfupper, utfchar = utf.upper, utf.char

--[[ldx--
<p>We provide (at least here) two entity handlers. The more extensive
resolver consults a hash first, tries to convert to <l n='utf'/> next,
and finaly calls a handler when defines. When this all fails, the
original entity is returned.</p>

<p>We do things different now but it's still somewhat experimental</p>
--ldx]]--

xml.entities = xml.entities or { } -- xml.entity_handler == function

-- experimental, this will be done differently

local parsedentity = xml.parsedentitylpeg

function xml.merge_entities(root)
    local documententities = root.entities
    local allentities = xml.entities
    if documententities then
        for k, v in next, documententities do
            allentities[k] = v
        end
    end
end

function xml.resolved_entity(str)
    local e = xml.entities[str]
    if e then
        local te = type(e)
        if te == "function" then
            e(str)
        elseif e then
            texsprint(ctxcatcodes,e)
        end
    else
        -- resolve hex and dec, todo: escape # & etc for ctxcatcodes
        -- normally this is already solved while loading the file
        local chr, err = parsedentity:match(str)
        if chr then
            texsprint(ctxcatcodes,chr)
        elseif err then
            texsprint(ctxcatcodes,err)
        else
            texsprint(ctxcatcodes,"\\xmle{",str,"}{",utfupper(str),"}") -- we need to use our own upper
        end
    end
end

xml.entities.amp = function() tex.write("&") end
xml.entities.lt  = function() tex.write("<") end
xml.entities.gt  = function() tex.write(">") end
