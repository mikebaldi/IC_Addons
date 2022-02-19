#SingleInstance, Force

;=======================
;Script Optimization
;=======================
#HotkeyInterval 1000  ; The default value is 2000 (milliseconds).
#MaxHotkeysPerInterval 70 ; The default value is 70
#NoEnv ; Avoids checking empty variables to see if they are environment variables (recommended for all new scripts). Default behavior for AutoHotkey v2.
SetWorkingDir %A_ScriptDir%
SetWinDelay, 33 ; Sets the delay that will occur after each windowing command, such as WinActivate. (Default is 100)
SetControlDelay, 0 ; Sets the delay that will occur after each control-modifying command. -1 for no delay, 0 for smallest possible delay. The default delay is 20.
;SetKeyDelay, 0 ; Sets the delay that will occur after each keystroke sent by Send or ControlSend. [SetKeyDelay , Delay, PressDuration, Play]
SetBatchLines, -1 ; How fast a script will run (affects CPU utilization).(Default setting is 10ms - prevent the script from using any more than 50% of an idle CPU's time.
                  ; This allows scripts to run quickly while still maintaining a high level of cooperation with CPU sensitive tasks such as games and video capture/playback.
ListLines Off
Process, Priority,, High
CoordMode, Mouse, Client

Gui, MyWindow:New
Gui, MyWindow:+Resize -MaximizeBox
Gui, MyWindow:Add, Text, x15 y15, NERDs add on is running.
Gui, MyWindow:Add, Text, x15 y+5, When the correct NERDs are in the wagon, this window will close and the script will end.
Gui, MyWindow:Add, Text, x15 y+5, To end the script early, just close this window.
Gui, MyWindow:Add, Text, x15 y+15, What is happening:
Gui, MyWindow:Add, Text, x+5 vNERDs_Status w300,
Gui, MyWindow:Add, Text, x15 y+5 vNERDs_UltKey w200,

Gui, MyWindow:Show, x0 y0, Running NERDs...
;Gui, MyWindow:Show

#include %A_LineFile%\..\..\..\SharedFunctions\MemoryRead\EffectKeyHandlers\NerdWagonHandler.ahk
global g_Nerds := new NerdWagonHandler
if !IsObject(g_Nerds)
{
    msgBox, Failed to load NERDs Wagon Handler, ending script.
    ExitApp
}

#include %A_LineFile%\..\..\..\SharedFunctions\IC_SharedFunctions_Class.ahk
global g_SF := new IC_SharedFunctions_Class

#include %A_LineFile%\..\..\..\SharedFunctions\IC_KeyHelper_Class.ahk
global g_KeyMap := KeyHelper.BuildVirtualKeysMap()

#include %A_LineFile%\..\..\..\SharedFunctions\json.ahk
global g_NERDsSettings := g_SF.LoadObjectFromJSON( A_LineFile . "\..\Settings.json" )
if !IsObject(g_NERDsSettings)
{
    msgBox, Failed to load settings, ending script.
    ExitApp
}

if (g_NERDsSettings.nerdCount > 3)
    g_NERDsSettings.nerdCount := 3

loop
{
    ;initialize shared functions for inputs and memory reads, every loop incase game closes/crashes
    g_SF.Hwnd := WinExist("ahk_exe IdleDragons.exe")
    Process, Exist, IdleDragons.exe
    g_SF.PID := ErrorLevel
    g_SF.Memory.OpenProcessReader()
    g_Nerds.Initialize()
    nerdCount := 0
    if (g_SF.Hwnd AND g_SF.PID)
    {
        if g_NERDsSettings[ g_Nerds.GetNeard0Int() ]
            ++nerdCount
        if g_NERDsSettings[ g_Nerds.GetNeard1Int() ]
            ++nerdCount
        if g_NERDsSettings[ g_Nerds.GetNeard2Int() ]
            ++nerdCount
        GuiControl, MyWindow:, NERDs_Status, % "Trying to load the correct NERDs. Matches: " . nerdCount
        if (nerdCount >= g_NERDsSettings.nerdCount)
        {
            msgBox, The correct NERDs are loaded, ending script.
            ExitApp
        }
        ultKey := g_SF.GetUltimateButtonByChampID(87)
        if (ultKey == -1)
        {
            msgbox, 5,, Cannot find NERDs ultimate. Make sure they are in the formation and leveled up prior to clicking 'Retry'. Click 'Cancel' to end script.
            IfMsgBox, Retry
                Continue
            IfMsgBox, Cancel
                ExitApp
        }
        GuiControl, MyWindow:, NERDs_UltKey, % "Ult Key: " . ultKey
        g_SF.DirectedInput(,, ultKey)
    }
    else
        GuiControl, MyWindow:, NERDs_Status, Waiting for another script to open IC...
    sleep, 250
}

MyWindowGuiClose() 
{
    MsgBox 4,, Are you sure you want to `exit?
    IfMsgBox Yes
    ExitApp
    IfMsgBox No
    return True
}