@LAZYGLOBAL OFF.

// 1. TERMINAL SETUP
// Important: The larger the terminal, the higher the resolution (1 char = 2x4 pixels).
// For a 100x60 char Canvas, we effectively have 200x240 pixels.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 40.
SET CONFIG:IPU TO 2000.
CLEARSCREEN.

// 2. IMPORT LIBRARIES
RUNPATH("0:/chart.ks").

PRINT "Initializing graph..." AT(0,0).

// 3. CHART OBJECT INSTANTIATION
// Signature: Chart(width, height, originX, originY, minX, maxX, minY, maxY, title, plotMode)
// width, height: in pixels (not characters!)
// originX, originY: top-left corner position in characters
GLOBAL myChart IS Chart(
    100,                // Width in pixels (approx. 50 characters)
    100,                // Height in pixels (approx. 25 characters)
    5,                  // Start X (column) in terminal
    5,                  // Start Y (row) in terminal
    0,                  // Min X (e.g., start time)
    100,                // Max X (e.g., time 100s)
    -1,                 // Min Y
    1,                  // Max Y
    "Sine Wave Test",   // Title
    "LINE"              // Mode: "LINE" (continuous) or "POINT" (points)
).

// 4. AXIS CONFIGURATION (Grid & Ticks)
// Signature: drawAxes(stepX, stepY, scaleX, scaleY)
// scaleX/Y is used to divide label values (e.g., 1000 for km)
myChart["drawAxes"](10, 0.5, 1, 1). 

// First forced draw (initializes buffer and clears area)
myChart["draw"](TRUE).

SET CONFIG:IPU TO 2000. // Increase instructions per update because rendering is expensive

LOCAL t0 IS TIME:SECONDS.

// 5. MAIN LOOP (Sampling & Plotting)
UNTIL FALSE {
    LOCAL dt IS TIME:SECONDS - t0.
    
    // Data generation (simulation here, in-flight e.g., SHIP:ALTITUDE)
    LOCAL val IS SIN(dt * 10). 

    // 6. PLOTTING DATA
    // The "plot" method automatically handles paging,
    // if X goes out of the range defined in the constructor.
    myChart["plot"](dt, val).

    // Optional: Display raw data alongside
    PRINT "T: " + ROUND(dt, 2) + "   " AT(0, 1).
    PRINT "V: " + ROUND(val, 2) + "   " AT(0, 2).

    WAIT 0.05. // Refresh rate
}