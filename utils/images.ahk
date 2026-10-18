SearchImage(imageName, options := "", xMin := 0, yMin := 0, xMax := 1920, yMax := 1080) {
    if ImageSearch(&xCoord, &yCoord, xMin, yMin, xMax, yMax, options " *42 " A_ScriptDir "\img\" imageName ".png") {
        global x := xCoord
        global y := yCoord
        return true
    }
}

ClickImage(imageName, delay := 1000, options := "", xMin := 0, yMin := 0, xMax := 1920, yMax := 1080) {
    if SearchImage(imageName, options, xMin, yMin, xMax, yMax) {
        Click(x,y)
        Sleep(delay)
        return true
    }
}

SearchRound(round) {
    if round != 7 and SearchRound(7) {
        return false
    }
    if menuside = "R" {
        roundDetected := ImageSearch(&xCoord, &yCoord, 1040, 21, 1115, 80, "*8 *TransBlack " A_ScriptDir "\img\rounds\" round ".png")
    } else {
        roundDetected := ImageSearch(&xCoord, &yCoord, 1413, 21, 1520, 80, "*8 *TransBlack " A_ScriptDir "\img\rounds\" round ".png")
    }
    return roundDetected
}

; --- Map selection page indicator ---------------------------------------------
; The row of dots below the map list has one dot per page, spaced 37px apart and
; centered horizontally on the screen. The dot of the current page is blue. Since
; the row is re-centered whenever the game adds a page, the position of the first
; dot depends on the total page count, so nothing here hardcodes that position.

MAP_PAGE_DOT_SPACING := 37
MAP_PAGE_DOT_Y := 758
MAP_PAGE_ROW_CENTER := 960

IsPageDotActive(color) {
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF
    return r >= 44 and r <= 84 and g >= 139 and g <= 179 and b >= 235
}

PageDotMatches(x, y, reference) {
    if x < 0 or x > 1919 {
        return false
    }
    color := PixelGetColor(x, y)
    diffR := Abs(((color >> 16) & 0xFF) - ((reference >> 16) & 0xFF))
    diffG := Abs(((color >> 8) & 0xFF) - ((reference >> 8) & 0xFF))
    diffB := Abs((color & 0xFF) - (reference & 0xFF))
    return diffR <= 24 and diffG <= 24 and diffB <= 24
}

; Returns the center [x, y] of the highlighted page dot, or false if there is none.
FindActivePageDot() {
    reach := MAP_PAGE_DOT_SPACING * 10
    if !PixelSearch(&px, &py, MAP_PAGE_ROW_CENTER - reach, MAP_PAGE_DOT_Y - 8, MAP_PAGE_ROW_CENTER + reach, MAP_PAGE_DOT_Y + 8, 0x409FF5, 20) {
        return false
    }
    ; The hit is on the top edge of the dot. Measure its extent to find the center.
    cy := py
    while cy < py + 40 and IsPageDotActive(PixelGetColor(px, cy + 1)) {
        cy += 1
    }
    cy := (py + cy) // 2
    left := px
    right := px
    while left > px - 40 and IsPageDotActive(PixelGetColor(left - 1, cy)) {
        left -= 1
    }
    while right < px + 40 and IsPageDotActive(PixelGetColor(right + 1, cy)) {
        right += 1
    }
    cx := (left + right) // 2
    yTop := cy
    yBottom := cy
    while yTop > cy - 40 and IsPageDotActive(PixelGetColor(cx, yTop - 1)) {
        yTop -= 1
    }
    while yBottom < cy + 40 and IsPageDotActive(PixelGetColor(cx, yBottom + 1)) {
        yBottom += 1
    }
    cy := (yTop + yBottom) // 2
    if right - left < 4 or right - left > 40 {
        return false    ; not a dot, probably some other blue UI element
    }
    return [cx, cy]
}

; Returns [page, pageCount] as shown by the game's page indicator, or false.
GetGamePage() {
    dot := FindActivePageDot()
    if !dot {
        return false
    }
    cx := dot[1]
    cy := dot[2]
    spacing := MAP_PAGE_DOT_SPACING

    ; The row is centered, so the neighbour on the side of the center is always a
    ; dot. Use it to learn what an inactive dot looks like, then count them.
    inactive := PixelGetColor(cx < MAP_PAGE_ROW_CENTER ? cx + spacing : cx - spacing, cy)
    if !IsPageDotActive(inactive) {
        before := 0
        while before < 20 and PageDotMatches(cx - spacing * (before + 1), cy, inactive) {
            before += 1
        }
        after := 0
        while after < 20 and PageDotMatches(cx + spacing * (after + 1), cy, inactive) {
            after += 1
        }
        firstX := cx - spacing * before
        lastX := cx + spacing * after
        if Abs((firstX + lastX) / 2 - MAP_PAGE_ROW_CENTER) <= 10 {
            return [before + 1, before + after + 1]
        }
        LogMsg("Page indicator is not centered (first dot x=" firstX ", last dot x=" lastX "), using the expected page count", true)
    }

    ; Fallback: assume the expected page count and work out the page from the position
    position := (cx - MAP_PAGE_ROW_CENTER) / spacing + (GAME_PAGE_COUNT + 1) / 2
    if Abs(position - Round(position)) <= 0.25 and Round(position) >= 1 and Round(position) <= GAME_PAGE_COUNT {
        return [Round(position), GAME_PAGE_COUNT]
    }
    LogMsg("Active page dot found at x=" cx ", y=" cy " but it does not fit the page layout")
    return false
}

; Returns the page of the current map selection screen as an index into MAPS.
; Returns 0 for a page the game has but MAPS does not (maps without a strategy).
GetCurrentMapPage() {
    global pageCountWarned
    Loop 3 {
        result := GetGamePage()
        if result {
            if result[2] != GAME_PAGE_COUNT and !pageCountWarned {
                LogMsg("The map selection has " result[2] " pages but " GAME_PAGE_COUNT " were expected. Update MAPS_CATEGORIES in data\maps.ahk")
                pageCountWarned := true
            }
            mapPage := GamePageToMapPage(result[1])
            LogMsg("Map selection page " result[1] "/" result[2] " (MAPS page " mapPage ")", true)
            return mapPage
        }
        Sleep(300)
    }
    LogMsg("Could not recognize the current map page")
    Sleep(5000)
}

SearchUpgrade(path) {
    if SearchImage("upgrades\" path "R", "", 1450, (325+path*150), 1520, (349+path*150)) {
        return true
    }
    if SearchImage("upgrades\" path "L", "", 230, (325+path*150), 300, (349+path*150)) {
        return true
    }
}

CheckDoubleCash(speed := true, power := "unchanged") {
    if SearchImage("states\double_cash", "*TransBlack", 280, 40, 350, 90) {
        LogMsg("Double Cash detected")
        global double_cash := true
        global speed_adjust := speed
        if power != "unchanged" {
            global allowPowers := power
        }
    }
}
