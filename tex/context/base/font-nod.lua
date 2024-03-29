if not modules then modules = { } end modules ['font-nod'] = {
    version   = 1.001,
    comment   = "companion to font-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is rather experimental. We need more control and some of this
might become a runtime module instead. This module will be cleaned up!</p>
--ldx]]--

local tonumber, tostring = tonumber, tostring
local utfchar = utf.char
local concat = table.concat
local match, gmatch, concat, rep = string.match, string.gmatch, table.concat, string.rep

local report_nodes = logs.reporter("fonts","tracing")

fonts = fonts or { }
nodes = nodes or { }

local fonts, nodes, node, context = fonts, nodes, node, context

local tracers          = nodes.tracers or { }
nodes.tracers          = tracers

local tasks            = nodes.tasks or { }
nodes.tasks            = tasks

local handlers         = nodes.handlers or { }
nodes.handlers         = handlers

local injections       = nodes.injections or { }
nodes.injections       = injections

local char_tracers     = tracers.characters or { }
tracers.characters     = char_tracers

local step_tracers     = tracers.steppers or { }
tracers.steppers       = step_tracers

local nodecodes        = nodes.nodecodes
local whatcodes        = nodes.whatcodes

local glyph_code       = nodecodes.glyph
local hlist_code       = nodecodes.hlist
local vlist_code       = nodecodes.vlist
local disc_code        = nodecodes.disc
local glue_code        = nodecodes.glue
local kern_code        = nodecodes.kern
local rule_code        = nodecodes.rule
local whatsit_code     = nodecodes.whatsit

local localpar_code    = whatcodes.localpar
local dir_code         = whatcodes.dir

local nuts             = nodes.nuts
local tonut            = nuts.tonut
local tonode           = nuts.tonode

local getfield         = nuts.getfield
local setfield         = nuts.setfield
local getnext          = nuts.getnext
local getprev          = nuts.getprev
local getid            = nuts.getid
local getfont          = nuts.getfont
local getsubtype       = nuts.getsubtype
local getchar          = nuts.getchar
local getlist          = nuts.getlist
local setbox           = nuts.setbox

local copy_node_list   = nuts.copy_list
local hpack_node_list  = nuts.hpack
local free_node_list   = nuts.flush_list
local traverse_nodes   = nuts.traverse
local protect_glyphs   = nuts.protect_glyphs

local nodepool         = nuts.pool
local new_glyph        = nodepool.glyph

local formatters       = string.formatters
local formatter        = string.formatter

local hashes           = fonts.hashes

local fontidentifiers  = hashes.identifiers
local fontdescriptions = hashes.descriptions
local fontcharacters   = hashes.characters
local fontproperties   = hashes.properties
local fontparameters   = hashes.parameters

function char_tracers.collect(head,list,tag,n)
    head = tonut(head)
    n = n or 0
    local ok, fn = false, nil
    while head do
        local id = getid(head)
        if id == glyph_code then
            local f = getfont(head)
            if f ~= fn then
                ok, fn = false, f
            end
            local c = getchar(head)
         -- local i = fontidentifiers[f].indices[c] or 0 -- zero anyway as indices is nilled
            if not ok then
                ok = true
                n = n + 1
                list[n] = list[n] or { }
                list[n][tag] = { }
            end
            local l = list[n][tag]
         -- l[#l+1] = { c, f, i }
            l[#l+1] = { c, f }
        elseif id == disc_code then
            -- skip
        else
            ok = false
        end
        head = getnext(head)
    end
end

function char_tracers.equal(ta, tb)
    if #ta ~= #tb then
        return false
    else
        for i=1,#ta do
            local a, b = ta[i], tb[i]
         -- if a[1] ~= b[1] or a[2] ~= b[2] or a[3] ~= b[3] then
            if a[1] ~= b[1] or a[2] ~= b[2] then
                return false
            end
        end
    end
    return true
end

function char_tracers.string(t)
    local tt = { }
    for i=1,#t do
        tt[i] = utfchar(t[i][1])
    end
    return concat(tt,"")
end

local f_unicode = formatters["%U"]

function char_tracers.unicodes(t,decimal)
    local tt = { }
    for i=1,#t do
        local n = t[i][1]
        if n == 0 then
            tt[i] = "-"
        elseif decimal then
            tt[i] = n
        else
            tt[i] = f_unicode(n)
        end
    end
    return concat(tt," ")
end

-- function char_tracers.indices(t,decimal)
--     local tt = { }
--     for i=1,#t do
--         local n = t[i][3]
--         if n == 0 then
--             tt[i] = "-"
--         elseif decimal then
--             tt[i] = n
--         else
--             tt[i] = f_unicode(n)
--         end
--     end
--     return concat(tt," ")
-- end

function char_tracers.start()
    local npc = handlers.characters -- should accept nuts too
    local list = { }
    function handlers.characters(head)
        local n = #list
        char_tracers.collect(head,list,'before',n)
        local h, d = npc(tonode(head)) -- for the moment tonode
        char_tracers.collect(head,list,'after',n)
        if #list > n then
            list[#list+1] = { }
        end
        return h, d
    end
    function char_tracers.stop()
        tracers.list['characters'] = list
        local variables = {
            ['title']                = 'ConTeXt Character Processing Information',
            ['color-background-one'] = lmx.get('color-background-yellow'),
            ['color-background-two'] = lmx.get('color-background-purple'),
        }
        lmx.show('context-characters.lmx',variables)
        handlers.characters = npc
        tasks.restart("processors", "characters")
    end
    tasks.restart("processors", "characters")
end

local stack = { }

function tracers.start(tag)
    stack[#stack+1] = tag
    local tracer = tracers[tag]
    if tracer and tracer.start then
        tracer.start()
    end
end
function tracers.stop()
    local tracer = stack[#stack]
    if tracer and tracer.stop then
        tracer.stop()
    end
    stack[#stack] = nil
end

-- experimental

local collection, collecting, messages = { }, false, { }

function step_tracers.start()
    collecting = true
end

function step_tracers.stop()
    collecting = false
end

function step_tracers.reset()
    for i=1,#collection do
        local c = collection[i]
        if c then
            free_node_list(c)
        end
    end
    collection, messages = { }, { }
end

function step_tracers.nofsteps()
    return context(#collection)
end

function step_tracers.glyphs(n,i)
    local c = collection[i]
    if c then
        local b = hpack_node_list(copy_node_list(c)) -- multiple arguments
        setbox(n,b)
    end
end

function step_tracers.features()
    -- we cannot use first_glyph here as it only finds characters with subtype < 256
    local f = collection[1]
    while f do
        if getid(f) == glyph_code then
            local tfmdata, t = fontidentifiers[getfont(f)], { }
            for feature, value in table.sortedhash(tfmdata.shared.features) do
                if feature == "number" or feature == "features" then
                    -- private
                elseif type(value) == "boolean" then
                    if value then
                        t[#t+1] = formatters["%s=yes"](feature)
                    else
                        -- skip
                    end
                else
                    t[#t+1] = formatters["%s=%s"](feature,value)
                end
            end
            if #t > 0 then
                context(concat(t,", "))
            else
                context("no features")
            end
            return
        end
        f = getnext(f)
    end
end

function tracers.fontchar(font,char)
    local n = new_glyph()
    setfield(n,"font",font)
    setfield(n,"char",char)
    setfield(n,"subtype",256)
    context(tonode(n))
end

function step_tracers.font(command)
    local c = collection[1]
    while c do
        local id = getid(c)
        if id == glyph_code then
            local font = getfont(c)
            local name = file.basename(fontproperties[font].filename or "unknown")
            local size = fontparameters[font].size or 0
            if command then
                context[command](font,name,size) -- size in sp
            else
                context("[%s: %s @ %p]",font,name,size)
            end
            return
        else
            c = getnext(c)
        end
    end
end

function step_tracers.codes(i,command)
    local c = collection[i]
    while c do
        local id = getid(c)
        if id == glyph_code then
            if command then
                local f, c = getfont(c), getchar(c)
                local d = fontdescriptions[f]
                local d = d and d[c]
                context[command](f,c,d and d.class or "")
            else
                context("[%s:U+%04X]",getfont(c),getchar(c))
            end
        elseif id == whatsit_code and (getsubtype(c) == localpar_code or getsubtype(c) == dir_code) then
            context("[%s]",getfield(c,"dir"))
        else
            context("[%s]",nodecodes[id])
        end
        c = getnext(c)
    end
end

function step_tracers.messages(i,command,split)
    local list = messages[i] -- or { "no messages" }
    if list then
        for i=1,#list do
            local l = list[i]
            if not command then
                context("(%s)",l)
            elseif split then
                local a, b = match(l,"^(.-)%s*:%s*(.*)$")
                context[command](a or l or "",b or "")
            else
                context[command](l)
            end
        end
    end
end

-- hooks into the node list processor (see otf)

function step_tracers.check(head)
    if collecting then
        step_tracers.reset()
        local n = copy_node_list(tonut(head))
        injections.handler(n,nil,"trace",true)
     -- handlers.protectglyphs(n) -- can be option
        protect_glyphs(n)
        collection[1] = n
    end
end

function step_tracers.register(head)
    if collecting then
        local nc = #collection+1
        if messages[nc] then
            local n = copy_node_list(tonut(head))
            injections.handler(n,nil,"trace",true)
         -- handlers.protectglyphs(n) -- can be option
            protect_glyphs(n)
            collection[nc] = n
        end
    end
end

function step_tracers.message(str,...)
    str = formatter(str,...)
    if collecting then
        local n = #collection + 1
        local m = messages[n]
        if not m then m = { } messages[n] = m end
        m[#m+1] = str
    end
    return str -- saves an intermediate var in the caller
end

--

local threshold = 65536

local function toutf(list,result,nofresult,stopcriterium)
    if list then
        for n in traverse_nodes(tonut(list)) do
            local id = getid(n)
            if id == glyph_code then
                local components = getfield(n,"components")
                if components then
                    result, nofresult = toutf(components,result,nofresult)
                else
                    local c = getchar(n)
                    local fc = fontcharacters[getfont(n)]
                    if fc then
                        local fcc = fc[c]
                        if fcc then
                            local u = fcc.unicode
                            if not u then
                                nofresult = nofresult + 1
                                result[nofresult] = utfchar(c)
                            elseif type(u) == "table" then
                                for i=1,#u do
                                    nofresult = nofresult + 1
                                    result[nofresult] = utfchar(u[i])
                                end
                            else
                                nofresult = nofresult + 1
                                result[nofresult] = utfchar(u)
                            end
                        else
                            nofresult = nofresult + 1
                            result[nofresult] = utfchar(c)
                        end
                    else
                        nofresult = nofresult + 1
                        result[nofresult] = f_unicode(c)
                    end
                end
            elseif id == disc_code then
                result, nofresult = toutf(getfield(n,"replace"),result,nofresult) -- needed?
            elseif id == hlist_code or id == vlist_code then
             -- if nofresult > 0 and result[nofresult] ~= " " then
             --     nofresult = nofresult + 1
             --     result[nofresult] = " "
             -- end
                result, nofresult = toutf(getlist(n),result,nofresult)
            elseif id == glue_code then
                if nofresult > 0 and result[nofresult] ~= " " then
                    nofresult = nofresult + 1
                    result[nofresult] = " "
                end
            elseif id == kern_code and getfield(n,"kern") > threshold then
                if nofresult > 0 and result[nofresult] ~= " " then
                    nofresult = nofresult + 1
                    result[nofresult] = " "
                end
            end
            if n == stopcriterium then
                break
            end
        end
    end
    if nofresult > 0 and result[nofresult] == " " then
        result[nofresult] = nil
        nofresult = nofresult - 1
    end
    return result, nofresult
end

function nodes.toutf(list,stopcriterium)
    local result, nofresult = toutf(list,{},0,stopcriterium)
    return concat(result)
end
