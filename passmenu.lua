--- Run passmenu to get password
--
-- This module allows you to edit the contents of the currently focused
-- password input with the result from calling passmenu. The focused input is
-- disabled, and the menu window will open.
-- After you have selected the password; the text input will be enabled and
-- its contents will be set to that of the selection.
--
-- @module passmenu

local modes = require("modes")
local editor = require("editor")
local add_binds = modes.add_binds

local _M = {}

--- The shell command used to get password on clipboard. The default is to
-- use `passmenu`
--
-- @type string
-- @readwrite
_M.menu_cmd = "passmenu"


local function run_passmenu(w)
    w.view:eval_js(string.format([=[
        var e = document.activeElement;
        if (e && 'password' === e.type)) {
            var s = e.value;
            s;
        } else 'false';
    ]=]), { callback = function(s)
        if "false" ~= s then
            luakit.spawn(_M.menu_cmd)
        end
    end })
end

add_binds("insert", {
    { "<Control-p>", "Run passmenu to get password on clipboard.", run_passmenu },
})

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
