function love.conf(t)
    t.identity = "editors_desk"       -- The name of the save folder
    t.version = "11.5"                -- LÖVE version this game was made for
    t.console = false                 -- Attach a console

    t.window.title = "The Editor's Desk"
    t.window.icon = nil
    t.window.width = 1280
    t.window.height = 720
    t.window.borderless = false
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 360
    t.window.vsync = 1
    t.window.msaa = 0
end
