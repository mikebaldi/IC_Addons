class IC_NML_Functions
{
    endScript := false

    ;requires single param == simple array of champ IDs. returns an array of obj where obj key == champ ID and obj has fields maxLvl == max level and fKey := Fkey string.
    GetMaxLvlArray(arrayIn)
    {
        arrayOut := {}
        g_SF.Memory.OpenProcessReader()
        for k, v in arrayIn
        {
            if !IsObject(arrayOut[v])
            {
                arrayOut[v] := {}
                arrayOut[v].fKey := "{F" . g_SF.Memory.ReadChampSeatByID(v) . "}"
            }
            upgradeCount := g_SF.Memory.GenericGetValue(g_SF.Memory.GameManager.Game.gameInstances.Controller.UserData.HeroHandler.heroes.allUpgradesOrdered.size.GetGameObjectFromListValues(0, v - 1))
            upgIndex := 0
            ;iterate through every upgrade for that hero
            loop %upgradeCount%
            {
                orderedUpgradesObject := g_SF.Memory.GetHeroOrderedUpgrade(v-1, upgIndex)
                requiredLvl := g_SF.Memory.GenericGetValue(orderedUpgradesObject.requiredLvl.GetGameObjectFromListValues(0))
                ;some upgrades with required level of 9999
                if (requiredLvl < 9999)
                    arrayOut[v].maxLvl := Max(requiredLvl, arrayOut[v].maxLvl)
                ++upgIndex
            }
        }
        return arrayOut
    }

    ;requires single param == array returned from GetMaxLvlArray(). returns inputs == array of Fkey strings of champs not at max lvl.
    GetFkeys(maxLvlArray)
    {
        inputs := {}
        for k, v in maxLvlArray
        {
            if (g_SF.Memory.ReadChampLvlByID(k) < v.maxLvl)
                inputs.Push(v.Fkey)
        }
        return inputs
    }

    BuildSpecSettingsGUI(defines, settings)
    {
        static 
        isBuilt := false
        if !isBuilt
        {
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
                for champID, define in defines
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
                            for k, v in settings[champID]
                            {
                                if (v.requiredLvl == reqLvl)
                                    choice := v.Choice
                            }
                            if !choice
                                choice := 1
                            ;var := "Champ" . champID . "Spec" . reqLvl . "Drop"
                            ;static %var%
                            Gui, SpecSettingsGUI:Add, DropDownList, x15 y+5 vChamp%champID%Spec%reqLvl%Drop Choose%choice% AltSubmit gNML_ChangedDDL, %ddlString%
                            prevUpg := define.SpecDefines.SpecDefinesList[set.reqLvl, prevUpg][choice].UpgradeID
                        }
                    }
                }
            }
        }
    }

    GetHeroDefines()
    {
        start := A_TickCount
        defines := {}
        g_SF.Memory.OpenProcessReader()
        ;iterate through every hero in memory
        heroCount := g_SF.Memory.GenericGetValue(g_SF.Memory.GameManager.Game.gameInstances.Controller.UserData.HeroHandler.heroes.size.GetGameObjectFromListValues(0))
        if (heroCount < 100)
            msgbox, "There may have been an error loading data. Reloading the script may fix the error. Error: Unexpected heroCount"
        champID := 0
        loop %heroCount%
        {
            ++champID
            ;only include owned heroes
            isOwned := g_SF.Memory.GenericGetValue(g_SF.Memory.GameManager.Game.gameInstances.Controller.UserData.HeroHandler.heroes.Owned.GetGameObjectFromListValues(0, champID - 1))
            if !isOwned
                Continue
            name := g_SF.Memory.ReadChampNameByID(champID)
            seat := g_SF.Memory.ReadChampSeatByID(champID)
            defines[champID] := new IC_NML_Functions.HeroDefine(champID, name, seat)
            upgradesObject := g_SF.Memory.GameManager.Game.gameInstances.Controller.UserData.HeroHandler.heroes.allUpgradesOrdered.List.GetFullGameObjectFromListOrDictValues("List", 0, champID - 1)
            upgradesObject := upgradesObject.GetFullGameObjectFromListOrDictValues("Dict", 0)
            upgradesObject.ValueType := "List"
            upgradeCount := g_SF.Memory.GenericGetValue(upgradesObject.size)
            upgIndex := 0
            ;iterate through every upgrade for that hero
            loop %upgradeCount%
            {
                orderedUpgrade := g_SF.Memory.GetHeroOrderedUpgrade(champID-1, upgIndex)
                requiredLvl := g_SF.Memory.GenericGetValue(orderedUpgrade.RequiredLevel)
                ;some upgrades with required level of 9999
                if (requiredLvl < 9999)
                    defines[champID].MaxLvl := Max(requiredLvl, defines[champID].MaxLvl)
                ;look to see if upgrade define has spec graphic id, easiest way to know it is a spec upgrade and appears to work 100% so far.
                ;trying to use upgrade type field was just wrong in a lot of cases. the type spec was commonly overrided by stuff like upgrade ability type.
                isSpec := g_SF.Memory.GenericGetValue(orderedUpgrade.defaultSpecGraphic)
                if isSpec
                {
                    upgradeID := g_SF.Memory.GenericGetValue(orderedUpgrade.ID)
                    requiredUpgradeID := g_SF.Memory.GenericGetValue(orderedUpgrade.RequiredUpgradeID)
                    specName := g_SF.Memory.GenericGetValue(orderedUpgrade.SpecializationName)
                    defines[champID].SpecDefines.AddSpec(upgradeID, requiredLvl, requiredUpgradeID, specName)
                }
                ++upgIndex
            }
            defines[champID].SpecDefines.SortSpecList()
        }
        ;defines.Loaded := 1
        defines.TimeStamp := A_MMMM . " " . A_DD . ", " . A_YYYY . " at " . A_Hour . ":" . A_Min . ":" . A_Sec
        defines.LoadTime := A_TickCount - start
        ;a bit easier to debug from json file
        g_SF.WriteObjectToJSON(A_LineFile . "\..\HeroDefines.JSON", defines)
        return defines
    }

    class HeroDefine
    {
        __new(heroID, heroName, seat)
        {
            this.HeroID := heroID
            this.HeroName := heroName
            this.MaxLvl := 1
            this.Seat := seat
            this.SpecDefines := new IC_NML_Functions.SpecDefineSets
            return this
        }
    }

    class SpecDefine
    {
        __new(upgradeID, requiredLvl, requiredUpgradeID, specName)
        {
            this.UpgradeID := upgradeID
            this.RequiredLvl := requiredLvl
            this.RequiredUpgradeID := requiredUpgradeID
            this.SpecName := specName
            return this
        }
    }

    class SpecDefineSets
    {
        ;each item is an array of spec upgrades associated with a given level and required upgrade.
        specList := {}
        specListSize := 0
        ;an array that mimics specList, but consists of strings for drop down list gui elements.
        ddlList := {}
        ;each item is an object of data to know which items from specList to use based on level and required upgrade data.
        setList := {}
        setListSize := 0

        AddSpec(upgID, reqLvl, reqUpgID, specName)
        {
            isNewSet := true
            for k, v in this.setList
            {
                if (reqLvl == v.reqLvl)
                {
                    isNewSet := false
                    ;this handles spec sets like Morg and Selise that change based on previous choices
                    if !v.listIndex.HasKey(reqUpgID)
                    {
                        index := this.createNewSpecListEntry()
                        v.AddNewReqUpgID(index, reqUpgID)
                    }
                    else
                        index := v.listIndex[reqUpgID]
                    ;following should not be possible, but leaving here just in case
                    ;if !IsObject(this.specList[index])
                    ;    this.createNewSpecListEntry(index)
                    this.pushSpec(index, upgID, reqLvl, reqUpgID, specName, k)
                    break
                }
            }
            if isNewSet
            {
                index := this.createNewSpecListEntry()
                this.setList.Push(new IC_NML_Functions.SetData(index, reqLvl, reqUpgID))
                this.setListSize := this.setList.Count()
                this.pushSpec(index, upgID, reqLvl, reqUpgID, specName, k)
            }
        }

        pushSpec(index, upgID, reqLvl, reqUpgID, specName, k)
        {
            this.specList[index].Push(new IC_NML_Functions.SpecDefine(upgID, reqLvl, reqUpgID, specName))
        }

        createNewSpecListEntry()
        {
            this.specListSize += 1
            this.specList[this.specListSize] := {}
            this.ddlList[this.specListSize] := ""
            return this.specListSize
        }

        SortSpecList()
        {
            for k, v in this.specList
            {
                ;insertion sort
                i := 1
                while (i <= v.Count())
                {
                    j := i
                    while (j > 1 AND v[j-1].UpgradeID > v[j].UpgradeID)
                    {
                        temp := v[j].Clone()
                        v[j] := v[j-1].Clone()
                        v[j-1] := temp.Clone()
                        --j
                    }
                    ++i
                }
            }
        }

        SpecDefineList[reqLvl, reqUpgID]
        {
            get
            {
                index := this.getIndex(reqLvl, reqUpgID)
                if (index == -1)
                    return ""
                else
                    return this.specList[index]
            }
        }

        DDL[reqLvl, reqUpgID]
        {
            get
            {
                index := this.getIndex(reqLvl, reqUpgID)
                if (index == -1)
                    return ""
                else
                {
                    string := ""
                    for k, v in this.specList[index]
                    {
                        string .= v.SpecName . "|"
                    }
                    return string
                }
            }
        }

        getIndex(reqLvl, reqUpgID)
        {
            for k, v in this.setList
            {
                if (reqLvl == v.reqLvl)
                {
                    if v.listIndex.HasKey(0)
                        return v.listIndex[0]
                    else
                        return v.listIndex[reqUpgID]
                }
            }
            return -1
        }
    }

    ;an object for all the spec upgrades associated with a particular level.
    class SetData
    {
        listIndex := {}
        listCount := 0

        __new(index, reqLvl, reqUpgID)
        {
            this.reqLvl := reqLvl
            this.AddNewReqUpgID(index, reqUpgID)
            return this
        }

        AddNewReqUpgID(index, reqUpgID)
        {
            this.listIndex[reqUpgID] := index
            this.listCount += 1
        }
    }

    LevelAndSpec(champID, targetLvl, maxLvlData, specSettings)
    {
        seat := g_SF.Memory.ReadChampSeatByID(champID)
        inputKey := "{F" . seat . "}"
        if !targetLvl
            targetLvl := maxLvlData[champID]
        while (targetLvl > g_SF.Memory.ReadChampLvlByID(champID) AND !(this.endScript))
        {
            g_SF.DirectedInput(,, inputKey)
            for k, v in specSettings[champID]
            {
                if (v.RequiredLvl == g_SF.Memory.ReadChampLvlByID(champID))
                    this.PickSpec(v.Choice, v.Choices, v.UpgradeID)
            }
        }
        return
    }

    IsSpec(champID, champLvl, specSettings)
    {
        for k, v in specSettings[champID]
        {
            if (v.RequiredLvl == champLvl)
                return true
        }
        return false
    }

    PickSpec(champID, champLvl, specSettings)
    {
        static lastUpgrade := 0
        static clickCount := 0
        for k, v in specSettings[champID]
        {
            if (v.RequiredLvl == champLvl)
            {
                choice := v.Choice
                choices := v.Choices
                upgradeID := v.UpgradeID
            }
        }
        ScreenCenterX := (g_SF.Memory.ReadScreenWidth(1) / 2)
        ScreenCenterY := (g_SF.Memory.ReadScreenHeight(1) / 2)
        yClick := ScreenCenterY + 245
        ButtonWidth := 70
        ButtonSpacing := 180
        TotalWidth := (ButtonWidth * Choices) + (ButtonSpacing * (Choices - 1))
        xFirstButton := ScreenCenterX - (TotalWidth / 2)
        xClick := xFirstButton + 35 + (250 * (Choice - 1))
        StartTime := A_TickCount
        ElapsedTime := 0
        loop, 1
        {
            WinActivate, ahk_exe IdleDragons.exe
            MouseClick, Left, xClick, yClick, 1
            Sleep, 10
        }
        if (lastUpgrade == upgradeID)
            ++clickCount
        else
        {
            lastUpgrade := upgradeID
            clickCount := 0
        }
        if (clickCount > 5)
        {
            msgbox, 4,, The script has failed specializing in %clicCount% consecutive attempts. Continue?
            IfMsgBox No
                this.endScript := true
        }
        return
    }

    ;favorite: 1 = save slot 1 (Q), 2 = save slot 2 (W), 3 = save slot 3 (E)
    LevelAndSpecFavoriteFormation(favorite, maxLvlData, specSettings)
    {
        this.endScript := false
        if (favorite == 1)
            inputKey := "q"
        else if (favorite == 2)
            inputKey := "w"
        else if (favorite == 3)
            inputKey := "e"
        loop 3
            g_SF.DirectedInput(,, inputKey)
        champArray := g_SF.Memory.GetFormationByFavorite(favorite)
        for k, v in champArray
        {
            if (v == -1)
                continue
            g_SF.DirectedInput(,, inputKey)
            this.LevelAndSpec(v, 0, maxLvlData, specSettings)
            if this.endScript
                return
        }
    }
}