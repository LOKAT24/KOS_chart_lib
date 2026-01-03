@LAZYGLOBAL OFF.

GLOBAL FUNCTION Chart {
    PARAMETER width, height, originX, originY, minX, maxX, minY, maxY, title IS "", plotMode IS "LINE".

    LOCAL FUNCTION formatLabel {
        PARAMETER val.
        LOCAL absVal IS ABS(val).
        
        IF absVal >= 1000000 {
            RETURN ROUND(val / 1000000, 1) + "M".
        }
        IF absVal >= 1000 {
            RETURN ROUND(val / 1000, 1) + "k".
        }
        IF absVal < 10 {
            LOCAL s IS ROUND(val, 1) + "".
            IF NOT s:CONTAINS(".") { SET s TO s + ".0". }
            RETURN s.
        }
        RETURN ROUND(val, 0) + "".
    }

    // Obliczamy maksymalna dlugosc etykiety osi Y (dla marginesu)
    // Zakladamy ze najdluzsza etykieta to albo minY albo maxY
    LOCAL maxLabelLen IS formatLabel(maxY):LENGTH.
    LOCAL minLabelLen IS formatLabel(minY):LENGTH.
    
    LOCAL marginLeft IS MAX(maxLabelLen, minLabelLen) + 1.

    LOCAL marginTop IS 0.
    IF title:LENGTH > 0 { SET marginTop TO 1. }
    
    LOCAL marginBottom IS 1.

    // Przesuwamy canvas, zeby zrobic miejsce na opisy
    LOCAL canvasX IS originX + marginLeft.
    LOCAL canvasY IS originY + marginTop.
    
    // Obliczamy wymiary canvasu (pomniejszone o marginesy)
    // width/height to wymiary calego widgetu w pikselach
    // 1 char = 2 px szerokosci, 4 px wysokosci
    LOCAL canvasWidth IS width - (marginLeft * 2).
    LOCAL canvasHeight IS height - ((marginTop + marginBottom) * 4).
    
    SET canvasWidth TO MAX(1, canvasWidth).
    SET canvasHeight TO MAX(1, canvasHeight).

    // Rysujemy tytul (wysrodkowany wzgledem calego obszaru wykresu)
    IF title:LENGTH > 0 {
        // Szerokosc calego komponentu w znakach
        LOCAL totalWidthChars IS CEILING(width / 2).
        LOCAL titleX IS originX + FLOOR((totalWidthChars - title:LENGTH) / 2).
        PRINT title AT(MAX(originX, titleX), originY).
    }
    
    SET CONFIG:IPU TO 10000. // Możesz ustawić nawet więcej, np. 4000
    LOCAL c IS Canvas(canvasWidth, canvasHeight, canvasX, canvasY).
    LOCAL ctx IS LEXICON().
    SET ctx["c"] TO c.
    SET ctx["minX"] TO minX.
    SET ctx["maxX"] TO maxX.
    SET ctx["minY"] TO minY.
    SET ctx["maxY"] TO maxY.
    SET ctx["w"] TO c["width"].
    SET ctx["h"] TO c["height"].
    SET ctx["ox"] TO c["originX"].
    SET ctx["oy"] TO c["originY"].
    SET ctx["originX"] TO originX.
    SET ctx["originY"] TO originY.
    SET ctx["plotMode"] TO plotMode.
    
    // Sentinel values for "no previous point"
    SET ctx["lastX"] TO -999999. 
    SET ctx["lastY"] TO -999999.
    SET ctx["firstPoint"] TO TRUE.

    LOCAL api IS LEXICON().

    // Rysuje osie i etykiety
    // stepX, stepY: co ile jednostek rysowac ticki
    // scaleX, scaleY: przez ile podzielic wartosc etykiety (np. 1000 dla km)
    api:ADD("drawAxes", {
        PARAMETER stepX, stepY, scaleX IS 1, scaleY IS 1.
        
        // Zapisz parametry do odswiezania
        SET ctx["stepX"] TO stepX.
        SET ctx["stepY"] TO stepY.
        SET ctx["scaleX"] TO scaleX.
        SET ctx["scaleY"] TO scaleY.
        
        LOCAL c IS ctx["c"].
        LOCAL w IS ctx["w"].
        LOCAL h IS ctx["h"].
        LOCAL ox IS ctx["ox"].
        LOCAL oy IS ctx["oy"].
        LOCAL line IS c["line"].

        // Czyszczenie obszaru etykiet (Y-axis)
        LOCAL clearWidthY IS ox - ctx["originX"].
        LOCAL clearHeightY IS CEILING(h / 4).
        IF clearWidthY > 0 {
            LOCAL emptyStr IS "".
            FROM {LOCAL i IS 0.} UNTIL i >= clearWidthY STEP {SET i TO i + 1.} DO { SET emptyStr TO emptyStr + " ". }
            FROM {LOCAL rowIdx IS 0.} UNTIL rowIdx < clearHeightY STEP {SET rowIdx TO rowIdx + 1.} DO {
                PRINT emptyStr AT(ctx["originX"], oy + rowIdx).
            }
        }

        // Czyszczenie obszaru etykiet (X-axis)
        LOCAL clearWidthX IS CEILING(w / 2).
        LOCAL clearHeightX IS 1. // Zakladamy 1 wiersz na etykiety X
        LOCAL emptyStrX IS "".
        FROM {LOCAL i IS 0.} UNTIL i >= clearWidthX STEP {SET i TO i + 1.} DO { SET emptyStrX TO emptyStrX + " ". }
        FROM {LOCAL rowIdx IS 0.} UNTIL rowIdx < clearHeightX STEP {SET rowIdx TO rowIdx + 1.} DO {
             PRINT emptyStrX AT(ox, oy + CEILING(h / 4) + rowIdx).
        }

        // Linie osi
        line:CALL(0, 0, 0, h - 1). // Os Y
        line:CALL(0, h - 1, w - 1, h - 1). // Os X

        // Ticki i etykiety osi Y
        FROM {LOCAL val IS ctx["minY"].} UNTIL val > ctx["maxY"] STEP {SET val TO val + stepY.} DO {
            LOCAL pct IS (val - ctx["minY"]) / (ctx["maxY"] - ctx["minY"]).
            LOCAL yPix IS (h - 1) - (pct * (h - 1)).
            SET yPix TO MAX(0, MIN(h - 1, yPix)).
            
            line:CALL(0, yPix, 4, yPix). // Tick dlugosci 4px
            
            LOCAL label IS formatLabel(val / scaleY).
            
            LOCAL labelLen IS label:LENGTH.
            LOCAL col IS ox - labelLen - 1.
            LOCAL row IS oy + FLOOR(yPix / 4).
            IF col >= 0 { PRINT label AT(col, row). }
        }

        // Ticki i etykiety osi X
        FROM {LOCAL val IS ctx["minX"].} UNTIL val > ctx["maxX"] STEP {SET val TO val + stepX.} DO {
            LOCAL pct IS (val - ctx["minX"]) / (ctx["maxX"] - ctx["minX"]).
            LOCAL xPix IS pct * (w - 1).
            SET xPix TO MAX(0, MIN(w - 1, xPix)).

            line:CALL(xPix, h - 1, xPix, h - 5). // Tick dlugosci 4px w gore

            LOCAL label IS formatLabel(val / scaleX).

            LOCAL col IS ox + FLOOR(xPix / 2).
            LOCAL row IS oy + CEILING(h / 4). 
            PRINT label AT(col, row).
        }
        
        c["draw"]:CALL(ox, oy, TRUE). // Wymus odswiezenie
    }).

    // Dodaje punkt do wykresu
    api:ADD("plot", {
        PARAMETER x, y.
        LOCAL c IS ctx["c"].
        LOCAL redrawNeeded IS FALSE.
        
        // Obsluga przewijania X (Paging)
        LOCAL rangeX IS ctx["maxX"] - ctx["minX"].
        IF x > ctx["maxX"] {
            // Przesuwamy okno az punkt sie zmiesci
            UNTIL x <= ctx["maxX"] {
                SET ctx["minX"] TO ctx["minX"] + rangeX.
                SET ctx["maxX"] TO ctx["maxX"] + rangeX.
            }
            SET redrawNeeded TO TRUE.
        } ELSE IF x < ctx["minX"] {
            // Przesuwamy okno w lewo
            UNTIL x >= ctx["minX"] {
                SET ctx["minX"] TO ctx["minX"] - rangeX.
                SET ctx["maxX"] TO ctx["maxX"] - rangeX.
            }
            SET redrawNeeded TO TRUE.
        }
        
        // Obsluga przewijania Y (Paging)
        LOCAL rangeY IS ctx["maxY"] - ctx["minY"].
        IF y > ctx["maxY"] {
             UNTIL y <= ctx["maxY"] {
                SET ctx["minY"] TO ctx["minY"] + rangeY.
                SET ctx["maxY"] TO ctx["maxY"] + rangeY.
            }
            SET redrawNeeded TO TRUE.
        } ELSE IF y < ctx["minY"] {
             UNTIL y >= ctx["minY"] {
                SET ctx["minY"] TO ctx["minY"] - rangeY.
                SET ctx["maxY"] TO ctx["maxY"] - rangeY.
            }
            SET redrawNeeded TO TRUE.
        }

        IF redrawNeeded {
            // Czyscimy plot
            c["clear"]:CALL().
            
            // Rysujemy osie na nowo (z nowymi etykietami)
            IF ctx:HASKEY("stepX") {
                api["drawAxes"]:CALL(ctx["stepX"], ctx["stepY"], ctx["scaleX"], ctx["scaleY"]).
            }
            
            // Resetujemy linie (zeby nie laczyc z punktem z poprzedniej strony)
            SET ctx["firstPoint"] TO TRUE.
        }
        
        LOCAL w IS ctx["w"].
        LOCAL h IS ctx["h"].
        LOCAL line IS c["line"].
        LOCAL setPixel IS c["set"].
        LOCAL draw IS c["draw"].

        // Skalowanie
        LOCAL pctX IS (x - ctx["minX"]) / (ctx["maxX"] - ctx["minX"]).
        LOCAL pctY IS (y - ctx["minY"]) / (ctx["maxY"] - ctx["minY"]).

        LOCAL px IS pctX * (w - 1).
        LOCAL py IS (h - 1) - (pctY * (h - 1)).

        // Clamp
        SET px TO MAX(0, MIN(w - 1, px)).
        SET py TO MAX(0, MIN(h - 1, py)).

        IF ctx["firstPoint"] {
            SET ctx["lastX"] TO px.
            SET ctx["lastY"] TO py.
            SET ctx["firstPoint"] TO FALSE.
            
            IF ctx["plotMode"] = "POINT" {
                setPixel:CALL(px, py, 1).
                draw:CALL().
            }
        } ELSE {
            // Rysuj jesli punkt zmienil pozycje (w dowolna strone)
            IF px <> ctx["lastX"] OR py <> ctx["lastY"] { 
                IF ctx["plotMode"] = "POINT" {
                    setPixel:CALL(px, py, 1).
                } ELSE {
                    line:CALL(ctx["lastX"], ctx["lastY"], px, py).
                }
                
                SET ctx["lastX"] TO px.
                SET ctx["lastY"] TO py.
                draw:CALL().
            }
        }
    }).

    api:ADD("draw", {
        PARAMETER force IS FALSE.
        ctx["c"]["draw"]:CALL(ctx["ox"], ctx["oy"], force).
    }).

    RETURN api.
}
