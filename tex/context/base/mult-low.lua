if not modules then modules = { } end modules ['mult-low'] = {
    version   = 1.001,
    comment   = "companion to mult-ini.mkiv",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- for syntax highlighters, only the ones that are for users (boring to collect them)

return {
    ["constants"] = {
        --
        "zerocount", "minusone", "minustwo", "plusone", "plustwo", "plusthree", "plusfour", "plusfive",
        "plussix", "plusseven", "pluseight", "plusnine", "plusten", "plussixteen", "plushundred",
        "plusthousand", "plustenthousand", "plustwentythousand", "medcard", "maxcard",
        "zeropoint", "onepoint", "onebasepoint", "maxdimen", "scaledpoint", "thousandpoint", "points",
        "zeroskip",
        "pluscxxvii", "pluscxxviii", "pluscclv", "pluscclvi",
        --
        "endoflinetoken", "outputnewlinechar",
        --
        "emptytoks", "empty", "undefined",
        --
        "voidbox", "emptybox", "emptyvbox", "emptyhbox",
        --
        "bigskipamount", "medskipamount", "smallskipamount",
        --
        "fmtname", "fmtversion", "texengine", "texenginename", "texengineversion",
        "luatexengine", "pdftexengine", "xetexengine", "unknownengine",
        "etexversion", "pdftexversion", "xetexversion", "xetexrevision",
        --
        "activecatcode",
        --
        "bgroup", "egroup",
        "endline",
        --
        "attributeunsetvalue",
        --
        "uprotationangle", "rightrotatioangle", "downrotatioangle", "leftrotatioangle",
        --
        "ctxcatcodes", "texcatcodes", "notcatcodes", "txtcatcodes", "vrbcatcodes",
        "prtcatcodes", "nilcatcodes", "luacatcodes", "tpacatcodes", "tpbcatcodes",
        "xmlcatcodes",
        --
        -- maybe a different class
        --
        "startmode", "stopmode", "startnotmode", "stopnotmode", "doifmode", "doifmodeelse", "doifnotmode",
        "startenvironment", "stopenvironment", "environment",
        "startcomponent", "stopcomponent", "component",
        "startproduct", "stopproduct", "product",
        "startproject", "stopproject", "project",
        "starttext", "stoptext", "startdocument", "stopdocument", "documentvariable",
        "startmodule", "stopmodule", "usemodule",
    },
    ["helpers"] = {
        --
        "startsetups", "stopsetups",
        "startxmlsetups", "stopxmlsetups",
        "starttexdefinition", "stoptexdefinition",
        "starttexcode", "stoptexcode",
        --
        "newcount", "newdimen", "newskip", "newmuskip", "newbox", "newtoks", "newread", "newwrite", "newmarks", "newinsert", "newattribute", "newif",
        "newlanguage", "newfamily", "newfam", "newhelp", -- not used
        --
        "htdp",
        "unvoidbox",
        "vfilll",
        --
        "scratchcounter", "globalscratchcounter",
        "scratchdimen", "globalscratchdimen",
        "scratchskip", "globalscratchskip",
        "scratchmuskip", "globalscratchmuskip",
        "scratchtoks", "globalscratchtoks",
        "scratchbox", "globalscratchbox",
        --
        "scratchwidth", "scratchheight", "scratchdepth", "scratchoffset",
        --
        "scratchcounterone", "scratchcountertwo", "scratchcounterthree",
        "scratchdimenone", "scratchdimentwo", "scratchdimenthree",
        "scratchskipone", "scratchskiptwo", "scratchskipthree",
        "scratchmuskipone", "scratchmuskiptwo", "scratchmuskipthree",
        "scratchtoksone", "scratchtokstwo", "scratchtoksthree",
        "scratchboxone", "scratchboxtwo", "scratchboxthree",
        --
        "doif", "doifnot", "doifelse",
        "doifinset", "doifnotinset", "doifinsetelse",
        "doifnextcharelse", "doifnextoptionalelse", "doifnextparenthesiselse", "doiffastoptionalcheckelse",
        "doifundefinedelse", "doifdefinedelse", "doifundefined", "doifdefined",
        "doifelsevalue", "doifvalue", "doifnotvalue",
        "doifnothing", "doifsomething", "doifelsenothing", "doifsomethingelse",
        "doifvaluenothing", "doifvaluesomething", "doifelsevaluenothing",
        "doifdimensionelse", "doifnumberelse",
        "doifcommonelse", "doifcommon", "doifnotcommon",
        "doifinstring", "doifnotinstring", "doifinstringelse",
        "doifassignmentelse",
        --
        "tracingall", "tracingnone", "loggingall",
        --
        "appendtoks", "prependtoks", "appendtotoks", "prependtotoks", "to",
        --
        "endgraf", "empty", "null", "space", "obeyspaces", "obeylines", "normalspace",
        --
        "executeifdefined",
        --
        "singleexpandafter", "doubleexpandafter", "tripleexpandafter",
        --
        "dontleavehmode",
        --
        "wait", "writestatus", "define", "redefine",
        --
        "setmeasure", "setemeasure", "setgmeasure", "setxmeasure", "definemeasure", "measure",
        --
        "getvalue", "setvalue", "setevalue", "setgvalue", "setxvalue", "letvalue", "letgvalue",
        "resetvalue", "undefinevalue", "ignorevalue",
        "setuvalue", "setuevalue", "setugvalue", "setuxvalue",
        "globallet", "glet",
        "getparameters", "geteparameters", "getgparameters", "getxparameters", "forgetparameters",
        --
        "processcommalist", "processcommacommand", "quitcommalist", "quitprevcommalist",
        "processaction", "processallactions", "processfirstactioninset", "processallactionsinset",
        --
        "unexpanded", "expanded", "startexpanded", "stopexpanded", "protected", "protect", "unprotect",
        --
        "firstofoneargument",
        "firstoftwoarguments", "secondoftwoarguments",
        "firstofthreearguments", "secondofthreearguments", "thirdofthreearguments",
        "firstoffourarguments", "secondoffourarguments", "thirdoffourarguments", "fourthoffourarguments",
        "firstoffivearguments", "secondoffivearguments", "thirdoffivearguments", "fourthoffivearguments", "fifthoffivearguments",
        "firstofsixarguments", "secondofsixarguments", "thirdofsixarguments", "fourthofsixarguments", "fifthofsixarguments", "sixthofsixarguments",
        --
        "gobbleoneargument", "gobbletwoarguments", "gobblethreearguments", "gobblefourarguments", "gobblefivearguments", "gobblesixarguments", "gobblesevenarguments", "gobbleeightarguments", "gobbleninearguments", "gobbletenarguments",
        "gobbleoneoptional", "gobbletwooptionals", "gobblethreeoptionals", "gobblefouroptionals", "gobblefiveoptionals",
        --
        "dorecurse", "doloop", "exitloop", "dostepwiserecurse", "recurselevel", "recursedepth",
        --
        "newconstant", "setnewconstant", "newconditional", "settrue", "setfalse",
        --
        "dosingleempty", "dodoubleempty", "dotripleempty", "doquadrupleempty", "doquintupleempty", "dosixtupleempty", "doseventupleempty",
        "dosinglegroupempty", "dodoublegroupempty", "dotriplegroupempty", "doquadruplegroupempty", "doquintuplegroupempty",
        --
        "nopdfcompression", "maximumpdfcompression", "normalpdfcompression",
        --
        "modulonumber", "dividenumber",
        --
        "getfirstcharacter", "doiffirstcharelse",
        --
        "startnointerference", "stopnointerference",
        --
        "strut", "setstrut", "strutbox", "strutht", "strutdp", "strutwd",
    }
}
