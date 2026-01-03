@LAZYGLOBAL OFF.
RUNONCEPATH("0:/canvas.ks").

GLOBAL FUNCTION Chart {
    PARAMETER width, height, originX, originY, minX, maxX, minY, maxY, title IS "", plotMode IS "LINE", enablePaging IS TRUE.

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

    LOCAL maxLabelLen IS formatLabel(maxY):LENGTH.
    LOCAL minLabelLen IS formatLabel(minY):LENGTH.
    
    LOCAL marginLeft IS MAX(maxLabelLen, minLabelLen) + 1.

    LOCAL marginTop IS 0.
    IF title:LENGTH > 0 { SET marginTop TO 1. }
    
    LOCAL marginBottom IS 1.

    LOCAL canvasX IS originX + marginLeft.
    LOCAL canvasY IS originY + marginTop.
    
    LOCAL canvasWidth IS width - (marginLeft * 2).
    LOCAL canvasHeight IS height - ((marginTop + marginBottom) * 4).
    
    SET canvasWidth TO MAX(1, canvasWidth).
    SET canvasHeight TO MAX(1, canvasHeight).

    
    LOCAL c IS Canvas(canvasWidth, canvasHeight, canvasX, canvasY).

    IF title:LENGTH > 0 {
        LOCAL totalWidthChars IS CEILING(width / 2).
        LOCAL titleX IS originX + FLOOR((totalWidthChars - title:LENGTH) / 2).
        PRINT title AT(MAX(originX, titleX), originY).
    }
    
    LOCAL currentMinX IS minX.
    LOCAL currentMaxX IS maxX.
    LOCAL currentMinY IS minY.
    LOCAL currentMaxY IS maxY.
    LOCAL w IS c["width"].
    LOCAL h IS c["height"].
    LOCAL ox IS c["originX"].
    LOCAL oy IS c["originY"].
    LOCAL currentPlotMode IS plotMode.
    
    LOCAL axisStepX IS 0.
    LOCAL axisStepY IS 0.
    LOCAL axisScaleX IS 1.
    LOCAL axisScaleY IS 1.
    LOCAL axesDefined IS FALSE.
    
    LOCAL lastX IS -999999. 
    LOCAL lastY IS -999999.
    LOCAL firstPoint IS TRUE.

    LOCAL api IS LEXICON().

    api:ADD("drawAxes", {
        PARAMETER stepX, stepY, scaleX IS 1, scaleY IS 1, clearOnly IS FALSE.
        
        IF NOT clearOnly {
            SET axisStepX TO stepX.
            SET axisStepY TO stepY.
            SET axisScaleX TO scaleX.
            SET axisScaleY TO scaleY.
            SET axesDefined TO TRUE.
        }
        
        LOCAL line IS c["line"].

        IF NOT clearOnly {
            line:CALL(0, 0, 0, h - 1).
            line:CALL(0, h - 1, w - 1, h - 1).
        }

        FROM {LOCAL val IS currentMinY.} UNTIL val > currentMaxY STEP {SET val TO val + stepY.} DO {
            LOCAL pct IS (val - currentMinY) / (currentMaxY - currentMinY).
            LOCAL yPix IS (h - 1) - (pct * (h - 1)).
            SET yPix TO MAX(0, MIN(h - 1, yPix)).
            
            IF NOT clearOnly {
                line:CALL(0, yPix, 4, yPix).
            }
            
            LOCAL label IS formatLabel(val / scaleY).
            
            LOCAL labelLen IS label:LENGTH.
            LOCAL col IS ox - labelLen - 1.
            LOCAL row IS oy + FLOOR(yPix / 4).
            IF col >= 0 { 
                IF clearOnly {
                    LOCAL emptyStr IS "".
                    FROM {LOCAL i IS 0.} UNTIL i >= labelLen STEP {SET i TO i + 1.} DO { SET emptyStr TO emptyStr + " ". }
                    PRINT emptyStr AT(col, row).
                } ELSE {
                    PRINT label AT(col, row). 
                }
            }
        }

        FROM {LOCAL val IS currentMinX.} UNTIL val > currentMaxX STEP {SET val TO val + stepX.} DO {
            LOCAL pct IS (val - currentMinX) / (currentMaxX - currentMinX).
            LOCAL xPix IS pct * (w - 1).
            SET xPix TO MAX(0, MIN(w - 1, xPix)).

            IF NOT clearOnly {
                line:CALL(xPix, h - 1, xPix, h - 5).
            }

            LOCAL label IS formatLabel(val / scaleX).

            LOCAL col IS ox + FLOOR(xPix / 2).
            LOCAL row IS oy + CEILING(h / 4). 
            
            IF clearOnly {
                LOCAL labelLen IS label:LENGTH.
                LOCAL emptyStr IS "".
                FROM {LOCAL i IS 0.} UNTIL i >= labelLen STEP {SET i TO i + 1.} DO { SET emptyStr TO emptyStr + " ". }
                PRINT emptyStr AT(col, row).
            } ELSE {
                PRINT label AT(col, row).
            }
        }
        
        IF NOT clearOnly {
            c["draw"]:CALL(ox, oy, TRUE).
        }
    }).

    api:ADD("plot", {
        PARAMETER x, y, autoDraw IS TRUE.
        LOCAL redrawNeeded IS FALSE.
        
        LOCAL newMinX IS currentMinX.
        LOCAL newMaxX IS currentMaxX.
        LOCAL newMinY IS currentMinY.
        LOCAL newMaxY IS currentMaxY.
        
        LOCAL rangeX IS currentMaxX - currentMinX.
        IF x > currentMaxX {
            IF enablePaging {
                UNTIL x <= newMaxX {
                    SET newMinX TO newMinX + rangeX.
                    SET newMaxX TO newMaxX + rangeX.
                }
                SET redrawNeeded TO TRUE.
            }
        } ELSE IF x < currentMinX {
            IF enablePaging {
                UNTIL x >= newMinX {
                    SET newMinX TO newMinX - rangeX.
                    SET newMaxX TO newMaxX - rangeX.
                }
                SET redrawNeeded TO TRUE.
            }
        }
        
        LOCAL rangeY IS currentMaxY - currentMinY.
        IF y > currentMaxY {
             IF enablePaging {
                 UNTIL y <= newMaxY {
                    SET newMinY TO newMinY + rangeY.
                    SET newMaxY TO newMaxY + rangeY.
                }
                SET redrawNeeded TO TRUE.
             }
        } ELSE IF y < currentMinY {
             IF enablePaging {
                 UNTIL y >= newMinY {
                    SET newMinY TO newMinY - rangeY.
                    SET newMaxY TO newMaxY - rangeY.
                }
                SET redrawNeeded TO TRUE.
             }
        }

        IF redrawNeeded {
            IF axesDefined {
                api["drawAxes"]:CALL(axisStepX, axisStepY, axisScaleX, axisScaleY, TRUE).
            }
            
            SET currentMinX TO newMinX.
            SET currentMaxX TO newMaxX.
            SET currentMinY TO newMinY.
            SET currentMaxY TO newMaxY.
            
            c["clear"]:CALL().
            
            IF axesDefined {
                api["drawAxes"]:CALL(axisStepX, axisStepY, axisScaleX, axisScaleY).
            }
            
            SET firstPoint TO TRUE.
        }
        
        LOCAL line IS c["line"].
        LOCAL setPixel IS c["set"].
        LOCAL draw IS c["draw"].

        LOCAL pctX IS (x - currentMinX) / (currentMaxX - currentMinX).
        LOCAL pctY IS (y - currentMinY) / (currentMaxY - currentMinY).

        LOCAL px IS pctX * (w - 1).
        LOCAL py IS (h - 1) - (pctY * (h - 1)).

        SET px TO MAX(0, MIN(w - 1, px)).
        SET py TO MAX(0, MIN(h - 1, py)).

        IF firstPoint {
            SET lastX TO px.
            SET lastY TO py.
            SET firstPoint TO FALSE.
            
            IF currentPlotMode = "POINT" {
                setPixel:CALL(px, py, 1).
                IF autoDraw { draw:CALL(). }
            }
        } ELSE {
            IF px <> lastX OR py <> lastY { 
                IF currentPlotMode = "POINT" {
                    setPixel:CALL(px, py, 1).
                } ELSE {
                    line:CALL(lastX, lastY, px, py).
                }
                
                SET lastX TO px.
                SET lastY TO py.
                IF autoDraw { draw:CALL(). }
            }
        }
    }).

    api:ADD("draw", {
        PARAMETER force IS FALSE.
        c["draw"]:CALL(ox, oy, force).
    }).

    RETURN api.
}
