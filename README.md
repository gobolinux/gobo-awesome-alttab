gobo-awesome-alttab
===================

An "Alt-Tab" window switching widget for Awesome WM. This is a fork of 
[awesome_alttab](https://github.com/jorenheit/awesome_alttab).

Requirements
------------

* Awesome 3.5+

Using
-----

Require the module:


```
local alttab = require("gobo.awesome.alttab")
```

Enable the keybindings. 
In a typical `rc.lua` this will look like this:


```
   -- Switch windows
   awful.key({ "Mod1" }, "Tab",
      function()
         alttab.switch(1, "Alt_L", "Tab", "ISO_Left_Tab")
      end,
      { description = "Switch between windows", group = "awesome" }
   ),
   awful.key({ "Mod1", "Shift" }, "Tab",
      function()
         alttab.switch(-1, "Alt_L", "Tab", "ISO_Left_Tab")
      end,
      { description = "Switch between windows backwards", group = "awesome" }
   ),
```
