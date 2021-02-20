-- Link hinting for luakit - web module.
--
-- @submodule domrem_wm
-- @copyright 2016 Aidan Holm <aidanholm@gmail.com>

local select = require("select_wm")
local lousy = require("lousy")
local ui = ipc_channel("domrem_wm")

local evaluators = {
    rem = function(element)
        element:remove()
        return
    end,
}

local page_mode = {}

local function domrem_hint(page, mode, hint)
    local evaluator
    if type(mode.evaluator) == "string" then
        evaluator = evaluators[mode.evaluator]
    elseif type(mode.evaluator) == "function" then
        evaluator = mode.evaluator
    else
        error("bad evaluator type '%s'", type(mode.evaluator))
    end

    local overlay_style = hint.overlay_elem.attr.style
    hint.overlay_elem.attr.style = "display: none;"
    local ret = evaluator(hint.elem, page)
    hint.overlay_elem.attr.style = overlay_style

    ui:emit_signal("domrem_func", page.id, ret)
end

local function domrem(page, all)
    -- Build array of hints to domrem
    local hints = all and select.hints(page) or { select.focused_hint(page) }
    hints = lousy.util.table.filter_array(hints, function (_, hint)
        return not hint.hidden
    end)

    -- Close hint select UI first if not persisting in domrem mode
    local mode = page_mode[page]
    if not mode.persist then
        select.leave(page)
        page_mode[page] = nil
    end

    -- Follow hints in idle cb to ensure select UI is closed if necessary
    luakit.idle_add(function ()
        for _, hint in pairs(hints) do
            domrem_hint(page, mode, hint)
        end
    end)
end

ui:add_signal("domrem", function(_, page, all)
    domrem(page, all)
end)

ui:add_signal("focus", function(_, page, step)
    select.focus(page, step)
end)

ui:add_signal("enter", function(_, page, mode, ignore_case)
    page_mode[page] = mode
    select.enter(page, mode.selector, mode.stylesheet, ignore_case)

    local num_visible_hints = #(select.hints(page))
    ui:emit_signal("matches", page.id, num_visible_hints)
end)

ui:add_signal("changed", function(_, page, hint_pat, text_pat, text)
    local _, num_visible_hints = select.changed(page, hint_pat, text_pat, text)
    ui:emit_signal("matches", page.id, num_visible_hints)
    if num_visible_hints == 1 and text ~= "" then
        domrem(page, false)
    end
end)

ui:add_signal("leave", function (_, page)
    if page_mode[page] then
        page_mode[page] = nil
        select.leave(page)
    end
end)

-- vim: et:sw=4:ts=8:sts=4:tw=80
