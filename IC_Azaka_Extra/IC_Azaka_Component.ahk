GUIFunctions.AddTab("Azaka")

global g_AzakaSettings := g_SF.LoadObjectFromJSON( A_LineFile . "\..\Settings.json" )
if !IsObject(g_AzakaSettings)
    g_AzakaSettings := {}

Gui, ICScriptHub:Tab, Azaka
Gui, ICScriptHub:Font, w700
Gui, ICScriptHub:Add, Text, x15 y80, Azaka
Gui, ICScriptHub:Font, w400
Gui, ICScriptHub:Add, Text, x15 y+5, This AddOn will spam Azaka and other champion's ults at a set Omin number of contracts fulfilled value.

if ( g_AzakaSettings.NumContracts == "" )
    g_AzakaSettings.NumContracts := 95
Gui, ICScriptHub:Add, Text, x15 y+15, Ult. on this many Contracts Fulfilled:
Gui, ICScriptHub:Add, Edit, vAzaka_Contracts x+5 w50, % g_AzakaSettings.NumContracts
Gui, ICScriptHub:Add, Text, x+5 vAzaka_Contracts_Saved w200, % "Saved value: " . g_AzakaSettings.NumContracts

if ( g_AzakaSettings.Loops == "" )
    g_AzakaSettings.Loops := 5
Gui, ICScriptHub:Add, Text, x15 y+15, Ult. this many times:
Gui, ICScriptHub:Add, Edit, vAzaka_Loops x+5 w50, % g_AzakaSettings.Loops
Gui, ICScriptHub:Add, Text, x+5 vAzaka_Loops_Saved w200, % "Saved value: " . g_AzakaSettings.Loops

if ( g_AzakaSettings.Ult == "" )
{
    g_AzakaSettings.Ult := {}
    loop, 10
    {
        g_AzakaSettings.Ult[A_Index] := 0
    }
}

Gui, ICScriptHub:Add, Text, x15 y+15, Use the following ultimates:
loop, 10
{
    chk := g_AzakaSettings.Ult[A_Index]
    Gui, ICScriptHub:Add, Checkbox, vAzaka_CB%A_Index% Checked%chk% x15 y+10, % A_Index
    Gui, ICScriptHub:Add, Text, x+5 vAzaka_CB%A_Index%_Saved w200, % chk == 1 ? "Saved value: Checked":"Saved value: Unchecked"
}

Gui, ICScriptHub:Add, Button, x15 y+10 w160 gAzaka_Save, Save Settings
Gui, ICScriptHub:Add, Button, x15 y+10 w160 gAzaka_Run, Run

Gui, ICScriptHub:Add, Text, x15 y+10 vAzaka_Running w300,
Gui, ICScriptHub:Add, Text, x15 y+5 vAzaka_CurrentContracts w300,
Gui, ICScriptHub:Add, Text, x15 y+5 vAzaka_UltsUsed w300,

Azaka_Save()
{
    global
    Gui, ICScriptHub:Submit, NoHide
    g_AzakaSettings.NumContracts := Azaka_Contracts
    GuiControl, ICScriptHub:, Azaka_Contracts_Saved, % "Saved value: " . g_AzakaSettings.NumContracts

    g_AzakaSettings.Loops := Azaka_Loops
    GuiControl, ICScriptHub:, Azaka_Loops_Saved, % "Saved value: " . g_AzakaSettings.Loops

    loop, 10
    {
        g_AzakaSettings.Ult[A_Index] := Azaka_CB%A_Index%
        GuiControl, ICScriptHub:, Azaka_CB%A_Index%_Saved, % Azaka_CB%A_Index% == 1 ? "Saved value: Checked":"Saved value: Unchecked"
    }

    g_SF.WriteObjectToJSON(A_LineFile . "\..\Settings.json" , g_AzakaSettings)
}

Azaka_Run()
{
    GuiControl, ICScriptHub:, Azaka_Running, Azaka farm is running.
    ;initialize shared functions for memory reads and directed inputs
    g_SF.Hwnd := WinExist("ahk_exe " . g_UserSettings[ "ExeName" ])
    g_SF.Memory.OpenProcessReader()
    ;create object for azaka class to update gui
    guiData := {}
    guiData.guiName := "ICScriptHub:"
    guiData.guiControlIDcont := "Azaka_CurrentContracts"
    guiData.guiControlIDults := "Azaka_UltsUsed"
    
    azaka := new AzakaFarm(g_AzakaSettings, guiData)
    azaka.AzakaFarm()

    GuiControl, ICScriptHub:, Azaka_Running, Azaka farm is complete.
    GuiControl, ICScriptHub:, Azaka_CurrentContracts,
    GuiControl, ICScriptHub:, Azaka_UltsUsed,
    msgbox, Azaka farm is complete.
}

class AzakaFarm
{
    omin := {}
    inputs := {}
    loops := {}
    useGUI := false

    __new(settings, guiData)
    {
        this.omin := g_SF.Memory.ActiveEffectKeyHandler.OminContractualObligationsHandler ;new OminContractualObligationsHandler
        loop, 10
        {
            if (settings.Ult[A_Index] AND A_Index < 10)
                this.inputs.Push(A_Index . "")
            else if (settings.Ult[A_Index] AND A_Index == 10)
                this.inputs.Push(0 . "")
        }
        this.loops := settings.Loops
        this.numContracts := settings.NumContracts
        if IsObject(guiData)
        {
            this.useGUI := true
            this.guiName := guiData.guiName
            this.guiControlIDcont := guiData.guiControlIDcont
            this.guiControlIDults := guiData.guiControlIDults
        }
        return this
    }

    AzakaFarm()
    {
        if (this.useGUI)
                GuiControl, % this.guiName, % this.guiControlIDults, % "Ultimates Used: 0"
        loops := this.Loops
        loop, %loops%
        {
            wait := true
            while wait
            {
                if this.farm()
                    wait := false
                sleep, 100
            }
            if (this.useGUI)
                GuiControl, % this.guiName, % this.guiControlIDults, % "Ultimates Used: " . A_Index
        }
    }

    farm()
    {
        g_SF.Memory.ActiveEffectKeyHandler.Refresh()
        num := ActiveEffectKeySharedFunctions.Omin.OminContractualObligationsHandler.ReadNumContractsFulfilled()
        if (this.useGUI)
            GuiControl, % this.guiName, % this.guiControlIDcont, % "Current No. Contracts Fulfilled: " . num
        if (num > this.numContracts)
        {
            while (num > this.numContracts)
            {
                num := ActiveEffectKeySharedFunctions.Omin.OminContractualObligationsHandler.ReadNumContractsFulfilled()
                g_SF.DirectedInput(,, this.inputs*)
                sleep, 100
            }
            return true
        }
        return false
    }
}