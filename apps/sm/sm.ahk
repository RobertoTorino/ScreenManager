; YouTube: @game_play267
; Twitch: RR_357000
; X:@relliK_2048
#SingleInstance force
#Persistent
#NoEnv
#WinActivateForce

SendMode Input
DetectHiddenWindows On
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
SetTitleMatchMode, 2


; DPI awareness (best-effort)
try DllCall("shcore\SetProcessDpiAwareness", "int", 2)  ; PROCESS_PER_MONITOR_DPI_AWARE
try DllCall("user32\SetProcessDPIAware")

; ─── Globals. ────────────────────────────────────────────────────────────────────
global scaleFactor      := 100  ; start at 100% = 1.0
global lastMovedHwnd    := ""
global GameExe          := ""

Global WindowConfigs := {}
Global SizeChoice := ""

lastStatus := "" ; tracks the last known Online/Offline state
online := true

OnExit("SaveSettings")
logInterval := 120000
lastResourceLog := 0

; ─── Global config. ────────────────────────────────────────────────────────────────────
baseDir     := A_ScriptDir
iniFile     := A_ScriptDir . "\sm.ini"
logFile     := A_ScriptDir . "\sm.log"
fallbackLog := A_ScriptDir . "\sm_fallback.log"

if !IsSet(iniFile)
    iniFile := A_ScriptDir "\sm.ini"

; ─── Admin relaunch (v1). ────────────────────────────────────────────────────────────────────
if !A_IsAdmin
{
    Run, *RunAs "%A_ScriptFullPath%"
    ExitApp
}


; ─── Ensure INI exists. ────────────────────────────────────────────────────────────────────
if !FileExist(iniFile)
{
    if (A_IsCompiled)
        FileInstall, sm.ini, %iniFile%, 1
    else
    {
        if FileExist(A_ScriptDir . "\sm.ini")
            FileCopy, %A_ScriptDir%\sm.ini, %iniFile%, 0
        else
        {
            FileAppend, [GAME_PATH]`nPath=`n[SIZE_SETTINGS]`nSizeChoice=Borderless`n[NUDGE_SETTINGS]`nNudgeStep=1`n[PRIORITY]`nPriority=Normal`n, %iniFile%
        }
    }
}


; ─── WindowConfigs setup. ────────────────────────────────────────────────────────────────────
; Standard modes
WindowConfigs["SizeFull"]       := {Mode:"FullScreen"}
WindowConfigs["SizeWindowed"]   := {Mode:"Windowed"}
WindowConfigs["SizeBorderless"] := {Mode:"Borderless"}
WindowConfigs["SizeHidden"]     := {Mode:"Hidden"}
WindowConfigs["SizeMinimized"]  := {Mode:"Minimized"}
WindowConfigs["SizeMaximized"]  := {Mode:"Maximized"}
WindowConfigs["SizeRestored"]   := {Mode:"Restored"}
WindowConfigs["SizeTopmost"]    := {Mode:"Topmost"}
WindowConfigs["SizeTool"]       := {Mode:"ToolWindow"}
WindowConfigs["SizeLayered"]    := {Mode:"Layered"}
WindowConfigs["SizeNoActivate"] := {Mode:"NoActivate"}

; Resolutions
WindowConfigs["Size1920"] := {Width:1920, Height:1080}
WindowConfigs["Size2560"] := {Width:2560, Height:1440}
WindowConfigs["Size3840"] := {Width:3840, Height:2160}
WindowConfigs["Size5120"] := {Width:5120, Height:2880}
WindowConfigs["Size6016"] := {Width:6016, Height:3384}
WindowConfigs["Size7680"] := {Width:7680, Height:4320}

; Combined examples
WindowConfigs["SizeBorderlessTopmost2560"] := {Width:2560, Height:1440, Mode:"Borderless", Topmost:true}
; ── Basic Borderless variants ────────────────────────────────
WindowConfigs["SizeBorderless1920"]          := {Width:1920, Height:1080, Mode:"Borderless"}
WindowConfigs["SizeBorderlessTopmost1920"]   := {Width:1920, Height:1080, Mode:"Borderless", Topmost:true}
WindowConfigs["SizeBorderlessTool1920"]      := {Width:1920, Height:1080, Mode:"Borderless", ToolWindow:true}
WindowConfigs["SizeBorderlessLayered1920"]   := {Width:1920, Height:1080, Mode:"Borderless", Layered:true, NoActivate:true}
WindowConfigs["SizeBorderlessTopLayered1920"]:= {Width:1920, Height:1080, Mode:"Borderless", Topmost:true, Layered:true}
WindowConfigs["SizeBorderlessNoAct1920"]     := {Width:1920, Height:1080, Mode:"Borderless", NoActivate:true}

; ── Windowed variants ─────────────────────────────────────────
WindowConfigs["SizeWindowed1920"]            := {Width:1920, Height:1080, Mode:"Windowed"}
WindowConfigs["SizeWindowedTopmost1920"]     := {Width:1920, Height:1080, Mode:"Windowed", Topmost:true}
WindowConfigs["SizeWindowedTool1920"]        := {Width:1920, Height:1080, Mode:"Windowed", ToolWindow:true}
WindowConfigs["SizeWindowedLayered1920"]     := {Width:1920, Height:1080, Mode:"Windowed", Layered:true}
WindowConfigs["SizeWindowedNoAct1920"]       := {Width:1920, Height:1080, Mode:"Windowed", NoActivate:true}
WindowConfigs["SizeWindowedTopLayered1920"]  := {Width:1920, Height:1080, Mode:"Windowed", Topmost:true, Layered:true}

; ── Fake fullscreen & other utility modes ─────────────────────
WindowConfigs["SizeFakeFull1920"]            := {Width:1920, Height:1080, Mode:"Borderless", Topmost:true}
WindowConfigs["SizeFakeFullLayered1920"]     := {Width:1920, Height:1080, Mode:"Borderless", Topmost:true, Layered:true}
WindowConfigs["SizeFakeFullTool1920"]        := {Width:1920, Height:1080, Mode:"Borderless", Topmost:true, ToolWindow:true}
WindowConfigs["SizeFakeFullNoAct1920"]       := {Width:1920, Height:1080, Mode:"Borderless", Topmost:true, NoActivate:true}
WindowConfigs["SizeFakeFullAll1920"]         := {Width:1920, Height:1080, Mode:"Borderless", Topmost:true, Layered:true, ToolWindow:true, NoActivate:true}

; ── Basic Borderless variants ────────────────────────────────
WindowConfigs["SizeBorderless2560"]          := {Width:2560, Height:1440, Mode:"Borderless"}
WindowConfigs["SizeBorderlessTopmost2560"]   := {Width:2560, Height:1440, Mode:"Borderless", Topmost:true}
WindowConfigs["SizeBorderlessTool2560"]      := {Width:2560, Height:1440, Mode:"Borderless", ToolWindow:true}
WindowConfigs["SizeBorderlessLayered2560"]   := {Width:2560, Height:1440, Mode:"Borderless", Layered:true, NoActivate:true}
WindowConfigs["SizeBorderlessTopLayered2560"]:= {Width:2560, Height:1440, Mode:"Borderless", Topmost:true, Layered:true}
WindowConfigs["SizeBorderlessNoAct2560"]     := {Width:2560, Height:1440, Mode:"Borderless", NoActivate:true}

; ── Windowed variants ─────────────────────────────────────────
WindowConfigs["SizeWindowed2560"]            := {Width:2560, Height:1440, Mode:"Windowed"}
WindowConfigs["SizeWindowedTopmost2560"]     := {Width:2560, Height:1440, Mode:"Windowed", Topmost:true}
WindowConfigs["SizeWindowedTool2560"]        := {Width:2560, Height:1440, Mode:"Windowed", ToolWindow:true}
WindowConfigs["SizeWindowedLayered2560"]     := {Width:2560, Height:1440, Mode:"Windowed", Layered:true}
WindowConfigs["SizeWindowedNoAct2560"]       := {Width:2560, Height:1440, Mode:"Windowed", NoActivate:true}
WindowConfigs["SizeWindowedTopLayered2560"]  := {Width:2560, Height:1440, Mode:"Windowed", Topmost:true, Layered:true}

; ── Fake fullscreen & other utility modes ─────────────────────
WindowConfigs["SizeFakeFull2560"]            := {Width:2560, Height:1440, Mode:"Borderless", Topmost:true}
WindowConfigs["SizeFakeFullLayered2560"]     := {Width:2560, Height:1440, Mode:"Borderless", Topmost:true, Layered:true}
WindowConfigs["SizeFakeFullTool2560"]        := {Width:2560, Height:1440, Mode:"Borderless", Topmost:true, ToolWindow:true}
WindowConfigs["SizeFakeFullNoAct2560"]       := {Width:2560, Height:1440, Mode:"Borderless", Topmost:true, NoActivate:true}
WindowConfigs["SizeFakeFullAll2560"]         := {Width:2560, Height:1440, Mode:"Borderless", Topmost:true, Layered:true, ToolWindow:true, NoActivate:true}


; ─── Retain INI values. ────────────────────────────────────────────────────────────────────
GoSub, LoadSavedSettings
return

LoadSavedSettings:
    IniRead, SizeChoice, %iniFile%, SIZE_SETTINGS, SizeChoice
    IniRead, NudgeStep, %iniFile%, NUDGE_SETTINGS, NudgeStep
    GuiControl,, NudgeStep, %NudgeStep%

    ; --- Read game executable path from INI ---
    GameExe := ""
    IniRead, GamePath, %iniFile%, GAME_PATH, Path
    if (GamePath != "" && FileExist(GamePath)) {
        SplitPath, GamePath, GameExe
        Log("INFO", "Game executable: " . GameExe)
    } else {
        GameExe := ""
        Log("WARNING", "GamePath not found or invalid in INI")
    }

    IniRead, Priority, %iniFile%, PRIORITY, Priority

    Log("DEBUG", "Screen size is set to: " . SizeChoice)
    Log("DEBUG", "Nudge step is set to: " . NudgeStep)
    Log("DEBUG", "Gamepath is set to: " . GamePath)
    Log("DEBUG", "Process priority is set to: " . Priority)

    for _, n in ["1", "5","10","15","20","25"] {
        label := (n = NudgeStep) ? "[" . n . "]" : n
        GuiControl,, Btn%n%, %label%
}


; ─── Monitor info. ────────────────────────────────────────────────────────────
monitorIndex := 1  ; Change this to 2 for your second monitor

SysGet, MonitorCount, MonitorCount
if (monitorIndex > MonitorCount) {
    ShowCustomMsgBox("Error", "Invalid monitor index: " . monitorIndex)
    Log("ERROR", "Invalid monitor index: " . monitorIndex)
    ExitApp
}

SysGet, monLeft, Monitor, %monitorIndex%
SysGet, monTop, Monitor, %monitorIndex%
SysGet, monRight, Monitor, %monitorIndex%
SysGet, monBottom, Monitor, %monitorIndex%

; ─── Get real screen dimensions. ────────────────────────────────────────────────────────────
SysGet, Monitor, Monitor, %monitorIndex%
monLeft     := MonitorLeft
monTop      := MonitorTop
monRight    := MonitorRight
monBottom   := MonitorBottom
monWidth    := monRight - monLeft
monHeight   := monBottom - monTop
monAspect   := monWidth / monHeight

msg := "Monitor Count: " . MonitorCount . "`n`n"
    . "Monitor  " . monitorIndex    . ":" . "`n"
    . "Left:    " . monLeft         . "`n"
    . "Top:     " . monTop          . "`n"
    . "Right:   " . monRight        . "`n"
    . "Bottom:  " . monBottom       . "`n"
    . "Width:   " . monWidth        . "`n"
    . "Height:  " . monHeight       . "`n"
    . "Aspect:  " . monAspect
Log("DEBUG", msg)


; ───  START GUI. ───────────────────────────────────────────────────────
Gui, Show, w810 h470, %title%
Gui, +LastFound +AlwaysOnTop
Gui, Font, s10, Segoe UI
Gui, Margin, 15, 15
GuiHwnd := WinExist()

Gui, Font, Bold s9, Courier UI
Gui, Add, Text, vMemUsage x12 y1 w750 c0000FF, Loading memory usage...

Gui, Font, Bold s10 q5, Segoe UI
Gui, Add, Button, gRunGame                              x10 y20 w90 h40, Run Game
Gui, Font, Normal s10 q5, Segoe UI
Gui, Add, Button, gSetGamePath                          x110 y20 w90 h40, Set Path
Gui, Add, Button, gRefreshPath                          x210 y20 w90 h40, Refresh Path
Gui, Font, Bold s10 q5, Segoe UI
Gui, Add, Button, gExitGame vExitGame                   x310 y20 w90 h40, Exit Game
Gui, Font, Normal s10 q5, Segoe UI
Gui, Add, Button, gFileBrowser                          x410 y20 w90 h40, File Browser
Gui, Add, Button, gViewConfig                           x510 y20 w90 h40, View Settings
Gui, Add, Button, gViewLog                              x610 y20 w90 h40, View Logs
Gui, Add, Button, gClearLog                             x710 y20 w90 h40, Clear Logs

Gui, Add, Text,                                         x12 y65 w400, Most used regular screen settings.
Gui, Add, Button, gSetSizeChoice vSizeBorderless        x10 y85 w90 h35, Borderless
Gui, Add, Button, gSetSizeChoice vSizeFull              x110 y85 w90 h35, Fullscreen
Gui, Add, Button, gSetSizeChoice vSizeWindowed          x210 y85 w90 h35, Windowed
Gui, Add, Button, gSetSizeChoice vSize1920              x310 y85 w90 h35, 1920x1080
Gui, Add, Button, gSetSizeChoice vSizeMinimized         x410 y85 w90 h35, Minimized
Gui, Add, Button, gSetSizeChoice vSizeMaximized         x510 y85 w90 h35, Maximised
Gui, Add, Button, gSetSizeChoice vSizeHidden            x610 y85 w90 h35, Hidden
Gui, Add, Button, gSetSizeChoice vSizeRestored          x710 y85 w90 h35, Restore

Gui, Font, Bold s10 q5, Segoe UI
Gui, Add, Button, gSnapshot vSnapshot               x10 y125 w90 h44, Snapshot
Gui, Font, Normal s10 q5, Segoe UI
Gui, Add, Button, gMoveToMonitor vMoveToMonitor     x110 y125 w90 h44, Switch Screen 1 / 2
Gui, Add, Button, gFocusGame vBtnFocusGame          x210 y125 w90 h44, Focus`nTo Game
Gui, Add, Button, gSetSizeChoice vSize2560          x310 y125 w90 h44, Experimental 2560x1440
Gui, Add, Button, gSetSizeChoice vSize3840          x410 y125 w90 h44, Experimental 3840x2160
Gui, Add, Button, gSetSizeChoice vSize5120          x510 y125 w90 h44, Experimental 5120x2880
Gui, Add, Button, gSetSizeChoice vSize6016          x610 y125 w90 h44, Experimental 6016x3384
Gui, Add, Button, gSetSizeChoice vSize7680          x710 y125 w90 h44, Experimental 7680x4320

Gui, Add, Text,                                                 x12 y175, Experimental screensize combinations with 1920x1080.
Gui, Add, Button, gSetSizeChoice vSizeBorderless1920            x10 y195 w90 h44, Borderless
Gui, Add, Button, gSetSizeChoice vSizeBorderlessTopmost1920     x110 y195 w90 h44, Borderless Topmost
Gui, Add, Button, gSetSizeChoice vSizeBorderlessTool1920        x210 y195 w90 h44, Borderless Tool
Gui, Add, Button, gSetSizeChoice vSizeBorderlessLayered1920     x310 y195 w90 h44, Borderless Layered
Gui, Add, Button, gSetSizeChoice vSizeBorderlessTopLayered1920  x410 y195 w90 h44, Borderless Top Layered
Gui, Add, Button, gSetSizeChoice vSizeBorderlessNoAct1920       x510 y195 w90 h44, Borderless Deactivate
Gui, Add, Button, gSetSizeChoice vSizeWindowedTopmost1920       x610 y195 w90 h44, Windowed Topmost
Gui, Add, Button, gSetSizeChoice vSizeWindowedTool1920          x710 y195 w90 h44, Windowed Tool

Gui, Add, Button, gSetSizeChoice vSizeWindowedLayered1920       x10 y242 w90 h44, Windowed Layered
Gui, Add, Button, gSetSizeChoice vSizeWindowedNoAct1920         x110 y242 w90 h44, Windowed Deactivate
Gui, Add, Button, gSetSizeChoice vSizeWindowedTopLayered1920    x210 y242 w90 h44, Windowed Top Layered
Gui, Add, Button, gSetSizeChoice vSizeFakeFullLayered1920       x310 y242 w90 h44, Fullscreen Layered
Gui, Add, Button, gSetSizeChoice vSizeFakeFullTool1920          x410 y242 w90 h44, Fullscreen Tool
Gui, Add, Button, gSetSizeChoice vSizeFakeFullNoAct1920         x510 y242 w90 h44, Fullscreen Deactivate
Gui, Add, Button, gSetSizeChoice vSizeFakeFullAll1920           x610 y242 w90 h44, Fullscreen All

Gui, Add, Text,                                 x12 y292, Position the screen if it is not centered correct, values in pixels (default is 1).
Gui, Add, Button, vBtnNudgeUp gNudgeUp          x10 y312 w50 h30, Up
Gui, Add, Button, vBtnNudgeDown gNudgeDown      x60 y312 w50 h30, Down
Gui, Add, Button, vBtnNudgeLeft gNudgeLeft      x110 y312 w50 h30, Left
Gui, Add, Button, vBtnNudgeRight gNudgeRight    x160 y312 w50 h30, Right
Gui, Add, Button, vBtn1 gSetNudge               x210 y312 w40 h30, 01
Gui, Add, Button, vBtn5 gSetNudge               x250 y312 w40 h30, 05
Gui, Add, Button, vBtn10 gSetNudge              x290 y312 w40 h30, 10
Gui, Add, Button, vBtn15 gSetNudge              x330 y312 w40 h30, 15
Gui, Add, Button, vBtn20 gSetNudge              x370 y312 w40 h30, 20
Gui, Add, Button, vBtn25 gSetNudge              x410 y312 w40 h30, 25
Gui, Add, Edit, vNudgeStep                      x450 y312 w40 h30 hidden, 1
IniRead, lastNudge, %iniFile%, NUDGE_SETTINGS, NudgeStep, 1

Gui, Add, Text,                                         x12 y350, If the window does not fit, try to resize it, adjust with the values from positioning.
Gui, Add, Button, vBtnResizeWider gResizeWider          x10 y370 w80 h30, Width ++
Gui, Add, Button, vBtnResizeNarrower gResizeNarrower    x95 y370 w80 h30, Width --
Gui, Add, Button, vBtnResizeTaller gResizeTaller       x180 y370 w80 h30, Height ++
Gui, Add, Button, vBtnResizeShorter gResizeShorter     x265 y370 w80 h30, Height --

Gui, Add, Text,                                             x12 y410 w750, Select Process Priority. WARNING! Realtime can make your system unstable.
Gui, Add, Button, gSetPriority vPriorityIdle Disabled       x10 y430 w65 h30, Idle
Gui, Add, Button, gSetPriority vPriorityBelow Disabled      x80 y430 w120 h30, Below Normal
Gui, Add, Button, gSetPriority vPriorityNormal Disabled     x205 y430 w120 h30, Normal
Gui, Add, Button, gSetPriority vPriorityAbove Disabled      x330 y430 w120 h30, Above Normal
Gui, Add, Button, gSetPriority vPriorityHigh Disabled       x455 y430 w120 h30, High
Gui, Add, Button, gSetPriority vPriorityRealtime Disabled   x580 y430 w120 h30, ! Realtime !

; Timers (v1 labels)
SetTimer, UpdateButtonStates, 1000
SetTimer, UpdatePriority, 3000
SetTimer, CheckInternetStatus, 5000
SetTimer, UpdateMemoryUsage, 30000

; --- GUI update ---
UpdateMemoryUsage:
    Log("DEBUG", "UpdateMemoryUsage running: '" . GameExe . "'")
    txt := GetMemoryText()
    GuiControl,, MemUsage, %txt%
return


; ─── Force one immediate priority update. ──────────────────────────────────────────────
Gosub, UpdatePriority

; ─── Record timestamp of last update. ───────────────────────────────────
FormatTime, timeStamp, , yyyy-MM-dd HH:mm:ss
Log("DEBUG", "Writing Timestamp " . timeStamp . " to " . iniFile)
IniWrite, %timeStamp%, %iniFile%, LAST_UPDATE, LastUpdated


; ─── System tray. ────────────────────────────────────────────────────────────
Menu, Tray, Add, Show GUI, ShowGui
Menu, Tray, Add
Menu, Tray, Add, About ScreenManager..., ShowAboutDialog
Menu, Tray, Default, Show GUI
Menu, Tray, Tip, Screen Manager


return
; ─── END GUI. ───────────────────────────────────────────────────────────────────


; --- Memory usage helpers ---
GetScriptMemoryKB() {
    hProcess := DllCall("GetCurrentProcess", "ptr")
    size := (A_PtrSize = 8) ? 72 : 40
    VarSetCapacity(pm, size, 0)
    NumPut(size, pm, 0, "UInt")

    if DllCall("psapi\GetProcessMemoryInfo", "ptr", hProcess, "ptr", &pm, "uint", size) {
        workingSet := NumGet(pm, (A_PtrSize = 8) ? 16 : 8, "UPtr")
        return Round(workingSet / 1024)  ; KB
    }
    return -1
}

GetSystemMemoryInfo() {
    VarSetCapacity(ms, 64, 0)
    NumPut(64, ms, 0, "UInt")
    if !DllCall("kernel32\GlobalMemoryStatusEx", "ptr", &ms)
        return {}

    total := NumGet(ms, 8, "UInt64") / 1024
    avail := NumGet(ms, 16, "UInt64") / 1024
    used  := total - avail
    load  := Round((used / total) * 100, 1)

    return { "total": total, "available": avail, "used": used, "load": load }
}

GetProcessMemoryKB(exeName) {
    Process, Exist, %exeName%
    pid := ErrorLevel
    if (!pid)
        return -1

    hProcess := DllCall("OpenProcess", "uint", 0x400 | 0x10, "int", 0, "uint", pid, "ptr")
    if !hProcess
        return -1

    size := (A_PtrSize = 8) ? 72 : 40
    VarSetCapacity(pm, size, 0)
    NumPut(size, pm, 0, "UInt")

    if !DllCall("psapi\GetProcessMemoryInfo", "ptr", hProcess, "ptr", &pm, "uint", size)
    {
        DllCall("CloseHandle", "ptr", hProcess)
        return -1
    }

    workingSet := NumGet(pm, (A_PtrSize = 8) ? 16 : 8, "UPtr")
    DllCall("CloseHandle", "ptr", hProcess)
    return Round(workingSet / 1024)
}


GetMemoryText() {
    Global GameExe
    kbScript := GetScriptMemoryKB()
    mem := GetSystemMemoryInfo()

    ; ─── System memory unavailable fallback ────────────────
    if (!mem.HasKey("total") || kbScript < 0) {
        Log("DEBUG", "Memory readings unavailable.")
        return "System memory usage: no-data "
    }

    ; ─── Check if GameExe is defined ───────────────────────
    if (!GameExe) {
        Log("DEBUG", "GetMemoryText: GameExe is empty.")
        return "System memory usage: no-data | Game: no-data "
    }

    ; ─── Check if game process is running ──────────────────
    Process, Exist, %GameExe%
    pid := ErrorLevel
    if (!pid) {
        Log("DEBUG", "GetMemoryText: Game process not found (" . GameExe . ").")
        return "System memory usage: no-data | Game: " . GameExe . " (not running)"
    }

    ; ─── Get game process memory ───────────────────────────
    kbGame := GetProcessMemoryKB(GameExe)
    if (kbGame = -1) {
        Log("DEBUG", "GetMemoryText: Failed to read memory for " . GameExe)
        gameText := " no-data"
    } else {
        gameText := Round(kbGame / 1024, 2) . "MB"
    }

    ; ─── System usage values ───────────────────────────────
    mbTotal := Round(mem.total / 1024, 0)
    mbUsed  := Round(mem.used / 1024, 0)
    mbScript := Round(kbScript / 1024, 2)
    load := mem.load

    msg := "System memory usage: " . mbUsed . "/" . mbTotal . "MB (" . load . "%)"
        . " | App usage: " . mbScript . "MB (" . Round((kbScript / mem.total) * 100, 3) . "%)"
        . " | Game usage: " . gameText

    if (kbGame > 0)
        msg .= " (" . Round((kbGame / mem.total) * 100, 3) . "%)"

    Log("DEBUG", msg)
    return msg
}


; ─── FileBrowser. ────────────────────────────────────────────────────────────────
FileBrowser:
    Run, %A_ScriptDir%
return


; ─── Run game standalone function. ────────────────────────────────────────────────────────────────
RunGame:
    Global iniFile, GameExe

    ; ─── Ensure INI exists. ────────────────────────────────────────────────────────────────────
    if (!FileExist(iniFile)) {
        SplitPath, IniFile, iniFileName
        CustomTrayTip("Missing " . iniFile . " — set game Path first.", 3)
        Log("ERROR", "Missing " . iniFile . " — set game Path first.")
        Return
    }

    ; ─── Read path from INI ────────────────────────────────────────────────────────────────────
    if !IsSet(iniFile)
        iniFile := A_ScriptDir "\sm.ini"  ; fallback to hardcoded path

    ; Read the game path from INI
    GameExe := ""
    IniRead, GamePath, %iniFile%, GAME_PATH, Path
    if (GamePath != "" && FileExist(GamePath)) {
        SplitPath, GamePath, GameExe
        Log("INFO", "Game executable: " . GameExe)
    } else {
        GameExe := ""
        CustomTrayTip("Could not read game path from " . iniFile, 3)
        Log("ERROR", "Could not read [GAME_PATH] Path from " . iniFile)
    }

    ; ─── Extract EXE name ────────────────────────────────────────────────────────────────────
    SplitPath, GamePath, GameExe

    ; ─── Kill any existing game process ────────────────────────────────────────────────────────────────────
    RunWait, %ComSpec% /c taskkill /im "%GameExe%" /F,, Hide
    Sleep, 500

    ; ─── Launch game. ────────────────────────────────────────────────────────────────────
    Run, %GamePath%
    Sleep, 500  ; allow window to appear

    ; ─── Restore window size/position. ────────────────────────────────────────────────────────────────────
    IniRead, X, %iniFile%, WINDOW, X, 0
    IniRead, Y, %iniFile%, WINDOW, Y, 0
    IniRead, W, %iniFile%, WINDOW, Width, 0
    IniRead, H, %iniFile%, WINDOW, Height, 0

    if (X && Y && W && H) {
        WinGet, hwnd, ID, ahk_exe %GameExe%
        if hwnd
            WinMove, ahk_id %hwnd%, , %X%, %Y%, %W%, %H%
    }

    ; ─── Verify it launched. ────────────────────────────────────────────────────────────────────
    Sleep, 2000
    Process, Exist, %GameExe%
    if (!ErrorLevel) {
        Log("ERROR", "Game failed to launch.")
        CustomTrayTip("ERROR: Game did not launch!", 3)
        return
    }

    Log("INFO", "Game Started: " . GamePath)
Return


; ─── Kill game with button function. ────────────────────────────────────────────────────────────────────
ExitGame:
    Global iniFile

    ; Ensure the INI file variable exists
    if !IsSet(iniFile)
        iniFile := A_ScriptDir "\sm.ini"  ; fallback to hardcoded path


    if (!FileExist(iniFile)) {
        CustomTrayTip("Missing " . iniFile . " Set game Path first.", 3)
        Log("ERROR", "Set game Path first.`n Missing " . iniFile)
        Return
    }


    ; Read the game path from INI
    GameExe := ""
    IniRead, GamePath, %iniFile%, GAME_PATH, Path
    if (GamePath != "" && FileExist(GamePath)) {
        SplitPath, GamePath, GameExe
        Log("INFO", "Game executable found: " . GameExe)
    } else {
        GameExe := ""
        Log("WARNING", "GamePath not found or invalid in INI: " . iniFile)
    }

    if !FileExist(GamePath) {
        CustomTrayTip("File not found: " . GamePath, 3)
        Log("ERROR", "The file does not exist:`n" . GamePath)
        Return
    }

    ; ─── Kill process if running. ────────────────────────────────────────────────────────────────────
    Process, Exist, %GameExe%
    pid := ErrorLevel

    if (pid) {
        RunWait, %ComSpec% /c taskkill /im "%GameExe%" /f,, Hide
        RunWait, %ComSpec% /c taskkill /im "powershell.exe" /f,, Hide
        CustomTrayTip(GameExe . " closed successfully.", 1)
        Log("INFO", "Game exited: " . GameExe)
    } else {
        ShowCustomMsgBox("Info", "No processes running for: " . GameExe)
        Log("DEBUG", "No process found for " . GameExe)
    }
return


; ─── kill all processes for game. ────────────────────────────────────────────────────────────────────
KillAllProcesses(pid := "") {
    ahkPid := DllCall("GetCurrentProcessId")
    if (pid) {
        RunWait, taskkill /im %GameExe% /F,, Hide
        RunWait, taskkill /im powershell.exe /F,, Hide
        RunWait, %ComSpec% /c taskkill /PID %pid% /F,, Hide
        RunWait, %ComSpec% /c taskkill /im powershell.exe /F,, Hide
    } else {
        ShowCustomMsgBox("Error", "No PID provided." . GameExe)
        Log("ERROR", "No PID provided." . GameExe)
    }
}


; --- SetSizeChoice handler ---
SetSizeChoice:
    Global iniFile, SizeChoice, WindowConfigs
    clicked := A_GuiControl

    if !(WindowConfigs.HasKey(clicked)) {
        ShowCustomMsgBox("Error", "Clicked button not in WindowConfigs: " . clicked)
        Return
    }

    cfg := WindowConfigs[clicked]
    labelParts := []

    if (cfg.HasKey("Mode"))
        labelParts.Push(cfg.Mode)
    for key, val in cfg
        if (key != "Mode" && key != "Width" && key != "Height" && val)
            labelParts.Push(key)
    if (cfg.HasKey("Width") && cfg.HasKey("Height"))
        labelParts.Push(cfg.Width "x" cfg.Height)

    SizeChoice := clicked
    IniWrite, %SizeChoice%, %iniFile%, SIZE_SETTINGS, SizeChoice

    GoSub, ResizeWindow
Return


; --- Helper to join arrays (AHK v1). ---
JoinArray(arr, sep := ",") {
    str := ""
    for index, val in arr {
        if (str != "")
            str .= sep
        str .= val
    }
    return str
}


FakeFullscreen(WinID, width, height, options) {
    if !IsObject(options)
        options := {}  ; initialize empty object if not passed

    ; Remove borders/title bar if not overridden by options
    if !options.HasKey("KeepBorders") {
        WinSet, Style, -0xC00000, %WinID%  ; WS_CAPTION
        WinSet, Style, -0x800000, %WinID%  ; WS_BORDER
        WinSet, ExStyle, -0x00040000, %WinID%  ; WS_EX_DLGMODALFRAME
    }

    ; Apply optional flags
    if options.HasKey("Topmost") && options.Topmost
        WinSet, AlwaysOnTop, On, %WinID%
    if options.HasKey("Layered") && options.Layered
        WinSet, ExStyle, +0x00080000, %WinID%
    if options.HasKey("ToolWindow") && options.ToolWindow
        WinSet, ExStyle, +0x00000080, %WinID%
    if options.HasKey("NoActivate") && options.NoActivate
        WinShow, %WinID%, NA
    else
        WinShow, %WinID%

    ; --- Get monitor the window is on ---
    WinGetPos, winX, winY, , , %WinID%
    SysGet, MonitorCount, MonitorCount
    Loop, %MonitorCount% {
        SysGet, Mon, Monitor, %A_Index%
        if (winX >= MonLeft && winX < MonRight
         && winY >= MonTop && winY < MonBottom) {
            monLeft   := MonLeft
            monTop    := MonTop
            monWidth  := MonRight  - MonLeft
            monHeight := MonBottom - MonTop
            break
        }
    }

    ; --- Calculate scaling if virtual resolution is bigger than monitor ---
    scaleW := monWidth / width
    scaleH := monHeight / height
    scale := (scaleW < scaleH) ? scaleW : scaleH
    if (scale > 1)
        scale := 1  ; don't enlarge beyond monitor size

    newWidth  := Round(width * scale)
    newHeight := Round(height * scale)

    ; Center the window
    newX := monLeft + (monWidth  - newWidth) // 2
    newY := monTop  + (monHeight - newHeight) // 2

    ; Move/resize
    WinMove, %WinID%, , newX, newY, newWidth, newHeight
}


; --- ResizeWindow handler ---
ResizeWindow:
    Global iniFile, GameExe, SizeChoice, WindowConfigs

    WinWait, ahk_exe %GameExe%,, 3
    if !WinExist("ahk_exe " GameExe) {
        ShowCustomMsgBox("Error", "Game window not found.")
        Return
    }

    WinGet, hwnd, ID, ahk_exe %GameExe%
    if !hwnd {
        ShowCustomMsgBox("Error", "Game executable not running.")
        Return
    }
    WinID := "ahk_id " hwnd

    cfg := WindowConfigs[SizeChoice]

    ; Apply resolution if provided
    if (cfg.HasKey("Width") && cfg.HasKey("Height")) {
        options := {}
        for key, val in cfg
            if (key != "Width" && key != "Height" && key != "Mode")
                options[key] := val
        FakeFullscreen(WinID, cfg.Width, cfg.Height, options)
        Return
    }

    ; Apply Mode
    if (cfg.HasKey("Mode")) {
        mode := cfg.Mode
        if (mode = "FullScreen") {
            WinRestore, %WinID%
            WinMaximize, %WinID%
        } else if (mode = "Windowed") {
            WinSet, Style, +0xC00000, %WinID%
            WinSet, Style, +0x800000, %WinID%
            WinSet, Style, +0x20000, %WinID%
            WinSet, Style, +0x10000, %WinID%
            WinSet, Style, +0x40000, %WinID%
            WinSet, ExStyle, +0x00040000, %WinID%
            WinShow, %WinID%
            WinRestore, %WinID%
        } else if (mode = "Borderless") {
            FakeFullscreen(WinID, A_ScreenWidth, A_ScreenHeight, {})
        } else if (mode = "Hidden") {
            WinHide, %WinID%
        } else if (mode = "Minimized") {
            WinMinimize, %WinID%
        } else if (mode = "Maximized") {
            WinRestore, %WinID%
            WinMaximize, %WinID%
        } else if (mode = "Restored") {
            WinRestore, %WinID%
        } else if (mode = "Topmost") {
            WinSet, AlwaysOnTop, On, %WinID%
            WinShow, %WinID%
        } else if (mode = "ToolWindow") {
            WinSet, ExStyle, +0x00000080, %WinID%
            WinShow, %WinID%
        } else if (mode = "Layered") {
            WinSet, ExStyle, +0x00080000, %WinID%
            WinShow, %WinID%
        } else if (mode = "NoActivate") {
            WinShow, %WinID%, NA
        }
    }
Return


; Helper: remove tooltip
RemoveTooltip:
    Tooltip
return


; ─── Monitor switch logic. ───────────────────────────────────────────────────────────────────
MoveToMonitor:
    global GameExe
    MoveWindowToOtherMonitor(GameExe)
return


; ─── hotkey to test. ─────────────────────────────────────────────────────────────────────
F8::MoveWindowToOtherMonitor(GameExe)


; ─── Move window to next monitor.  ────────────────────────────────
MoveWindowToOtherMonitor(GameExe) {
    global lastMovedHwnd
    WinGet, hwnd, ID, ahk_exe %GameExe%
    if !hwnd {
        ShowCustomMsgBox("Error", GameExe . " is not running.")
        Log("ERROR", . GameExe . " is not running.")
        return
    }
    lastMovedHwnd := hwnd

    ; get window center.
    WinGetPos, winX, winY, winW, winH, ahk_id %hwnd%
    centerX := winX + (winW // 2)
    centerY := winY + (winH // 2)

    SysGet, monCount, MonitorCount
    if (monCount < 2)
        return

    ; find current monitor.
    currentMon := 1
    Loop, %monCount% {
        SysGet, Mon, Monitor, %A_Index%
        if (centerX >= MonLeft && centerX < MonRight && centerY >= MonTop && centerY < MonBottom) {
            currentMon := A_Index
            break
        }
    }

    ; target monitor.
    targetMon := (currentMon < monCount) ? currentMon + 1 : 1
    SysGet, MonT, Monitor, %targetMon%
    tLeft   := MonTLeft
    tTop    := MonTTop
    tRight  := MonTRight
    tBottom := MonTBottom
    tWidth  := tRight - tLeft
    tHeight := tBottom - tTop

    ; move roughly centered on target monitor (same physical size).
    newX := tLeft + (tWidth - winW) // 2
    newY := tTop + (tHeight - winH) // 2

    WinRestore, ahk_id %hwnd%
    Sleep, 100
    WinMove, ahk_id %hwnd%, , %newX%, %newY%, %winW%, %winH%
    WinSet, Redraw,, ahk_id %hwnd%
}


; ─── nudge button handler. ───────────────────────────────────────────────────────────────────
NudgeLeft:
    Gui, Submit, NoHide
    NudgeWindow(GameExe, -NudgeStep, 0)
return

NudgeRight:
    Gui, Submit, NoHide
    NudgeWindow(GameExe, NudgeStep, 0)
return

NudgeUp:
    Gui, Submit, NoHide
    NudgeWindow(GameExe, 0, -NudgeStep)
return

NudgeDown:
    Gui, Submit, NoHide
    NudgeWindow(GameExe, 0, NudgeStep)
return

SetNudge:
    Global iniFile, GameExe
    clickedText := A_GuiControl
    value := SubStr(clickedText, 4)

    ; Set the Edit field
    GuiControl,, NudgeStep, %value%
    IniWrite, %value%, %iniFile%, NUDGE_SETTINGS, NudgeStep

    ; Update the visual labels
    for _, n in ["1", "5", "10", "15", "20", "25"] {
        label := (clickedText = "Btn" . n) ? "[" . n . "]" : n
        GuiControl,, Btn%n%, %label%
    }
return

NudgeWindow(GameExe, dx, dy) {
    Global iniFile
    WinGet, hwnd, ID, ahk_exe %GameExe%
    if !hwnd {
        ShowCustomMsgBox("Error", "Window not found for: " . GameExe)
        Log("ERROR", "Window not found for: " . GameExe)
        return
    }
    WinGetPos, x, y, w, h, ahk_id %hwnd%
    WinMove, ahk_id %hwnd%, , x + dx, y + dy

    ; Save new position to INI
    IniWrite, % (x + dx), %iniFile%, WINDOW, X
    IniWrite, % (y + dy), %iniFile%, WINDOW, Y
    IniWrite, % w, %iniFile%, WINDOW, Width
    IniWrite, % h, %iniFile%, WINDOW, Height
}


; ─── resize button handler. ───────────────────────────────────────────────────────────────────
ResizeWider:
    Gui, Submit, NoHide
    ResizeWindowNudge(GameExe, NudgeStep, 0)
return

ResizeNarrower:
    Gui, Submit, NoHide
    ResizeWindowNudge(GameExe, -NudgeStep, 0)
return

ResizeTaller:
    Gui, Submit, NoHide
    ResizeWindowNudge(GameExe, 0, NudgeStep)
return

ResizeShorter:
    Gui, Submit, NoHide
    ResizeWindowNudge(GameExe, 0, -NudgeStep)
return

ResizeWindowNudge(GameExe, dw, dh) {
    Global iniFile
    WinGet, hwnd, ID, ahk_exe %GameExe%
    if !hwnd
        return

    ; Get current position and size
    WinGetPos, x, y, w, h, ahk_id %hwnd%

    ; Calculate new width and height
    newW := w + dw
    newH := h + dh

    ; Minimum size safeguard
    if (newW < 200)
        newW := 200
    if (newH < 200)
        newH := 200

    ; Center the window after resizing (shift by half of the change)
    newX := x - (dw // 2)
    newY := y - (dh // 2)

    WinMove, ahk_id %hwnd%, , newX, newY, newW, newH

    ; Save new position and size to INI
    IniWrite, %newX%, %iniFile%, WINDOW, X
    IniWrite, %newY%, %iniFile%, WINDOW, Y
    IniWrite, %newW%, %iniFile%, WINDOW, Width
    IniWrite, %newH%, %iniFile%, WINDOW, Height
}


; ─── Show GUI. ───────────────────────────────────────────────────────────────────
ShowGui:
    Gui, Show
return

ExitScript:
    ExitApp
return


; ─── Show "about" dialog function. ────────────────────────────────────────────────────────────────────
ShowAboutDialog() {
    tempFile := A_Temp "\version.dat"
    hRes := DllCall("FindResource", "Ptr", 0, "VERSION_FILE", "Ptr", 10) ;RT_RCDATA = 10
    if (hRes) {
        hData := DllCall("LoadResource", "Ptr", 0, "Ptr", hRes)
        pData := DllCall("LockResource", "Ptr", hData)
        size := DllCall("SizeofResource", "Ptr", 0, "Ptr", hRes)
        if (pData && size) {
            File := FileOpen(tempFile, "w")
            if IsObject(File) {
                File.RawWrite(pData + 0, size)
                File.Close()
            }
        }
    }

    FileRead, verContent, %tempFile%
    version := "0.0.0"
    if (verContent != "") {
        version := verContent
    }

    aboutText := "Screen Manager`n"
             . "Version: " . version . "`n"
             . Chr(169) . " " . A_YYYY . " Philip" . "`n"
             . "YouTube: @game_play267" . "`n"
             . "Twitch: RR_357000" . "`n"
             . "X: @relliK_2048"

    MsgBox, 64, About ScreenManager, %aboutText%
}


; ─── Set path to game executable function. ────────────────────────────────────────────────────────────────────
SetGamePath:
    Global GamePath, GameExe, iniFile
    FileSelectFile, path,, , Select game executable, Executable Files (*.exe)
    if (path != "" && FileExist(path)) {
        GamePath := path
        SplitPath, GamePath, GameExe
        IniWrite, %GamePath%, %iniFile%, GAME_PATH, Path
        SavegamePath(path)
        CustomTrayTip("Saved path to config: " . GameExe, 1)
        Log("INFO", "Path saved: " . GamePath)
    } else {
        CustomTrayTip("Path not selected or invalid.", 3)
        Log("ERROR", "No valid game executable selected.")
    }
Return


; ─── Get path to game function. ────────────────────────────────────────────────────────────────────
GetGamePath() {
    Global iniFile, GameExe

    if !FileExist(iniFile) {
        CustomTrayTip("Missing INI file.", 3)
        Log("ERROR", "Missing INI file when calling GetGamePath()")
        return ""
    }

    IniRead, path, %iniFile%, GAME_PATH, Path
    if (ErrorLevel) {
        CustomTrayTip("Could not read [GAME_PATH] path from INI file.", 3)
        Log("ERROR", "Could not read [GAME_PATH] path from INI file")
        return ""
    }

    path := Trim(path, "`" " ")  ; trim surrounding quotes and spaces
    Log("DEBUG", "GetGamePath, Path is: " . path)

    if (path != "" && FileExist(path) && SubStr(path, -3) = ".exe")
        return path

    CustomTrayTip("Could not read [GAME_PATH] path from: " . path, 3)
    Log("ERROR", "Invalid or non-existent path in INI file: " . path)
    return ""
}


; ─── SavegamePath. ────────────────────────────────────────────────────────────────────
SavegamePath(path) {
    Global GameExe
    static iniFile := A_ScriptDir . "\sm.ini"
    IniWrite, %path%, %iniFile%, GAME_PATH, Path
    SplitPath, path, GameExe
    Log("DEBUG", "Saved path to config: " . path)
}

GamePath := GetGamePath()
Log("DEBUG", "Saved path to config: " . GamePath)

if (GamePath = "") {
    ShowCustomMsgBox("Warning", "Warning, Path not set in INI file or invalid path. Please select it now.")
    Log("WARNING", "Window not found for: " . GameExe)
    FileSelectFile, path,, , Select game executable, Executable Files (*.exe)
    if (path != "" && FileExist(path)) {
        SavegamePath(path)
        ;GamePath := selectedPath
        ShowCustomMsgBox("Info", "Saved : " . GamePath)
        Log("DEBUG", "Saved : " . GamePath)
    } else {
        ShowCustomMsgBox("Error", "No valid path selected. Exiting.")
        Log("ERROR", "No valid path selected. Exiting.")
        ExitApp
    }
} else {
    ShowCustomMsgBox("Info", "Using path:" . GamePath)
}


; ─── Refresh path function. ────────────────────────────────────────────────────────────────────
RefreshPath() {
    Global GamePath, iniFile

    IniRead, path, %iniFile%, GAME_PATH, Path
    path := Trim(path, "`" " ")

    if (path = "" || !FileExist(path) || SubStr(path, -3) != ".exe") {
        Log("ERROR", "Invalid path in INI file. Please select the game's executable manually.")

        FileSelectFile, userPath, 3, , Select game Executable, Executable (*.exe)
        if (userPath = "") {
            ShowCustomMsgBox("Info", "Cancelled, No file selected. Path unchanged.")
            Log("INFO", "Cancelled, No file selected. Path unchanged.")
            return
        }

        userPath := Trim(userPath, "`" " ")
        IniWrite, %userPath%, %iniFile%, GAME_PATH, Path
        GamePath := userPath
        ShowCustomMsgBox("Info", "Path updated, path successfully updated to: " . userPath)
        return
    }

    GamePath := path
    Log("INFO", "Path refreshed: " . path)
    CustomTrayTip("Path refreshed: " . path, 1)
}


; ─── Check if running function. ────────────────────────────────────────────────────────────────────
GetWindowID(ByRef hwnd) {
    WinGet, hwnd, ID, ahk_exe GameExe
    if !hwnd {
        ShowCustomMsgBox("Warning", "Game executable is not running.")
        Log("WARNING", "Game executable is not running.")
        return false
    }
    return true
}


; ─── Take Snapshot (fast + clean + silent, hybrid capture) ────────────────────────────────
Snapshot:
    Global iniFile, pToken

    ; Ensure INI file is set
    if !IsSet(iniFile)
        iniFile := A_ScriptDir "\sm.ini"

    ; Read game path
    IniRead, GamePath, %iniFile%, GAME_PATH, Path
    if (GamePath = "" || !FileExist(GamePath)) {
        ShowCustomMsgBox("Warning", "Game path not valid in INI.")
        return
    }
    SplitPath, GamePath, GameExe

    ; Check game window
    if !WinExist("ahk_exe " GameExe) {
        ShowCustomMsgBox("Warning", "Game not running: " . GameExe)
        return
    }
    WinGet, hwnd, ID, ahk_exe %GameExe%

    ; Start GDI+ once
    if !IsSet(pToken) {
        pToken := Gdip_Startup()
        if !pToken {
            CustomTrayTip("GDI+ init failed.", 2)
            return
        }
    }

    ; Capture window (hybrid logic)
    pBitmap := CaptureWindow(hwnd)
    if !pBitmap {
        CustomTrayTip("Screen capture failed.", 2)
        return
    }

    ; Snapshot format
    IniRead, ShotFormat, %iniFile%, Settings, SnapshotFormat, png
    ShotFormat := (ShotFormat = "jpg") ? "jpg" : "png"

    ; Create folder and file path
    SnapshotDir := A_ScriptDir "\snapshots"
    FileCreateDir, %SnapshotDir%
    FormatTime, ts,, yyyy-MM-dd_HH-mm-ss
    filePath := SnapshotDir "\" GameExe "_" ts "." ShotFormat

    ; Save image
    result := Gdip_SaveBitmapToFile(pBitmap, filePath)
    Gdip_DisposeImage(pBitmap)

    if (result) {
        CustomTrayTip("Save failed (" . result . ")", 2)
    } else {
        Log("DEBUG", "Snapshot saved: " . filePath)
        if !IsFolderOpen(SnapshotDir)
            Run, explorer.exe "%SnapshotDir%"
    }
return


; ─── Capture Window (PrintWindow → BitBlt → Screen fallback) ───────────────────────────────
CaptureWindow(hwnd) {
    ; Get position & size of window
    WinGetPos, X, Y, W, H, ahk_id %hwnd%
    if (W <= 0 || H <= 0)
        return 0

    ; --- Step 1: try PrintWindow (works for most windowed modes)
    hbm := CreateDIBSection(W, H)
    hdc := CreateCompatibleDC()
    obm := SelectObject(hdc, hbm)
    result := DllCall("user32\PrintWindow", "Ptr", hwnd, "Ptr", hdc, "UInt", 0x00000002)

    ; --- Step 2: fallback to BitBlt (visible region)
    if (!result) {
        hdcSrc := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
        if (hdcSrc) {
            DllCall("gdi32\BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", W, "Int", H
                , "Ptr", hdcSrc, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
            DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", hdcSrc)
        }
    }

    ; --- Convert HBITMAP → GDI+ Bitmap
    pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)

    ; --- Cleanup
    SelectObject(hdc, obm)
    DeleteDC(hdc)
    DeleteObject(hbm)

    ; --- Step 3: final fallback if both failed (fullscreen or blocked)
    if (!pBitmap)
        pBitmap := Gdip_BitmapFromScreen(X "|" Y "|" W "|" H)

    return pBitmap
}


; ─── Check if folder already open ─────────────────────────────────────────────────────────
IsFolderOpen(dirPath) {
    DetectHiddenWindows, On
    WinGet, idList, List, ahk_class CabinetWClass
    Loop, %idList% {
        this_id := idList%A_Index%
        WinGetTitle, this_title, ahk_id %this_id%
        if (InStr(this_title, dirPath))
            return True
    }
    return False
}


; ─── Focus handler. ────────────────────────────────────────────────────────────────────
FocusGame:
    Global GameExe
    if !GameExe {
        ShowCustomMsgBox("Warning", "No game defined yet.")
        Log("WARNING", "No game defined yet.")
        return
    }

    ; --- Get all matching game windows ---
    WinGet, hwndList, List, ahk_exe %GameExe%
    if (hwndList = 0) {
        ShowCustomMsgBox("Error", "Game window not found.")
        Log("ERROR", "Game window not found.")
        return
    }

    ; Use the first window for simplicity (or choose based on other criteria)
    hwnd := hwndList1

    ; --- Restore if minimized or hidden ---
    WinGet, winState, MinMax, ahk_id %hwnd%
    if (winState = -1) {
        Log("INFO", "Game window is hidden. Restoring...")
        WinRestore, ahk_id %hwnd%
    } else if (winState = -1 || winState = 1) {
        WinRestore, ahk_id %hwnd%
    }

    ; --- Try normal activation ---
    WinActivate, ahk_id %hwnd%
    WinWaitActive, ahk_id %hwnd%, , 2

    ; --- Focus-stealing workaround ---
    ; Some games prevent focus, use AlwaysOnTop toggle trick
    WinSet, AlwaysOnTop, On, ahk_id %hwnd%
    Sleep, 50
    WinSet, AlwaysOnTop, Off, ahk_id %hwnd%

    ; --- Check if activation succeeded ---
    WinGetActiveTitle, activeTitle
    WinGetTitle, gameTitle, ahk_id %hwnd%
    if (activeTitle != gameTitle) {
        Log("WARNING", "Failed to fully focus game window, it may block focus.")
        ; Optional: retry after a small delay
        Sleep, 100
        WinActivate, ahk_id %hwnd%
        WinWaitActive, ahk_id %hwnd%, , 1
    }

    Log("DEBUG", "Focused game window successfully: " . gameTitle)
return


; ─── Set process priority function. ────────────────────────────────────────────
SetPriority:
    Global GameExe, lastPriorityChoice
    Gui, Submit, NoHide
    clicked := A_GuiControl

    if (clicked = "PriorityIdle")
        PriorityChoice := "Idle"
    else if (clicked = "PriorityBelow")
        PriorityChoice := "Below Normal"
    else if (clicked = "PriorityNormal")
        PriorityChoice := "Normal"
    else if (clicked = "PriorityAbove")
        PriorityChoice := "Above Normal"
    else if (clicked = "PriorityHigh")
        PriorityChoice := "High"
    else if (clicked = "PriorityRealtime")
        PriorityChoice := "Realtime"

    ; store it globally for SaveSettings()
    lastPriorityChoice := PriorityChoice

    ; map text to code
    priorityCode := ""
    if (PriorityChoice = "Idle")
        priorityCode := "L"
    else if (PriorityChoice = "Below Normal")
        priorityCode := "B"
    else if (PriorityChoice = "Normal")
        priorityCode := "N"
    else if (PriorityChoice = "Above Normal")
        priorityCode := "A"
    else if (PriorityChoice = "High")
        priorityCode := "H"
    else if (PriorityChoice = "Realtime")
        priorityCode := "R"

    Process, Exist, %GameExe%
    if (ErrorLevel) {
        Process, Priority, %ErrorLevel%, %priorityCode%
        Log("INFO", "Process priority set to " . PriorityChoice)
        CustomTrayTip("Process priority set to " . PriorityChoice, 2)
        HighlightPriorityButton(PriorityChoice)  ; highlight active button
    } else {
        CustomTrayTip("Game is not running.", 1)
        Log("WARN", "Attempted to set process priority, but game is not running.")
    }
return


; ─── Update process priority function. ───────────────────────────────────────────
UpdatePriority:
    Process, Exist, %GameExe%
    if (!ErrorLevel) {
        GuiControl,, CurrentPriority, Game is not running.
        for k, v in ["PriorityIdle", "PriorityBelow", "PriorityNormal", "PriorityAbove", "PriorityHigh", "PriorityRealtime"]
            GuiControl, Disable, %v%
        return
    }

    pid := ErrorLevel
    current := GetPriority(pid)
    GuiControl,, CurrentPriority, Priority: %current%

    Global lastPriority
    if (current != lastPriority) {
        lastPriority := current
        HighlightPriorityButton(current)
    }

    for k, v in ["PriorityIdle", "PriorityBelow", "PriorityNormal", "PriorityAbove", "PriorityHigh", "PriorityRealtime"]
        GuiControl, Enable, %v%
return


; ─── Highlight active priority button. ────────────────────────────
HighlightPriorityButton(current) {
    static buttons, origLabel

    if (!IsObject(buttons)) {
        buttons := {}
        origLabel := {}

        buttons["Idle"]         := "PriorityIdle"
        buttons["Below Normal"] := "PriorityBelow"
        buttons["Normal"]       := "PriorityNormal"
        buttons["Above Normal"] := "PriorityAbove"
        buttons["High"]         := "PriorityHigh"
        buttons["Realtime"]     := "PriorityRealtime"

        ; store original labels (so we can restore them later)
        for key, ctrl in buttons {
            ; read current text of control into a temp var
            GuiControlGet, tmp,, %ctrl%
            if (tmp = "")  ; if not set/readable, use the human label
                tmp := key
            origLabel[ctrl] := tmp
        }
    }

    ; Reset all buttons to original text and remove Default
    for key, ctrl in buttons {
        GuiControl,, %ctrl%, % origLabel[ctrl]
        GuiControl, -Default, %ctrl%
    }

    ; Highlight the selected one by prefixing and making it Default
    if (buttons.HasKey(current)) {
        selCtrl := buttons[current]
        GuiControl,, %selCtrl%, % Chr(0x25CF) . " " . origLabel[selCtrl]
        GuiControl, +Default, %selCtrl%
    }
}


; ─── Get currrent process priority function. ────────────────────────────────────────────────────────────────────
GetPriority(pid) {
    try {
        wmi := ComObjGet("winmgmts:")
        query := "Select Priority from Win32_Process where ProcessId=" pid
        for proc in wmi.ExecQuery(query)
            return MapPriority(proc.Priority)
        return "Unknown"
    } catch e {
        CustomTrayTip("Failed to get priority.", 3)
        return "Error"
    }
}

MapPriority(val) {
    switch val {
        case 4, 64:
            return "Idle"
        case 6, 16384:
            return "Below Normal"
        case 8, 32:
            return "Normal"
        case 10, 32768:
            return "Above Normal"
        case 13, 128:
            return "High"
        case 24, 256:
            return "Realtime"
        default:
            return "Unknown (" val ")"
    }
}


; ─── Load settings function. ────────────────────────────────────────────────────────────────────
LoadSettings() {
    Global PriorityChoice, iniFile, GameExe

    Process, Exist, %GameExe%
    if (!ErrorLevel) {
        defaultPriority := "Normal"

        ; Extract just the filename for display
        SplitPath, iniFile, iniFileName

        ; Update GUI
        GuiControl, ChooseString, PriorityChoice, %defaultPriority%
        PriorityChoice := defaultPriority

        Log("INFO", "Set default priority to " defaultPriority " in " iniFile)
    }
    else {
        ; Load saved priority if process exists
        IniRead, savedPriority, %iniFile%, PRIORITY, Priority, Normal
        GuiControl, ChooseString, PriorityChoice, %savedPriority%
        PriorityChoice := savedPriority
    }
}


; ─── Save current settings function. ────────────────────────────────────────────────────────────────────
SaveSettings() {
    Global iniFile, lastPriorityChoice

    if (lastPriorityChoice = "") {
        Log("WARN", "No priority selected nothing to save.")
        return
    }

    Log("DEBUG", "Attempting to save priority: " lastPriorityChoice)
    IniWrite, %lastPriorityChoice%, %iniFile%, PRIORITY, Priority
    Log("INFO", "Priority set to: " lastPriorityChoice)
}


; ─── View configuration function. ────────────────────────────────────────────────────────────────────
ViewConfig:
    Global iniFile
    Run, notepad.exe "%iniFile%"
    SplitPath, iniFile, iniFileName
    Log("DEBUG", "Opened and viewed: " iniFile)
return


; ─── LOG FUNCTION ─────────────────────────────────────────────────────────────────────
Log(level, msg) {
    Global logFile
    static needsRotation := true
    static inLog := false
    static maxEntries := 1000  ; Keep last 1000 lines

    if (inLog)
        return
    inLog := true

    ; Ensure main log path is defined
    if (!logFile) {
        logFile := A_ScriptDir . "\sm.log"
    }

    ; --- Rotation if >1MB ---
    if (needsRotation && FileExist(logFile)) {
        FileGetSize, size, %logFile%
        if (size > 1024000) {  ; 1 MB
            FormatTime, timestamp,, yyyyMMdd_HHmmss
            SplitPath, logFile, name
            newName := A_ScriptDir . "\" . name . "_" . timestamp . ".log"
            FileMove, %logFile%, %newName%
        }
        needsRotation := false
    }

    ; --- New log entry ---
    FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
    logEntry := "[" timestamp "] [" level "] " msg "`r`n"

    ; Write to log (safe overwrite with trimming)
    try {
        TrimAndPrepend(logFile, logEntry, maxEntries)
    } catch {
        ; Last resort: try to append directly
        FileAppend, %logEntry%, %logFile%
    }

    inLog := false
}

; --- HELPER FUNCTION TO TRIM AND PREPEND LOG ---
TrimAndPrepend(filePath, newEntry, maxEntries) {
    FileRead, oldContent, %filePath%
    lines := StrSplit(oldContent, "`n", "`r")

    ; Trim to last maxEntries-1 lines
    if (lines.MaxIndex() > maxEntries - 1) {
        startIndex := lines.MaxIndex() - (maxEntries - 2)
        newLines := []
        Loop, % lines.MaxIndex() - startIndex + 1
            newLines.Push(lines[startIndex + A_Index - 1])
        lines := newLines
    }

    trimmedContent := ""
    if (lines.MaxIndex() > 0) {
        for index, line in lines
            trimmedContent .= line "`n"
    }

    ; Prepend new entry
    FileDelete, %filePath%
    FileAppend, %newEntry%%trimmedContent%, %filePath%
}


; ─── VIEW LOG FUNCTION ────────────────────────────────────────────────────────────────
ViewLog:
    Global logFile
    if (!logFile)
        logFile := A_ScriptDir . "\sm.log"

    if (FileExist(logFile)) {
        Run, notepad.exe "%logFile%"
        Log("DEBUG", "Opened log: " . logFile)
    } else {
        CustomTrayTip("No log file found.", 1)
        Log("WARNING", "ViewLog: No log file found.")
    }
return


; ─── CLEAR LOG FUNCTION ──────────────────────────────────────────────────────────────
ClearLog:
    Global logFile
    if (!logFile)
        logFile := A_ScriptDir . "\sm.log"

    if (FileExist(logFile)) {
        f := FileOpen(logFile, "w")
        if (f) {
            f.Close()
            CustomTrayTip("Log cleared successfully", 1)
            Log("INFO", "Cleared main log.")
        } else {
            CustomTrayTip("Failed to clear log", 1)
            Log("ERROR", "Failed to clear log.")
        }
    } else {
        CustomTrayTip("No log file to clear.", 1)
        Log("INFO", "ClearLog: No log file found.")
    }
return


; ─── Custom tray tip function. ────────────────────────────────────────────────────────────────────
CustomTrayTip(Text, Icon := 1) {
    static Title := "ScreenManager"
    Icon := (Icon >= 0 && Icon <= 3) ? Icon : 1
    TrayTip, %Title%, %Text%, , % Icon|16
}


; -------------------------------
; Embedded minimal GDI+ functions
; -------------------------------
; ─── GDI Helper Functions . ────────────────────────────────────────────────────────────────────────
CreateCompatibleDC() {
    return DllCall("gdi32.dll\CreateCompatibleDC", "Ptr", 0, "Ptr")
}

CreateDIBSection(w, h, hdc := 0, bpp := 32) {
    VarSetCapacity(bi, 40, 0)
    NumPut(40, bi, 0, "UInt")       ; biSize
    NumPut(w, bi, 4, "Int")         ; biWidth
    NumPut(-h, bi, 8, "Int")        ; biHeight (negative = top-down)
    NumPut(1, bi, 12, "UShort")     ; biPlanes
    NumPut(bpp, bi, 14, "UShort")   ; biBitCount
    NumPut(0, bi, 16, "UInt")       ; biCompression = BI_RGB
    return DllCall("gdi32.dll\CreateDIBSection", "Ptr", hdc, "Ptr", &bi, "UInt", 0, "PtrP", ppvBits := 0, "Ptr", 0, "UInt", 0, "Ptr")
}

DeleteDC(hdc) {
    return DllCall("gdi32.dll\DeleteDC", "Ptr", hdc)
}

DeleteObject(hObj) {
    return DllCall("gdi32.dll\DeleteObject", "Ptr", hObj)
}

SelectObject(hdc, hObj) {
    return DllCall("gdi32.dll\SelectObject", "Ptr", hdc, "Ptr", hObj)
}

; ─── Clean up GDI+ at exit ──────────────────────────────────────────────────────────────────────
OnExit, CleanupGDI
return


Gdip_Startup() {
    local gdiplusToken, si
    VarSetCapacity(si, 16, 0)
    NumPut(1, si, 0, "UInt")
    if (DllCall("gdiplus\GdiplusStartup", "ptr*", gdiplusToken, "ptr", &si, "ptr", 0) != 0)
        return 0
    return gdiplusToken
}
Gdip_Shutdown(token) {
    if (token)
        DllCall("gdiplus\GdiplusShutdown", "ptr", token)
}
Gdip_BitmapFromScreen(Screen) {
    local S, x, y, w, h, hdcScreen, hdcMem, hbm, obm, pBitmap
    StringSplit, S, Screen, |
    if (S0 = 4) {
        x := S1, y := S2, w := S3, h := S4
    } else {
        SysGet, x, 76 ; SM_XVIRTUALSCREEN
        SysGet, y, 77 ; SM_YVIRTUALSCREEN
        SysGet, w, 78 ; SM_CXVIRTUALSCREEN
        SysGet, h, 79 ; SM_CYVIRTUALSCREEN
    }

    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    hdcMem := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hbm := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", w, "int", h, "ptr")
    obm := DllCall("SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
    DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h, "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", hdcMem, "ptr", obm)
    DllCall("DeleteDC", "ptr", hdcMem)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    if (DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", pBitmap) != 0) {
        DllCall("DeleteObject", "ptr", hbm)
        return 0
    }
    DllCall("DeleteObject", "ptr", hbm)
    return pBitmap
}
Gdip_SaveBitmapToFile(pBitmap, sOutput) {
    local ext, guid, CLSID
    SplitPath, sOutput,,, ext
    ext := LTrim(ext)
    if (ext = "")
        ext := "png"
    static clsid_png := "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
    static clsid_jpg := "{557CF401-1A04-11D3-9A73-0000F81EF32E}"
    guid := (ext = "jpg" || ext = "jpeg") ? clsid_jpg : clsid_png
    VarSetCapacity(CLSID, 16)
    if (DllCall("ole32\CLSIDFromString", "wstr", guid, "ptr", &CLSID) != 0)
        return 1
    return DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", sOutput, "ptr", &CLSID, "ptr", 0)
}
Gdip_DisposeImage(pBitmap) {
    return DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
}

; ─── Convert HBITMAP → GDI+ Bitmap ────────────────────────────────────────────────
Gdip_CreateBitmapFromHBITMAP(hBitmap, hPalette := 0) {
    DllCall("gdiplus.dll\GdipCreateBitmapFromHBITMAP"
        , "Ptr", hBitmap
        , "Ptr", hPalette
        , "PtrP", pBitmap)
    return pBitmap
}

CleanupGDI:
    Global pToken
    if (pToken)
        Gdip_Shutdown(pToken)
    ExitApp
return


; ─── Custom msgbox. ────────────────────────────────────────────────────────────────────
ShowCustomMsgBox(title, text, x := "", y := "") {
    Gui, MsgBoxGui:New, +AlwaysOnTop +ToolWindow, %title%
    Gui, MsgBoxGui:Add, Text,, %text%
    Gui, MsgBoxGui:Add, Button, gCloseCustomMsgBox Default, OK

    ; Auto-position if x/y provided
    if (x != "" && y != "")
        Gui, MsgBoxGui:Show, x%x% y%y% AutoSize
    else
        Gui, MsgBoxGui:Show, AutoSize Center
}

CloseCustomMsgBox:
    Gui, MsgBoxGui:Destroy
return


; ───  Check internet status. ──────────────────────────────────────────────
CheckInternetStatus:
    online := IsInternetAvailable()
    statusText := online ? "online" : "offline"
    symbol := online ? Chr(0x25CF) : Chr(0x25CB)  ; ● or ○

    if (statusText != lastStatus) {
        title := "Screen Manager :: " . Chr(169) . " " . A_YYYY . " Philip :: " . symbol . " " . statusText
        Gui, Show, NA, %title%
        lastStatus := statusText
        Log("INFO", "Internet status changed: " . statusText)
    }
return


; ───  Is internet available. ──────────────────────────────────────────────
IsInternetAvailable() {
    url := "https://jsonplaceholder.typicode.com/posts"
    http := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    try {
        http.SetTimeouts(3000,3000,3000,3000)
        http.Open("GET", url, false)
        http.Send()
        return (http.Status >= 200 && http.Status < 300)
    } catch {
        return false
    }
}


; ─── Enable/disable buttons depending on whether the game is running. ─────────────────────────────
UpdateButtonStates() {
    global GameExe

    Process, Exist, %GameExe%     ; Check if the game is running
    isRunning := ErrorLevel

    ; Enable/disable your buttons
    if (isRunning) {
        GuiControl, Enable, ExitGame
        GuiControl, Enable, SizeFull
        GuiControl, Enable, SizeWindowed
        GuiControl, Enable, SizeBorderless
        GuiControl, Enable, SizeMinimized
        GuiControl, Enable, SizeMaximized
        GuiControl, Enable, SizeHidden
        GuiControl, Enable, SizeRestored
        GuiControl, Enable, Size1920
        GuiControl, Enable, Size2560
        GuiControl, Enable, Size3840
        GuiControl, Enable, Size5120
        GuiControl, Enable, Size6016
        GuiControl, Enable, Size7680
        GuiControl, Enable, Snapshot
        GuiControl, Enable, MoveToMonitor
        GuiControl, Enable, BtnResizeWider
        GuiControl, Enable, BtnResizeNarrower
        GuiControl, Enable, BtnResizeTaller
        GuiControl, Enable, BtnResizeShorter
        GuiControl, Enable, BtnFocusGame
        GuiControl, Enable, BtnNudgeUp
        GuiControl, Enable, BtnNudgeDown
        GuiControl, Enable, BtnNudgeLeft
        GuiControl, Enable, BtnNudgeRight
        GuiControl, Enable, Btn1
        GuiControl, Enable, Btn5
        GuiControl, Enable, Btn10
        GuiControl, Enable, Btn15
        GuiControl, Enable, Btn20
        GuiControl, Enable, Btn25
        GuiControl, Enable, SizeBorderless1920
        GuiControl, Enable, SizeBorderlessTopmost1920
        GuiControl, Enable, SizeBorderlessTool1920
        GuiControl, Enable, SizeBorderlessLayered1920
        GuiControl, Enable, SizeBorderlessTopLayered1920
        GuiControl, Enable, SizeBorderlessNoAct1920
        GuiControl, Enable, SizeWindowedTopmost1920
        GuiControl, Enable, SizeWindowedTool1920
        GuiControl, Enable, SizeWindowedLayered1920
        GuiControl, Enable, SizeWindowedNoAct1920
        GuiControl, Enable, SizeWindowedTopLayered1920
        GuiControl, Enable, SizeFakeFullLayered1920
        GuiControl, Enable, SizeFakeFullTool1920
        GuiControl, Enable, SizeFakeFullNoAct1920
        GuiControl, Enable, SizeFakeFullAll1920
    } else {
        GuiControl, Disable, ExitGame
        GuiControl, Disable, SizeFull
        GuiControl, Disable, SizeWindowed
        GuiControl, Disable, SizeBorderless
        GuiControl, Disable, SizeHidden
        GuiControl, Disable, SizeMinimized
        GuiControl, Disable, SizeMaximized
        GuiControl, Disable, SizeHidden
        GuiControl, Disable, SizeRestored
        GuiControl, Disable, Size1920
        GuiControl, Disable, Size2560
        GuiControl, Disable, Size3840
        GuiControl, Disable, Size5120
        GuiControl, Disable, Size6016
        GuiControl, Disable, Size7680
        GuiControl, Disable, Snapshot
        GuiControl, Disable, MoveToMonitor
        GuiControl, Disable, BtnResizeWider
        GuiControl, Disable, BtnResizeNarrower
        GuiControl, Disable, BtnResizeTaller
        GuiControl, Disable, BtnResizeShorter
        GuiControl, Disable, BtnFocusGame
        GuiControl, Disable, BtnNudgeUp
        GuiControl, Disable, BtnNudgeDown
        GuiControl, Disable, BtnNudgeLeft
        GuiControl, Disable, BtnNudgeRight
        GuiControl, Disable, Btn1
        GuiControl, Disable, Btn5
        GuiControl, Disable, Btn10
        GuiControl, Disable, Btn15
        GuiControl, Disable, Btn20
        GuiControl, Disable, Btn25
        GuiControl, Disable, SizeBorderless1920
        GuiControl, Disable, SizeBorderlessTopmost1920
        GuiControl, Disable, SizeBorderlessTool1920
        GuiControl, Disable, SizeBorderlessLayered1920
        GuiControl, Disable, SizeBorderlessTopLayered1920
        GuiControl, Disable, SizeBorderlessNoAct1920
        GuiControl, Disable, SizeWindowedTopmost1920
        GuiControl, Disable, SizeWindowedTool1920
        GuiControl, Disable, SizeWindowedLayered1920
        GuiControl, Disable, SizeWindowedNoAct1920
        GuiControl, Disable, SizeWindowedTopLayered1920
        GuiControl, Disable, SizeFakeFullLayered1920
        GuiControl, Disable, SizeFakeFullTool1920
        GuiControl, Disable, SizeFakeFullNoAct1920
        GuiControl, Disable, SizeFakeFullAll1920
    }
}


GuiClose:
    ExitApp
return
