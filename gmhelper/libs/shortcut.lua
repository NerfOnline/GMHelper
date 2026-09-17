--[[
* /gmh subcommands: favorites, scripts, presets.
]]

require('common');

local chat = require('chat');

local shortcut = {};

local function notify(ok, err)
    if (ok) then
        return;
    end
    print(chat.header('gmhelper'):append(chat.error(err or 'Command failed.')));
end

local function usage(text)
    print(chat.header('gmhelper'):append(chat.message('Usage: ')):append(chat.success(text)));
end

local function is_stop(args)
    return #args >= 3 and string.lower(tostring(args[3] or '')) == 'stop';
end

--[[
* args[1] = /gmh|/gmhelper
* Returns true if a subcommand was handled (including usage errors).
* Returns false when args are only the root command (caller toggles UI).
]]
function shortcut.handle(args, cfg, state, save)
    if (args == nil or #args < 2) then
        return false;
    end

    local kind = string.lower(tostring(args[2] or ''));
    if (kind ~= 'favorites' and kind ~= 'scripts' and kind ~= 'presets') then
        usage('/gmh [favorites|scripts|presets] ...');
        return true;
    end

    if (kind == 'presets') then
        if (is_stop(args)) then
            require('libs.ui.presets').stop(state);
            return true;
        end
        if (#args < 3) then
            usage('/gmh presets <number|stop>');
            return true;
        end
        local index = tonumber(args[#args]);
        if (index == nil) then
            usage('/gmh presets <number|stop>');
            return true;
        end
        local ok, err = require('libs.ui.presets').run_line(cfg, math.floor(index), save, state);
        notify(ok, err);
        return true;
    end

    if (kind == 'scripts' and is_stop(args)) then
        require('libs.ui.scripts').stop(state);
        return true;
    end

    if (#args < 4) then
        if (kind == 'scripts') then
            usage('/gmh scripts <tab name> <number>');
            usage('/gmh scripts stop');
        else
            usage('/gmh ' .. kind .. ' <tab name> <number>');
        end
        return true;
    end
    local index = tonumber(args[#args]);
    if (index == nil) then
        usage('/gmh ' .. kind .. ' <tab name> <number>');
        return true;
    end
    local tab = table.concat(args, ' ', 3, #args - 1);
    local ok, err;
    if (kind == 'favorites') then
        ok, err = require('libs.ui.favorites').run_line(cfg, tab, math.floor(index), save, state);
    else
        ok, err = require('libs.ui.scripts').run_line(cfg, tab, math.floor(index), save, state);
    end
    notify(ok, err);
    return true;
end

return shortcut;
