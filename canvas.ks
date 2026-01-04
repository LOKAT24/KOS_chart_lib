@LAZYGLOBAL OFF.

// STATIC CACHE & LUTs - Generated once on file load
LOCAL _STATIC_CHAR_CACHE IS LIST().
FROM {LOCAL i IS 0.} UNTIL i > 255 STEP {SET i TO i + 1.} DO {
    _STATIC_CHAR_CACHE:ADD(CHAR(10240 + i)).
}

// Braille dot masks
LOCAL _STATIC_MASKS IS LIST(1, 2, 4, 64, 8, 16, 32, 128).

// Pre-calculate LUTs for up to 1000 pixels (enough for any screen)
LOCAL _MAX_DIM IS 1000.
LOCAL _STATIC_X_CELL IS LIST().
LOCAL _STATIC_X_SUB IS LIST().
FROM {LOCAL i IS 0.} UNTIL i >= _MAX_DIM STEP {SET i TO i + 1.} DO {
    _STATIC_X_CELL:ADD(FLOOR(i / 2)).
    _STATIC_X_SUB:ADD(MOD(i, 2)).
}

LOCAL _STATIC_Y_ROW IS LIST().
LOCAL _STATIC_Y_SUB IS LIST().
FROM {LOCAL i IS 0.} UNTIL i >= _MAX_DIM STEP {SET i TO i + 1.} DO {
    _STATIC_Y_ROW:ADD(FLOOR(i / 4)).
    _STATIC_Y_SUB:ADD(MOD(i, 4)).
}

// Pre-allocate zeros for buffer (max 5000 chars = approx full screen)
LOCAL _MAX_BUF IS 5000.
LOCAL _STATIC_ZEROS IS LIST().
FROM {LOCAL i IS 0.} UNTIL i >= _MAX_BUF STEP {SET i TO i + 1.} DO {
    _STATIC_ZEROS:ADD(0).
}

LOCAL _STATIC_TRUES IS LIST().
FROM {LOCAL i IS 0.} UNTIL i >= _MAX_DIM STEP {SET i TO i + 1.} DO {
    _STATIC_TRUES:ADD(TRUE).
}

GLOBAL FUNCTION Canvas {
    PARAMETER widthPx, heightPx, startX IS 0, startY IS 0.

    LOCAL w IS CEILING(widthPx / 2).
    LOCAL h IS CEILING(heightPx / 4).
    LOCAL originX IS startX.
    LOCAL originY IS startY.
    LOCAL px_w IS w * 2.
    LOCAL px_h IS h * 4.
    
    // FAST BUFFER INIT: Copy from static zeros instead of looping
    LOCAL totalSize IS w * h.
    LOCAL buffer IS LIST().
    IF totalSize <= _MAX_BUF {
        SET buffer TO _STATIC_ZEROS:SUBLIST(0, totalSize).
    } ELSE {
        // Fallback for huge buffers
        SET buffer TO _STATIC_ZEROS:SUBLIST(0, _MAX_BUF).
        FROM {LOCAL i IS _MAX_BUF.} UNTIL i >= totalSize STEP {SET i TO i + 1.} DO buffer:ADD(0).
    }

    // Use reference to static cache
    LOCAL charCache IS _STATIC_CHAR_CACHE.

    LOCAL rows IS LIST().
    FROM {LOCAL i IS 0.} UNTIL i >= h STEP {SET i TO i + 1.} DO rows:ADD("").
    
    // FAST DIRTY INIT
    LOCAL dirty IS LIST().
    IF h <= _MAX_DIM {
        SET dirty TO _STATIC_TRUES:SUBLIST(0, h).
    } ELSE {
        SET dirty TO _STATIC_TRUES:SUBLIST(0, _MAX_DIM).
        FROM {LOCAL i IS _MAX_DIM.} UNTIL i >= h STEP {SET i TO i + 1.} DO dirty:ADD(TRUE).
    }

    // USE STATIC LUTs (Read-only access is safe)
    LOCAL masks IS _STATIC_MASKS.
    LOCAL xCell IS _STATIC_X_CELL.
    LOCAL xSub IS _STATIC_X_SUB.
    LOCAL yRow IS _STATIC_Y_ROW.
    LOCAL ySub IS _STATIC_Y_SUB.

    LOCAL FUNCTION set_pixel_raw {
        PARAMETER x, y, val.

        LOCAL cx IS xCell[x].
        LOCAL cy IS yRow[y].
        LOCAL idx IS cy * w + cx.

        LOCAL sx IS xSub[x].
        LOCAL sy IS ySub[y].
        LOCAL mask IS masks[sx * 4 + sy].
        LOCAL cur IS buffer[idx].

        LOCAL temp IS FLOOR(cur / mask).
        LOCAL is_set IS MOD(temp, 2).

        IF val > 0 {
            IF is_set = 0 {
                SET buffer[idx] TO cur + mask.
                SET dirty[cy] TO TRUE.
            }
        } ELSE {
            IF is_set = 1 {
                SET buffer[idx] TO cur - mask.
                SET dirty[cy] TO TRUE.
            }
        }
    }

    LOCAL api IS LEXICON().
    api:ADD("width", px_w).
    api:ADD("height", px_h).
    api:ADD("originX", originX).
    api:ADD("originY", originY).

    api:ADD("set", {
        PARAMETER x, y, val IS 1.
        SET x TO ROUND(x). SET y TO ROUND(y).
        IF x >= 0 AND x < px_w AND y >= 0 AND y < px_h {
            set_pixel_raw(x, y, val).
        }
    }).

    api:ADD("clear", {
        // FAST CLEAR: Replace buffer with static zeros
        IF buffer:LENGTH <= _MAX_BUF {
            SET buffer TO _STATIC_ZEROS:SUBLIST(0, buffer:LENGTH).
        } ELSE {
            FROM {LOCAL i IS 0.} UNTIL i >= buffer:LENGTH STEP {SET i TO i + 1.} DO {
                SET buffer[i] TO 0.
            }
        }
        
        // FAST DIRTY RESET
        IF h <= _MAX_DIM {
            SET dirty TO _STATIC_TRUES:SUBLIST(0, h).
        } ELSE {
            FROM {LOCAL i IS 0.} UNTIL i >= h STEP {SET i TO i + 1.} DO {
                SET dirty[i] TO TRUE.
            }
        }
    }).

    api:ADD("draw", {
        PARAMETER c0 IS originX, r0 IS originY, force IS FALSE.
        
        FROM {LOCAL rowIdx IS 0.} UNTIL rowIdx >= h STEP {SET rowIdx TO rowIdx + 1.} DO {
            IF dirty[rowIdx] OR force {
                LOCAL s IS "".
                LOCAL rowOffset IS rowIdx * w.
                FROM {LOCAL colIdx IS 0.} UNTIL colIdx >= w STEP {SET colIdx TO colIdx + 1.} DO {
                    SET s TO s + charCache[buffer[rowOffset + colIdx]].
                }
                SET rows[rowIdx] TO s.
                SET dirty[rowIdx] TO FALSE.
                PRINT rows[rowIdx] AT(c0, r0 + rowIdx).
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
                set_pixel_raw(x0, y0, val).
            }

            IF x0 = x1 AND y0 = y1 BREAK.
            LOCAL e2 IS 2 * err.
            IF e2 > -dy { SET err TO err - dy. SET x0 TO x0 + sx. }
            IF e2 < dx { SET err TO err + dx. SET y0 TO y0 + sy. }
        }
    }).

    api:ADD("fastLine", {
        PARAMETER x0, y0, x1, y1, val IS 1.
        SET x0 TO ROUND(x0). SET y0 TO ROUND(y0).
        SET x1 TO ROUND(x1). SET y1 TO ROUND(y1).
        LOCAL dx IS ABS(x1 - x0). LOCAL dy IS ABS(y1 - y0).
        LOCAL sx IS 1. IF x0 > x1 { SET sx TO -1. }
        LOCAL sy IS 1. IF y0 > y1 { SET sy TO -1. }
        LOCAL err IS dx - dy.
        
        UNTIL FALSE {
            // INLINED set_pixel_raw
            LOCAL cx IS xCell[x0].
            LOCAL cy IS yRow[y0].
            LOCAL idx IS cy * w + cx.

            LOCAL subX IS xSub[x0].
            LOCAL subY IS ySub[y0].
            LOCAL mask IS masks[subX * 4 + subY].
            LOCAL cur IS buffer[idx].

            LOCAL temp IS FLOOR(cur / mask).
            LOCAL is_set IS MOD(temp, 2).

            IF val > 0 {
                IF is_set = 0 {
                    SET buffer[idx] TO cur + mask.
                    SET dirty[cy] TO TRUE.
                }
            } ELSE {
                IF is_set = 1 {
                    SET buffer[idx] TO cur - mask.
                    SET dirty[cy] TO TRUE.
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