-- Bypass Paywall
--
-- *Note: the word 'referer' is intentionally misspelled for historic reasons.*
--
-- # Usage
--
-- As this is a web module, it will not function if loaded on the main UI Lua
-- process through `require()`. Instead, it should be loaded with
-- `require_web_module()`:
--
--     require_web_module("bypass_paywall_wm")
--
-- @module bypass_paywall_wm
-- @copyright 2021 Chris Howey <chris@howey.me>

local _M = {}

_M.paywall_domains = {
    ["ft.com"] = true,
    ["wsj.com"] = true,
    ["washingtonpost.com"] = true,
    ["seekingalpha.com"] = true,
    ["quora.com"] = true,
}

local function domain_from_uri(uri)
    local domain = (uri and string.match(string.lower(uri), "^%a+://([^/]*)/?"))
    -- Strip leading www. www2. etc
    domain = string.match(domain or "", "^www%d?%.(.+)") or domain
    return domain or ""
end

luakit.add_signal("page-created", function(page)
    page:add_signal("send-request", function(p, _, headers)
        local domain = domain_from_uri(p.uri)
        local pw = _M.paywall_domains[domain]
        if pw then 
            headers.Referer = "https://www.google.com/"
            headers["User-Agent"] = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
            headers["X-Forwarded-For"] = "66.249.66.1"
        end
    end)
end)

return _M

-- vim: et:sw=4:ts=8:sts=4:tw=80
