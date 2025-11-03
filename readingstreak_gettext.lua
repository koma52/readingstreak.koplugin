-- Localization wrapper for plugin translations

local DataStorage = require("datastorage")
local GetText = require("gettext")
local logger = require("logger")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")

local function getPluginDir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    local plugin_dir = source:match("(.*/)readingstreak_gettext%.lua")
    
    if plugin_dir then
        plugin_dir = plugin_dir:gsub("[\\/]+$", "")
        plugin_dir = plugin_dir:gsub("\\", "/")
        
        if plugin_dir:match("^/") or plugin_dir:match("^[A-Z]:") then
            return plugin_dir
        end
        
        local cwd = lfs.currentdir() or "."
        if cwd and cwd ~= "." then
            local abs_path = cwd .. "/" .. plugin_dir
            abs_path = abs_path:gsub("//+", "/")
            if lfs.attributes(abs_path, "mode") == "directory" then
                return abs_path
            end
        end
    end
    
    local data_dir = DataStorage:getDataDir()
    local plugin_paths = {
        data_dir .. "/plugins/readingstreak.koplugin",
        "./plugins/readingstreak.koplugin",
        "../plugins/readingstreak.koplugin",
    }
    
    for _, path in ipairs(plugin_paths) do
        if lfs.attributes(path, "mode") == "directory" then
            return path
        end
    end
    
    return data_dir .. "/plugins/readingstreak.koplugin"
end

local plugin_dir = getPluginDir()

local source_path = debug.getinfo(1, "S").source
if source_path:sub(1, 1) == "@" then
    source_path = source_path:sub(2)
end
local lib_path, _ = util.splitFilePathName(source_path)
if lib_path then
    local extracted_plugin_dir = lib_path:gsub("/+$", "")
    if extracted_plugin_dir and extracted_plugin_dir ~= "" then
        local extracted_l10n_dir = extracted_plugin_dir .. "/l10n"
        extracted_l10n_dir = extracted_l10n_dir:gsub("//+", "/")
        
        if extracted_l10n_dir:match("^/") or extracted_l10n_dir:match("^[A-Z]:") then
            if lfs.attributes(extracted_l10n_dir, "mode") == "directory" then
                plugin_dir = extracted_plugin_dir
            end
        else
            local cwd = lfs.currentdir() or "."
            if cwd and cwd ~= "." then
                local abs_path = cwd .. "/" .. extracted_l10n_dir
                abs_path = abs_path:gsub("//+", "/")
                if lfs.attributes(abs_path, "mode") == "directory" then
                    plugin_dir = extracted_plugin_dir
                end
            end
        end
    end
end

local l10n_dir = plugin_dir .. "/l10n"
l10n_dir = l10n_dir:gsub("//+", "/")

local function c_escape(what_full, what)
    if what == "\n" then return ""
    elseif what == "a" then return "\a"
    elseif what == "b" then return "\b"
    elseif what == "f" then return "\f"
    elseif what == "n" then return "\n"
    elseif what == "r" then return "\r"
    elseif what == "t" then return "\t"
    elseif what == "v" then return "\v"
    elseif what == "0" then return "\0"
    else
        return what_full
    end
end

local function logicalCtoLua(logical_str)
    logical_str = logical_str:gsub("&&", "and")
    logical_str = logical_str:gsub("!=", "~=")
    logical_str = logical_str:gsub("||", "or")
    return logical_str
end

local function getDefaultPlural(n)
    if n ~= 1 then
        return 1
    else
        return 0
    end
end

local function getPluralFunc(pl_tests, nplurals, plural_default)
    local plural_func_str = "return function(n) if "

    if #pl_tests > 1 then
        for i = 1, #pl_tests do
            local pl_test = pl_tests[i]
            pl_test = logicalCtoLua(pl_test)

            if i > 1 and tonumber(pl_test) == nil then
                pl_test = " elseif "..pl_test
            end
            if tonumber(pl_test) ~= nil then
                pl_test = " else return "..pl_test
            end
            pl_test = pl_test:gsub("?", " then return")

            plural_func_str = plural_func_str..pl_test
        end
        plural_func_str = plural_func_str.." end end"
    else
        local pl_test = pl_tests[1]
        if pl_test == plural_default then
            return getDefaultPlural
        end
        if tonumber(pl_test) ~= nil then
            plural_func_str = "return function(n) return "..pl_test.." end"
        else
            pl_test = logicalCtoLua(pl_test)
            plural_func_str = "return function(n) if "..pl_test.." then return 1 else return 0 end end"
        end
    end
    return loadstring(plural_func_str)()
end

local function addTranslation(msgctxt, msgid, msgstr, n)
    local unescaped_string = string.gsub(msgstr, "(\\(.))", c_escape)
    if msgctxt and msgctxt ~= "" then
        if not GetText.context[msgctxt] then
            GetText.context[msgctxt] = {}
        end
        if n then
            if not GetText.context[msgctxt][msgid] then
                GetText.context[msgctxt][msgid] = {}
            end
            GetText.context[msgctxt][msgid][n] = unescaped_string ~= "" and unescaped_string or nil
        else
            GetText.context[msgctxt][msgid] = unescaped_string ~= "" and unescaped_string or nil
        end
    else
        if n then
            if not GetText.translation[msgid] then
                GetText.translation[msgid] = {}
            end
            GetText.translation[msgid][n] = unescaped_string ~= "" and unescaped_string or nil
        else
            -- For non-plural translations, store as string directly (matching assistant.koplugin format)
            if unescaped_string ~= "" then
                GetText.translation[msgid] = unescaped_string
            end
        end
    end
end


local NewGetText = {}
local original_dirname = GetText.dirname

local function updateLanguage()
    local main_gettext = require("gettext")
    local new_lang = main_gettext.current_lang or "C"
    
    local original_l10n_dirname = GetText.dirname
    local original_textdomain = GetText.textdomain
    local original_context = GetText.context
    local original_translation = GetText.translation
    local original_wrapUntranslated_func = GetText.wrapUntranslated
    local original_current_lang = GetText.current_lang
    local original_getPlural = GetText.getPlural

    GetText.dirname = l10n_dir
    GetText.textdomain = "readingstreak"
    
    -- Try to use standard GetText.changeLang which supports both .mo and .po files
    -- .mo files are preferred and work more reliably
    local ok, err = pcall(GetText.changeLang, new_lang)
    
    if ok then
        local has_translations = (GetText.translation and next(GetText.translation) ~= nil) or (GetText.context and next(GetText.context) ~= nil)
        
        if has_translations then
            NewGetText = {}
            for k, v in pairs(GetText) do
                if type(v) == "function" then
                    NewGetText[k] = v
                elseif type(v) == "table" then
                    if k == "translation" or k == "context" then
                        NewGetText[k] = {}
                        for k2, v2 in pairs(v) do
                            if type(v2) == "table" then
                                NewGetText[k][k2] = {}
                                for k3, v3 in pairs(v2) do
                                    NewGetText[k][k2][k3] = v3
                                end
                            else
                                NewGetText[k][k2] = v2
                            end
                        end
                    else
                        NewGetText[k] = {}
                        for k2, v2 in pairs(v) do
                            NewGetText[k][k2] = v2
                        end
                    end
                else
                    NewGetText[k] = v
                end
            end
            local translation_count = GetText.translation and (function()
                local count = 0
                for _ in pairs(GetText.translation) do count = count + 1 end
                return count
            end)() or 0
            local sample_key, sample_value = nil, nil
            if GetText.translation then
                for k, v in pairs(GetText.translation) do
                    sample_key = k
                    sample_value = type(v) == "table" and (v[0] or v) or v
                    break
                end
            end
        end
    end
    
    GetText.dirname = original_l10n_dirname
    GetText.textdomain = original_textdomain
    GetText.context = original_context
    GetText.translation = original_translation
    GetText.wrapUntranslated = original_wrapUntranslated_func
    GetText.current_lang = original_current_lang
    GetText.getPlural = original_getPlural
end

local function createGetTextWrapper()
    local mt = {}
    local last_lang = nil
    
    mt.__index = function(tbl, key)
        local main_gettext = require("gettext")
        local current_lang = main_gettext.current_lang
        
        if last_lang ~= current_lang then
            updateLanguage()
            last_lang = current_lang
        end
        
        if key == "gettext" then
            return mt.__call
        end
        
        local value = NewGetText[key]
        if value ~= nil then
            return value
        end
        
        return GetText[key]
    end
    
    mt.__call = function(tbl, msgid)
        local main_gettext = require("gettext")
        local current_lang = main_gettext.current_lang
        
        if last_lang ~= current_lang then
            updateLanguage()
            last_lang = current_lang
        end
        
        if NewGetText and type(NewGetText) == "table" then
            if NewGetText.translation and NewGetText.translation[msgid] then
                local trans = NewGetText.translation[msgid]
                -- Format matches assistant.koplugin: translation[msgid][0] or translation[msgid] (string)
                if type(trans) == "table" then
                    -- Plural forms: check for index 0 first (singular form)
                    if trans[0] ~= nil then
                        return trans[0]
                    elseif next(trans) then
                        -- Return first non-nil value if no index 0
                        for _, v in pairs(trans) do
                            if v ~= nil then
                                return v
                            end
                        end
                    end
                    return msgid
                else
                    -- Non-plural: return string directly
                    return trans or msgid
                end
            end
        end
        
        -- Fallback to standard GetText
        if GetText then
            if type(GetText) == "function" then
                return GetText(msgid)
            elseif GetText.gettext and type(GetText.gettext) == "function" then
                return GetText.gettext(msgid)
            elseif GetText.translation and GetText.translation[msgid] then
                local trans = GetText.translation[msgid]
                if type(trans) == "table" then
                    return trans[0] or trans or msgid
                else
                    return trans or msgid
                end
            end
        end
        
        return msgid
    end
    
    local wrapper = {}
    setmetatable(wrapper, mt)
    
    local main_gettext = require("gettext")
    updateLanguage()
    last_lang = main_gettext.current_lang
    
    return wrapper
end

return createGetTextWrapper()
