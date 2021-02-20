# Luakit Modules

## Domrem

In normal mode, hit *x* and then the desired marker to remove the div from the
DOM.

```
local domrem = require "domrem"
domrem.pattern_maker = domrem.pattern_styles.match_label
```

## Passmenu

Integrate with [pass](https://passwordstore.org) or
[age-pass](https://github.com/howeyc/age-pass) using a dmenu-like selector.

When in input mode, press <Ctrl-p> to open the menu. The
assumption is the program you run will put the password on the clipboard. You
then paste it yourself. It's basically a hotkey to run the menu, that's all.

```
local passmenu = require "passmenu"
```

## Bypass Paywall

Very simplistic bypass for a few sites. Basically just sets user agent to
Googlebot.

```
require_web_module("bypass_paywall_wm")
```

