#include %A_LineFile%\..\..\..\SharedFunctions\MemoryRead\EffectKeyHandlers\NerdWagonHandler.ahk

GUIFunctions.AddTab("NERDs")

global g_NERDsSettings := g_SF.LoadObjectFromJSON( A_LineFile . "\..\Settings.json" )
if !IsObject(g_NERDsSettings)
    g_NERDsSettings := {}

Gui, ICScriptHub:Tab, NERDs
Gui, ICScriptHub:Font, w700
Gui, ICScriptHub:Add, Text, x15 y80, NERDs
Gui, ICScriptHub:Font, w400
Gui, ICScriptHub:Add, Text, x15 y+5 w450 wrap, This AddOn will launch a seaparte script that will spam NERDs ultimate until you get the desired set of three NERDs.
Gui, ICScriptHub:Add, Text, x15 y+15, Select the NERDs you would like in your wagon:
loop, 6
{
    if (g_NERDsSettings[A_Index] == "")
        g_NERDsSettings[A_Index] := 0
    chk := g_NERDsSettings[A_Index]
    nerd := new NerdWagonHandler
    Gui, ICScriptHub:Add, Checkbox, vNERDs_CB%A_Index% Checked%chk% x15 y+10 gNERDs_CB_Clicked, % nerd.NerdType[A_Index]
    Gui, ICScriptHub:Add, Text, x+5 vNERDs_CB%A_Index%_Saved w200, % chk == 1 ? "Saved value: Checked":"Saved value: Unchecked"
}
NERDs_CB_Clicked()

;Gui, ICScriptHub:Add, Button, x15 y+10 w160 gNERDs_Save, Save Settings
Gui, ICScriptHub:Add, Button, x15 y+20 w160 gNERDs_Run, Run

NERDs_Save()
{
    Gui, ICScriptHub:Submit, NoHide
    nerdCount := 0
    loop, 6
    {
        g_NERDsSettings[A_Index] := NERDs_CB%A_Index%
        if NERDs_CB%A_Index%
            ++nerdCount
        GuiControl, ICScriptHub:, NERDs_CB%A_Index%_Saved, % NERDs_CB%A_Index% == 1 ? "Saved value: Checked":"Saved value: Unchecked"
    }

    g_NERDsSettings.nerdCount := nerdCount

    g_SF.WriteObjectToJSON(A_LineFile . "\..\Settings.json" , g_NERDsSettings)
}

NERDs_Run()
{
    scriptLocation := A_LineFile . "\..\IC_NERDs_Run.ahk"
    Run, %A_AhkPath% "%scriptLocation%"    
}

NERDs_CB_Clicked()
{
    Gui, ICScriptHub:Submit, NoHide
    nerdCount := 0
    loop, 6
    {
        if (nerdCount >= 3)
        {
            GuiControl, ICScriptHub:, NERDs_CB%A_Index%, 0
            GuiControl, ICScriptHub:Disable, NERDs_CB%A_Index%
        }
        else
        {
            GuiControl, ICScriptHub:Enable, NERDs_CB%A_Index%
        }
        if NERDs_CB%A_Index%
            ++nerdCount
    }
    if (nerdCount >= 3)
    {
        loop, 6
        {
            if !(NERDs_CB%A_Index%)
                GuiControl, ICScriptHub:Disable, NERDs_CB%A_Index%
        }
    }
    NERDs_Save()
}