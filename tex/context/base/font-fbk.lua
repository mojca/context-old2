if not modules then modules = { } end modules ['font-fbk'] = {
    version   = 1.001,
    comment   = "companion to font-ini.tex",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

--[[ldx--
<p>This is very experimental code!</p>
--ldx]]--

fonts.fallbacks            = fonts.fallbacks or { }
fonts.vf.aux.combine.trace = false

local vf  = fonts.vf
local tfm = fonts.tfm

vf.aux.combine.commands["enable-tracing"] = function(g,v)
    vf.aux.combine.trace = true
end

vf.aux.combine.commands["disable-tracing"] = function(g,v)
    vf.aux.combine.trace = false
end

vf.aux.combine.commands["set-tracing"] = function(g,v)
    if v[2] == nil then
        vf.aux.combine.trace = true
    else
        vf.aux.combine.trace = v[2]
    end
end

function vf.aux.combine.initialize_trace()
    if vf.aux.combine.trace then
        return "special", "pdf: .8 0 0 rg .8 0 0 RG", "pdf: 0 .8 0 rg 0 .8 0 RG", "pdf: 0 0 .8 rg 0 0 .8 RG", "pdf: 0 g 0 G"
    else
        return "comment", "", "", "", ""
    end
end

vf.aux.combine.force_fallback = false

vf.aux.combine.commands["fake-character"] = function(g,v) -- g, nr, fallback_id
    local index, fallback = v[2], v[3]
    if vf.aux.combine.force_fallback or not g.characters[index] then
        if fonts.fallbacks[fallback] then
            g.characters[index] = fonts.fallbacks[fallback](g)
        end
    end
end

fonts.fallbacks['textcent'] = function (g)
    local c = string.byte("c")
    local t = table.fastcopy(g.characters[c])
    local s = tfm.scaled(g.specification.size or g.size)
    local a = - math.tan(math.rad(g.italicangle or 0))
    local special, red, green, blue, black = vf.aux.combine.initialize_trace()
    if a == 0 then
        t.commands = {
            {"push"}, {"slot", 1, c}, {"pop"},
            {"right", .5*t.width},
            {"down",  .2*t.height},
            {special, green},
            {"rule", 1.4*t.height, .02*s},
            {special, black},
        }
    else
        t.commands = {
            {"push"},
            {"right", .5*t.width-.025*s},
            {"down",  .2*t.height},
            {"special",string.format("pdf: q 1 0 %s 1 0 0 cm",a)},
            {special, green},
            {"rule", 1.4*t.height, .025*s},
            {special, black},
            {"special","pdf: Q"},
            {"pop"},
            {"slot", 1, c} -- last else problems with cm
        }
    end
    -- somehow the width is messed up now
    -- todo: set height
    t.height = 1.2*t.height
    t.depth  = 0.2*t.height
    return t
end

fonts.fallbacks['texteuro'] = function (g)
    local c = string.byte("C")
    local t = table.fastcopy(g.characters[c])
    local s = tfm.scaled(g.specification.size or g.size)
    local d = math.cos(math.rad(90+(g.italicangle)))
    local special, red, green, blue, black = vf.aux.combine.initialize_trace()
    t.width = 1.05*t.width
    t.commands = {
        {"right", .05*t.width},
        {"push"}, {"slot", 1, c}, {"pop"},
        {"right", .5*t.width*d},
        {"down", -.5*t.height},
        {special, green},
        {"rule", .05*s, .4*s},
        {special, black},
    }
    return t
end

-- maybe store llx etc instead of bbox in tfm blob / more efficient

vf.aux.combine.force_composed = false

function vf.aux.compose_characters(g) -- todo: scaling depends on call location
    -- this assumes that slot 1 is self, there will be a proper self some day
    local chars = g.characters
    local fastcopy = table.fastcopy
    local xchar = chars[string.byte("X")]
    if xchar and xchar.description then
        local cap_lly = xchar.description.boundingbox[4]
        local ita_cor = math.cos(math.rad(90+(g.italicangle or 0)))
        local force = vf.aux.combine.force_composed
        local fallbacks = characters.fallbacks
        local special, red, green, blue, black = vf.aux.combine.initialize_trace()
        red, green, blue, black = { special, red }, { special, green }, { special, blue }, { special, black }
        local push, pop = { "push" }, { "pop" }
        local trace = vf.aux.combine.trace -- saves mem
        for i,c in pairs(characters.data) do
            if force or not chars[i] then
                local s = c.specials
                if s and s[1] == 'char' then
                    local chr = s[2]
                    local charschr = chars[chr]
                    if charschr then
                        local cc = c.category
                        if cc == 'll' or cc == 'lu' or cc == 'lt' then
                            local acc = s[3]
                         -- local t = fastcopy(charschr) -- mem hogg but we cannot share
                            local t = { }
                            for k, v in pairs(charschr) do
                                if k == "commands" then
                                    -- skip
                                elseif k == "description" then
                                    local d = { }
                                    for kk, vv in pairs(v) do
                                        d[kk] = vv
                                    end
                                    t.description = d
                                else
                                    t[k] = v
                                end
                            end
                            local d = t.description
                            d.name = c.adobename or "unknown"
                            d.unicode = i
                            local charsacc = chars[acc]
                            if not charsacc then
                                acc = fallbacks[acc]
                                charsacc = acc and chars[acc]
                            end
                            if charsacc then
                                local cb = charschr.description.boundingbox
                                local ab = charsacc.description.boundingbox
                                if cb and ab then
                                    local c_llx, c_lly, c_urx, c_ury = cb[1], cb[2], cb[3], cb[4]
                                    local a_llx, a_lly, a_urx, a_ury = ab[1], ab[2], ab[3], ab[4]
                                    local dx = (c_urx - a_urx - a_llx + c_llx)/2
                                    local dd = (c_urx-c_llx)*ita_cor
                                    -- we can use predefined tables for { special, red } ... saves space
                                    if a_ury < 0  then
                                        local dy = cap_lly-a_lly
                                        if trace then
                                            t.commands = {
                                                push,
                                                {"right", dx-dd},
                                                {"down", -dy}, -- added
                                                red,
                                                {"slot", 1, acc},
                                                black,
                                                pop,
                                                {"slot", 1, chr},
                                            }
                                        else
                                            t.commands = {
                                                push,
                                                {"right", dx-dd},
                                                {"down", -dy}, -- added
                                                {"slot", 1, acc},
                                                pop,
                                                {"slot", 1, chr},
                                            }
                                        end
                                    elseif c_ury > a_lly then
                                        local dy = cap_lly-a_lly
                                        if trace then
                                            t.commands = {
                                                push,
                                                {"right", dx+dd},
                                                {"down", -dy},
                                                green,
                                                {"slot", 1, acc},
                                                black,
                                                pop,
                                                {"slot", 1, chr},
                                            }
                                        else
                                            t.commands = {
                                                push,
                                                {"right", dx+dd},
                                                {"down", -dy},
                                                {"slot", 1, acc},
                                                pop,
                                                {"slot", 1, chr},
                                            }
                                        end
                                    else
                                        if trace then
                                            t.commands = {
                                                {"push"},
                                                {"right", dx+dd},
                                                blue,
                                                {"slot", 1, acc},
                                                black,
                                                {"pop"},
                                                {"slot", 1, chr},
                                            }
                                        else
                                            t.commands = {
                                                {"push"},
                                                {"right", dx+dd},
                                                {"slot", 1, acc},
                                                {"pop"},
                                                {"slot", 1, chr},
                                            }
                                        end
                                    end
                                end
                            end
                            chars[i] = t
                        end
                    end
                end
            end
        end
    end
end

vf.aux.combine.commands["complete-composed-characters"] = function(g,v)
    vf.aux.compose_characters(g)
end

--~         {'special', 'pdf: q ' .. s .. ' 0 0 '.. s .. ' 0 0 cm'},
--~         {'special', 'pdf: q 1 0 0 1 ' .. -w .. ' ' .. -h .. ' cm'},
--~     --  {'special', 'pdf: /Fm\XX\space Do'},
--~         {'special', 'pdf: Q'},
--~         {'special', 'pdf: Q'},

-- for documentation purposes we provide:

fonts.define.methods.install("fallback", { -- todo: auto-fallback with loop over data.characters
    { "fake-character", 0x00A2, 'textcent' },
    { "fake-character", 0x20AC, 'texteuro' }
})

vf.aux.combine.commands["enable-force"] = function(g,v)
    vf.aux.combine.force_composed = true
    vf.aux.combine.force_fallback = true
end
vf.aux.combine.commands["disable-force"] = function(g,v)
    vf.aux.combine.force_composed = false
    vf.aux.combine.force_fallback = false
end

fonts.define.methods.install("demo-2", {
    { "enable-tracing" },
    { "enable-force" },
    { "initialize" },
    { "include-method", "fallback" },
    { "complete-composed-characters" },
    { "disable-tracing" },
    { "disable-force" },
})

fonts.define.methods.install("demo-3", {
    { "enable-tracing" },
    { "initialize" },
    { "complete-composed-characters" },
    { "disable-tracing" },
})
