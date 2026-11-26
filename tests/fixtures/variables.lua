local scheme = require("scheme.current")

return {
    ------------------
    ---- HYPRLAND ----
    ------------------

    -- Apps
    terminal                   = "foot",
    browser                    = "firefox",
    privateBrowser             = "firefox --private-window",
    editor                     = "codium",
    fileExplorer               = "nautilus",
    audioSettings              = "pavucontrol",
    youtube                    = "firefox https://www.youtube.com",

    -- Touchpad
    touchpadDisableTyping      = true,
    touchpadScrollFactor       = 0.3,
    gestureFingers             = 3,
    workspaceSwipeFingers      = 4,
    gestureFingersMore         = 4,

    -- Blur
    blurEnabled                = true,
    blurSpecialWs              = false,
    blurPopups                 = true,
    blurInputMethods           = true,
    blurSize                   = 6,
    blurPasses                 = 2,
    blurXray                   = false,

    -- Shadow
    shadowEnabled              = true,
    shadowRange                = 15,
    shadowRenderPower          = 4,
    shadowColour               = "rgba(" .. scheme.inversePrimary .. "10)",

    -- Gaps
    workspaceGaps              = 20,
    windowGapsIn               = 5,
    windowGapsOut              = 10,
    singleWindowGapsOut        = 20,

    -- Window styling
    windowActiveOpacity        = 1.0,
    windowInactiveOpacity      = 1.0,
    windowFullscreenOpacity    = 1.0,

    windowRounding             = 15,
    windowBorderSize           = 2,
    activeWindowBorderColour   = {
        colors = {
            "rgba(" .. scheme.term9 .. "ee)",
            "rgba(" .. scheme.term11 .. "ee)",
            "rgba(" .. scheme.term10 .. "ee)",
            "rgba(" .. scheme.term14 .. "ee)",
            "rgba(" .. scheme.term10 .. "ee)",
            "rgba(" .. scheme.term11 .. "ee)",
            "rgba(" .. scheme.term9 .. "ee)",
        },
        angle = 45,
    },
    inactiveWindowBorderColour = "rgba(" .. scheme.onSurfaceVariant .. "11)",

    -- Misc
    volumeStep                 = 10,
    volumeMax                  = 100,
    cursorTheme                = "Bibata-Modern-Ice",
    cursorSize                 = 24,
    sleepGestureCmd            = "systemctl suspend",

    ------------------
    ---- KEYBINDS ----
    ------------------

    -- Workspaces
    kbMoveWinToWs              = "SUPER + SHIFT",
    kbMoveWinToWsGroup         = "CTRL + SUPER + ALT",
    kbGoToWs                   = "SUPER",
    kbGoToWsGroup              = "CTRL + SUPER",
    kbNextWs                   = "SUPER + TAB",
    kbPrevWs                   = "SUPER + SHIFT + TAB",

    -- Window Group
    kbWindowGroupCycleNext     = "ALT + TAB",
    kbWindowGroupCyclePrev     = "SHIFT + ALT + TAB",
    kbUngroup                  = "SUPER + U",
    kbToggleGroup              = "SUPER + Comma",

    -- Window Action
    kbMoveWindow               = "SUPER + mouse:272",
    kbResizeWindow             = "SUPER + mouse:273",
    kbWindowPip                = "SUPER + ALT + backslash",
    kbPinWindow                = "SUPER + P",
    kbWindowFullscreen         = "SUPER + F",
    kbWindowBorderedFullscreen = "SUPER + ALT + F",
    kbToggleWindowFloating     = "SUPER + ALT + space",
    kbCloseWindow              = "SUPER + Q",
    kbKillWindow               = "SUPER + SHIFT + Q",

    -- Special workspaces toggles
    kbSpecialWs                = "SUPER + S",
    kbSystemMonitorWs          = "CTRL + SHIFT + Escape",
    kbMusicWs                  = "SUPER + M",
    kbCommunicationWs          = "SUPER + D",
    kbTodoWs                   = "SUPER + R",

    -- Apps
    kbTerminal                 = "SUPER + RETURN",
    kbBrowser                  = "SUPER + B",
    kbPrivateBrowser           = "SUPER + SHIFT + B",
    kbEditor                   = "SUPER + C",
    kbFileExplorer             = "SUPER + E",
    kbYoutube                  = "SUPER + Y",

    -- Misc
    kbSession                  = "CTRL + ALT + Delete",
    kbShowSidebar              = "SUPER + N",
    kbClearNotifs              = "CTRL + ALT + C",
    kbShowPanels               = "SUPER + K",
    kbLock                     = "SUPER + L",
    kbRestoreLock              = "SUPER + ALT + L",

    -- wallpaper
    kbWallpaperPicker          = "SUPER + W",
    kbWallpaperToggle          = "SUPER + SHIFT + W",

    -- gamemode
    kbGameMode                 = "SUPER + G",
}
