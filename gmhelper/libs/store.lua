--[[
* Split Ashita settings aliases:
*   settings  -> Settings tab options
*   favorites -> favorite tabs / commands
*   history   -> executed command history entries
*   scripts   -> script tabs / custom scripts
]]

require('common');

local settings = require('settings');

local store = {};

local settingsCfg;
local favCfg;
local histCfg;
local scriptCfg;
local cfg;

local settingsDefaults = T{
    tier = 5,
    scale = 1,
    commandDelay = 1.5,
    historyDateSep = '/',
    historyDateOrder = 'mdy',
    historyDateFormat = '%m/%d/%Y',
    historyTimeFormat = '%H:%M:%S',
    historyMax = 1000,
    welcomeAccepted = false,
    windowX = nil,
    windowY = nil,
    windowW = 700,
    windowH = 550,
    groupOrder = T{},
};

local favDefaults = T{
    favoriteTabs = T{},
    nextFavId = 1,
};

local histDefaults = T{
    entries = T{},
};

local scriptDefaults = T{
    scriptTabs = T{},
    nextScriptId = 1,
    scriptBuiltinsSeeded = false,
};

local function strip_legacy(target)
    if (target == nil) then
        return;
    end
    target.favoriteTabs = nil;
    target.favorites = nil;
    target.nextFavId = nil;
    target.history = nil;
    target.presets = nil;
    target.presetScale = nil;
    target.scriptTabs = nil;
    target.nextScriptId = nil;
end

local function normalize_settings(target)
    if (target == nil) then
        return;
    end
    if (target.tier == nil) then
        target.tier = 5;
    end
    if (target.scale == nil or target.scale < 0.1 or target.scale > 3) then
        target.scale = 1;
    end
    if (target.commandDelay == nil and target.presetScale ~= nil) then
        target.commandDelay = target.presetScale;
    end
    if (target.commandDelay == nil or target.commandDelay < 0.5 or target.commandDelay > 5) then
        target.commandDelay = 1.5;
    end
    target.commandDelay = math.floor(target.commandDelay * 10 + 0.5) / 10;
    if (target.historyDateSep ~= '/' and target.historyDateSep ~= '-' and target.historyDateSep ~= '.') then
        local format = target.historyDateFormat or '';
        if (format:find('%.', 1, true)) then
            target.historyDateSep = '.';
        elseif (format:find('-', 1, true)) then
            target.historyDateSep = '-';
        else
            target.historyDateSep = '/';
        end
    end
    if (target.historyDateOrder ~= 'mdy' and target.historyDateOrder ~= 'dmy' and target.historyDateOrder ~= 'ymd') then
        local format = target.historyDateFormat or '';
        if (format:sub(1, 2) == '%d') then
            target.historyDateOrder = 'dmy';
        elseif (format:sub(1, 2) == '%Y') then
            target.historyDateOrder = 'ymd';
        else
            target.historyDateOrder = 'mdy';
        end
    end
    if (target.historyDateFormat == nil or target.historyDateFormat == '') then
        target.historyDateFormat = '%m/%d/%Y';
    end
    if (target.historyTimeFormat == nil or target.historyTimeFormat == '') then
        target.historyTimeFormat = '%H:%M:%S';
    end
    local max = tonumber(target.historyMax) or 1000;
    max = math.floor((max / 100) + 0.5) * 100;
    if (max < 200) then
        max = 200;
    elseif (max > 10000) then
        max = 10000;
    end
    target.historyMax = max;
    if (target.welcomeAccepted ~= true) then
        target.welcomeAccepted = false;
    end
    local winW = tonumber(target.windowW) or 700;
    local winH = tonumber(target.windowH) or 550;
    if (winW < 320) then
        winW = 320;
    end
    if (winH < 240) then
        winH = 240;
    end
    target.windowW = math.floor(winW + 0.5);
    target.windowH = math.floor(winH + 0.5);
    if (target.windowX ~= nil) then
        target.windowX = tonumber(target.windowX);
    end
    if (target.windowY ~= nil) then
        target.windowY = tonumber(target.windowY);
    end
    if (type(target.groupOrder) ~= 'table') then
        target.groupOrder = T{};
    end
end

local function normalize_history(entries)
    if (type(entries) ~= 'table') then
        return;
    end
    for _, entry in ipairs(entries) do
        if (entry ~= nil and type(entry.stamp) == 'string') then
            entry.stamp = tonumber(entry.stamp);
        end
    end
end

local function ensure_script_tabs(cfgTable)
    require('libs.ui.scripts').ensure_script_tabs(cfgTable);
end

local function ensure_defaults()
    if (type(favCfg.favoriteTabs) ~= 'table') then
        favCfg.favoriteTabs = T{};
    end
    if (favCfg.nextFavId == nil) then
        favCfg.nextFavId = 1;
    end
    if (#favCfg.favoriteTabs == 0) then
        favCfg.favoriteTabs = T{
            T{ id = 'default', name = 'Default', commands = T{} },
        };
    end
    if (type(histCfg.entries) ~= 'table') then
        histCfg.entries = T{};
    end
    ensure_script_tabs(scriptCfg);
    normalize_history(histCfg.entries);
end

local function build_cfg()
    cfg = setmetatable({}, {
        __index = function(_, key)
            if (key == 'favoriteTabs') then
                return favCfg.favoriteTabs;
            end
            if (key == 'nextFavId') then
                return favCfg.nextFavId;
            end
            if (key == 'history') then
                return histCfg.entries;
            end
            if (key == 'scriptTabs') then
                return scriptCfg.scriptTabs;
            end
            if (key == 'nextScriptId') then
                return scriptCfg.nextScriptId;
            end
            if (key == 'scriptBuiltinsSeeded') then
                return scriptCfg.scriptBuiltinsSeeded;
            end
            if (key == 'presets' or key == 'favorites') then
                return nil;
            end
            return settingsCfg[key];
        end,
        __newindex = function(_, key, value)
            if (key == 'favoriteTabs') then
                favCfg.favoriteTabs = value;
                return;
            end
            if (key == 'nextFavId') then
                favCfg.nextFavId = value;
                return;
            end
            if (key == 'history') then
                histCfg.entries = value;
                return;
            end
            if (key == 'scriptTabs') then
                scriptCfg.scriptTabs = value;
                return;
            end
            if (key == 'nextScriptId') then
                scriptCfg.nextScriptId = value;
                return;
            end
            if (key == 'scriptBuiltinsSeeded') then
                scriptCfg.scriptBuiltinsSeeded = value;
                return;
            end
            if (key == 'presets' or key == 'favorites') then
                return;
            end
            settingsCfg[key] = value;
        end,
    });
end

function store.cfg()
    return cfg;
end

function store.history_max()
    normalize_settings(settingsCfg);
    return settingsCfg.historyMax or 1000;
end

function store.save()
    strip_legacy(settingsCfg);
    normalize_settings(settingsCfg);
    ensure_script_tabs(scriptCfg);
    settings.save('settings');
    settings.save('favorites');
    settings.save('history');
    settings.save('scripts');
end

function store.init()
    settingsCfg = settings.load(settingsDefaults, 'settings');
    favCfg = settings.load(favDefaults, 'favorites');
    histCfg = settings.load(histDefaults, 'history');
    scriptCfg = settings.load(scriptDefaults, 'scripts');
    normalize_settings(settingsCfg);
    ensure_defaults();
    build_cfg();
    settings.save('scripts');

    settings.register('settings', 'gmhelper_settings', function(s)
        if (s ~= nil) then
            settingsCfg = s;
            normalize_settings(settingsCfg);
            strip_legacy(settingsCfg);
            build_cfg();
        end
        settings.save('settings');
    end);

    settings.register('favorites', 'gmhelper_favorites', function(s)
        if (s ~= nil) then
            favCfg = s;
            if (type(favCfg.favoriteTabs) ~= 'table') then
                favCfg.favoriteTabs = T{};
            end
            if (favCfg.nextFavId == nil) then
                favCfg.nextFavId = 1;
            end
            build_cfg();
        end
        settings.save('favorites');
    end);

    settings.register('history', 'gmhelper_history', function(s)
        if (s ~= nil) then
            histCfg = s;
            if (type(histCfg.entries) ~= 'table') then
                histCfg.entries = T{};
            end
            normalize_history(histCfg.entries);
            build_cfg();
        end
        settings.save('history');
    end);

    settings.register('scripts', 'gmhelper_scripts', function(s)
        if (s ~= nil) then
            scriptCfg = s;
            ensure_script_tabs(scriptCfg);
            build_cfg();
        end
        settings.save('scripts');
    end);

    return cfg;
end

return store;
