if not modules then modules = { } end modules ['mtx-update'] = {
    version   = 1.002,
    comment   = "companion to mtxrun.lua",
    author    = "Hans Hagen, PRAGMA-ADE, Hasselt NL",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files"
}

-- This script is dedicated to Mojca Miklavec, who is the driving force behind
-- moving minimal generation from our internal machines to the context garden.
-- Together with Arthur Reutenauer she made sure that it worked well on all
-- platforms that matter.

local format, concat, gmatch = string.format, table.concat, string.gmatch

scripts         = scripts         or { }
scripts.update  = scripts.update  or { }

minimals        = minimals        or { }
minimals.config = minimals.config or { }

-- this is needed under windows
-- else rsync fails to set the right chmod flags to files

os.setenv("CYGWIN","nontsec")

scripts.update.texformats = {
    "cont-en",
    "cont-nl",
    "cont-cz",
    "cont-de",
    "cont-fa",
    "cont-it",
    "cont-ro",
    "cont-uk",
    "cont-pe",
    "cont-xp",
    "mptopdf",
    "plain"
}

scripts.update.mpformats = {
    "metafun",
    "mpost",
}

-- experimental is not functional at the moment

scripts.update.repositories = {
    "current",
    "experimental"
}

-- more options than just these two are available (no idea why this is here)

scripts.update.versions = {
    "current",
    "latest"
}

-- list of basic folders that are needed to make a functional distribution

scripts.update.base = {
    { "base/tex/",                "texmf" },
    { "base/metapost/",           "texmf" },
    { "fonts/common/",            "texmf" },
    { "fonts/other/",             "texmf" }, -- not *really* needed, but helpful
    { "context/<version>/",       "texmf-context" },
    { "context/img/",             "texmf-context" },
    { "misc/setuptex/",           "." },
    { "misc/web2c",               "texmf" },
    { "bin/common/<platform>/",   "texmf-<platform>" },
    { "bin/context/<platform>/",  "texmf-<platform>" },
    { "bin/metapost/<platform>/", "texmf-<platform>" },
    { "bin/man/",                 "texmf-<platform>" },
}

-- binaries and font-related files
-- for pdftex we don't need OpenType fonts, for LuaTeX/XeTeX we don't need TFM files

scripts.update.engines = {
    ["luatex"] = {
        { "fonts/new/",               "texmf" },
        { "bin/luatex/<platform>/",   "texmf-<platform>" },
    },
    ["xetex"] = {
        { "base/xetex/",              "texmf" },
        { "fonts/new/",               "texmf" },
        { "bin/xetex/<platform>/",    "texmf-<platform>" },
    },
    ["pdftex"] = {
        { "fonts/old/",               "texmf" },
        { "bin/pdftex/<platform>/",   "texmf-<platform>" },
    },
    ["all"] = {
        { "fonts/new/",               "texmf" },
        { "fonts/old/",               "texmf" },
        { "base/xetex/",              "texmf" },
        { "bin/luatex/<platform>/",   "texmf-<platform>" },
        { "bin/xetex/<platform>/",    "texmf-<platform>" },
        { "bin/pdftex/<platform>/",   "texmf-<platform>" },
    },
}

scripts.update.platforms = {
    ["mswin"]         = "mswin",
    ["windows"]       = "mswin",
    ["win32"]         = "mswin",
    ["win"]           = "mswin",
    ["linux"]         = "linux",
    ["freebsd"]       = "freebsd",
    ["freebsd-amd64"] = "freebsd-amd64",
    ["linux-32"]      = "linux",
    ["linux-64"]      = "linux-64",
    ["linux32"]       = "linux",
    ["linux64"]       = "linux-64",
    ["linux-ppc"]     = "linux-ppc",
    ["ppc"]           = "linux-ppc",
    ["osx"]           = "osx-intel",
    ["macosx"]        = "osx-intel",
    ["osx-intel"]     = "osx-intel",
    ["osx-ppc"]       = "osx-ppc",
    ["osx-powerpc"]   = "osx-ppc",
    ["osxintel"]      = "osx-intel",
    ["osxppc"]        = "osx-ppc",
    ["osxpowerpc"]    = "osx-ppc",
    ["solaris-intel"] = "solaris-intel",
    ["solaris-sparc"] = "solaris-sparc",
    ["solaris"]       = "solaris-sparc",
}

-- the list is filled up later (when we know what modules to download)

scripts.update.modules = {
}

function scripts.update.run(str)
    logs.report("run", str)
    if environment.argument("force") then
        -- important, otherwise formats fly to a weird place
        -- (texlua sets luatex as the engine, we need to reset that or to fix texexec :)
        os.setenv("engine",nil)
        os.execute(str)
    end
end

function scripts.update.fullpath(path)
    if file.is_rootbased_path(path) then
        return path
    else
        return lfs.currentdir() .. "/" .. path
    end
end

function scripts.update.synchronize()

    logs.report("update","start")

    local texroot = scripts.update.fullpath(states.get("paths.root"))
    local engines = states.get('engines') or { }
    local platforms = states.get('platforms') or { }
    local repositories = states.get('repositories') -- minimals
    local bin = states.get("rsync.program")         -- rsync
    local url = states.get("rsync.server")          -- contextgarden.net
    local version = states.get("context.version")   -- current (or beta)
    local extras = states.get("extras")             -- extra goodies (like modules)
    local force = environment.argument("force")

    bin = string.gsub(bin,"\\","/")

    if not url:find("::$") then url = url .. "::" end
    local ok = lfs.attributes(texroot,"mode") == "directory"
    if not ok and force then
        dir.mkdirs(texroot)
        ok = lfs.attributes(texroot,"mode") == "directory"
    end

    if force then
        dir.mkdirs(format("%s/%s", texroot, "texmf-cache"))
        dir.mkdirs(format("%s/%s", texroot, "texmf-local"))
    end

    if ok or not force then

        local fetched, individual, osplatform = { }, { }, os.currentplatform()

        -- takes a collection as argument and returns a list of folders

        local function collection_to_list_of_folders(collection, platform)
            local archives = {}
            for _, c in ipairs(collection) do
                local archive = c[1]
                archive = archive:gsub("<platform>", platform)
                archive = archive:gsub("<version>", version)
                archives[#archives+1] = archive
            end
            return archives
        end

        -- takes a list of folders as argument and returns a string for rsync
        -- sample input:
        --     {'bin/common', 'bin/context'}
        -- output:
        --     'minimals/current/bin/common minimals/current/bin/context'

        local function list_of_folders_to_rsync_string(list_of_folders)
            local repository  = 'current'
            local prefix = format("%s/%s/", states.get('rsync.module'), repository) -- minimals/current/

            return prefix .. concat(list_of_folders, format(" %s", prefix))
        end

        -- example of usage: print(list_of_folders_to_rsync_string(collection_to_list_of_folders(scripts.update.base, os.currentplatform)))

        -- rename function and add some more functionality:
        --   * recursive/non-recursive (default: non-recursive)
        --   * filter folders or regular files only (default: no filter)
        --   * grep for size of included files (with --stats switch)

        local function get_list_of_files_from_rsync(list_of_folders)
            -- temporary file to store the output of rsync (could be a more random name; watch for overwrites)
            local temp_file = "rsync.tmp.txt"
            -- a set of folders
            local folders = {}
            local command = format("%s %s'%s' > %s", bin, url, list_of_folders_to_rsync_string(list_of_folders), temp_file)
            os.execute(command)
            -- read output of rsync
            local data = io.loaddata(temp_file) or ""
            -- for every line extract the filename
            for chmod, s in data:gmatch("([d%-][rwx%-]+).-(%S+)[\n\r]") do
                -- skip "current" folder
                if s ~= '.' and chmod:len() == 10 then
                    folders[#folders+1] = s
                end
            end
            -- delete the file to which we have put output of rsync
            os.remove(temp_file)
            return folders
        end

        -- rsync://contextgarden.net/minimals/current/modules/

        if extras and type(extras) == "table" then
            -- fetch the list of available modules from rsync server
            local available_modules = get_list_of_files_from_rsync({"modules/"})
            -- hash of requested modules
            -- local h = table.tohash(extras:split(","))
            for _, s in ipairs(available_modules) do
            --  if extras == "all" or h[s] then
                if extras.all or extras[s] then
                    scripts.update.modules[#scripts.update.modules+1] = { format("modules/%s/",s), "texmf-context" }
                end
            end
            -- TODO: check if every module from the list has been added and issue warning otherwise
            -- one idea to do it: remove every value from h once added and then check if anything is left in h
        end

        local function add_collection(collection,platform)
            if collection and platform then
                platform = scripts.update.platforms[platform]
                if platform then
                    for _, c in ipairs(collection) do
                        local archive = c[1]:gsub("<platform>", platform)
                        local destination = format("%s/%s", texroot, c[2]:gsub("<platform>", platform))
                        destination = destination:gsub("\\","/")
                        archive = archive:gsub("<version>",version)
                        if osplatform == "windows" or osplatform == "mswin" then
                            destination = destination:gsub("([a-zA-Z]):/", "/cygdrive/%1/")
                        end
                        individual[#individual+1] = { archive, destination }
                    end
                end
            end
        end

        for platform, _ in pairs(platforms) do
            add_collection(scripts.update.base,platform)
        end
        for platform, _ in pairs(platforms) do
            add_collection(scripts.update.modules,platform)
        end
        for engine, _ in pairs(engines) do
            for platform, _ in pairs(platforms) do
                add_collection(scripts.update.engines[engine],platform)
            end
        end

        local combined = { }
        for _, repository in ipairs(scripts.update.repositories) do
            if repositories[repository] then
                for _, v in pairs(individual) do
                    local archive, destination = v[1], v[2]
                    local cd = combined[destination]
                    if not cd then
                        cd = { }
                        combined[destination] = cd
                    end
                    cd[#cd+1] = format("%s/%s/%s",states.get('rsync.module'),repository,archive)
                end
            end
        end
        if logs.verbose then
            for k, v in pairs(combined) do
                logs.report("update", k)
                for k,v in ipairs(v) do
                    logs.report("update", "  <= " .. v)
                end
            end
        end
        for destination, archive in pairs(combined) do
            local archives, command = concat(archive," "), ""
        --  local normalflags, deleteflags = states.get("rsync.flags.normal"), states.get("rsync.flags.delete")
        --    if environment.argument("keep") or destination:find("%.$") then
        --       command = format("%s %s    %s'%s' '%s'", bin, normalflags,              url, archives, destination)
        --    else
        --        command = format("%s %s %s %s'%s' '%s'", bin, normalflags, deleteflags, url, archives, destination)
        --    end
            local normalflags, deleteflags = states.get("rsync.flags.normal"), ""
            if (destination:find("texmf$") or destination:find("texmf%-context$")) and (not environment.argument("keep")) then
                deleteflags = states.get("rsync.flags.delete")
            end
            command = format("%s %s %s %s'%s' '%s'", bin, normalflags, deleteflags, url, archives, destination)
            logs.report("mtx update", format("running command: %s",command))
            if not fetched[command] then
                scripts.update.run(command)
                fetched[command] = command
            end
        end

        local function update_script(script, platform)
            local bin = bin:gsub("\\","/")
            local texroot = texroot:gsub("\\","/")
            platform = scripts.update.platforms[platform]
            if platform then
                local command
                if platform == 'mswin' then
                    bin = bin:gsub("([a-zA-Z]):/", "/cygdrive/%1/")
                    texroot = texroot:gsub("([a-zA-Z]):/", "/cygdrive/%1/")
                    command = string.format("%s -t %s/texmf-context/scripts/context/lua/%s.lua %s/texmf-mswin/bin/", bin, texroot, script, texroot)
                else
                    command = string.format("%s -tgo --chmod=a+x %s/texmf-context/scripts/context/lua/%s.lua %s/texmf-%s/bin/%s", bin, texroot, script, texroot, platform, script)
                end
                logs.report("mtx update", format("updating %s for %s: %s", script, platform, command))
                scripts.update.run(command)
            end
        end

        for platform, _ in pairs(platforms) do
            update_script('luatools',platform)
            update_script('mtxrun',platform)
        end

    else
        logs.report("mtx update", format("no valid texroot: %s",texroot))
    end
    if not force then
        logs.report("update", "use --force to really update files")
    end
    logs.report("update","done")
end

function table.fromhash(t)
    local h = { }
    for k, v in pairs(t) do -- no ipairs here
        if v then h[#h+1] = k end
    end
    return h
end

-- make the ConTeXt formats
function scripts.update.make()

    logs.report("make","start")

    local force = environment.argument("force")
    local texroot = scripts.update.fullpath(states.get("paths.root"))
    local engines= states.get('engines')
    local platforms = states.get('platforms')
    local formats = states.get('formats')

    resolvers.load_tree(texroot)
    -- update filename database for pdftex/xetex
    scripts.update.run("mktexlsr")
    -- update filename database for luatex
    scripts.update.run("luatools --generate")
    local askedformats = formats
    local texformats = table.tohash(scripts.update.texformats)
    local mpformats = table.tohash(scripts.update.mpformats)
    for k,v in pairs(texformats) do
        if not askedformats[k] then
            texformats[k] = nil
        end
    end
    for k,v in pairs(mpformats) do
        if not askedformats[k] then
            mpformats[k] = nil
        end
    end
    local formatlist = concat(table.fromhash(texformats), " ")
    if formatlist ~= "" then
        for engine in pairs(engines) do
            if engine == "luatex" then
                scripts.update.run(format("context --make")) -- maybe also formatlist
            else
                -- todo: just handle make here or in mtxrun --script context --make
                scripts.update.run(format("texexec --make --all --fast --%s %s",engine,formatlist))
            end
        end
    end
    local formatlist = concat(table.fromhash(mpformats), " ")
    if formatlist ~= "" then
        scripts.update.run(format("texexec --make --all --fast %s",formatlist))
    end
    if not force then
        logs.report("make", "use --force to really make formats")
    end
    scripts.update.run("mktexlsr")
    scripts.update.run("luatools --generate")
    logs.report("make","done")
end

logs.extendbanner("Download Tools 0.20",true)

messages.help = [[
--platform=string     platform (windows, linux, linux-64, osx-intel, osx-ppc, linux-ppc)
--server=string       repository url (rsync://contextgarden.net)
--module=string       repository url (minimals)
--repository=string   specify version (current, experimental)
--context=string      specify version (current, latest, yyyy.mm.dd)
--rsync=string        rsync binary (rsync)
--texroot=string      installation directory (not guessed for the moment)
--engine=string       tex engine (luatex, pdftex, xetex)
--extras=string       extra modules (can be list or 'all')
--force               instead of a dryrun, do the real thing
--update              update minimal tree
--make                also make formats and generate file databases
--keep                don't delete unused or obsolete files
--state               update tree using saved state
]]

scripts.savestate = true

if scripts.savestate then

    states.load("status-of-update.lua")

    -- tag, value, default, persistent

    statistics.starttiming(states)

    states.set("info.version",0.1) -- ok
    states.set("info.count",(states.get("info.count") or 0) + 1,1,false) -- ok
    states.set("info.comment","this file contains the settings of the last 'mtxrun --script update ' run",false) -- ok
    states.set("info.date",os.date("!%Y-%m-%d %H:%M:%S")) -- ok

    states.set("rsync.program", environment.argument("rsync"), "rsync", true) -- ok
    states.set("rsync.server", environment.argument("server"), "contextgarden.net::", true) -- ok
    states.set("rsync.module", environment.argument("module"), "minimals", true) -- ok
    states.set("rsync.flags.normal", environment.argument("flags"), "-rpztlv --stats", true) -- ok
    states.set("rsync.flags.delete", nil, "--delete", true) -- ok

    states.set("paths.root", environment.argument("texroot"), "tex", true) -- ok

    states.set("context.version", environment.argument("context"), "current", true) -- ok

    local valid = table.tohash(scripts.update.repositories)
    for r in gmatch(environment.argument("repository") or "current","([^, ]+)") do
        if valid[r] then states.set("repositories." .. r, true) end
    end
    local valid = scripts.update.engines
    for r in gmatch(environment.argument("engine") or "all","([^, ]+)") do
        if r == "all" then
            for k, v in pairs(valid) do
                if k ~= "all" then
                    states.set("engines." .. k, true)
                end
            end
        elseif valid[r] then
            states.set("engines." .. r, true)
        end
    end
    local valid = scripts.update.platforms
    for r in gmatch(environment.argument("platform") or os.currentplatform(),"([^, ]+)") do
        if valid[r] then states.set("platforms." .. r, true) end
    end

    local valid = table.tohash(scripts.update.texformats)
    for r in gmatch(environment.argument("formats") or "","([^, ]+)") do
        if valid[r] then states.set("formats." .. r, true) end
    end
    local valid = table.tohash(scripts.update.mpformats)
    for r in gmatch(environment.argument("formats") or "","([^, ]+)") do
        if valid[r] then states.set("formats." .. r, true) end
    end

    states.set("formats.cont-en", true)
    states.set("formats.cont-nl", true)
    states.set("formats.metafun", true)

    for r in gmatch(environment.argument("extras") or "","([^, ]+)") do
        states.set("extras." .. r, true)
    end

    logs.report("state","loaded")

end

if environment.argument("state") then
    environment.setargument("update",true)
    environment.setargument("force",true)
    environment.setargument("make",true)
end

if environment.argument("update") then
    scripts.update.synchronize()
    if environment.argument("make") then
        scripts.update.make()
    end
elseif environment.argument("make") then
    scripts.update.make()
else
    logs.help(messages.help)
end

if scripts.savestate then
    statistics.stoptiming(states)
    states.set("info.runtime",tonumber(statistics.elapsedtime(states)))
    if environment.argument("force") then
        states.save()
        logs.report("state","saved")
    end
end