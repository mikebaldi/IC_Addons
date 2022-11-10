#include %A_LineFile%\..\_AreaHandler.ahk

GUIFunctions.AddTab("Area Handler")

Gui, ICScriptHub:Tab, Area Handler
Gui, ICScriptHub:Font, w700
Gui, ICScriptHub:Add, Text, x15 y80, Area Handler
Gui, ICScriptHub:Font, w400
Gui, ICScriptHub:Add, Text, x15 y+5 w450, This Addon uses memory writes to make all transitions quick, all monsters basic (melee if possible), and enable skipping bosses on variants.

Gui, ICScriptHub:Add, Button, x15 y+10 w160 gAreaHandler_Run, Run

AreaHandler_Run()
{
    areaHandler := new _AreaHandler
    msgbox, The Area Handler has completed updating memory values.
}