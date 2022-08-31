#include %A_LineFile%\..\IC_NoModronLvling_Functions.ahk

GUIFunctions.AddTab("No Modron Leveling")

global g_HeroDefines

global g_SpecSettings := g_SF.LoadObjectFromJSON( A_LineFile . "\..\SpecSettings.json" )
if !IsObject(g_SpecSettings)
{
    g_SpecSettings := {}
    g_SpecSettings.TimeStamp := ""
}
global g_MaxLvl := g_SF.LoadObjectFromJSON( A_LineFile . "\..\MaxLvl.json" )
if !IsObject(g_MaxLvl)
{
    g_MaxLvl := {}
    g_MaxLvl.TimeStamp := ""
}

Gui, ICScriptHub:Tab, No Modron Leveling
Gui, ICScriptHub:Font, w700
Gui, ICScriptHub:Add, Text, x15 y80, BETA No Modron Leveling and Specializing
Gui, ICScriptHub:Font, w400
Gui, ICScriptHub:Add, Text, x15 y+5, An add on that will level to soft cap and specialize champions without Modron Automation.
Gui, ICScriptHub:Add, Text, x15 y+5, To pause this script, press the PAUSE key.
Gui, ICScriptHub:Add, Text, x15 y+5, NOTE: This add on will take control of the mouse to select specializations and assumes sufficient gold to soft cap.
Gui, ICScriptHub:Add, Text, x15 y+10, Specialization Settings Status: 
Gui, ICScriptHub:Add, Text, x+5 vNML_Settings w300, % g_SpecSettings.TimeStamp ? "Loaded and dated " . g_SpecSettings.TimeStamp : "Not Loaded"
Gui, ICScriptHub:Add, Button, x15 y+10 w160 gNML_SpecSettings, Select/Create Spec. Settings
Gui, ICScriptHub:Add, Text, x15 y+10, Max. Level Data Status: 
Gui, ICScriptHub:Add, Text, x+5 vNML_MaxLvl w300, % g_MaxLvl.TimeStamp ? "Loaded and dated " . g_MaxLvl.TimeStamp : "Not Loaded"
Gui, ICScriptHub:Add, Button, x15 y+10 w160 gNML_BuildMaxLvlData, Load Max. Level Data
Gui, ICScriptHub:Add, Text, x15 y+15, Select the formations to level and specialize
Gui, ICScriptHub:Add, Checkbox, vNML_CB1 x15 y+5, "Q"
Gui, ICScriptHub:Add, Checkbox, vNML_CB2 x+15, "W"
Gui, ICScriptHub:Add, Checkbox, vNML_CB3 x+15, "E"
Gui, ICScriptHub:Add, Button, x15 y+10 w160 gNML_LevelAndSpec, Level and Specialize

Gui, ICScriptHub:Add, Text, x15 y+15 vNML_Formation w300,
Gui, ICScriptHub:Add, Text, x15 y+5 vNML_Champ w300,

NML_LevelAndSpec()
{
    global
    if !(g_MaxLvl.TimeStamp)
    {
        msgbox, Max level data not found, click Load Max. Level Data prior to running this script.
        return
    }
    if !(g_SpecSettings.TimeStamp)
    {
        msgbox, Specialization settings not found, click Select/Create Spec. Settings prior to running this script.
        return
    }
    g_SF.Hwnd := WinExist("ahk_exe " . g_UserSettings[ "ExeName" ])
    g_SF.Memory.OpenProcessReader()
    lvlObj := new IC_NML_Functions
    Gui, ICScriptHub:Submit, NoHide
    formationKey := {1:"q", 2:"w", 3:"e"}
    index := 1
    loop, 3
    {
        if (NML_CB%index%)
        {
            loop, 3
                g_SF.DirectedInput(,, formationKey[index])
            champArray := g_SF.Memory.GetFormationByFavorite(index)
            GuiControl, ICScriptHub:, NML_Formation, % "Formation " . formationKey[index] . ": " . ArrFnc.GetDecFormattedArrayString(champArray)
            for k, v in champArray
            { 
                if (v == -1 OR !v)
                    continue
                seat := g_SF.Memory.ReadChampSeatByID(v)
                inputKey := "{F" . seat . "}"
                name := g_SF.Memory.ReadChampNameByID(v)
                if !name
                    name := v
                champLvl := g_SF.Memory.ReadChampLvlByID(v)
                GuiControl, ICScriptHub:, NML_Champ, % "Leveling " . name . " (" . inputKey . ") " . champLvl . " / " . g_MaxLvl[v]
                while (g_MaxLvl[v] > champLvl)
                {
                    g_SF.DirectedInput(,, inputKey, formationKey[index])
                    sleep, 33
                    champLvl := g_SF.Memory.ReadChampLvlByID(v)
                    if lvlObj.IsSpec(v, champLvl, g_SpecSettings)
                        lvlObj.PickSpec(v, champLvl, g_SpecSettings)
                    GuiControl, ICScriptHub:, NML_Champ, % "Leveling " . name . " (" . inputKey . ") " . champLvl . " / " . g_MaxLvl[v]
                }
            }
        }
        ++index
    }
    GuiControl, ICScriptHub:, NML_Formation,
    GuiControl, ICScriptHub:, NML_Champ,
    msgbox, Leveling and Specializing Complete.
}

NML_SpecSettings()
{
    GuiControl, ICScriptHub:, NML_Settings, Processing data, please wait...
    g_HeroDefines := IC_NML_Functions.GetHeroDefines()
    NML_BuildSpecSettingsGUI()
    Gui, SpecSettingsGUI:Show
    GuiControl, ICScriptHub:, NML_Settings, % g_SpecSettings.TimeStamp ? "Loaded and dated " . g_SpecSettings.TimeStamp : "Not Loaded"
}

NML_BuildMaxLvlData()
{
    GuiControl, ICScriptHub:, NML_MaxLvl, Processing data, please wait...
    g_HeroDefines := IC_NML_Functions.GetHeroDefines()
    g_MaxLvl := {}
    for k, v in g_HeroDefines
    {
        if v.MaxLvl
            g_MaxLvl[k] := v.MaxLvl
    }
    g_MaxLvl.TimeStamp := A_MMMM . " " . A_DD . ", " . A_YYYY . ", " . A_Hour . ":" . A_Min . ":" . A_Sec
    g_SF.WriteObjectToJSON(A_LineFile . "\..\MaxLvl.JSON", g_MaxLvl)
    GuiControl, ICScriptHub:, NML_MaxLvl, % g_MaxLvl.TimeStamp ? "Loaded and dated " . g_MaxLvl.TimeStamp : "Not Loaded"
}

NML_BuildSpecSettingsGUI()
{
    global
    Gui, SpecSettingsGUI:New
    Gui, SpecSettingsGUI:+Resize -MaximizeBox
    Gui, SpecSettingsGUI:Font, q5
    Gui, SpecSettingsGUI:Add, Button, x554 y25 w60 gNML_SaveClicked, Save
    Gui, SpecSettingsGUI:Add, Button, x554 y+25 w60 gNML_CloseClicked, Close
    Gui, SpecSettingsGUI:Add, Tab3, x5 y5 w539, Seat 1|Seat 2|Seat 3|Seat 4|Seat 5|Seat 6|Seat 7|Seat 8|Seat 9|Seat 10|Seat 11|Seat 12|
    seat := 1
    loop, 12
    {
        Gui, Tab, Seat %seat%
        Gui, SpecSettingsGUI:Font, w700 s11
        Gui, SpecSettingsGUI:Add, Text, x15 y35, Seat %Seat% Champions:
        Gui, SpecSettingsGUI:Font, w400 s9
        for champID, define in g_HeroDefines
        {
            if (define.Seat == seat)
            {
                name := define.HeroName
                Gui, SpecSettingsGUI:Font, w700
                Gui, SpecSettingsGUI:Add, Text, x15 y+10, Name: %name%    `ID: %champID%
                Gui, SpecSettingsGUI:Font, w400
                prevUpg := 0
                for key, set in define.SpecDefines.setList
                {
                    reqLvl := set.reqLvl
                    ddlString := define.SpecDefines.DDL[reqLvl, prevUpg]
                    choice := 0
                    for k, v in g_SpecSettings[champID]
                    {
                        if (v.requiredLvl == reqLvl)
                            choice := v.Choice
                    }
                    if !choice
                        choice := 1
                    Gui, SpecSettingsGUI:Add, DropDownList, x15 y+5 vNML_%champID%Spec%reqLvl% Choose%choice% AltSubmit gNML_UpdateDDL, %ddlString%
                    prevUpg := define.SpecDefines.SpecDefineList[reqLvl, prevUpg][choice].UpgradeID
                }
            }
        }
        ++seat
    }
    Return
}

;close spec settings GUI
NML_CloseClicked()
{
    Gui, SpecSettingsGUI:Hide
    Return
}

;save button function from GUI built as part of NML_BuildSpecSettingsGUI()
NML_SaveClicked()
{
    Gui, SpecSettingsGUI:Submit, NoHide
    For champID, define in g_HeroDefines
    {
        g_SpecSettings[champID] := {}
        prevUpg := 0
        for k, v in define.SpecDefines.setList
        {
            reqLvl := v.reqLvl
            choice := NML_%champID%Spec%reqLvl%
            position := g_SpecSettings[champID].Push(define.SpecDefines.SpecDefineList[reqLvl, prevUpg][choice].Clone())
            g_SpecSettings[champID][position].Choice := choice
            g_SpecSettings[champID][position].Choices := define.SpecDefines.SpecDefineList[reqLvl, prevUpg].Count()
            prevUpg := g_SpecSettings[champID][position].UpgradeID
        }
    }
    g_SpecSettings.TimeStamp := A_MMMM . " " . A_DD . ", " . A_YYYY . ", " . A_Hour . ":" . A_Min . ":" . A_Sec
    g_SF.WriteObjectToJSON(A_LineFile . "\..\SpecSettings.JSON", g_SpecSettings)
    GuiControl, ICScriptHub:, NML_Settings, % g_SpecSettings.TimeStamp ? "Loaded and dated " . g_SpecSettings.TimeStamp : "Not Loaded"
    Return
}

NML_UpdateDDL()
{
    Gui, SpecSettingsGUI:Submit, NoHide
    choice := %A_GuiControl%
    foundPos := InStr(A_GuiControl, "S")
    champID := SubStr(A_GuiControl, 5, foundPos - 5) + 0
    foundPos := InStr(A_GuiControl, "Spec")
    reqLvl := SubStr(A_GuiControl, foundPos + 4) + 0
    ;need previous upgrade id to get current upgrade id
    prevUpg := 0
    for k, v in g_SpecSettings[champID]
    {
        if (v.requiredLvl < reqLvl)
            prevUpg := v.UpgradeID
    }
    prevUpg := g_HeroDefines[champID].SpecDefines.SpecDefineList[reqLvl, prevUpg][choice].UpgradeID
    for k, v in g_HeroDefines[champID].SpecDefines.setList
    {
        requiredLvl := v.reqLvl
        if (v.listCount > 1 AND requiredLvl > reqLvl)
        {
            ddlString := "|"
            ddlString .= g_HeroDefines[champID].SpecDefines.DDL[requiredLvl, prevUpg]
            GuiControl, SpecSettingsGUI:, NML_%champID%Spec%requiredLvl%, %ddlString%
            GuiControl, SpecSettingsGUI:Choose, NML_%champID%Spec%requiredLvl%, 1
            prevUpg := g_HeroDefines[champID].SpecDefines.SpecDefineList[requiredLvl, prevUpg][1].UpgradeID
        }
    } 
}

;$SC045::
;Pause

Hotkey, SC045, NML_Pause

NML_Pause()
{
    Pause
}