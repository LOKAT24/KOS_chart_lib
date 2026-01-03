@LAZYGLOBAL OFF.

GLOBAL FUNCTION Canvas {
    PARAMETER widthPx, heightPx, startX IS 0, startY IS 0.

    LOCAL w IS CEILING(widthPx / 2).
    LOCAL h IS CEILING(heightPx / 4).
    LOCAL px_w IS w * 2.
    LOCAL px_h IS h * 4.
    
    LOCAL pixels IS LIST().
    LOCAL totalPixels IS px_w * px_h.
    FROM {LOCAL i IS 0.} UNTIL i >= totalPixels STEP {SET i TO i + 1.} DO {
        pixels:ADD(0).
    }

    LOCAL char_buffer IS LIST().
    LOCAL totalChars IS w * h.
    FROM {LOCAL i IS 0.} UNTIL i >= totalChars STEP {SET i TO i + 1.} DO {
        char_buffer:ADD(0).
    }

    LOCAL dirty_cells IS LIST(). 
    FROM {LOCAL i IS 0.} UNTIL i >= totalChars STEP {SET i TO i + 1.} DO {
        dirty_cells:ADD(FALSE).
    }

    LOCAL dirty_rows IS LIST().
    LOCAL rows IS LIST().
    FROM {LOCAL i IS 0.} UNTIL i >= h STEP {SET i TO i + 1.} DO {
        dirty_rows:ADD(TRUE).
        rows:ADD("").
    }

    LOCAL charCache IS LIST().
    FROM {LOCAL i IS 0.} UNTIL i > 255 STEP {SET i TO i + 1.} DO {
        charCache:ADD(CHAR(10240 + i)).
    }

    LOCAL xCell IS LIST().
    FROM {LOCAL i IS 0.} UNTIL i >= px_w STEP {SET i TO i + 1.} DO {
        xCell:ADD(FLOOR(i / 2)).
    }
    LOCAL yRow IS LIST().
    FROM {LOCAL i IS 0.} UNTIL i >= px_h STEP {SET i TO i + 1.} DO {
        yRow:ADD(FLOOR(i / 4)).
    }

    LOCAL FUNCTION set_pixel_raw {
        PARAMETER x, y, val.
        
        LOCAL idx IS y * px_w + x.
        
        IF pixels[idx] <> val {
            SET pixels[idx] TO val.
            
            LOCAL row_idx IS yRow[y].
            SET dirty_cells[row_idx * w + xCell[x]] TO TRUE.
            SET dirty_rows[row_idx] TO TRUE.
        }
    }

    LOCAL api IS LEXICON().
    api:ADD("width", px_w).
    api:ADD("height", px_h).
    api:ADD("originX", startX).
    api:ADD("originY", startY).

    api:ADD("set", {
        PARAMETER x, y, val IS 1.
        SET x TO ROUND(x). SET y TO ROUND(y).
        IF x >= 0 AND x < px_w AND y >= 0 AND y < px_h {
            set_pixel_raw(x, y, val).
        }
    }).

    api:ADD("clear", {
        FROM {LOCAL i IS 0.} UNTIL i >= totalPixels STEP {SET i TO i + 1.} DO { SET pixels[i] TO 0. }
        FROM {LOCAL i IS 0.} UNTIL i >= totalChars STEP {SET i TO i + 1.} DO { SET char_buffer[i] TO 0. }
        FROM {LOCAL i IS 0.} UNTIL i >= totalChars STEP {SET i TO i + 1.} DO { SET dirty_cells[i] TO FALSE. }
        FROM {LOCAL i IS 0.} UNTIL i >= h STEP {SET i TO i + 1.} DO { SET dirty_rows[i] TO TRUE. }
    }).

    api:ADD("draw", {
        PARAMETER c0 IS startX, r0 IS startY, force IS FALSE.
        
        FROM {LOCAL row_idx IS 0.} UNTIL row_idx >= h STEP {SET row_idx TO row_idx + 1.} DO {
            IF dirty_rows[row_idx] OR force {
                LOCAL rowBaseIdx IS row_idx * w.
                LOCAL rowChanged IS FALSE.
                
                FROM {LOCAL c IS 0.} UNTIL c >= w STEP {SET c TO c + 1.} DO {
                    LOCAL cidx IS rowBaseIdx + c.
                    IF dirty_cells[cidx] {
                        LOCAL val IS 0.
                        LOCAL basePxX IS c * 2.
                        LOCAL basePxY IS row_idx * 4.
                        LOCAL pPtr IS basePxY * px_w + basePxX.
                        
        
                        IF pixels[pPtr] > 0 { SET val TO val + 1. }
                        IF pixels[pPtr + px_w] > 0 { SET val TO val + 2. }
                        IF pixels[pPtr + 2*px_w] > 0 { SET val TO val + 4. }
                        IF pixels[pPtr + 3*px_w] > 0 { SET val TO val + 64. }
                        
                
                        SET pPtr TO pPtr + 1.
                        IF pixels[pPtr] > 0 { SET val TO val + 8. }
                        IF pixels[pPtr + px_w] > 0 { SET val TO val + 16. }
                        IF pixels[pPtr + 2*px_w] > 0 { SET val TO val + 32. }
                        IF pixels[pPtr + 3*px_w] > 0 { SET val TO val + 128. }
                        
                        SET char_buffer[cidx] TO val.
                        SET dirty_cells[cidx] TO FALSE.
                        SET rowChanged TO TRUE.
                    }
                }
                
                IF rowChanged OR force {
                    LOCAL s IS "".
                    FROM {LOCAL c IS 0.} UNTIL c >= w STEP {SET c TO c + 1.} DO {
                        SET s TO s + charCache[char_buffer[rowBaseIdx + c]].
                    }
                    SET rows[row_idx] TO s.
                    PRINT s AT(c0, r0 + row_idx).
                }
                
                SET dirty_rows[row_idx] TO FALSE.
            }
        }
    }).

    api:ADD("line", {
        PARAMETER x0, y0, x1, y1, val IS 1.
        SET x0 TO ROUND(x0). SET y0 TO ROUND(y0).
        SET x1 TO ROUND(x1). SET y1 TO ROUND(y1).
        LOCAL dx IS ABS(x1 - x0). LOCAL dy IS ABS(y1 - y0).
        LOCAL sx IS 1. IF x0 > x1 { SET sx TO -1. }
        LOCAL sy IS 1. IF y0 > y1 { SET sy TO -1. }
        LOCAL err IS dx - dy.
        
        UNTIL FALSE {
            IF x0 >= 0 AND x0 < px_w AND y0 >= 0 AND y0 < px_h {
                LOCAL idx IS y0 * px_w + x0.
                IF pixels[idx] <> val {
                    SET pixels[idx] TO val.
                    LOCAL row_idx IS yRow[y0].
                    SET dirty_cells[row_idx * w + xCell[x0]] TO TRUE.
                    SET dirty_rows[row_idx] TO TRUE.
                }
            }

            IF x0 = x1 AND y0 = y1 BREAK.
            LOCAL e2 IS 2 * err.
            IF e2 > -dy { SET err TO err - dy. SET x0 TO x0 + sx. }
            IF e2 < dx { SET err TO err + dx. SET y0 TO y0 + sy. }
        }
    }).

    RETURN api.

}