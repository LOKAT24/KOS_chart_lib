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
    
    // Enforce minimum margin of 4 chars for labels + 1 spacer
    LOCAL marginLeft IS MAX(MAX(maxLabelLen, minLabelLen), 4) + 1.

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
    
    // CACHED DELEGATES (Avoid lexicon lookup in loops)
    LOCAL canvas_fastLine IS c["fastLine"].
    LOCAL canvas_set IS c["set"].
    LOCAL canvas_draw IS c["draw"].
    LOCAL canvas_clear IS c["clear"].

    // PRECALCULATED MATH
    LOCAL rangeX IS maxX - minX.
    LOCAL rangeY IS maxY - minY.
    LOCAL recipRangeX IS 0. IF rangeX <> 0 { SET recipRangeX TO 1.0 / rangeX. }
    LOCAL recipRangeY IS 0. IF rangeY <> 0 { SET recipRangeY TO 1.0 / rangeY. }
    
    LOCAL wMinus1 IS w - 1.
    LOCAL hMinus1 IS h - 1.
    LOCAL factorX IS recipRangeX * wMinus1.
    LOCAL factorY IS recipRangeY * hMinus1.

    LOCAL axisStepX IS 0.
    LOCAL axisStepY IS 0.
    LOCAL axisScaleX IS 1.
    LOCAL axisScaleY IS 1.
    LOCAL axesDefined IS FALSE.
    
    LOCAL lastX IS -999999. 
    LOCAL lastY IS -999999.
    LOCAL firstPoint IS TRUE.
    
    LOCAL paddingSpaces IS "          ". // 10 spaces for padding

    LOCAL api IS LEXICON().

    api:ADD("drawAxes", {
        PARAMETER stepX, stepY, scaleX IS 1, scaleY IS 1, clearOnly IS FALSE.
        
        IF clearOnly {
            // OPTIMIZED BULK CLEAR
            // Clear Y-Axis area (Left margin)
            // Extend clearing to the left (safeMargin) to catch labels that grew longer than initial margin
            LOCAL safeMargin IS 8.
            LOCAL clearX IS MAX(0, originX - safeMargin).
            LOCAL clearW IS ox - clearX.

            IF clearW > 0 {
                LOCAL emptyY IS "".
                FROM {LOCAL i IS 0.} UNTIL i >= clearW STEP {SET i TO i + 1.} DO { SET emptyY TO emptyY + " ". }
                LOCAL rowsY IS CEILING(h / 4).
                FROM {LOCAL i IS 0.} UNTIL i <= rowsY STEP {SET i TO i + 1.} DO {
                    PRINT emptyY AT(clearX, oy + i).
                }
            }
            
            // Clear X-Axis area (Bottom margin)
            LOCAL rowX IS oy + CEILING(h / 4).
            LOCAL emptyX IS "".
            // Extend clearing to cover labels protruding to the right
            LOCAL clearLen IS CEILING(width / 2) + 8. 
            FROM {LOCAL i IS 0.} UNTIL i >= clearLen STEP {SET i TO i + 1.} DO { SET emptyX TO emptyX + " ". }
            PRINT emptyX AT(originX, rowX).
            
            RETURN.
        }

        SET axisStepX TO stepX.
        SET axisStepY TO stepY.
        SET axisScaleX TO scaleX.
        SET axisScaleY TO scaleY.
        SET axesDefined TO TRUE.
        
        LOCAL line IS canvas_fastLine.

        line:CALL(0, 0, 0, h - 1).
        line:CALL(0, h - 1, w - 1, h - 1).

        FROM {LOCAL val IS currentMinY.} UNTIL val > currentMaxY STEP {SET val TO val + stepY.} DO {
            LOCAL yPix IS hMinus1 - (val - currentMinY) * factorY.
            IF yPix < 0 { SET yPix TO 0. } ELSE IF yPix > hMinus1 { SET yPix TO hMinus1. }
            
            line:CALL(0, yPix, 4, yPix).
            
            LOCAL label IS formatLabel(val / scaleY).
            
            // PADDING LOGIC: Pad label with spaces to clear previous values
            LOCAL targetLen IS marginLeft - 1.
            IF label:LENGTH < targetLen {
                LOCAL pad IS targetLen - label:LENGTH.
                IF pad <= 10 {
                    SET label TO paddingSpaces:SUBSTRING(0, pad) + label.
                } ELSE {
                    // Fallback for huge padding
                    FROM {LOCAL i IS 0.} UNTIL i >= pad STEP {SET i TO i + 1.} DO { SET label TO " " + label. }
                }
            }

            LOCAL labelLen IS label:LENGTH.
            LOCAL col IS ox - labelLen - 1.
            LOCAL row IS oy + FLOOR(yPix / 4).
            IF col >= 0 { 
                PRINT label AT(col, row). 
            }
        }

        LOCAL xAxisStr IS "".
        LOCAL rowX IS oy + CEILING(h / 4).

        FROM {LOCAL val IS currentMinX.} UNTIL val > currentMaxX STEP {SET val TO val + stepX.} DO {
            LOCAL xPix IS (val - currentMinX) * factorX.
            IF xPix < 0 { SET xPix TO 0. } ELSE IF xPix > wMinus1 { SET xPix TO wMinus1. }

            line:CALL(xPix, h - 1, xPix, h - 5).

            LOCAL label IS formatLabel(val / scaleX).
            LOCAL targetRelCol IS FLOOR(xPix / 2).
            
            LOCAL currentLen IS xAxisStr:LENGTH.
            
            IF targetRelCol > currentLen {
                LOCAL spaces IS targetRelCol - currentLen.
                IF spaces <= 10 {
                    SET xAxisStr TO xAxisStr + paddingSpaces:SUBSTRING(0, spaces).
                } ELSE {
                    FROM {LOCAL i IS 0.} UNTIL i >= spaces STEP {SET i TO i + 1.} DO { SET xAxisStr TO xAxisStr + " ". }
                }
                SET xAxisStr TO xAxisStr + label.
            } ELSE {
                SET xAxisStr TO xAxisStr:SUBSTRING(0, targetRelCol) + label.
            }
        }
        PRINT xAxisStr AT(ox, rowX).
        
        canvas_draw:CALL(ox, oy, TRUE).
    }).

    api:ADD("plot", {
        PARAMETER x, y, autoDraw IS TRUE.
        LOCAL redrawNeeded IS FALSE.
        
        LOCAL newMinX IS currentMinX.
        LOCAL newMaxX IS currentMaxX.
        LOCAL newMinY IS currentMinY.
        LOCAL newMaxY IS currentMaxY.
        
        IF x > currentMaxX {
            IF enablePaging {
                LOCAL diff IS x - currentMaxX.
                LOCAL pages IS CEILING(diff * recipRangeX).
                IF pages = 0 { SET pages TO 1. } 
                LOCAL shift IS pages * rangeX.
                SET newMinX TO newMinX + shift.
                SET newMaxX TO newMaxX + shift.
                SET redrawNeeded TO TRUE.
            }
        } ELSE IF x < currentMinX {
            IF enablePaging {
                LOCAL diff IS currentMinX - x.
                LOCAL pages IS CEILING(diff * recipRangeX).
                IF pages = 0 { SET pages TO 1. }
                LOCAL shift IS pages * rangeX.
                SET newMinX TO newMinX - shift.
                SET newMaxX TO newMaxX - shift.
                SET redrawNeeded TO TRUE.
            }
        }
        
        IF y > currentMaxY {
             IF enablePaging {
                LOCAL diff IS y - currentMaxY.
                LOCAL pages IS CEILING(diff * recipRangeY).
                IF pages = 0 { SET pages TO 1. }
                LOCAL shift IS pages * rangeY.
                SET newMinY TO newMinY + shift.
                SET newMaxY TO newMaxY + shift.
                SET redrawNeeded TO TRUE.
             }
        } ELSE IF y < currentMinY {
             IF enablePaging {
                LOCAL diff IS currentMinY - y.
                LOCAL pages IS CEILING(diff * recipRangeY).
                IF pages = 0 { SET pages TO 1. }
                LOCAL shift IS pages * rangeY.
                SET newMinY TO newMinY - shift.
                SET newMaxY TO newMaxY - shift.
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
            
            canvas_clear:CALL().
            
            IF axesDefined {
                api["drawAxes"]:CALL(axisStepX, axisStepY, axisScaleX, axisScaleY).
            }
            
            SET firstPoint TO TRUE.
        }
        
        LOCAL line IS canvas_fastLine.
        LOCAL setPixel IS canvas_set.
        LOCAL draw IS canvas_draw.

        LOCAL px IS (x - currentMinX) * factorX.
        LOCAL py IS hMinus1 - (y - currentMinY) * factorY.

        IF px < 0 { SET px TO 0. } ELSE IF px > wMinus1 { SET px TO wMinus1. }
        IF py < 0 { SET py TO 0. } ELSE IF py > hMinus1 { SET py TO hMinus1. }

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
        canvas_draw:CALL(ox, oy, force).
    }).

    RETURN api.
}
