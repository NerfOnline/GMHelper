--[[
* GM Helper Favorites tab.
]]

require('common');

local imgui = require('imgui');
local kit = require('libs.ui.kit');
local listload = require('libs.listload');
local theme = require('libs.theme');
local widgets = require('libs.widgets');
local cmdpage = require('libs.ui.commands');

local M = {};

function M.ensure_favorite_tabs(cfg)
    if (type(cfg.favoriteTabs) ~= 'table' or #cfg.favoriteTabs == 0) then
        cfg.favoriteTabs = T{
            T{ id = 'default', name = 'Default', commands = T{} },
        };
    end
    cfg.nextFavId = cfg.nextFavId or 1;
    for _, tab in ipairs(cfg.favoriteTabs) do
        if (type(tab.commands) ~= 'table') then
            tab.commands = {};
        end
        for index, raw in ipairs(tab.commands) do
            if (type(raw) == 'string') then
                tab.commands[index] = { id = raw, values = {} };
            elseif (type(raw) == 'table') then
                if (raw.id == nil and type(raw[1]) == 'string') then
                    tab.commands[index] = { id = raw[1], values = {} };
                elseif (raw.values == nil) then
                    raw.values = {};
                end
            end
        end
    end
end

function M.favorite_tab(cfg, id)
    M.ensure_favorite_tabs(cfg);
    for _, tab in ipairs(cfg.favoriteTabs) do
        if (tab.id == id) then
            return tab;
        end
    end
    return cfg.favoriteTabs[1];
end

function M.fav_entry_id(entry)
    if (type(entry) == 'string') then
        return entry;
    end
    if (type(entry) == 'table') then
        return entry.id;
    end
    return nil;
end

function M.command_is_favorited(cfg, commandId)
    if (commandId == nil or commandId == '') then
        return false;
    end
    M.ensure_favorite_tabs(cfg);
    for _, tab in ipairs(cfg.favoriteTabs) do
        for _, entry in ipairs(tab.commands or {}) do
            if (M.fav_entry_id(entry) == commandId) then
                return true;
            end
        end
    end
    return false;
end

function M.add_favorite_to(cfg, tabId, commandId, values, save, state)
    local tab = M.favorite_tab(cfg, tabId);
    if (tab == nil or commandId == nil or commandId == '') then
        return;
    end
    if (tab.commands == nil) then
        tab.commands = {};
    end
    tab.commands[#tab.commands + 1] = {
        id = commandId,
        values = values or {},
    };
    kit.bump_list(state, 'favorites');
    save();
end

function M.remove_favorite_at(cfg, tabId, slot, save, state)
    local tab = M.favorite_tab(cfg, tabId);
    if (tab == nil or tab.commands == nil or slot == nil) then
        return;
    end
    if (tab.commands[slot] == nil) then
        return;
    end
    table.remove(tab.commands, slot);
    kit.bump_list(state, 'favorites');
    save();
end

function M.selected_fav_tab(state, cfg)
    M.ensure_favorite_tabs(cfg);
    local tab = M.favorite_tab(cfg, state.favTab);
    state.favTab = tab.id;
    return tab;
end

function M.fav_search(state, tabId)
    if (state.favSearch == nil) then
        state.favSearch = {};
    end
    if (state.favSearch[tabId] == nil) then
        state.favSearch[tabId] = { '' };
    end
    return state.favSearch[tabId];
end

function M.draw_favorites_page(state, cfg, save)
    local tab = M.selected_fav_tab(state, cfg);
    local queryBuf = M.fav_search(state, tab.id);
    local query = kit.trim_query(queryBuf[1]);
    local ids = tab.commands or {};
    local token = table.concat({
        'fav',
        tostring(tab.id),
        query,
        tostring(#ids),
        tostring(state.favListEpoch or 0),
    }, '|');
    local cache = listload.cache(state, 'favorites', token, #ids);
    listload.pump(cache, function(index)
        local entry = ids[index];
        local commandId = M.fav_entry_id(entry);
        local command = kit.command_by_id(commandId);
        if (command ~= nil and kit.matches_query(command, query)) then
            cache.rows[#cache.rows + 1] = {
                command = command,
                entry = entry,
                slot = index,
            };
        end
    end);
    kit.draw_list_loading(cache);
    if (#ids == 0) then
        widgets.empty_state('Favorite a command to pin it here. Current field values are kept when you favorite.');
        return;
    end
    if (#cache.rows == 0 and cache.ready) then
        widgets.empty_state('No commands match.');
        return;
    end
    local nameCommands = {};
    for _, row in ipairs(cache.rows) do
        nameCommands[#nameCommands + 1] = row.command;
    end
    local nameCol = kit.name_column(nameCommands);
    local numW = kit.line_num_width(#ids);
    local listSpace = kit.begin_command_list_spacing();
    for index, row in ipairs(cache.rows) do
        local command = row.command;
        local bag = kit.bag_for_entry(row.entry, command);
        local errKey = 'fav' .. tostring(tab.id) .. '_' .. tostring(row.slot);
        cmdpage.draw_command(command, bag, 'favorite', nil, function()
            M.remove_favorite_at(cfg, tab.id, row.slot, save, state);
        end, function()
            kit.run_command(cfg, command, bag, save, state.errors, errKey, state);
        end, state.errors[errKey], nameCol, index < #cache.rows, tostring(tab.id) .. '_' .. tostring(row.slot), nil, row.slot, numW);
    end
    kit.end_command_list_spacing(listSpace);
end

function M.find_tab(cfg, name)
    M.ensure_favorite_tabs(cfg);
    local q = tostring(name or ''):lower();
    if (q == '') then
        return nil;
    end
    for _, tab in ipairs(cfg.favoriteTabs) do
        if (tostring(tab.name or ''):lower() == q or tostring(tab.id or ''):lower() == q) then
            return tab;
        end
    end
    return nil;
end

function M.run_line(cfg, tabName, line, save, state)
    local tab = M.find_tab(cfg, tabName);
    if (tab == nil) then
        return false, 'Unknown favorites tab.';
    end
    local index = math.floor(tonumber(line) or 0);
    local entry = tab.commands and tab.commands[index];
    if (entry == nil) then
        return false, 'Favorite line not found.';
    end
    local command = kit.command_by_id(M.fav_entry_id(entry));
    if (command == nil) then
        return false, 'Favorite command missing.';
    end
    local bag = kit.bag_for_entry(entry, command);
    local payload, err = require('libs.say').build(command, bag);
    if (payload == nil) then
        return false, err or 'Could not build favorite.';
    end
    if (not kit.run_payload(cfg, payload, save, state.errors or {}, 'cli_fav', state)) then
        return false, (state.errors and state.errors.cli_fav) or 'Could not send.';
    end
    return true;
end

function M.note_fav_menu(state, tab)
    if (imgui.IsItemClicked == nil) then
        return;
    end
    local ok, clicked = pcall(imgui.IsItemClicked, 1);
    if (not ok or clicked ~= true) then
        return;
    end
    local mx, my = kit.mouse_pos();
    state.favMenuId = tab.id;
    state.favMenuPos = { mx, my };
    state.favMenuRequest = true;
end

function M.fav_tab_menu(state, cfg)
    if (state.favMenuId == nil or imgui.BeginPopup == nil) then
        return;
    end
    local tab = M.favorite_tab(cfg, state.favMenuId);
    if (tab == nil or tab.id ~= state.favMenuId) then
        state.favMenuRequest = false;
        state.favMenuId = nil;
        return;
    end
    if (state.favMenuRequest) then
        if (kit.mouse_held(1) or kit.mouse_held(0)) then
            return;
        end
        if (imgui.OpenPopup ~= nil) then
            imgui.OpenPopup('###gmhelper_favmenu');
        end
        state.favMenuRequest = false;
    end
    local pos = state.favMenuPos or { 0, 0 };
    local cond = ImGuiCond_Always or 1;
    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    -- Top-left of the menu at the cursor so it opens toward the bottom-right.
    if (not pcall(imgui.SetNextWindowPos, pos, cond, { 0, 0 })) then
        pcall(imgui.SetNextWindowPos, pos, cond);
    end
    local opened = false;
    local ok, result = pcall(imgui.BeginPopup, '###gmhelper_favmenu');
    opened = ok and (result == true or (result ~= nil and result ~= false));
    if (not opened) then
        return;
    end
    local itemW = kit.px(84);
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_SelectableTextAlign, { 0.5, 0.5 });
    end
    if (kit.menu_hit('Rename', true, itemW)) then
        state.favRenameId = tab.id;
        state.favRename = { tab.name or '' };
        state.favRenameRequest = true;
        state.favMenuId = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (kit.menu_hit('Delete', #cfg.favoriteTabs > 1, itemW)) then
        state.favDeleteId = tab.id;
        state.favDeleteName = tab.name or 'this tab';
        state.favDeleteRequest = true;
        state.favMenuId = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (imgui.PopStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PopStyleVar();
    end
    imgui.EndPopup();
end

function M.next_fav_name(cfg)
    local used = {};
    for _, tab in ipairs(cfg.favoriteTabs) do
        used[tab.name] = true;
    end
    local number = #cfg.favoriteTabs + 1;
    local name = 'Tab ' .. tostring(number);
    while (used[name]) do
        number = number + 1;
        name = 'Tab ' .. tostring(number);
    end
    return name;
end

function M.add_fav_tab(state, cfg, save)
    cfg.nextFavId = (cfg.nextFavId or 1) + 1;
    local tab = T{
        id = 'tab' .. tostring(cfg.nextFavId),
        name = M.next_fav_name(cfg),
        commands = T{},
    };
    cfg.favoriteTabs[#cfg.favoriteTabs + 1] = tab;
    state.favTab = tab.id;
    save();
end

function M.draw_fav_tabs(state, cfg, save)
    M.ensure_favorite_tabs(cfg);
    local startX = imgui.GetCursorPosX();
    local startY = imgui.GetCursorPosY();
    local indent = kit.px(kit.ROUND);
    if (imgui.SetCursorPosX ~= nil) then
        imgui.SetCursorPosX(startX + indent);
    end
    local usable = math.max(1, kit.remaining_width() - indent);
    local right = startX + indent + usable;
    local cursorX = startX + indent;
    local row = 0;
    local rowH = kit.px(30);
    local current = M.selected_fav_tab(state, cfg);
    for index, tab in ipairs(cfg.favoriteTabs) do
        local width = math.max(kit.px(48), math.ceil(kit.text_px(tab.name or '') + kit.px(20)));
        if (cursorX > startX + indent and cursorX + width > right and imgui.SetCursorPos ~= nil) then
            row = row + 1;
            cursorX = startX + indent;
            imgui.SetCursorPos({ cursorX, startY + row * rowH });
        elseif (index > 1) then
            imgui.SameLine(0, 0);
        end
        local clicked = kit.nav_button(tab.name or 'Tab', 'favtab' .. tab.id, current.id == tab.id, width);
        cursorX = cursorX + width;
        kit.note_tab_drag('fav', index);
        kit.accept_tab_drop('fav', index, cfg.favoriteTabs);
        M.note_fav_menu(state, tab);
        if (clicked and not kit.tabDrag.moved) then
            state.favTab = tab.id;
            state.section = 'favorites';
        end
    end
    local addW = kit.px(30);
    if (cursorX > startX + indent and cursorX + addW > right and imgui.SetCursorPos ~= nil) then
        row = row + 1;
        cursorX = startX + indent;
        imgui.SetCursorPos({ cursorX, startY + row * rowH });
    else
        imgui.SameLine(0, 0);
    end
    if (kit.nav_button('+', 'favtabadd', false, kit.px(30)) and not kit.tabDrag.moved) then
        M.add_fav_tab(state, cfg, save);
    end
    if (kit.tabDrag.kind == 'fav' and kit.tabDrag.from ~= nil and imgui.IsItemHovered ~= nil and imgui.IsItemHovered() and imgui.IsMouseDragging ~= nil and imgui.IsMouseDragging(0, 0)) then
        local last = #cfg.favoriteTabs;
        if (kit.tabDrag.from ~= last) then
            kit.move_item(cfg.favoriteTabs, kit.tabDrag.from, last);
            kit.tabDrag.from = last;
            kit.tabDrag.moved = true;
        end
    end
    if (imgui.SetCursorPos ~= nil) then
        imgui.SetCursorPos({ startX, startY + (row + 1) * rowH - kit.px(kit.GAP) });
        kit.submit_space(0);
    end
    M.fav_tab_menu(state, cfg);
end

function M.favorite_picker(cfg, choiceId)
    M.ensure_favorite_tabs(cfg);
    local shown = M.favorite_tab(cfg, choiceId).name or 'Default';
    local tabLabels = {};
    for _, tab in ipairs(cfg.favoriteTabs) do
        tabLabels[#tabLabels + 1] = tab.name or 'Tab';
    end
    local flags = ImGuiComboFlags_PopupAlignLeft;
    local opened, centered, listW = widgets.begin_labels_combo('##favpicktab', shown, tabLabels, flags, 'fill');
    local picked = choiceId;
    if (opened) then
        for _, tab in ipairs(cfg.favoriteTabs) do
            if (widgets.labels_combo_option('favpick' .. tab.id, tab.name or 'Tab', tab.id == picked, listW)) then
                picked = tab.id;
            end
        end
        widgets.end_labels_combo(opened, centered);
    end
    return picked;
end

function M.delete_fav_tab(state, cfg, save, tabId)
    if (#cfg.favoriteTabs <= 1) then
        return;
    end
    local nextTabs = {};
    for _, saved in ipairs(cfg.favoriteTabs) do
        if (saved.id ~= tabId) then
            nextTabs[#nextTabs + 1] = saved;
        end
    end
    cfg.favoriteTabs = nextTabs;
    if (state.favTab == tabId) then
        state.favTab = nextTabs[1] and nextTabs[1].id or nil;
    end
    kit.bump_list(state, 'favorites');
    save();
end

function M.draw_fav_modal(state, cfg, save)
    if (state.favPick == nil) then
        return;
    end
    if (state.favPickRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.favPickRequest == true;
    if (not kit.begin_modal('favpick', 'Favorite', request)) then
        return;
    end
    state.favPickRequest = false;
    widgets.helper_text('Choose a favorites tab for this command.', theme.colors.text);
    imgui.Spacing();
    state.favPick.tabId = M.favorite_picker(cfg, state.favPick.tabId);
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'favpickconfirm', buttonW, 'primary')) then
        M.add_favorite_to(
            cfg,
            state.favPick.tabId,
            state.favPick.commandId,
            state.favPick.values,
            save,
            state
        );
        state.favTab = state.favPick.tabId;
        state.favPick = nil;
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'favpickcancel', buttonW, 'secondary')) then
        state.favPick = nil;
    end
    kit.end_modal('favpick');
end

function M.draw_rename_modal(state, cfg, save)
    if (state.favRenameRequest ~= true and state.favRenameId == nil) then
        return;
    end
    local tab = M.favorite_tab(cfg, state.favRenameId);
    if (tab == nil) then
        state.favRenameRequest = false;
        state.favRenameId = nil;
        return;
    end
    if (state.favRenameRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.favRenameRequest == true;
    if (not kit.begin_modal('favrename', 'Rename Tab', request)) then
        return;
    end
    state.favRenameRequest = false;
    widgets.helper_text('Rename this favorites tab.', theme.colors.text);
    imgui.Spacing();
    imgui.SetNextItemWidth(-1);
    local enterFlags = ImGuiInputTextFlags_EnterReturnsTrue or 64;
    local result = nil;
    local ok, changed = pcall(imgui.InputText, '##favrenamefield', state.favRename, 64, enterFlags);
    if (ok) then
        result = changed;
    else
        result = imgui.InputText('##favrenamefield', state.favRename, 64);
    end
    if (type(result) == 'string') then
        state.favRename[1] = result;
        result = false;
    end
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'favrenameconfirm', buttonW, 'primary') or result == true) then
        if (kit.apply_rename(tab, state.favRename, save)) then
            state.favRenameId = nil;
            state.favRenameRequest = false;
        end
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'favrenamecancel', buttonW, 'secondary')) then
        state.favRenameId = nil;
        state.favRenameRequest = false;
    end
    kit.end_modal('favrename');
end

function M.draw_delete_modal(state, cfg, save)
    if (state.favDeleteRequest ~= true and state.favDeleteId == nil) then
        return;
    end
    if (#cfg.favoriteTabs <= 1) then
        state.favDeleteRequest = false;
        state.favDeleteId = nil;
        return;
    end
    if (state.favDeleteRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.favDeleteRequest == true;
    if (not kit.begin_modal('favdelete', 'Delete Tab', request)) then
        return;
    end
    state.favDeleteRequest = false;
    local name = state.favDeleteName or 'this tab';
    imgui.Text('Delete "' .. name .. '"?');
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.peach);
    local warn = 'Commands in this tab will be removed from favorites.';
    if (imgui.TextWrapped ~= nil) then
        imgui.TextWrapped(warn);
    elseif (imgui.PushTextWrapPos ~= nil) then
        local wrapX = imgui.GetCursorPosX() + kit.remaining_width();
        imgui.PushTextWrapPos(wrapX);
        imgui.Text(warn);
        imgui.PopTextWrapPos();
    else
        imgui.Text('Commands in this tab will be');
        imgui.Text('removed from favorites.');
    end
    imgui.PopStyleColor();
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Delete', 'favdeleteconfirm', buttonW, 'danger')) then
        M.delete_fav_tab(state, cfg, save, state.favDeleteId);
        state.favDeleteId = nil;
        state.favDeleteRequest = false;
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'favdeletecancel', buttonW, 'secondary')) then
        state.favDeleteId = nil;
        state.favDeleteRequest = false;
    end
    kit.end_modal('favdelete');
end

return M;
