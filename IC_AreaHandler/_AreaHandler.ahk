class _AreaHandler
{
    ; offsets for items that should probably be added to imports, until then placing them here for fast updating
    offsets := {"ActiveCampaignData.currentObjective.Repeatable":0xCC, "ActiveCampaignData.adventureDef":16
                , "ActiveCampaignData.adventureDef.areas":168, "ActiveCampaignData.adventureDef.areas.Monsters":0x20
                , "ActiveCampaignData.adventureDef.areas.BackgroundDefID":204, "ActiveCampaignData.adventureDef.areas.isFixed":252
                , "ActiveCampaignData.adventureDef.areas.backgroundDef":144, "ActiveCampaignData.adventureDef.areas.backgroundDef.ID":16
                , "ActiveCampaignData.adventureDef.areas.backgroundDef.IsFixed":105, "ActiveCampaignData.adventureDef.areas.Bosses":0x28
                , "ActiveCampaignData.adventureDef.areas.StaticMonsters":0x48
                , "Controller.area.activeMonsters.monsterDef":856, "Controller.area.activeMonsters.monsterDef.ID":16
                , "Controller.area.activeMonsters.monsterDef.availableAttacks":0x20
                , "Controller.area.activeMonsters.monsterDef.availableAttacks.AttackDef":0x10
                , "Controller.area.activeMonsters.monsterDef.availableAttacks.AttackDef.ID":0x10}

    __new()
    {
        this.BackGroundsToSet := {}
        g_SF.Memory.OpenProcessReader() ; standard starting step to enable memory reading
        g_SF.ToggleAutoProgress(0) ; disable autoprogress, errors can occur if levels progress before all data is gathered.

        this.classMemory := g_SF.Memory.GameManager.Main ; just an easier location to access classMemory instance

        ; set memory value at Repeatable to a number greater than 0
        ; this should enable boss skips
        ; TO DO, add Repeatable to scripthub game objects
        repeatable := new GameObjectStructure(g_SF.Memory.GameManager.game.gameInstances.ActiveCampaignData.currentObjective, "Int"
            , [this.offsets["ActiveCampaignData.currentObjective.Repeatable"]])
        this.classMemory.write(repeatable.baseAddress, 1, "Int", repeatable.GetGameObjectFromListValues(0).GetOffsets()*)

        ; set up our parent game object, this.Areas
        ; this is the last game object set up in script hub, but we need ActiveCampaignData.adventureDef.areas, which is a list of all 50 zones
        ; TO DO, add areas to scripthub game objects
        activeCampaignData := g_SF.Memory.GameManager.game.gameInstances.ActiveCampaignData.GetGameObjectFromListValues(0) ; take the list out of GameInstances
        ; 0x10 corresponds to the offset of the collected items in the list
        ; list collected items will have offsets starting at 0x20 and occur every 0x8
        ; this list has 50 items, one for each zone
        this.Areas := new GameObjectStructure(activeCampaignData, g_SF.Memory.ptrType
            , [this.offsets["ActiveCampaignData.adventureDef"], this.offsets["ActiveCampaignData.adventureDef.areas"], 0x10])

        ; this method determines the background and monster ids by analyzing data in the current zone
        ; looks through the current zone for monsters with meleee attacks.
        ; if it does not find a monster with a melee attack it will use the last id analyzed.
        ; the monster choosen from this method will be set for all monsters on the adventure.
        this.SetDefIDs()
        if (this.MonsterDefID < 0 or this.MonsterDefID > 10000)
        {
            this.ThrowException("Bad Monster Def ID. ID: " . this.MonsterDefID)
        } 

        ; this method sets various values in each area def
        ; background defs within area def do not populate until that area has been seen
        ; so this area also tracks which background defs have not been populated
        this.SetAreaDefValues()

        return this
    }

    SetAreaDefValues()
    {
        ; we are going to do a lot of reading and the list shouldn't move in memory while we sit on one zone
        areasAddress := this.classMemory.getAddressFromOffsets(this.Areas.baseAddress, this.Areas.GetOffsets()*)

        ; go through each area and set various values
        ; track which areas that can't be set now
        outer:
        loop, 50
        {
            skipAreaDef := false ; a flag to skip changing area defs if there is a static monster, since it could be a blockade
            areaAddress := this.classMemory.getAddressFromOffsets(areasAddress, 0x20 + (0x8 * (A_Index - 1)))
            
            ; next set of code is setting monsters to all be the same
            ; start by setting static monsters because messing with blocade area defs can mess things up
            ; StaticMonsters is a dictionary of static monsters <string, dictionary>, actually defined as <string, object>
            ; a static monster is a dictionary of properties <string, int32 struct>, actually defined as <string, object>
            ; 0x40 corresponds to dictionary count value
            countStaticMonsters := this.classMemory.read(areaAddress, "Int", [this.offsets["ActiveCampaignData.adventureDef.areas.StaticMonsters"], 0x40]*)
            if (countStaticMonsters AND countStaticMonsters < 100 AND countStaticMonsters > 0) ; reality check the read
            {
                skipAreaDef := true
                i := 0
                loop, %countStaticMonsters%
                {
                    ; 0x18 corresponds to offset of the collected key value pairs in the dictionary
                    ; the first key is at 0x28, with the next 0x18 away
                    ; the first value is at 0x30, with the next 0x18 away
                    ; 0x40 corresponds to the dictionary count
                    countProperties := this.classMemory.read(areaAddress, "Int"
                        , [this.offsets["ActiveCampaignData.adventureDef.areas.StaticMonsters"], 0x18, 0x30 + (0x18 * i), 0x40]*)
                    if (countProperties AND countProperties < 100 AND countProperties > 0) ; reality check the read
                    {
                        j := 0
                        loop, %countProperties%
                        {
                            string := this.classMemory.readString(areaAddress, 0, "UTF-16"
                                , [this.offsets["ActiveCampaignData.adventureDef.areas.StaticMonsters"], 0x18, 0x30 + (0x18 * i), 0x18, 0x28 + (0x18 * j), 0x14]*)
                            if (string == "monster_id")
                            {
                                this.classMemory.write(areaAddress, this.MonsterDefID, "Int"
                                    , [this.offsets["ActiveCampaignData.adventureDef.areas.StaticMonsters"], 0x18, 0x30 + (0x18 * i), 0x18, 0x30 + (0x18 * j), 0x10]*)
                            }
                            j++
                        }
                    }
                    else if countProperties
                    {
                        this.ThrowException("Static Monsters Properties collection count read returned unexpected value. Value Read: " . countProperties)
                    }
                    i++
                }
            }
            else if countStaticMonsters
            {
                this.ThrowException("Static Monsters collection count read returned unexpected value. Value Read: " . countStaticMonsters)
            }
            ; next is bosses, which is actually a list of list of id
            ; 0x18 corresponds to the list size value
            _size := this.classMemory.read(areaAddress, "Int", [this.offsets["ActiveCampaignData.adventureDef.areas.Bosses"], 0x18]*)
            if (_size AND _size < 100 AND _size > 0) ; reality check the read
            {
                i := 0
                ; 0x10 corresponds to the collected list items
                bossListAddress := this.classMemory.getAddressFromOffsets(areaAddress, [this.offsets["ActiveCampaignData.adventureDef.areas.Bosses"], 0x10]*)
                loop, %_size%
                {
                    ; 0x20 is the first list item, second is 0x8 off
                    ; 0x18 corresponds to the list size value
                    _size2 := this.classMemory.read(bossListAddress, "Int", [0x20 + (0x8 * i), 0x18]*)
                    if (_size2 AND _size2 < 100) ; reality check the read
                    {
                        j := 0
                        loop, %_size2%
                        {
                            ; list items start at 0x20, for reference type lists they are spaced 0x8 apart
                            ; 0x10 corresponds to the second list collection set
                            ; the second list of ids are int32, so they are 4 bytes apart
                            this.classMemory.write(bossListAddress, this.MonsterDefID, "Int", [0x20 + (0x8 * i), 0x10, 0x20 + (0x4 * j)]*)
                            j++
                        }
                    }
                    else if _size_2
                    {
                        this.ThrowException("Bosses Waves collection count read returned unexpected value. Value Read: " . _size2)
                    }
                    i++
                }
            }
            else if _size
            {
                this.ThrowException("Bosses collection count read returned unexpected value. Value Read: " . _size)
            }
            ; finally, set standard monsters
            ; 0x18 corresponds to the list size value
            _size := this.classMemory.read(areaAddress, "Int", [this.offsets["ActiveCampaignData.adventureDef.areas.Monsters"], 0x18]*)
            if (_size AND _size < 100) ; reality check the read
            {
                i := 0
                loop, %_size%
                {
                    ; 0x10 corresponds to the collected list items
                    ; first item is offset 0x20, then second is 0x4 since it is a collection of int32
                    this.classMemory.write(areaAddress, this.MonsterDefID, "Int"
                        , [this.offsets["ActiveCampaignData.adventureDef.areas.Monsters"], 0x10, 0x20 + (0x4 * i)]*)
                    i++
                }
            }
            else if _size
            {
                this.ThrowException("Monsters collection count read returned unexpected value. Value Read: " . _size)
            }

            ; next set of code is to force quick transitions
            if skipAreaDef
            {
                continue outer
            }
            ; next two lines set a nullable boolean to true, this probably could be done with a single two byte write
            this.classMemory.write(areaAddress, 1, "Char", this.offsets["ActiveCampaignData.adventureDef.areas.isFixed"])
            this.classMemory.write(areaAddress, 1, "Char", this.offsets["ActiveCampaignData.adventureDef.areas.isFixed"] + 1)
            ; check to see if the background def is set and set or mark as to be set as appropriate
            backgroundDefID := this.classMemory.read(areaAddress, "Int", this.offsets["ActiveCampaignData.adventureDef.areas.BackgroundDefID"])
            if (backgroundDefID != this.BackGroundDefID OR this.BackGroundsToSet[A_Index])
            {
                this.classMemory.write(areaAddress, this.BackGroundDefID, "Int", this.offsets["ActiveCampaignData.adventureDef.areas.BackgroundDefID"])
                backGroundDefAddress := this.classMemory.getAddressFromOffsets(areaAddress, this.offsets["ActiveCampaignData.adventureDef.areas.backgroundDef"])
                ; check to see if background def has been populated
                if (backGroundDefAddress > 0)
                {
                    id := this.classMemory.read(backGroundDefAddress, "Int", this.offsets["ActiveCampaignData.adventureDef.areas.backgroundDef.ID"])
                    if (id != this.BackGroundDefID)
                    {
                        this.classMemory.write(backGroundDefAddress, this.BackGroundDefID, "Int", this.offsets["ActiveCampaignData.adventureDef.areas.BackgroundDef.ID"])
                    }
                    ; I don't think we need to set this as true, the getter will pull from Area defs.
                    ; TODO check DLL for the isfixed getter to see if these are needed.
                    isFixed := this.classMemory.read(backGroundDefAddress, "Char", this.offsets["ActiveCampaignData.adventureDef.areas.backgroundDef.IsFixed"])
                    if !isFixed
                    {
                        this.classMemory.write(backGroundDefAddress, 1, "Char", this.offsets["ActiveCampaignData.adventureDef.areas.backgroundDef.IsFixed"])
                    }
                }
                ; TODO create method to use this data.
                else
                {
                    this.BackGroundsToSet[A_Index] := A_Index
                }
            }
        }
        return
    }

    SetDefIDs()
    {
        ; set currentZone so we know which item in the areas list to look at
        currentZone := mod(g_SF.Memory.ReadCurrentZone(), 50)
        currentZone := currentZone == 0 ? 50 : currentZone
        if (!(currentZone > 0) AND !(currentZone < 51))
        {
            this.ThrowException("Bad memory read of current zone. Current Zone Read: " . currentZone)
        }

        if (!mod(currentZone, 5))
        {
            this.ThrowException("Cannot initilaize script when on boss zone.")
        }

        ; we will need to set these background id and isfixed properties uniquely
        this.BackGroundsToSet[currentZone] := currentZone
        this.BackGroundsToSet[currentZone + 1] := currentZone + 1

        ; we are going to do a lot of reading and the list shouldn't move in memory while we sit on one zone
        areasAddress := this.classMemory.getAddressFromOffsets(this.Areas.baseAddress, this.Areas.GetOffsets()*)
        areaAddress := this.classMemory.getAddressFromOffsets(areasAddress, 0x20 + (0x8 * (currentZone - 1)))

        ; set the background def id value to be used for all backgrounds that have already been set
        ; background defs are set as they are moved through, so by using the current area, we can avoid an additional write
        this.BackGroundDefID := this.classMemory.read(areaAddress, "Int", this.offsets["ActiveCampaignData.adventureDef.areas.BackgroundDefID"])
        if (!(this.BackGroundDefID) OR this.BackGroundDefID < 1 OR this.BackGroundDefID > 10000)
        {
            this.BackGroundDefID := 9 ; zone 1 of cursed farmer
        }

        ; set the monster def id value to be used for all monsters in the adventure
        ; create a collection of id's of all monsters that can spawn on the current area
        ; using adventureDef.areas.Monsters, a list of monsters that can spawn on this area
        monsters := {} ; an object to store the id's of monster that can spawn on this area
        _size := this.classMemory.read(areaAddress, "Int", [this.offsets["ActiveCampaignData.adventureDef.areas.Monsters"], 0x18]*)
        if (!_size OR _size > 100 OR _size < 0)
        {
            this.ThrowException("Monster list size read returned unexpecte value. Value Read: " . _size)
        }
        i := 0
        monstersAddress := this.classMemory.getAddressFromOffsets(areaAddress, [this.offsets["ActiveCampaignData.adventureDef.areas.Monsters"], 0x10]*)
        loop, %_size%
        {
            id := this.classMemory.read(monstersAddress, "Int", 0x20 + (0x4 * i))
            if id
            {
                monsters[id] := id
                this.MonsterDefID := id ; set to last monster in list in case none have a basic melee as only attack
            }
            i++
        }

        ; no valid id was read
        if !(this.MonsterDefID)
        {
            this.ThrowException("Monster Def ID failed to set propertly.")
        }

        ; now we will look through the active monsters spawning for one with a melee attack
        ; as we check an id, we will remove it from the monsters list we created above
        ; same reasoning as above to reduce reads
        activeMonsters := g_SF.Memory.GameManager.game.gameInstances.Controller.area.activeMonsters.GetGameObjectFromListValues(0) ; take the list out of GameInstances
        activeMonstersAddress := this.classMemory.getAddressFromOffsets(activeMonsters.baseAddress, activeMonsters.GetOffsets()*)
        ;activeMonstersList := new GameObjectStructure(activeMonsters, g_SF.Memory.ptrType, [0x10])
        ;activeMonstersListAddress := this.classMemory.getAddressFromOffsets(activeMonstersList.baseAddress, activeMonstersList.GetOffsets()*)
        failedReadCount := 0 ; in case something happens so we don't get in an endless loop
        while monsters.Count()
        {
            ; we are only ever going to look at the first item in the list since click damage will kill so fast
            ; we need to pull the monsterDef address since the monster may be removed from the active list before we finish
            monsterDefAddress := this.classMemory.getAddressFromOffsets(activeMonstersAddress, [0x20, this.offsets["Controller.area.activeMonsters.monsterDef"]]*)
            activeId := this.classMemory.read(monsterDefAddress, "Int", this.offsets["Controller.area.activeMonsters.monsterDef.ID"])
            if !activeId
            {
                failedReadCount++
                if failedReadCount > 9
                {
                    return
                }
            }
            else if monsters.HasKey(activeId)
            {
                monsters.Delete(activeId)
                availableAttacksAddress := this.classMemory.getAddressFromOffsets(monsterDefAddress, this.offsets["Controller.area.activeMonsters.monsterDef.availableAttacks"])
                _size := this.classMemory.read(availableAttacksAddress, "Int", 0x18)
                ; available attacks is a list, but we only want melee, so only check if the list is 1 item
                if (_size == 1)
                {
                    attackId := this.classMemory.read(availableAttacksAddress, "Int"
                        , [0x10, 0x20, this.offsets["Controller.area.activeMonsters.monsterDef.availableAttacks.AttackDef"]
                            , this.offsets["Controller.area.activeMonsters.monsterDef.availableAttacks.AttackDef.ID"]]*)
                    if (attackId == 21) ; id for basic melee attack
                    {
                        this.MonsterDefID := activeId
                        return
                    }
                }
            }
        }
    }

    ThrowException(reason)
    {
        MsgBox, % reason . "`n`nExiting App."
        ExitApp
    }
}