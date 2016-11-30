
local alttab = {}

local cairo = require("lgi").cairo
local mouse = mouse
local screen = screen
local wibox = require('wibox')
local table = table
local gears = require("gears")
local keygrabber = keygrabber
local math = require('math')
local awful = require('awful')
local client = client
awful.client = require('awful.client')

local surface = cairo.ImageSurface(cairo.Format.RGB24,20,20)
local cr = cairo.Context(surface)

-- settings

alttab.settings = { 
   preview_box = true,
   preview_box_bg = "#001111aa",
   preview_box_border = "#22222200",
   preview_box_text_color = "#00ffffff",
   preview_box_fps = 15,
   preview_box_delay = 150,

   client_opacity = true,
   client_opacity_value = 0.5,
   client_opacity_delay = 150,
}
local settings = alttab.settings

-- A wrapper that ignores :stop() calls in already-stopped timers.
local function timer(args)
   local t = gears.timer(args)
   local started = false
   return {
      start = function()
         started = true
         return t:start()
      end,
      stop = function()
         if not started then return end 
         return t:stop()
      end,
      connect_signal = function(_, s, f)
         return t:connect_signal(s, f)
      end
   }
end

-- Full history of all clients:
local history
history = {
   log = {},
   add = function(c)
      history.delete(c)
      table.insert(history.log, 1, c)
   end,
   delete = function(c)
      for i, v in ipairs(history.log) do
         if v == c then
            table.remove(history.log, i)
            return
         end
      end
   end,
}
setmetatable(history.log, { __mode = "v" })
client.connect_signal("focus", history.add)
client.connect_signal("unmanage", history.delete)
client.connect_signal("minimize", history.delete)

-- Create a wibox to contain all the client-widgets
local preview_wbox = wibox({ width = screen[mouse.screen].geometry.width })
preview_wbox.border_width = 0
preview_wbox.ontop = true
preview_wbox.visible = false

local preview_live_timer = timer({}) --( {timeout = 1/settings.preview_box_fps} )

local altTabTable = {}
local altTabIndex = 1
local applyOpacity = false

local function set_text_color(cr, text_color)
   local r, g, b, a = text_color:match("#(..)(..)(..)(..)")
   if r then
      r, g, b, a = tonumber(r, 16), tonumber(g, 16), tonumber(b, 16), tonumber(a, 16)
   else
      r, g, b, a = 0, 0, 0, 1
   end
   cr:set_source_rgba(r, g, b, a)
end

local function get_title(c)
   local title = c.name
   local len = c.icon and 13 or 16
   if #title > len*2 then
      title = " " .. title:sub(1, len) .. "…" .. title:sub(-len)
   else
      title = " " .. title
   end
   return title
end

local function preview()
   if not settings.preview_box then return end

   -- Apply settings
   preview_wbox:set_bg(settings.preview_box_bg)
   preview_wbox.border_color = settings.preview_box_border

   local preview_widgets = {}
   
   -- Make the wibox the right size, based on the number of clients
   local n = math.max(7, #altTabTable)
   local W = screen[mouse.screen].geometry.width + 2 * preview_wbox.border_width
   local w = W / n -- widget width
   local h = w * 0.75  -- widget height
   local textboxHeight = 30

   local x = screen[mouse.screen].geometry.x - preview_wbox.border_width
   local y = screen[mouse.screen].geometry.y + (screen[mouse.screen].geometry.height - h - textboxHeight) / 2
   preview_wbox:geometry({x = x, y = y, width = W, height = h + textboxHeight})

   -- create a list that holds the clients to preview, from left to right
   local leftRightTab = {}
   local nLeft
   local nRight
   if #altTabTable == 2 then
      nLeft = 0
      nRight = 2
   else
      nLeft = math.floor(#altTabTable / 2)
      nRight = math.ceil(#altTabTable / 2)
   end

   for i = 1, nLeft do
      table.insert(leftRightTab, altTabTable[#altTabTable - nLeft + i])
   end
   for i = 1, nRight do
      table.insert(leftRightTab, altTabTable[i])
   end

   -- determine fontsize -> find maximum classname-length
   local text, textWidth, textHeight, maxText
   local maxTextWidth = 0
   local maxTextHeight = 0
   local bigFont = textboxHeight / 2
   for i = 1, #leftRightTab do
      text = get_title(leftRightTab[i])
      textWidth = cr:text_extents(text).width
      textHeight = cr:text_extents(text).height
      if textWidth > maxTextWidth or textHeight > maxTextHeight then
            maxTextHeight = textHeight
            maxTextWidth = textWidth
            maxText = text
      end
   end

   while true do
      cr:set_font_size(bigFont)
      textWidth = cr:text_extents(maxText).width
      textHeight = cr:text_extents(maxText).height

      if textWidth < w - textboxHeight and textHeight < textboxHeight then
            break
      end

      bigFont = bigFont - 1
   end
   local smallFont = bigFont * 0.8


   -- create all the widgets
   for i = 1, #leftRightTab do
      preview_widgets[i] = wibox.widget.base.make_widget()
      preview_widgets[i].fit = function(preview_widget, width, height)
         return w, h
      end
      
      preview_widgets[i].draw = function(preview_widget, preview_wbox, cr, width, height)
         if width ~= 0 and height ~= 0 then

            local c = leftRightTab[i]
            local a = 0.7
            local overlay = 0.6
            local fontSize = smallFont
            if c == altTabTable[altTabIndex] then
               a = 0.9
               overlay = 0
               fontSize = bigFont
            end

            local sx, sy, tx, ty

            -- Icons
            local icon
            local iconboxWidth
            if c.icon then
               icon = gears.surface(c.icon)
               iconboxWidth = 0.9 * textboxHeight
            else
               iconboxWidth = 0
            end
            local iconboxHeight = iconboxWidth

            -- Titles
            cr:select_font_face("Lode Sans", "sans", "italic", "normal")
            cr:set_font_face(cr:get_font_face())
            cr:set_font_size(fontSize)
            
            text = get_title(c)
            textWidth = cr:text_extents(text).width
            textHeight = cr:text_extents(text).height

            local titleboxWidth = textWidth + iconboxWidth 

            tx = (w - titleboxWidth) / 2
            ty = h 
            -- Draw icons
            if icon then
               sx = iconboxWidth / icon.width
               sy = iconboxHeight  / icon.height
   
               cr:translate(tx, ty)
               cr:scale(sx, sy)
               cr:set_source_surface(icon, 0, 0)
               cr:paint()
               cr:scale(1/sx, 1/sy)
               cr:translate(-tx, -ty)
            end
            
            -- Draw titles
            tx = tx + iconboxWidth
            ty = h + (textboxHeight + textHeight) / 2

            set_text_color(cr, settings.preview_box_text_color)

            cr:move_to(tx, ty)
            cr:show_text(text)
            cr:stroke()

            -- Draw previews
               local cg = c:geometry()
            if cg.width > cg.height then
               sx = a * w / cg.width 
               sy = math.min(sx, a * h / cg.height)
            else
               sy = a * h / cg.height               
               sx = math.min(sy, a * h / cg.width)
            end

            tx = (w - sx * cg.width) / 2
            ty = (h - sy * cg.height) / 2

            local tmp = gears.surface(c.content)
            cr:translate(tx, ty)
            cr:scale(sx, sy)
            cr:set_source_surface(tmp, 0, 0)
            cr:paint()
            tmp:finish()

            -- Overlays
            cr:scale(1/sx, 1/sy)
            cr:translate(-tx, -ty)
            cr:set_source_rgba(0,0,0,overlay)
            cr:rectangle(tx, ty, sx * cg.width, sy * cg.height)
            cr:fill()
         end
      end

      preview_live_timer.timeout = 1 / settings.preview_box_fps
      preview_live_timer:connect_signal("timeout", function() 
                                           preview_widgets[i]:emit_signal("widget::updated") 
      end)

   end

   -- Spacers left and right
   local spacer = wibox.widget.base.make_widget()
   spacer.fit = function(leftSpacer, width, height)
      return (W - w * #altTabTable) / 2, preview_wbox.height
   end
   spacer.draw = function(preview_widget, preview_wbox, cr, width, height) end

   --layout
   local preview_layout = wibox.layout.fixed.horizontal()
   
   preview_layout:add(spacer)
   for i = 1, #leftRightTab do
      preview_layout:add(preview_widgets[i])
   end
   preview_layout:add(spacer)

   preview_wbox:set_widget(preview_layout)
end

local function set_client_opacity(altTabTable, altTabIndex)
   if not settings.client_opacity then return end

   for i,c in pairs(altTabTable) do
      if i == altTabIndex then
         c.opacity = 1
         c:raise()
      elseif applyOpacity then
         c.opacity = settings.client_opacity_value
      end
   end
end


local function cycle(altTabTable, altTabIndex, dir)
   -- Switch to next client
   altTabIndex = altTabIndex + dir
   if altTabIndex > #altTabTable then
      altTabIndex = 1 -- wrap around
   elseif altTabIndex < 1 then
      altTabIndex = #altTabTable -- wrap around
   end

   altTabTable[altTabIndex].minimized = false
   
   if not settings.preview_box and not settings.client_opacity then
      client.focus = altTabTable[altTabIndex]
   end

   if settings.client_opacity then
      set_client_opacity(altTabTable, altTabIndex)
   end

   return altTabIndex
end

function alttab.switch(dir, alt, tab, shift_tab)

   altTabTable = {}
   local altTabMinimized = {}
   local altTabOpacity = {}

   local idx = 1
   local c = history.log[idx]
 
   while c do
      table.insert(altTabTable, c)
      table.insert(altTabMinimized, c.minimized)
      table.insert(altTabOpacity, c.opacity)
      idx = idx + 1
      c = history.log[idx]
   end

   for s = 1, screen.count() do
   
      -- Minimized clients will not appear in the focus history
      -- Find them by cycling through all clients, and adding them to the list
      -- if not already there.
      -- This will preserve the history AND enable you to focus on minimized clients
   
      local t = screen[s].selected_tag
      local all = client.get(s)
   
      for i = 1, #all do
         local c = all[i]
         local ctags = c:tags();
   
         -- check if the client is on the current tag
         local isCurrentTag = false
         for j = 1, #ctags do
            if t == ctags[j] then
               isCurrentTag = true
               break
            end
         end
   
         if isCurrentTag then
            -- check if client is already in the history
            -- if not, add it
            local addToTable = true
            for k = 1, #altTabTable do
               if altTabTable[k] == c then
                  addToTable = false
                  break
               end
            end
   
            if addToTable then
               table.insert(altTabTable, c)
               table.insert(altTabMinimized, c.minimized)
               table.insert(altTabOpacity, c.opacity)
            end
         end
      end
   end

   if #altTabTable == 0 then
      return
   elseif #altTabTable == 1 then 
      altTabTable[1].minimized = false
      altTabTable[1]:raise()
      return
   end

   -- reset index
   altTabIndex = 1

   -- preview delay timer
   local previewDelay = settings.preview_box_delay / 1000
   local previewDelayTimer = timer({timeout = previewDelay})
   previewDelayTimer:connect_signal("timeout", function() 
                                       preview_wbox.visible = true
                                       previewDelayTimer:stop()
                                       preview(altTabTable, altTabIndex) 
   end)
   previewDelayTimer:start()
   preview_live_timer:start()

   -- opacity delay timer
   local opacityDelay = settings.client_opacity_delay / 1000
   local opacityDelayTimer = timer({timeout = opacityDelay})
   opacityDelayTimer:connect_signal("timeout", function() 
                                       applyOpacity = true
                                       opacityDelayTimer:stop()
                                       set_client_opacity(altTabTable, altTabIndex)
   end)
   opacityDelayTimer:start()


   -- Now that we have collected all windows, we should run a keygrabber
   -- as long as the user is alt-tabbing:
   keygrabber.run(
      function (mod, key, event)  
         -- Stop alt-tabbing when the alt-key is released
         if key == alt or key == "Escape" and event == "release" then
            preview_wbox.visible = false
            applyOpacity = false
            preview_live_timer:stop()
            previewDelayTimer:stop()
            opacityDelayTimer:stop()
   
            if key == "Escape" then 
               for i,c in pairs(altTabTable) do
                  c.opacity = altTabOpacity[i]
               end
               keygrabber.stop()
               return
            end

            -- Raise clients in order to restore history
            local c
            for i = 1, altTabIndex - 1 do
               c = altTabTable[altTabIndex - i]
               if not altTabMinimized[i] then
                  c:raise()
                  client.focus = c
               end
            end

            -- raise chosen client on top of all
            c = altTabTable[altTabIndex]
            c:raise()
            client.focus = c
            history.add(c)

            -- restore minimized clients
            for i = 1, #altTabTable do
               if i ~= altTabIndex and altTabMinimized[i] then 
                  altTabTable[i].minimized = true
               end
               altTabTable[i].opacity = altTabOpacity[i]
            end

            keygrabber.stop()

         -- Move to previous client on Shift-Tab
         elseif (key == shift_tab or (mod[1] == "Shift" and key == "Tab") or key == "Left") and event == "press" then
            altTabIndex = cycle(altTabTable, altTabIndex, -1)

         -- Move to next client on each Tab-press
         elseif (key == tab or key == "Right") and event == "press" then
            altTabIndex = cycle(altTabTable, altTabIndex, 1)
            
         end
      end
   )

   -- switch to next client
   altTabIndex = cycle(altTabTable, altTabIndex, dir)

end -- function switch

return alttab
