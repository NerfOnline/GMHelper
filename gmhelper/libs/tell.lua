--[[
* Tracks the last tell recipient and expands the token "Tell" in player fields.
]]

require('common');

local tell = {};

local lastTarget = nil;

local function trim(value)
    if (value == nil) then
        return '';
    end
    return (tostring(value):gsub('^%s+', ''):gsub('%s+$', ''));
end

local function note(name)
    name = trim(name);
    if (name == '' or #name > 15) then
        return;
    end
    lastTarget = name;
end

local function last_teller_name()
    local ok, targets = pcall(require, 'ffxi.targets');
    if (not ok or targets == nil or targets.get_last_teller_name == nil) then
        return nil;
    end
    local okName, name = pcall(targets.get_last_teller_name);
    if (not okName) then
        return nil;
    end
    name = trim(name);
    if (name == '') then
        return nil;
    end
    return name;
end

function tell.last()
    if (lastTarget ~= nil and lastTarget ~= '') then
        return lastTarget;
    end
    return last_teller_name();
end

function tell.is_player_field(field)
    if (field == nil or field.kind == 'lookup') then
        return false;
    end
    local key = tostring(field.key or ''):lower();
    local label = tostring(field.label or ''):lower();
    local ph = tostring(field.placeholder or ''):lower();
    if (key:find('zone', 1, true) or label:find('zone', 1, true)) then
        return false;
    end
    return key:find('player', 1, true) ~= nil
        or key:find('target', 1, true) ~= nil
        or label:find('player', 1, true) ~= nil
        or label == 'target'
        or ph == 'player';
end

function tell.resolve(value)
    local text = trim(value);
    if (text:lower() ~= 'tell') then
        return tostring(value or '');
    end
    local name = tell.last();
    if (name == nil or name == '') then
        return text;
    end
    return name;
end

function tell.apply_buffer(buffer)
    if (buffer == nil or buffer[1] == nil) then
        return;
    end
    local resolved = tell.resolve(buffer[1]);
    if (resolved ~= buffer[1]) then
        buffer[1] = resolved;
    end
end

function tell.on_command(e)
    if (e == nil or e.command == nil) then
        return;
    end
    local args = e.command:args();
    if (#args < 1) then
        return;
    end
    local cmd = tostring(args[1] or ''):lower();
    if ((cmd == '/tell' or cmd == '/t') and args[2] ~= nil) then
        note(args[2]);
    elseif (cmd == '/r') then
        note(last_teller_name());
    end
end

function tell.on_packet_out(e)
    if (e == nil or e.id ~= 0x0B5) then
        return;
    end
    local msgType = struct.unpack('B', e.data_modified or e.data, 0x04 + 1);
    if (msgType ~= 3) then
        return;
    end
    -- /tell Name msg often reaches us via the command event first.
    -- /r and some UI tells only show up here; message body is the text only,
    -- so fall back to the client's last-teller (the /r target).
    if (lastTarget == nil or lastTarget == '') then
        note(last_teller_name());
    end
end

return tell;
