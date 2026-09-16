--[[
* GM Helper UI shell: window chrome, welcome, section tabs, routing.
]]

require('common');

local imgui = require('imgui');
local commands = require('data.commands');
local theme = require('libs.theme');
local widgets = require('libs.widgets');
local kit = require('libs.ui.kit');
local commandsPage = require('libs.ui.commands');
local favorites = require('libs.ui.favorites');
local scripts = require('libs.ui.scripts');
local presets = require('libs.ui.presets');
local history = require('libs.ui.history');
local settings = require('libs.ui.settings');

local ui = {};

function ui.modal_open()
    return kit.modal_open();
end

ui.SECTIONS = {
    { id = 'commands', label = 'Commands' },
    { id = 'favorites', label = 'Favorites' },
    { id = 'scripts', label = 'Scripts' },
    { id = 'presets', label = 'Presets' },
    { id = 'history', label = 'History' },
    { id = 'settings', label = 'Settings' },
};

function ui.draw_section_tabs(state)
    local startX = imgui.GetCursorPosX();
    local avail = kit.remaining_width();
    local count = #ui.SECTIONS;
    local slot = math.floor(avail / math.max(1, count));
    local extra = avail - slot * count;
    for index, section in ipairs(ui.SECTIONS) do
        if (index > 1) then
            imgui.SameLine(0, 0);
        end
        local width = slot;
        if (index <= extra) then
            width = width + 1;
        end
        if (kit.section_tab(section.label, 'section' .. section.id, state.section == section.id, width)) then
            state.section = section.id;
        end
    end
    if (imgui.SetCursorPos ~= nil) then
        imgui.SetCursorPosX(startX);
    end
end

function ui.draw_modals(state, cfg, save)
    favorites.draw_fav_modal(state, cfg, save);
    favorites.draw_rename_modal(state, cfg, save);
    favorites.draw_delete_modal(state, cfg, save);
    scripts.draw_script_rename_modal(state, cfg, save);
    scripts.draw_script_delete_modal(state, cfg, save);
    scripts.draw_script_add_modal(state);
end

function ui.draw_tabs(state, cfg, save)
    kit.sync_nav(state);
    favorites.ensure_favorite_tabs(cfg);
    scripts.ensure_script_tabs(cfg);
    commandsPage.ensure_group_order(cfg);
    local lift = kit.px(kit.PAD) - kit.px(kit.GAP) - 1;
    if (lift > 0 and imgui.SetCursorPosY ~= nil and imgui.GetCursorPosY ~= nil) then
        imgui.SetCursorPosY(imgui.GetCursorPosY() - lift);
    end
    ui.draw_section_tabs(state);
    if (state.section == 'commands' or state.section == 'favorites' or state.section == 'scripts' or state.section == 'presets' or state.section == 'history') then
        if (state.section == 'favorites') then
            local tab = favorites.selected_fav_tab(state, cfg);
            kit.draw_search_bar('favsearch' .. tab.id, favorites.fav_search(state, tab.id));
        elseif (state.section == 'scripts') then
            local tab = scripts.selected_script_tab(state, cfg);
            kit.draw_search_bar('scriptsearch' .. tab.id, scripts.script_search(state, tab.id));
        elseif (state.section == 'presets') then
            kit.draw_search_bar('presetsearch', presets.preset_search(state));
        else
            commandsPage.draw_page_search(state);
        end
    end
    if (state.section == 'commands') then
        commandsPage.draw_group_tabs(state, cfg);
    elseif (state.section == 'favorites') then
        favorites.draw_fav_tabs(state, cfg, save);
    elseif (state.section == 'scripts') then
        scripts.draw_script_tabs(state, cfg, save);
    end
    kit.finish_tab_drag(save);
end

function ui.draw(state, cfg, save)
    kit.scale = kit.clamp_scale(cfg.scale);
    kit.sync_nav(state);
    kit.modalActive = false;
    local section = state.section;
    local page = state.page;
    local pad = kit.px(kit.PAD);
    local _, padX, padY, barH = kit.title_metrics();
    local totalW = tonumber(cfg.windowW) or 700;
    local totalH = tonumber(cfg.windowH) or 550;
    if (totalW < 320) then
        totalW = 320;
    end
    if (totalH < 240) then
        totalH = 240;
    end
    local width = math.floor(totalW * kit.scale + 0.5);
    -- Total height includes the title bar.
    local bodyH = math.max(kit.px(120), math.floor(totalH * kit.scale + 0.5) - barH + 1);
    local scaleChanged = state.drawnScale ~= kit.scale;
    state.drawnScale = kit.scale;
    local condAlways = ImGuiCond_Always or 1;
    local rounding = kit.px(kit.ROUND);
    theme.push();

    local sw, sh = kit.screen_size();
    local totalDrawnH = bodyH + barH - 1;
    local titleX = state.pendingWindowX or cfg.windowX;
    local titleY = state.pendingWindowY or cfg.windowY;
    local placeOnce = state.applyWindowPos ~= false;
    if (titleX == nil or titleY == nil) then
        titleX = math.floor((sw - width) * 0.5);
        titleY = math.floor((sh - totalDrawnH) * 0.5);
        cfg.windowX = titleX;
        cfg.windowY = titleY;
        placeOnce = true;
    else
        titleX = math.floor(titleX + 0.5);
        titleY = math.floor(titleY + 0.5);
    end
    local resizing = false;
    local dragging = false;
    titleX, titleY, resizing = kit.update_shell_resize(cfg, titleX, titleY, width, bodyH, barH);
    if (resizing) then
        totalW = cfg.windowW or totalW;
        totalH = cfg.windowH or totalH;
        width = math.floor(totalW * kit.scale + 0.5);
        bodyH = math.max(kit.px(120), math.floor(totalH * kit.scale + 0.5) - barH + 1);
        placeOnce = true;
        state.applyWindowSize = true;
        state.geomDirty = true;
    end
    local open = { true };
    local titleFlags = kit.bor_flags(ImGuiWindowFlags_NoTitleBar, kit.NO_RESIZE, kit.NO_SCROLL, kit.NO_SCROLL_MOUSE, kit.NO_BACKGROUND, kit.NO_DOCK);
    if (resizing) then
        titleFlags = bit.bor(titleFlags, kit.NO_MOVE);
    end

    -- Let ImGui move the title natively, then anchor the body to its current position.
    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, condAlways);
    end
    if (placeOnce or resizing) then
        imgui.SetNextWindowPos({ titleX, titleY }, condAlways);
    end
    if (placeOnce) then
        state.applyWindowPos = false;
    end
    imgui.SetNextWindowSize({ width, barH }, condAlways);
    imgui.SetNextWindowBgAlpha(0);
    local titleStyles = kit.push_styles({
        { ImGuiStyleVar_WindowPadding, { padX, padY } },
        { ImGuiStyleVar_WindowRounding, 0 },
        { ImGuiStyleVar_WindowBorderSize, 0 },
    });
    local titleFont = false;
    if (imgui.Begin('###gmhelper_title', open, titleFlags)) then
        titleFont = kit.push_font();
        kit.fontScaled = titleFont;
        widgets.configure(kit.scale, kit.fontScaled);
        widgets.sync_widths(commands);

        if (not resizing and imgui.GetWindowPos ~= nil) then
            local nextX, nextY = kit.window_pos();
            nextX = math.floor(nextX + 0.5);
            nextY = math.floor(nextY + 0.5);
            if (nextX ~= titleX or nextY ~= titleY) then
                titleX = nextX;
                titleY = nextY;
                state.pendingWindowX = nextX;
                state.pendingWindowY = nextY;
                state.geomDirty = true;
                state.shellDragging = kit.mouse_held(0);
            elseif (not kit.mouse_held(0)) then
                state.shellDragging = false;
            end
        else
            state.shellDragging = false;
        end
        dragging = state.shellDragging == true;

        local fill, edge = kit.title_chrome(state.panelFocused);
        kit.paint_panel(rounding, state.collapsed and kit.ROUND_ALL or kit.ROUND_TOP, fill, edge);
        kit.draw_title(state);
        state.panelFocused = kit.window_focused() or dragging or resizing;
        kit.pop_font(titleFont);
    end
    imgui.End();
    kit.pop_styles(titleStyles);

    if (not state.collapsed and state.visible ~= false) then
        if (imgui.SetNextWindowDockID ~= nil) then
            pcall(imgui.SetNextWindowDockID, 0, condAlways);
        end
        imgui.SetNextWindowPos({ titleX, titleY + barH - 1 }, condAlways);
        if (state.applyWindowSize ~= false or scaleChanged or resizing) then
            imgui.SetNextWindowSize({ width, bodyH }, condAlways);
            if (not scaleChanged and not resizing) then
                state.applyWindowSize = false;
            end
        end
        imgui.SetNextWindowBgAlpha(0);
        local bodyStyles = kit.push_styles({
            { ImGuiStyleVar_WindowPadding, { pad, pad } },
            { ImGuiStyleVar_WindowRounding, 0 },
            { ImGuiStyleVar_WindowBorderSize, 0 },
            { ImGuiStyleVar_FramePadding, { kit.px(10), kit.px(6) } },
            { ImGuiStyleVar_ItemSpacing, { kit.px(kit.GAP), kit.px(kit.GAP) } },
            { ImGuiStyleVar_ItemInnerSpacing, { kit.px(6), kit.px(4) } },
        });
        local bodyFlags = kit.bor_flags(ImGuiWindowFlags_NoTitleBar, kit.NO_RESIZE, kit.NO_MOVE, kit.NO_SCROLL, kit.NO_SCROLL_MOUSE, kit.NO_BACKGROUND, kit.NO_FRONT, kit.NO_DOCK);
        local bodyFont = false;
        if (imgui.Begin('###gmhelper_body', open, bodyFlags)) then
            bodyFont = kit.push_font();
            kit.fontScaled = bodyFont;
            widgets.configure(kit.scale, kit.fontScaled);
            kit.paint_panel(rounding, kit.ROUND_BOTTOM);
            if (scaleChanged or resizing) then
                state.skipSizeSample = true;
            elseif (not state.skipSizeSample and imgui.GetWindowWidth ~= nil and imgui.GetWindowHeight ~= nil and kit.scale > 0) then
                local sampledW = imgui.GetWindowWidth();
                local sampledH = imgui.GetWindowHeight();
                if (sampledW > 0 and sampledH > 0) then
                    local nextW = math.floor(sampledW / kit.scale + 0.5);
                    local nextH = math.floor((sampledH + barH - 1) / kit.scale + 0.5);
                    if (nextW ~= cfg.windowW or nextH ~= cfg.windowH) then
                        cfg.windowW = nextW;
                        cfg.windowH = nextH;
                        state.geomDirty = true;
                    end
                end
            else
                state.skipSizeSample = false;
            end
            if (kit.window_focused()) then
                state.panelFocused = true;
            end
            if (cfg.welcomeAccepted ~= true) then
                kit.draw_welcome(cfg, save);
            else
                kit.expire_errors(state);
                ui.draw_tabs(state, cfg, save);
                local query = kit.trim_query(state.search[1]);
                widgets.begin_child('page', { 0, 0 }, false);
                widgets.apply_load_scroll('page');
                widgets.apply_font();
                if (section == 'favorites') then
                    favorites.draw_favorites_page(state, cfg, save);
                elseif (section == 'scripts') then
                    scripts.draw_scripts_page(state, cfg, save);
                elseif (section == 'presets') then
                    presets.draw_presets_page(state, cfg, save);
                elseif (section == 'history') then
                    history.draw_history_page(state, cfg, save, query);
                elseif (section == 'settings') then
                    settings.draw_settings_page(state, cfg, save);
                else
                    commandsPage.draw_category_page(state, cfg, save, page, query);
                end
                imgui.EndChild();
            end
            kit.pop_font(bodyFont);
        end
        imgui.End();
        kit.pop_styles(bodyStyles);
    end
    if (state.geomDirty and imgui.IsMouseReleased ~= nil and imgui.IsMouseReleased(0)) then
        state.geomDirty = false;
        if (state.pendingWindowX ~= nil and state.pendingWindowY ~= nil) then
            cfg.windowX = state.pendingWindowX;
            cfg.windowY = state.pendingWindowY;
            state.pendingWindowX = nil;
            state.pendingWindowY = nil;
        end
        save();
    end
    ui.draw_modals(state, cfg, save);
    theme.pop();
end

return ui;
