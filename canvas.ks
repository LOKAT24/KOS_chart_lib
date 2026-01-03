@LAZYGLOBAL OFF.

GLOBAL FUNCTION Canvas {
    PARAMETER widthPx, heightPx, startX IS 0, startY IS 0.

    LOCAL ctx IS LEXICON().
    SET ctx["w"] TO CEILING(widthPx / 2).
    SET ctx["h"] TO CEILING(heightPx / 4).
    SET ctx["x"] TO startX.
    SET ctx["y"] TO startY.
    SET ctx["px_w"] TO ctx["w"] * 2.
    SET ctx["px_h"] TO ctx["h"] * 4.
    
    SET ctx["buffer"] TO LIST().
    FROM {LOCAL i IS 0.} UNTIL i >= (ctx["w"] * ctx["h"]) STEP {SET i TO i + 1.} DO {
        ctx["buffer"]:ADD(0).
    }

    // Cache znakow Braille'a (optymalizacja)
    LOCAL charCache IS LIST().
    FROM {LOCAL i IS 0.} UNTIL i > 255 STEP {SET i TO i + 1.} DO {
        charCache:ADD(CHAR(10240 + i)).
    }

    // Cache wierszy (stringow) i flagi dirty
    SET ctx["rows"] TO LIST().
    SET ctx["dirty"] TO LIST().
    FROM {LOCAL i IS 0.} UNTIL i >= ctx["h"] STEP {SET i TO i + 1.} DO {
        ctx["rows"]:ADD("").
        ctx["dirty"]:ADD(TRUE).
    }

    // Splaszczona tablica masek dla szybszego dostepu
    // x=0: 1, 2, 4, 64; x=1: 8, 16, 32, 128
    LOCAL masks IS LIST(1, 2, 4, 64, 8, 16, 32, 128).

    // Precompute mapowania wspolrzednych piksela -> (komorka, offset)
    // Zdejmuje FLOOR/dzielenia z goracej sciezki set_pixel_raw.
    SET ctx["xCell"] TO LIST().
    SET ctx["xSub"] TO LIST().
    FROM {LOCAL i IS 0.} UNTIL i >= ctx["px_w"] STEP {SET i TO i + 1.} DO {
        LOCAL cx IS FLOOR(i / 2).
        ctx["xCell"]:ADD(cx).
        ctx["xSub"]:ADD(i - (cx * 2)).
    }

    SET ctx["yRow"] TO LIST().
    SET ctx["ySub"] TO LIST().
    FROM {LOCAL i IS 0.} UNTIL i >= ctx["px_h"] STEP {SET i TO i + 1.} DO {
        LOCAL cy IS FLOOR(i / 4).
        ctx["yRow"]:ADD(cy).
        ctx["ySub"]:ADD(i - (cy * 4)).
    }

    // Lokalna funkcja ustawiania piksela (szybsza niz api:set w petli)
    LOCAL FUNCTION set_pixel_raw {
        PARAMETER x, y, val.

        LOCAL cx IS ctx["xCell"][x].
        LOCAL cy IS ctx["yRow"][y].
        LOCAL idx IS cy * ctx["w"] + cx.

        LOCAL sx IS ctx["xSub"][x].
        LOCAL sy IS ctx["ySub"][y].
        LOCAL mask IS masks[sx * 4 + sy].
        LOCAL cur IS ctx["buffer"][idx].

        // Symulacja operacji bitowych (maska to potega 2)
        LOCAL temp IS FLOOR(cur / mask).
        LOCAL is_set IS temp - 2 * FLOOR(temp / 2).

        IF val > 0 {
            IF is_set = 0 {
                SET ctx["buffer"][idx] TO cur + mask.
                SET ctx["dirty"][cy] TO TRUE.
            }
        } ELSE {
            IF is_set = 1 {
                SET ctx["buffer"][idx] TO cur - mask.
                SET ctx["dirty"][cy] TO TRUE.
            }
        }
    }

    LOCAL api IS LEXICON().
    api:ADD("width", ctx["px_w"]).
    api:ADD("height", ctx["px_h"]).
    api:ADD("originX", ctx["x"]).
    api:ADD("originY", ctx["y"]).

    api:ADD("set", {
        PARAMETER x, y, val IS 1.
        SET x TO ROUND(x). SET y TO ROUND(y).
        IF x >= 0 AND x < ctx["px_w"] AND y >= 0 AND y < ctx["px_h"] {
            set_pixel_raw(x, y, val).
        }
    }).

    api:ADD("clear", {
        FROM {LOCAL i IS 0.} UNTIL i >= ctx["buffer"]:LENGTH STEP {SET i TO i + 1.} DO {
            SET ctx["buffer"][i] TO 0.
        }
        FROM {LOCAL i IS 0.} UNTIL i >= ctx["h"] STEP {SET i TO i + 1.} DO {
            SET ctx["dirty"][i] TO TRUE.
        }
    }).

    api:ADD("draw", {
        PARAMETER c0 IS ctx["x"], r0 IS ctx["y"], force IS FALSE.
        LOCAL buf IS ctx["buffer"].
        LOCAL w IS ctx["w"].
        LOCAL h IS ctx["h"].
        LOCAL rows IS ctx["rows"].
        LOCAL dirty IS ctx["dirty"].
        
        FROM {LOCAL rowIdx IS 0.} UNTIL rowIdx >= h STEP {SET rowIdx TO rowIdx + 1.} DO {
            IF dirty[rowIdx] OR force {
                IF dirty[rowIdx] {
                    LOCAL s IS "".
                    LOCAL rowOffset IS rowIdx * w.
                    FROM {LOCAL colIdx IS 0.} UNTIL colIdx >= w STEP {SET colIdx TO colIdx + 1.} DO {
                        SET s TO s + charCache[buf[rowOffset + colIdx]].
                    }
                    SET rows[rowIdx] TO s.
                    SET dirty[rowIdx] TO FALSE.
                }
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
        
        LOCAL px_w IS ctx["px_w"].
        LOCAL px_h IS ctx["px_h"].

        UNTIL FALSE {
            // Bezposrednie wywolanie lokalnej funkcji
            IF x0 >= 0 AND x0 < px_w AND y0 >= 0 AND y0 < px_h {
                set_pixel_raw(x0, y0, val).
            }

            IF x0 = x1 AND y0 = y1 BREAK.
            LOCAL e2 IS 2 * err.
            IF e2 > -dy { SET err TO err - dy. SET x0 TO x0 + sx. }
            IF e2 < dx { SET err TO err + dx. SET y0 TO y0 + sy. }
        }
    }).

    RETURN api.

}