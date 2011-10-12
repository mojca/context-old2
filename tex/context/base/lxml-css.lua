if not modules then modules = { } end modules ['lxml-css'] = {
    version   = 1.001,
    comment   = "companion to lxml-css.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

local tonumber, rawset = tonumber, rawset
local lower, format = string.lower, string.format
local P, S, C, R, Cb, Cg, Carg, Ct, Cc, Cf = lpeg.P, lpeg.S, lpeg.C, lpeg.R, lpeg.Cb, lpeg.Cg, lpeg.Carg, lpeg.Ct, lpeg.Cc, lpeg.Cf
local lpegmatch, lpegpatterns = lpeg.match, lpeg.patterns

xml.css            = xml.css or { }
local css          = xml.css

local dimenfactors = number.dimenfactors
local bpf          = 1/dimenfactors.bp
local cmf          = 1/dimenfactors.cm
local mmf          = 1/dimenfactors.mm
local inf          = 1/dimenfactors["in"]

local validdimen = Cg(lpegpatterns.number,'a') * (
        Cb('a') * P("pt")           / function(s)     return tonumber(s) * bpf end
      + Cb('a') * P("cm")           / function(s)     return tonumber(s) * cmf end
      + Cb('a') * P("mm")           / function(s)     return tonumber(s) * mmf end
      + Cb('a') * P("in")           / function(s)     return tonumber(s) * inf end
      + Cb('a') * P("px") * Carg(1) / function(s,pxf) return tonumber(s) * pxf end
      + Cb('a') * P("%")  * Carg(2) / function(s,pcf) return tonumber(s) * pcf end
      + Cb('a') * P("ex") * Carg(3) / function(s,exf) return tonumber(s) * exf end
      + Cb('a') * P("em") * Carg(4) / function(s,emf) return tonumber(s) * emf end
      + Cb('a')           * Carg(1) / function(s,pxf) return tonumber(s) * pxf end
    )

local pattern = (validdimen * lpegpatterns.whitespace^0)^1

-- todo: default if ""

local function padding(str,pixel,percent,exheight,emwidth)
    local top, bottom, left, right = lpegmatch(pattern,str,1,pixel,percent,exheight,emwidth)
    if not bottom then
        bottom, left, right = top, top, top
    elseif not left then
        bottom, left, right = top, bottom, bottom
    elseif not right then
        bottom, left, right = left, bottom, bottom
    end
    return top, bottom, left, right
end

css.padding = padding

-- local hsize    = 655360*100
-- local exheight = 65536*4
-- local emwidth  = 65536*10
-- local pixel    = emwidth/100
--
-- print(padding("10px",pixel,hsize,exheight,emwidth))
-- print(padding("10px 20px",pixel,hsize,exheight,emwidth))
-- print(padding("10px 20px 30px",pixel,hsize,exheight,emwidth))
-- print(padding("10px 20px 30px 40px",pixel,hsize,exheight,emwidth))
--
-- print(padding("10%",pixel,hsize,exheight,emwidth))
-- print(padding("10% 20%",pixel,hsize,exheight,emwidth))
-- print(padding("10% 20% 30%",pixel,hsize,exheight,emwidth))
-- print(padding("10% 20% 30% 40%",pixel,hsize,exheight,emwidth))
--
-- print(padding("10",pixel,hsize,exheight,emwidth))
-- print(padding("10 20",pixel,hsize,exheight,emwidth))
-- print(padding("10 20 30",pixel,hsize,exheight,emwidth))
-- print(padding("10 20 30 40",pixel,hsize,exheight,emwidth))
--
-- print(padding("10pt",pixel,hsize,exheight,emwidth))
-- print(padding("10pt 20pt",pixel,hsize,exheight,emwidth))
-- print(padding("10pt 20pt 30pt",pixel,hsize,exheight,emwidth))
-- print(padding("10pt 20pt 30pt 40pt",pixel,hsize,exheight,emwidth))

-- local currentfont  = font.current
-- local texdimen     = tex.dimen
-- local hashes       = fonts.hashes
-- local quads        = hashes.quads
-- local xheights     = hashes.xheights
--
-- local function padding(str)
--     local font     = currentfont()
--     local exheight = xheights[font]
--     local emwidth  = quads[font]
--     local hsize    = texdimen.hsize/100
--     local pixel    = emwidth/100
--     return padding(str,pixel,hsize,exheight,emwidth)
-- end
--
-- function css.simplepadding(str)
--     context("%ssp",padding(str,pixel,hsize,exheight,emwidth))
-- end

local pattern = Cf( Ct("") * (
    Cg(
        Cc("style")   * (
            C("italic")
          + C("oblique")
          + C("slanted") / "oblique"
        )
      + Cc("variant") * (
            (C("smallcaps") + C("caps")) / "small-caps"
        )
      + Cc("weight")  *
            C("bold")
      + Cc("family")  * (
            (C("mono") + C("type")) / "monospace"       -- just ignore the "space(d)"
          + (C("sansserif") + C("sans")) / "sans-serif" -- match before serif
          + C("serif")
        )
    ) + P(1)
)^0 , rawset)

function css.fontspecification(str)
    return str and lpegmatch(pattern,lower(str))
end

function css.colorspecification(str)
    local c = str and attributes.colors.values[tonumber(str)]
    return c and format("rgb(%s%%,%s%%,%s%%)",c[3]*100,c[4]*100,c[5]*100)
end
