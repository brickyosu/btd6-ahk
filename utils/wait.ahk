; --- Stall watchdog --------------------------------------------------------------
; The loops that wait for the game only end when they recognize what they wait
; for, or a defeat/victory screen. If the game ends on a screen that isn't
; recognized they would loop forever (resending keys). Progress is a new round, a
; placed tower or a finished upgrade. Without progress for STALL_TIMEOUT the game
; is considered stuck.
STALL_TIMEOUT := 5 * 60 * 1000

MarkProgress() {
    global lastProgress := A_TickCount
}

; Returns true if the game has been stuck for too long and the caller should stop
; waiting. Tries to get back to the menu, the main loop takes over from there.
CheckStalled(where) {
    if A_TickCount - lastProgress < STALL_TIMEOUT {
        return false
    }
    LogMsg("No progress for " STALL_TIMEOUT // 60000 " minutes while " where " (round " currentRound "), giving up on this game")
    if SearchImage("states\defeat") {
        LogMsg("The defeat screen is visible at x=" x ", y=" y " but CheckDefeat() did not find it there")
    }
    global defeated := true
    global lastProgress := A_TickCount
    ClickImage("buttons\home_defeat_1", 2000)
    ClickImage("buttons\home_defeat_2", 2000)
    return true
}

; UpdateMouseRest() changes the mouse cursor location to the
; midpoint of one or more towers
UpdateMouseRest(towers*) {
    xSum := 0
    ySum := 0
    count := towers.Length
    for tower in towers {
        xSum += TS[tower][2][1]
        ySum += TS[tower][2][2]
    }
    coords := [(xSum // count), (ySum // count)]
    LogMsg("xSum: " xSum " ySum: " ySum " tower count: " count " mouseRest coord: [" coords[1] ", " coords[2] "]", true)
    global mouseRest := coords
}

CheckLevelUp() {
    if SearchImage("states\level_up", , 982, 537, 1084, 603) {
        global toweropen
        okMsg := false

        LogMsg("Level up detected")
        Click(6, 4)
        Sleep(2000)

        Loop {
            Click(6, 4)
            Sleep(2000)
            
            if !SearchImage("states\level_up2", "*10", 1675, 10, 1865, 75){
                break
            }

            if SearchImage("states\victory") or CheckInstaMonkey() {
                global defeated := true
                LogMsg(A_ThisFunc "() | Found victory on R" currentRound )
                break
            }

            ; clear the first time getting MK interrupt message
            if ClickImage("buttons\ok", , "*Trans0xFF00FF", 760, 660, 1160, 860) {
                okMsg := true
            }
        }

        ; reselects the tower if the MK interrupt message occurs
        if okMsg && toweropen != "" {
            Open(toweropen)
            LogMsg(A_ThisFunc "() | Cleared in game message", true)
        }
        MouseMove(mouseRest[1], mouseRest[2])
    }
}

CheckInstaMonkey() {
    if ClickImage("states\insta_monkey") {
        LogMsg("Insta monkey detected")
	    return true
    }
}

/* 
    Looks for the in game interrupt that displays an ok button to acknowledge.
    About the interrupt:
        - occurs at the start of some game modes or the first time an account 
        experiences certain types of bloons (regrow, ZOMG, BAD, etc)
        - if a placed tower is Open() aka selected at the time of interrupt,
        the tower will automatically close 
*/ 
CheckInGameMsg() {
    if ClickImage("buttons\ok", , "*Trans0xFF00FF", 760, 660, 1160, 860) {
        global toweropen

        ; reselects the tower if it was already selected at the time of interrupt
        if toweropen != "" {
            Open(toweropen)
        }
        LogMsg("Cleared in game message", true)

        MouseMove(mouseRest[1], mouseRest[2])
    }
    Sleep(1000)
}

CheckInterrupt() {
    CheckLevelUp()
    CheckInstaMonkey()
    CheckInGameMsg()
}

CheckPauseMenu() {
    MouseMove(1, 1)
    Sleep(500)
    if SearchImage("buttons\home") {
        LogMsg("Pause menu detected on round " currentRound)
        Send("{Esc}")
        Sleep(500)
    }
}

WaitForRound(round, delay := 0) {
    if defeated {
        return
    }
    CheckPauseMenu()
    MouseMove(mouseRest[1], mouseRest[2])
    if speed_adjust {
        return
    }
    Loop {
        UpdateRound()
        if currentRound >= round {
            Sleep(delay)
            break
        }
        if CheckStalled("waiting for round " round) {
            break
        }
        if defeated or CheckDefeat() {
            global defeated := true
            LogMsg('Found defeat on R' currentRound ' when waiting for R' round '')
            ScreenRecordDefeat()
            break
        }
        if SearchImage("states\victory") or CheckInstaMonkey() {
            global defeated := true
            LogMsg("Found victory on R" currentRound)
            break
        }
        CheckLevelUp()
        CheckInGameMsg()
    }
}

WaitForVictoryOrDefeat() {
    CheckPauseMenu()
    MouseMove(mouseRest[1], mouseRest[2])
    Loop {
        if SearchImage("states\victory") {
            Sleep(500)
            ClickImage("buttons\next")
            ClickImage("buttons\home_victory", 2000)
            global victories := victories + 1
            LogMsg("Victory")
            break
        }
        if CheckDefeat() {
            Sleep(500)
            ClickImage("buttons\home_defeat_1", 2000)
            ClickImage("buttons\home_defeat_2", 2000)
            global defeats := defeats + 1
            LogMsg("Defeat on round " currentRound)
            break
        }
        CheckInstaMonkey()
        CheckLevelUp()
        CheckInGameMsg()
        UpdateRound()
        if CheckStalled("waiting for the game to end") {
            break
        }
        Sleep(2000)
    }
}

WaitForUpgrade(path) {
    if defeated {
        return
    }
    if menuside = "L" {
        MouseMove(max(mouseRest[1], 425), mouseRest[2])
    } else {
        MouseMove(min(mouseRest[1], 1246), mouseRest[2])
    }
    Loop {
        if SearchUpgrade(path) {
            break
        }
        if CheckStalled("waiting for upgrade " path) {
            break
        }
        if CheckDefeat() {
            global defeated := true
            LogMsg("Found defeat instead of upgrade " path " on " toweropen)
            ScreenRecordDefeat()
            break
        }
        if SearchImage("states\victory") or CheckInstaMonkey() {
            global defeated := true
            LogMsg("Found victory instead of upgrade " path " on " toweropen)
            break
        }
        CheckLevelUp()
        CheckInGameMsg()
        UpdateRound()
    }
}

WaitForAbility(tower, ability, position, delay := 0) {
    MouseMove(mouseRest[1], mouseRest[2])
    Loop {
        if SearchImage("abilities\" tower "\" ability, "", (50+100*position), 1000, (150+100*position), 1079) {
            Sleep(delay)
            break
        }
        if defeated {
            break
        }
        if CheckStalled("waiting for ability " ability) {
            break
        }
        if CheckDefeat() {
            global defeated := true
            LogMsg("Found defeat instead of ability " ability " from " tower)
            ScreenRecordDefeat()
            break
        }
        if SearchImage("states\victory") or CheckInstaMonkey() {
            global defeated := true
            LogMsg("Found victory instead of ability " ability " from " tower)
            break
        }
        CheckLevelUp()
        CheckInGameMsg()
        UpdateRound()
    }
}

UpdateRound() {
    if SearchRound(Mod(currentRound, 10)) {
        return
    }
    
    loop 3 {
        if SearchRound(Mod(currentRound + A_Index, 10)) {
            updatedRound := currentRound + A_Index
            if A_Index > 1 {
                LogMsg(A_ThisFunc "() | Detected | currentRound: " currentRound 
                " | updatedRound: " updatedRound " | loopcnt: " A_Index)
            }
            global currentRound := updatedRound
            MarkProgress()
            break
        }
    }
}

Wait(delay) {
    MouseMove(mouseRest[1], mouseRest[2])
    if defeated{
        return
    }
    Sleep(delay)
    if CheckDefeat() or SearchImage("states\victory") or CheckInstaMonkey() {
        global defeated := true
    }
    CheckLevelUp()
    CheckInGameMsg()
}

StartFreePlay() {
    if defeated or !enableFreeplayInsta { 
        return
    }

    CheckPauseMenu()
    MouseMove(mouseRest[1], mouseRest[2])
    Loop {
        if SearchImage("states\victory") {
            Sleep(500)
            ClickImage("buttons\next")
            ClickImage("buttons\victory_freeplay", 2000)
            CheckInGameMsg()
            Sleep(500)
            Send(KEYS["play"])                                              ; Resume Game
            global victories := victories + 1
            global defeated := false                                        ; Ensure it is false just in case it was changed to true previously
            global inFreeplay := true
            LogMsg("Victory")
            LogMsg(A_ThisFunc "() | Victory - Starting Freeplay mode")
            return true
        }
        if CheckDefeat() {
            Sleep(500)
            global defeated := true
            ScreenRecordDefeat()
            LogMsg(A_ThisFunc "() | Defeat - Found during normal rounds. No longer able to start freeplay")
            return false
        }
        CheckInGameMsg()
        UpdateRound()
        Sleep(2000)
    }
}

WaitForFreeplayInsta() {
    CheckPauseMenu()
    MouseMove(mouseRest[1], mouseRest[2])
    Loop {
        if SearchImage("states\victory") {
            Sleep(500)
            ClickImage("buttons\next")
            ClickImage("buttons\home_victory", 2000)
            LogMsg(A_ThisFunc "() | Victory - This should not occur within this func.")
            break
        }
        if CheckDefeat() {
            Sleep(500)
            ClickImage("buttons\next") 
            ClickImage("buttons\home_defeat_1", 2000)
            ClickImage("buttons\home_defeat_2", 2000)
            LogMsg(A_ThisFunc "() | Defeat -  Found during freeplay on R" currentRound)
            return false
        }
        if CheckInstaMonkey() {
            LogMsg(A_ThisFunc "() | Leaving freeplay after insta found")
            Send("{Esc}")
            Sleep(1500)
            ClickImage("buttons\home", 4000)
            return true
        }
        CheckLevelUp()
        CheckInGameMsg()
        UpdateRound()
        Sleep(2000)
    }
}