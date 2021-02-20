--- Link hinting for luakit.
--
-- Link hints allow interacting with web pages without the use of a
-- mouse. When `domrem` mode is entered, all clickable elements are
-- highlighted and labeled with a short number. Typing either an element
-- number or part of the element text will "domrem" that hint, issuing a
-- mouse click. This is most commonly used to click links without using
-- the mouse and focus text input boxes. In addition, the `ex-domrem`
-- mode offers several variations on this behavior. For example, instead
-- of clicking, the URI of a domremed link can be copied into the clipboard.
-- Another example would be hinting all images on the page, and opening the
-- domremed image in a new tab.
--
-- # Customizing hint labels
--
-- If you prefer to use letters instead of numbers for hint labels (useful if
-- you use a non-qwerty keyboard layout), this can be done by replacing the
-- @ref{label_maker} function:
--
--     local select = require "select"
--
--     select.label_maker = function ()
--         local chars = charset("asdfqwerzxcv")
--         return trim(sort(reverse(chars)))
--     end
--
-- Here, the `charset()` function generates hints using the specified letters.
-- For a full explanation of what the `trim(sort(reverse(...)))` construction
-- does, see the @ref{select} module documentation; the short explanation is
-- that it makes hints as short as possible, saving you typing.
--
-- Note: this requires modifying the @ref{select} module because the actual
-- link hinting interface is implemented in the `select` module; the
-- `domrem` module provides the `domrem` and `ex-domrem` user interface on top
-- of that.
--
-- ## Hinting with non-latin letters
--
-- If you use a keyboard layout with non-latin keys, you may prefer to use
-- non-latin letters to hint. For example, using the Cyrillic alphabet, the
-- above code could be changed to the domreming:
--
--     ...
--     local chars = charset("ФЫВАПРОЛДЖЭ")
--     ...
--
-- ## Hint text direction
--
-- Hints consisting entirely of characters which are drawn Left-to-Right
-- (eg Latin, Cyrillic) or characters drawn Right-to-Left (eg Arabic, Hebrew),
-- will render intuitively in the appropriate direction.
-- Hints will be drawn non-intuitively if they contain a mix of Left-to-Right
-- and Right-to-Left characters.
--
-- Punctuation characters do not have an intrinsic direction, and will be drawn
-- using the direction specified by the HTML/CSS context in which they appear.
-- This leads to corner cases if the hint charset contains punctuation characters,
-- for example:
--
--     ...
--     local chars = charset("fjdksla;ghutnvir")
--     ...
--
-- In this case, hints will display intuitively if used on pages which are
-- drawn Left-to-Right, but not on pages drawn Right-to-Left.
--
-- To guard against this, it is recommended that if punctuation characters
-- are used in hints, a clause should be added to a user stylesheet giving
-- an explicit text direction eg:
--
--     ...
--     #luakit_select_overlay .hint_label { direction: ltr; }
--     ...
--
-- ## Alternating between left- and right-handed letters
--
-- To make link hints easier to type, you may prefer to have them alternate
-- between letters on the left and right side of your keyboard. This is easy to
-- do with the `interleave()` label composer function.
--
--     ...
--     local chars = interleave("qwertasdfgzxcvb", "yuiophjklnm")
--     ...
--
-- # Matching only hint labels, not element text
--
-- If you prefer not to match element text, and wish to select hints only by
-- their label, this can be done by specifying the @ref{pattern_maker}:
--
--     -- Match only hint label text
--     domrem.pattern_maker = domrem.pattern_styles.match_label
--
-- # Ignoring element text case
--
-- To ignore element text case when filtering hints, set the domreming option:
--
--     -- Uncomment if you want to ignore case when matching
--     domrem.ignore_case = true
--
-- @module domrem
-- @copyright 2010-2012 Mason Larobina <mason.larobina@gmail.com>
-- @copyright 2010-2011 Fabian Streitel <karottenreibe@gmail.com>

local window = require("window")
local new_mode = require("modes").new_mode
local modes = require("modes")
local add_binds = modes.add_binds
local lousy = require("lousy")
local theme = lousy.theme.get()

local _M = {}

local domrem_wm = require_web_module("domrem_wm")

--- Duration to ignore keypresses after domreming a hint. 200ms by default.
--
-- After each domrem ignore all keys pressed by the user to prevent the
-- accidental activation of other key bindings.
-- @type number
-- @readwrite
_M.ignore_delay = 200

--- CSS applied to the domrem mode overlay.
-- @type string
-- @readwrite
_M.stylesheet = [[
#luakit_select_overlay {
    position: absolute;
    left: 0;
    top: 0;
    z-index: 2147483647; /* Maximum allowable on WebKit */
}

#luakit_select_overlay .hint_overlay {
    display: block;
    position: absolute;
    background-color: ]] .. (theme.hint_overlay_bg     or "rgba(255,255,153,0.3)") .. [[;
    border:           ]] .. (theme.hint_overlay_border or "1px dotted #000")       .. [[;
    opacity:          ]] .. (theme.hint_opacity        or "0.3")                   .. [[;
}

#luakit_select_overlay .hint_label {
    display: block;
    position: absolute;
    background-color: ]] .. (theme.hint_bg     or "#000088")                             .. [[;
    border:           ]] .. (theme.hint_border or "1px dashed #000")                     .. [[;
    color:            ]] .. (theme.hint_fg     or "#fff")                                .. [[;
    font:             ]] .. (theme.hint_font   or "10px monospace, courier, sans-serif") .. [[;
}

#luakit_select_overlay .hint_selected {
    background-color: ]] .. (theme.hint_overlay_selected_bg     or "rgba(0,255,0,0.3)") .. [[ !important;
    border:           ]] .. (theme.hint_overlay_selected_border or "1px dotted #000")   .. [[;
}
]]

-- Lua regex escape function
local function regex_escape(s)
    local escape_chars = "%^$().[]*+-?"
    local escape_pat = '([' .. escape_chars:gsub("(.)", "%%%1") .. '])'
    return s:gsub(escape_pat, "%%%1")
end

local re_match_text = function (text) return nil, text end
local re_match_both = function (text) return text, text end
local match_label_re_text = function (text)
    return #text > 0 and "^"..regex_escape(text) or "", text
end
local match_label = function (text)
    return #text > 0 and "^"..regex_escape(text) or "", nil
end

--- Table of functions used to select a hint matching style.
-- @type {[string]=function}
-- @readonly
_M.pattern_styles = {
    re_match_text = re_match_text, -- Regex match target text only.
    re_match_both = re_match_both, -- Regex match both hint label or target text
    match_label_re_text = match_label_re_text, -- String match hint label & regex match text
    match_label = match_label, -- String match hint label only
}

--- Hint matching style functions.
-- @type function
-- @readwrite
_M.pattern_maker = _M.pattern_styles.match_label_re_text

--- Whether text case should be ignored in domrem mode. True by default.
-- @type boolean
-- @readwrite
_M.ignore_case = true

local function focus(w, step)
    domrem_wm:emit_signal(w.view, "focus", step)
end

local hit_nop = function () return true end

local function ignore_keys(w)
    local delay = _M.ignore_delay
    if not delay or delay == 0 then return end
    -- Replace w:hit(..) with a no-op
    w.hit = hit_nop
    local timer = timer{ interval = delay }
    timer:add_signal("timeout", function (t)
        t:stop()
        w.hit = nil
    end)
    timer:start()
end

local function do_domrem(w, all)
    domrem_wm:emit_signal(w.view, "domrem", all)
end

local function domrem_all_hints(w)
    do_domrem(w, true)
end

local function domrem_func_cb(w, ret)
    local mode = w.domrem_state.mode

    if mode.func then mode.func(ret) end

    -- don't set mode if func() changed it (e.g. to command mode)
    if w:is_mode("domrem") or w:is_mode("ex-domrem") then
        if mode.persist then
            w:set_input("")
            w:set_mode("domrem", mode)
        elseif ret ~= "form-active" and ret ~= "root-active" then
            w:set_mode()
        end
    end

    ignore_keys(w)
end

local function matches_cb(w, n)
    w:set_ibar_theme(n > 0 and "ok" or "error")
end

domrem_wm:add_signal("domrem_func", function(_, page_id, ret)
    for _, w in pairs(window.bywidget) do
        if w.view.id == page_id then domrem_func_cb(w, ret) end
    end
end)
domrem_wm:add_signal("matches", function(_, page_id, n)
    for _, w in pairs(window.bywidget) do
        if w.view.id == page_id then matches_cb(w, n) end
    end
end)

new_mode("domrem", {
    enter = function (w, mode)
        assert(type(mode) == "table", "invalid domrem mode")

        if mode.label_maker then
            msg.warn("Custom label maker not yet implemented!")
        end

        assert(type(mode.pattern_maker or _M.pattern_maker) == "function",
            "invalid pattern_maker function")

        local view = w.view

        local selector = mode.selector_func or _M.selectors[mode.selector]
        assert(type(selector) == "string", "invalid domrem selector")

        -- Append site-specific selector
        mode.selector = selector

        local stylesheet = mode.stylesheet or _M.stylesheet
        assert(type(stylesheet) == "string", "invalid stylesheet")
        mode.stylesheet = stylesheet

        if w.domrem_persist then
            mode.persist = true
            w.domrem_persist = nil
        end

        w.domrem_state = {
            mode = mode, view = view,
            evaluator = mode.evaluator,
        }

        if mode.prompt then
            w:set_prompt(string.format("DOM Remove (%s):", mode.prompt))
        else
            w:set_prompt("Remove:")
        end

        w:set_input("")
        w:set_ibar_theme()

        -- Cut func out of mode, since we can't send functions
        local func = mode.func
        mode.func = nil
        domrem_wm:emit_signal(w.view, "enter", mode, _M.ignore_case)
        mode.func = func
    end,

    changed = function (w, text)
        local mode = w.domrem_state.mode

        -- Make the hint label/text matching patterns
        local pattern_maker = mode.pattern_maker or _M.pattern_maker
        local hint_pat, text_pat = pattern_maker(text)

        domrem_wm:emit_signal(w.view, "changed", hint_pat, text_pat, text)
    end,

    leave = function (w)
        w:set_ibar_theme()
        domrem_wm:emit_signal(w.view, "leave")
    end,
})

add_binds("domrem", {
    { "<Tab>",    "Focus the next element hint.",
        function (w) focus(w, 1) end },
    { "<Shift-Tab>",    "Focus the previous element hint.",
        function (w) focus(w, -1)        end },
    { "<Return>", "Activate the currently focused element hint.",
        function (w) do_domrem(w)        end },
    { "<Shift-Return>", "Activate all currently visible element hints.",
        function (w) domrem_all_hints(w) end },
})

--- Element selectors used to filter elements to domrem.
-- @type {[string]=string}
-- @readwrite
_M.selectors = {
    clickable = 'a, area, textarea, select, input:not([type=hidden]), button, label',
    -- Elements that can be clicked.
    focus = 'a, area, textarea, select, input:not([type=hidden]), button, body, applet, object',
    -- Elements that can be given input focus.
    uri = 'a, area',
    -- Elements that have a URI (e.g. hyperlinks).
    desc = '*[title], img[alt], applet[alt], area[alt], input[alt]',
    -- Elements that can have a description.
    image = 'img, input[type=image]',
    -- Image elements.
    thumbnail = "a img",
    -- Image elements within a hyperlink.
    div = "div",
    -- Image elements within a hyperlink.
}

add_binds("normal", {
    { "^x$", [[Start `domrem` mode. Hint all div elements
        and remove the selected element.]],
        function (w)
            w:set_mode("domrem", {
                selector = "div", evaluator = "rem",
                func = function (s) w:emit_form_root_active_signal(s) end,
            })
        end },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
