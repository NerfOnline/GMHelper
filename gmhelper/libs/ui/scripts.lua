--[[
* GM Helper Scripts tab — user script tabs (saved).
]]

require('common');

local imgui = require('imgui');
local kit = require('libs.ui.kit');
local listload = require('libs.listload');
local theme = require('libs.theme');
local widgets = require('libs.widgets');

local M = {};

function M.ensure_script_tabs(cfg)
    if (type(cfg.scriptTabs) ~= 'table') then
        cfg.scriptTabs = T{};
    end
    cfg.nextScriptId = cfg.nextScriptId or 1;
    local tabs = {};
    for _, tab in ipairs(cfg.scriptTabs) do
        if (type(tab) == 'table' and tab.id ~= 'presets') then
            tab.locked = false;
            if (type(tab.items) ~= 'table') then
                tab.items = T{};
            end
            if (tab.name == nil or tab.name == '') then
                tab.name = 'Tab';
            end
            if (tab.id == nil or tab.id == '') then
                cfg.nextScriptId = (cfg.nextScriptId or 1) + 1;
                tab.id = 'tab' .. tostring(cfg.nextScriptId);
            end
            tabs[#tabs + 1] = tab;
        end
    end
    if (#tabs == 0) then
        tabs[1] = T{ id = 'default', name = 'Default', items = T{} };
    end
    cfg.scriptTabs = tabs;
end

function M.script_tab(cfg, id)
    M.ensure_script_tabs(cfg);
    for _, tab in ipairs(cfg.scriptTabs) do
        if (tab.id == id) then
            return tab;
        end
    end
    return cfg.scriptTabs[1];
end

function M.selected_script_tab(state, cfg)
    M.ensure_script_tabs(cfg);
    local tab = M.script_tab(cfg, state.scriptTab);
    state.scriptTab = tab.id;
    return tab;
end

function M.script_tab_count(cfg)
    M.ensure_script_tabs(cfg);
    return #cfg.scriptTabs;
end

function M.script_search(state, tabId)
    if (state.scriptSearches == nil) then
        state.scriptSearches = {};
    end
    local key = tostring(tabId or 'default');
    if (state.scriptSearches[key] == nil) then
        state.scriptSearches[key] = T{ '' };
    end
    return state.scriptSearches[key];
end

function M.draw_scripts_page(state, cfg, save)
    local tab = M.selected_script_tab(state, cfg);
    local queryBuf = M.script_search(state, tab.id);
    local query = kit.trim_query(queryBuf[1]);
    local items = tab.items or {};
    local token = table.concat({
        'script',
        tostring(tab.id),
        query,
        tostring(#items),
        tostring(state.scriptListEpoch or 0),
    }, '|');
    local cache = listload.cache(state, 'scripts', token, #items);
    listload.pump(cache, function(index)
        local item = items[index];
        if (item == nil) then
            return;
        end
        local label = tostring(item.name or item.id or 'Script');
        if (query == '' or label:lower():find(query, 1, true) ~= nil) then
            cache.rows[#cache.rows + 1] = { item = item, slot = index };
        end
    end);
    kit.draw_list_loading(cache);

    local addW = kit.px(88);
    if (widgets.button('Add', 'scriptlistadd' .. tostring(tab.id), addW, 'primary')) then
        state.scriptAddOpen = true;
        state.scriptAddRequest = true;
    end
    imgui.Spacing();

    if (#items == 0 and cache.ready) then
        widgets.empty_state('No scripts in this tab yet.');
        return;
    end
    if (#cache.rows == 0 and cache.ready) then
        widgets.empty_state('No scripts match.');
        return;
    end
    local numW = kit.line_num_width(#items);
    local startX = imgui.GetCursorPosX();
    for index, row in ipairs(cache.rows) do
        local item = row.item;
        local label = item.name or item.id or 'Script';
        local y = imgui.GetCursorPosY();
        local refH = kit.text_height();
        kit.draw_line_num(row.slot, numW, startX, y, refH);
        imgui.SetCursorPos({ startX + numW, y });
        imgui.Text(tostring(label));
        if (index < #cache.rows) then
            imgui.Separator();
        end
    end
end

function M.find_tab(cfg, name)
    M.ensure_script_tabs(cfg);
    local q = tostring(name or ''):lower();
    if (q == '') then
        return nil;
    end
    for _, tab in ipairs(cfg.scriptTabs) do
        if (tostring(tab.name or ''):lower() == q or tostring(tab.id or ''):lower() == q) then
            return tab;
        end
    end
    return nil;
end

function M.run_line(cfg, tabName, line, save, state)
    local tab = M.find_tab(cfg, tabName);
    if (tab == nil) then
        return false, 'Unknown scripts tab.';
    end
    local index = math.floor(tonumber(line) or 0);
    local item = tab.items and tab.items[index];
    if (item == nil) then
        return false, 'Script line not found.';
    end
    local lines = item.lines or item.commands;
    if (type(lines) ~= 'table' or #lines == 0) then
        return false, 'Script has no commands yet.';
    end
    local say = require('libs.say');
    for _, step in ipairs(lines) do
        local payload = tostring(step or '');
        if (payload ~= '') then
            if (payload:sub(1, 1) ~= '!') then
                payload = '!' .. payload;
            end
            local ok, err = say.send(payload);
            if (not ok) then
                return false, err or 'Could not send.';
            end
            if (save ~= nil and state ~= nil) then
                require('libs.ui.history').push_history(cfg, payload, save, state);
            end
        end
    end
    return true;
end

function M.note_script_menu(state, tab)
    if (imgui.IsItemClicked == nil) then
        return;
    end
    local ok, clicked = pcall(imgui.IsItemClicked, 1);
    if (not ok or clicked ~= true) then
        return;
    end
    local mx, my = kit.mouse_pos();
    state.scriptMenuId = tab.id;
    state.scriptMenuPos = { mx, my };
    state.scriptMenuRequest = true;
end

function M.script_tab_menu(state, cfg)
    if (state.scriptMenuId == nil or imgui.BeginPopup == nil) then
        return;
    end
    local tab = M.script_tab(cfg, state.scriptMenuId);
    if (tab == nil or tab.id ~= state.scriptMenuId) then
        state.scriptMenuRequest = false;
        state.scriptMenuId = nil;
        return;
    end
    if (state.scriptMenuRequest) then
        if (kit.mouse_held(1) or kit.mouse_held(0)) then
            return;
        end
        if (imgui.OpenPopup ~= nil) then
            imgui.OpenPopup('###gmhelper_scriptmenu');
        end
        state.scriptMenuRequest = false;
    end
    local pos = state.scriptMenuPos or { 0, 0 };
    local cond = ImGuiCond_Always or 1;
    if (imgui.SetNextWindowDockID ~= nil) then
        pcall(imgui.SetNextWindowDockID, 0, cond);
    end
    if (not pcall(imgui.SetNextWindowPos, pos, cond, { 0, 0 })) then
        pcall(imgui.SetNextWindowPos, pos, cond);
    end
    local opened = false;
    local ok, result = pcall(imgui.BeginPopup, '###gmhelper_scriptmenu');
    opened = ok and (result == true or (result ~= nil and result ~= false));
    if (not opened) then
        return;
    end
    local itemW = kit.px(84);
    if (imgui.PushStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PushStyleVar(ImGuiStyleVar_SelectableTextAlign, { 0.5, 0.5 });
    end
    if (kit.menu_hit('Rename', true, itemW)) then
        state.scriptRenameId = tab.id;
        state.scriptRename = { tab.name or '' };
        state.scriptRenameRequest = true;
        state.scriptMenuId = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (kit.menu_hit('Delete', M.script_tab_count(cfg) > 1, itemW)) then
        state.scriptDeleteId = tab.id;
        state.scriptDeleteName = tab.name or 'this tab';
        state.scriptDeleteRequest = true;
        state.scriptMenuId = nil;
        if (imgui.CloseCurrentPopup ~= nil) then
            imgui.CloseCurrentPopup();
        end
    end
    if (imgui.PopStyleVar ~= nil and ImGuiStyleVar_SelectableTextAlign ~= nil) then
        imgui.PopStyleVar();
    end
    imgui.EndPopup();
end

function M.next_script_name(cfg)
    local used = {};
    for _, tab in ipairs(cfg.scriptTabs) do
        used[tab.name] = true;
    end
    local number = M.script_tab_count(cfg) + 1;
    local name = 'Tab ' .. tostring(number);
    while (used[name]) do
        number = number + 1;
        name = 'Tab ' .. tostring(number);
    end
    return name;
end

function M.add_script_tab(state, cfg, save)
    M.ensure_script_tabs(cfg);
    cfg.nextScriptId = (cfg.nextScriptId or 1) + 1;
    local tab = T{
        id = 'tab' .. tostring(cfg.nextScriptId),
        name = M.next_script_name(cfg),
        items = T{},
    };
    cfg.scriptTabs[#cfg.scriptTabs + 1] = tab;
    state.scriptTab = tab.id;
    save();
end

function M.draw_script_tabs(state, cfg, save)
    M.ensure_script_tabs(cfg);
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
    local current = M.selected_script_tab(state, cfg);
    for index, tab in ipairs(cfg.scriptTabs) do
        local width = math.max(kit.px(48), math.ceil(kit.text_px(tab.name or '') + kit.px(20)));
        if (cursorX > startX + indent and cursorX + width > right and imgui.SetCursorPos ~= nil) then
            row = row + 1;
            cursorX = startX + indent;
            imgui.SetCursorPos({ cursorX, startY + row * rowH });
        elseif (index > 1) then
            imgui.SameLine(0, 0);
        end
        local clicked = kit.nav_button(tab.name or 'Tab', 'scripttab' .. tab.id, current.id == tab.id, width);
        cursorX = cursorX + width;
        kit.note_tab_drag('script', index);
        kit.accept_tab_drop('script', index, cfg.scriptTabs);
        M.note_script_menu(state, tab);
        if (clicked and not kit.tabDrag.moved) then
            state.scriptTab = tab.id;
            state.section = 'scripts';
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
    if (kit.nav_button('+', 'scripttabadd', false, kit.px(30)) and not kit.tabDrag.moved) then
        M.add_script_tab(state, cfg, save);
    end
    if (kit.tabDrag.kind == 'script' and kit.tabDrag.from ~= nil and imgui.IsItemHovered ~= nil and imgui.IsItemHovered() and imgui.IsMouseDragging ~= nil and imgui.IsMouseDragging(0, 0)) then
        local last = #cfg.scriptTabs;
        if (kit.tabDrag.from ~= last) then
            kit.move_item(cfg.scriptTabs, kit.tabDrag.from, last);
            kit.tabDrag.from = last;
            kit.tabDrag.moved = true;
        end
    end
    if (imgui.SetCursorPos ~= nil) then
        imgui.SetCursorPos({ startX, startY + (row + 1) * rowH - kit.px(kit.GAP) });
        kit.submit_space(0);
    end
    M.script_tab_menu(state, cfg);
end

function M.delete_script_tab(state, cfg, save, tabId)
    if (M.script_tab_count(cfg) <= 1) then
        return;
    end
    local nextTabs = {};
    for _, saved in ipairs(cfg.scriptTabs) do
        if (saved.id ~= tabId) then
            nextTabs[#nextTabs + 1] = saved;
        end
    end
    cfg.scriptTabs = nextTabs;
    M.ensure_script_tabs(cfg);
    if (state.scriptTab == tabId) then
        state.scriptTab = cfg.scriptTabs[1].id;
    end
    kit.bump_list(state, 'scripts');
    save();
end

function M.draw_script_rename_modal(state, cfg, save)
    if (state.scriptRenameRequest ~= true and state.scriptRenameId == nil) then
        return;
    end
    local tab = M.script_tab(cfg, state.scriptRenameId);
    if (tab == nil) then
        state.scriptRenameRequest = false;
        state.scriptRenameId = nil;
        return;
    end
    if (state.scriptRenameRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.scriptRenameRequest == true;
    if (not kit.begin_modal('scriptrename', 'Rename Tab', request)) then
        return;
    end
    state.scriptRenameRequest = false;
    widgets.helper_text('Rename this scripts tab.', theme.colors.text);
    imgui.Spacing();
    imgui.SetNextItemWidth(-1);
    local enterFlags = ImGuiInputTextFlags_EnterReturnsTrue or 64;
    local result = nil;
    local ok, changed = pcall(imgui.InputText, '##scriptrenamefield', state.scriptRename, 64, enterFlags);
    if (ok) then
        result = changed;
    else
        result = imgui.InputText('##scriptrenamefield', state.scriptRename, 64);
    end
    if (type(result) == 'string') then
        state.scriptRename[1] = result;
        result = false;
    end
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Confirm', 'scriptrenameconfirm', buttonW, 'primary') or result == true) then
        if (kit.apply_rename(tab, state.scriptRename, save)) then
            state.scriptRenameId = nil;
            state.scriptRenameRequest = false;
        end
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'scriptrenamecancel', buttonW, 'secondary')) then
        state.scriptRenameId = nil;
        state.scriptRenameRequest = false;
    end
    kit.end_modal('scriptrename');
end

function M.draw_script_delete_modal(state, cfg, save)
    if (state.scriptDeleteRequest ~= true and state.scriptDeleteId == nil) then
        return;
    end
    if (M.script_tab_count(cfg) <= 1) then
        state.scriptDeleteId = nil;
        state.scriptDeleteRequest = false;
        return;
    end
    if (state.scriptDeleteRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.scriptDeleteRequest == true;
    if (not kit.begin_modal('scriptdelete', 'Delete Tab', request)) then
        return;
    end
    state.scriptDeleteRequest = false;
    local name = state.scriptDeleteName or 'this tab';
    imgui.Text('Delete "' .. name .. '"?');
    imgui.PushStyleColor(ImGuiCol_Text, theme.colors.peach);
    local warn = 'Scripts in this tab will be removed.';
    if (imgui.TextWrapped ~= nil) then
        imgui.TextWrapped(warn);
    else
        imgui.Text(warn);
    end
    imgui.PopStyleColor();
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW, buttonW });
    if (widgets.button('Delete', 'scriptdeleteconfirm', buttonW, 'danger')) then
        M.delete_script_tab(state, cfg, save, state.scriptDeleteId);
        state.scriptDeleteId = nil;
        state.scriptDeleteRequest = false;
    end
    imgui.SameLine();
    if (widgets.button('Cancel', 'scriptdeletecancel', buttonW, 'secondary')) then
        state.scriptDeleteId = nil;
        state.scriptDeleteRequest = false;
    end
    kit.end_modal('scriptdelete');
end

function M.draw_script_add_modal(state)
    if (state.scriptAddOpen ~= true) then
        return;
    end
    if (state.scriptAddRequest and kit.mouse_held(0)) then
        return;
    end
    local request = state.scriptAddRequest == true;
    if (not kit.begin_modal('scriptadd', 'Add Script', request)) then
        return;
    end
    state.scriptAddRequest = false;
    widgets.helper_text('Script editor coming soon.', theme.colors.text);
    imgui.Spacing();
    local buttonW = kit.modal_button_width();
    kit.center_buttons({ buttonW });
    if (widgets.button('OK', 'scriptaddok', buttonW, 'primary')) then
        state.scriptAddOpen = false;
    end
    kit.end_modal('scriptadd');
end

return M;
