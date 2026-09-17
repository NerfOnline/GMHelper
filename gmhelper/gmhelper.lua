--[[
* GM Helper
* Drop the gmhelper folder into Ashita/addons, then /addon load gmhelper
* The window stays closed until /gmh or /gmhelper
]]

addon.name = 'gmhelper';
addon.author = 'Nerf';
addon.version = '0.0.1';
addon.desc = 'LandSandBoat GM command panel for Ashita v4.';
addon.link = '';

require('common');

local ffi = require('ffi');
local chat = require('chat');
local imgui = require('imgui');
local lookup = require('libs.lookup');
local store = require('libs.store');
local shortcut = require('libs.shortcut');
local tell = require('libs.tell');
local ui = require('libs.ui');
local widgets = require('libs.widgets');

local cfg = store.init();
local state = {
    visible = false,
    page = 'Player',
    search = T{ '' },
    values = {},
    favValues = {},
    errors = {},
    dbCategory = 'items',
};

local function save()
    store.save();
end

local function is_toggle_command(name)
    name = string.lower(tostring(name or ''));
    return name == '/gmh' or name == '/gmhelper';
end

ashita.events.register('load', 'gmhelper_load', function()
    widgets.reset_scrolls();
    require('libs.ui.kit').ensure_line_num_font();
    print(chat.header(addon.name):append(chat.message('Loaded. Use ')):append(chat.success('/gmh')):append(chat.message(' or ')):append(chat.success('/gmhelper')):append(chat.message(' to open.')));
end);

ashita.events.register('unload', 'gmhelper_unload', function()
    store.save();
end);

ashita.events.register('command', 'gmhelper_command', function(e)
    tell.on_command(e);
    local args = e.command:args();
    if (#args == 0 or not is_toggle_command(args[1])) then
        return;
    end
    e.blocked = true;
    cfg = store.cfg();
    if (shortcut.handle(args, cfg, state, save)) then
        return;
    end
    state.visible = not state.visible;
    if (not state.visible) then
        store.save();
    end
end);

ashita.events.register('packet_out', 'gmhelper_packet_out', function(e)
    tell.on_packet_out(e);
end);

local STEP_UP = 0xC8;
local STEP_DOWN = 0xD0;

local function step_key(key)
    return key == STEP_UP or key == STEP_DOWN;
end

ashita.events.register('key_data', 'gmhelper_key_data', function(e)
    if (e.injected) then
        return;
    end
    -- Game-control keys only. ImGui still receives WNDPROC/text input for the modal.
    if (ui.modal_open()) then
        e.blocked = true;
        return;
    end
    if (not widgets.arrows_captured() or not step_key(e.key)) then
        return;
    end
    e.blocked = true;
end);

ashita.events.register('key_state', 'gmhelper_key_state', function(e)
    if (e.data_raw == nil) then
        return;
    end
    if (ui.modal_open()) then
        local size = e.size or 256;
        if (size > 0 and size <= 256) then
            ffi.fill(e.data_raw, size, 0);
        end
        return;
    end
    if (not widgets.arrows_captured()) then
        return;
    end
    if (e.size ~= nil and e.size <= STEP_DOWN) then
        return;
    end
    local keys = ffi.cast('uint8_t*', e.data_raw);
    keys[STEP_UP] = 0;
    keys[STEP_DOWN] = 0;
end);

ashita.events.register('d3d_present', 'gmhelper_present', function()
    lookup.tick();
    widgets.begin_frame();
    cfg = store.cfg();
    require('libs.ui.presets').tick(state, cfg, save);
    if (state.visible) then
        ui.draw(state, cfg, save);
    end
    lookup.end_frame();
    widgets.end_frame();
end);
