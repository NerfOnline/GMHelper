--[[
* GM Helper theme. Phoenix site colors on solid window and section backgrounds.
* Palette from https://phoenix-xi.com/approved-addons
]]

require('common');

local imgui = require('imgui');

local theme = {};

theme.colors = {
    abyss = { 0x18 / 255, 0x0e / 255, 0x0e / 255, 1.0 },
    glass = { 0x29 / 255, 0x1c / 255, 0x1c / 255, 1.0 },
    deep = { 0x29 / 255, 0x1c / 255, 0x1c / 255, 1.0 },
    surface = { 0x32 / 255, 0x1f / 255, 0x1f / 255, 0.94 },
    field = { 0x22 / 255, 0x16 / 255, 0x16 / 255, 1.0 },
    fieldHover = { 0x28 / 255, 0x1b / 255, 0x1b / 255, 1.0 },
    fieldActive = { 0x2e / 255, 0x1f / 255, 0x1f / 255, 1.0 },
    titleIdle = { 0x10 / 255, 0x09 / 255, 0x09 / 255, 1.0 },
    titleActive = { 0x2a / 255, 0x16 / 255, 0x16 / 255, 1.0 },
    titleHover = { 0x3c / 255, 0x1e / 255, 0x1e / 255, 1.0 },
    text = { 0xff / 255, 0xf8 / 255, 0xf8 / 255, 1.0 },
    secondary = { 0xea / 255, 0xe1 / 255, 0xe1 / 255, 1.0 },
    peach = { 0xd2 / 255, 0xab / 255, 0xab / 255, 1.0 },
    muted = { 0x8a / 255, 0x6b / 255, 0x6b / 255, 1.0 },
    dim = { 0x5a / 255, 0x45 / 255, 0x45 / 255, 1.0 },
    royal = { 0xc5 / 255, 0x51 / 255, 0x51 / 255, 1.0 },
    royalHover = { 0xd4 / 255, 0x5e / 255, 0x5e / 255, 1.0 },
    royalActive = { 0xb8 / 255, 0x40 / 255, 0x40 / 255, 1.0 },
    remove = { 0xe0 / 255, 0x40 / 255, 0x40 / 255, 1.0 },
    removeHover = { 0xea / 255, 0x58 / 255, 0x58 / 255, 1.0 },
    border = { 0xd2 / 255, 0xab / 255, 0xab / 255, 0.20 },
    borderSoft = { 0xd2 / 255, 0xab / 255, 0xab / 255, 0.12 },
    clear = { 0, 0, 0, 0 },
};

local pushedColors = 0;
local pushedVars = 0;

local function pushColor(idx, color)
    imgui.PushStyleColor(idx, color);
    pushedColors = pushedColors + 1;
end

local function pushVar(idx, ...)
    imgui.PushStyleVar(idx, ...);
    pushedVars = pushedVars + 1;
end

function theme.push()
    pushedColors = 0;
    pushedVars = 0;

    pushVar(ImGuiStyleVar_WindowRounding, 8);
    pushVar(ImGuiStyleVar_ChildRounding, 6);
    pushVar(ImGuiStyleVar_FrameRounding, 4);
    pushVar(ImGuiStyleVar_PopupRounding, 6);
    pushVar(ImGuiStyleVar_ScrollbarRounding, 6);
    pushVar(ImGuiStyleVar_WindowPadding, { 16, 14 });
    pushVar(ImGuiStyleVar_FramePadding, { 10, 6 });
    pushVar(ImGuiStyleVar_ItemSpacing, { 8, 8 });
    pushVar(ImGuiStyleVar_ItemInnerSpacing, { 6, 4 });
    pushVar(ImGuiStyleVar_WindowBorderSize, 1);
    pushVar(ImGuiStyleVar_FrameBorderSize, 1);
    pushVar(ImGuiStyleVar_ScrollbarSize, 10);

    pushColor(ImGuiCol_Text, theme.colors.text);
    pushColor(ImGuiCol_TextDisabled, theme.colors.muted);
    pushColor(ImGuiCol_WindowBg, theme.colors.abyss);
    pushColor(ImGuiCol_ChildBg, theme.colors.glass);
    pushColor(ImGuiCol_PopupBg, { 0x18 / 255, 0x0e / 255, 0x0e / 255, 1.0 });
    if (ImGuiCol_ModalWindowDimBg ~= nil) then
        pushColor(ImGuiCol_ModalWindowDimBg, { 0.02, 0.01, 0.01, 0.55 });
    end
    pushColor(ImGuiCol_Border, theme.colors.border);
    pushColor(ImGuiCol_FrameBg, theme.colors.field);
    pushColor(ImGuiCol_FrameBgHovered, theme.colors.fieldHover);
    pushColor(ImGuiCol_FrameBgActive, theme.colors.fieldActive);
    pushColor(ImGuiCol_TitleBg, theme.colors.abyss);
    pushColor(ImGuiCol_TitleBgActive, theme.colors.abyss);
    pushColor(ImGuiCol_ScrollbarBg, { 0x18 / 255, 0x0e / 255, 0x0e / 255, 0.35 });
    pushColor(ImGuiCol_ScrollbarGrab, { 0xd2 / 255, 0xab / 255, 0xab / 255, 0.35 });
    pushColor(ImGuiCol_ScrollbarGrabHovered, { 0xd2 / 255, 0xab / 255, 0xab / 255, 0.55 });
    pushColor(ImGuiCol_ScrollbarGrabActive, theme.colors.royal);
    pushColor(ImGuiCol_Button, { 0x32 / 255, 0x1f / 255, 0x1f / 255, 0.55 });
    pushColor(ImGuiCol_ButtonHovered, { 0xc5 / 255, 0x51 / 255, 0x51 / 255, 0.35 });
    pushColor(ImGuiCol_ButtonActive, { 0xc5 / 255, 0x51 / 255, 0x51 / 255, 0.55 });
    pushColor(ImGuiCol_Header, { 0xc5 / 255, 0x51 / 255, 0x51 / 255, 0.28 });
    pushColor(ImGuiCol_HeaderHovered, { 0xc5 / 255, 0x51 / 255, 0x51 / 255, 0.42 });
    pushColor(ImGuiCol_HeaderActive, { 0xc5 / 255, 0x51 / 255, 0x51 / 255, 0.55 });
    pushColor(ImGuiCol_Separator, theme.colors.borderSoft);
    pushColor(ImGuiCol_ResizeGrip, { 0xd2 / 255, 0xab / 255, 0xab / 255, 0.25 });
    pushColor(ImGuiCol_ResizeGripHovered, theme.colors.royal);
    pushColor(ImGuiCol_ResizeGripActive, theme.colors.royalHover);
end

function theme.pop()
    if (pushedColors > 0) then
        imgui.PopStyleColor(pushedColors);
    end
    if (pushedVars > 0) then
        imgui.PopStyleVar(pushedVars);
    end
    pushedColors = 0;
    pushedVars = 0;
end

local function mix_color(base, tint, amount)
    local rest = 1 - amount;
    return {
        base[1] * rest + tint[1] * amount,
        base[2] * rest + tint[2] * amount,
        base[3] * rest + tint[3] * amount,
        1,
    };
end

local function curve_inset(radius, distance)
    if (radius <= 0 or distance >= radius) then
        return 0;
    end
    local remain = radius * radius - (radius - distance) * (radius - distance);
    if (remain <= 0) then
        return radius;
    end
    return radius - math.sqrt(remain);
end

function theme.paint_tab_highlight(x1, y1, x2, y2, bar, panel, radius, strength)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw == nil or draw.AddRectFilledMultiColor == nil) then
        return;
    end
    bar = math.max(1, bar or 2);
    panel = panel or theme.colors.glass;
    radius = radius or 0;
    strength = strength or 1;
    if (strength < 0) then
        strength = 0;
    elseif (strength > 1) then
        strength = 1;
    end
    local fadeEnd = y2 - bar;
    local span = math.max(1, fadeEnd - y1);
    local slices = 16;
    for index = 0, slices - 1 do
        local t0 = index / slices;
        local t1 = (index + 1) / slices;
        local stay0 = t0 ^ 0.45;
        local stay1 = t1 ^ 0.45;
        local top = mix_color(panel, theme.colors.royal, 0.3 * stay0 * strength);
        local bottom = mix_color(panel, theme.colors.royal, 0.3 * stay1 * strength);
        local rowTop = y1 + span * t0;
        local inset = curve_inset(radius, rowTop - y1);
        pcall(draw.AddRectFilledMultiColor, draw, {
            x1 + inset,
            rowTop,
        }, {
            x2 - inset,
            y1 + span * t1,
        }, theme.col32(top), theme.col32(top), theme.col32(bottom), theme.col32(bottom));
    end
    if (draw.AddRectFilled == nil) then
        return;
    end
    local royal = theme.colors.royal;
    pcall(draw.AddRectFilled, draw, { x1, fadeEnd }, { x2, y2 }, theme.col32({
        royal[1],
        royal[2],
        royal[3],
        (royal[4] or 1) * strength,
    }));
end

function theme.paint_row_highlight(x1, y1, x2, y2, bar)
    local draw = imgui.GetWindowDrawList ~= nil and imgui.GetWindowDrawList() or nil;
    if (draw == nil or draw.AddRectFilledMultiColor == nil) then
        return;
    end
    bar = math.max(3, bar or 3);
    local panel = theme.colors.glass;
    local fadeStart = x1 + bar;
    local span = math.max(1, x2 - fadeStart);
    local slices = 16;
    for index = 0, slices - 1 do
        local t0 = index / slices;
        local t1 = (index + 1) / slices;
        local stay0 = (1 - t0) ^ 0.45;
        local stay1 = (1 - t1) ^ 0.45;
        local left = mix_color(panel, theme.colors.royal, 0.3 * stay0);
        local right = mix_color(panel, theme.colors.royal, 0.3 * stay1);
        pcall(draw.AddRectFilledMultiColor, draw, {
            fadeStart + span * t0,
            y1,
        }, {
            fadeStart + span * t1,
            y2,
        }, theme.col32(left), theme.col32(right), theme.col32(right), theme.col32(left));
    end
    if (draw.AddRectFilled ~= nil) then
        pcall(draw.AddRectFilled, draw, { x1, y1 }, { x1 + bar, y2 }, theme.col32(theme.colors.royal));
    end
end

function theme.col32(color, alpha)
    local packed = { color[1], color[2], color[3], alpha or color[4] };
    if (imgui.GetColorU32 ~= nil) then
        return imgui.GetColorU32(packed);
    end
    local a = math.floor(packed[4] * 255);
    return bit.bor(
        bit.lshift(a, 24),
        bit.lshift(math.floor(packed[3] * 255), 16),
        bit.lshift(math.floor(packed[2] * 255), 8),
        math.floor(packed[1] * 255)
    );
end

return theme;
