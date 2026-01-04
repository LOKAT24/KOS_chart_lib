@LAZYGLOBAL OFF.

// BENCHMARK.KS

CLEARSCREEN.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 60.
SET CONFIG:IPU TO 2000. 

PRINT "=== KOS CHART BENCHMARK ===" AT(0,0).
PRINT "Loading libraries..." AT(0,1).

LOCAL tStartLoad IS TIME:SECONDS.
RUNPATH("0:/canvas.ks").
RUNPATH("0:/chart.ks").
PRINT "Load time: " + ROUND(TIME:SECONDS - tStartLoad, 4) + "s" AT(0,2).

WAIT 1.

PRINT "Test 1: Initialization (50 iterations)..." AT(0,4).
LOCAL t0 IS TIME:SECONDS.

FROM {LOCAL i IS 0.} UNTIL i >= 50 STEP {SET i TO i + 1.} DO {
    // Create a 100x100 pixel chart
    // This tests memory allocation and LUT generation in canvas.ks
    LOCAL tempChart IS Chart(100, 100, 0, 0, 0, 100, 0, 100).
}

LOCAL t1 IS TIME:SECONDS.
LOCAL initTime IS t1 - t0.
PRINT "Result: " + ROUND(initTime, 4) + "s" AT(0,5).
PRINT "Avg per chart: " + ROUND(initTime / 50, 4) + "s" AT(0,6).

// --- PREPARATION FOR TEST 2 & 3 ---
// Create one object for stress testing
LOCAL benchChart IS Chart(100, 100, 5, 25, 0, 1000, -1, 1, "BENCHMARK", "LINE").
benchChart["drawAxes"](100, 0.5).
benchChart["draw"](TRUE). // First draw

// --- TEST 2: PLOTTING (CALCULATIONS) ---
// Testing speed of 'plot' and 'fastLine' functions WITHOUT drawing to screen (autoDraw = FALSE)
PRINT "Test 2: Plotting (1000 points, no draw)..." AT(0,8).
LOCAL t2 IS TIME:SECONDS.

FROM {LOCAL i IS 0.} UNTIL i >= 1000 STEP {SET i TO i + 1.} DO {
    // Draw a dense sine wave
    benchChart["plot"](i, SIN(i * 10), FALSE).
}

LOCAL t3 IS TIME:SECONDS.
LOCAL plotTime IS t3 - t2.
PRINT "Result: " + ROUND(plotTime, 4) + "s" AT(0,9).
PRINT "Points per sec: " + ROUND(1000 / plotTime, 0) AT(0,10).

// --- TEST 3: RENDERING (SCREEN DRAWING) ---
// Testing only terminal refresh (string building and PRINT)
PRINT "Test 3: Rendering (20 frames, force redraw)..." AT(0,12).
LOCAL t4 IS TIME:SECONDS.

FROM {LOCAL i IS 0.} UNTIL i >= 20 STEP {SET i TO i + 1.} DO {
    benchChart["draw"](TRUE). // TRUE forces full redraw
}

LOCAL t5 IS TIME:SECONDS.
LOCAL renderTime IS t5 - t4.
PRINT "Result: " + ROUND(renderTime, 4) + "s" AT(0,13).
PRINT "FPS (approx): " + ROUND(20 / renderTime, 1) AT(0,14).

// --- TEST 4: PAGING (CHART SCROLLING) ---
// Testing performance of range shifting (clearing axes, clearing buffer, drawing new axes)
// Changing Y range to negative to test clearing of minus signs
PRINT "Test 4: Paging (10 shifts)..." AT(0,16).
LOCAL pagingChart IS Chart(100, 100, 10, 25, 0, 10, -10, 10, "PAGING", "LINE").
pagingChart["drawAxes"](1, 2).
pagingChart["draw"](TRUE).

LOCAL t6 IS TIME:SECONDS.
FROM {LOCAL i IS 0.} UNTIL i >= 100 STEP {SET i TO i + 1.} DO {
    // Range is 0-10. We go to 100, so we force 10 shifts (pages)
    // Y value oscillates around zero so labels change from positive to negative
    pagingChart["plot"](i, 5 * SIN(i * 20), FALSE). 
}
LOCAL t7 IS TIME:SECONDS.
LOCAL pagingTime IS t7 - t6.
PRINT "Result: " + ROUND(pagingTime, 4) + "s" AT(0,17).
PRINT "Avg per shift: " + ROUND(pagingTime / 10, 4) + "s" AT(0,18).


PRINT "---------------------------" AT(0,20).
PRINT "TOTAL TIME: " + ROUND(initTime + plotTime + renderTime + pagingTime, 4) + "s" AT(0,21).
PRINT "DONE." AT(0,22).
