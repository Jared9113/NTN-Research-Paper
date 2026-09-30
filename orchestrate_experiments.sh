#!/bin/bash
MATLAB="/c/Program Files/Polyspace/R2019a/bin/matlab.exe"
cd "C:/Users/Hp/Documents/NTN_LEO_Simulation"

# Wait for the currently-running experiment12 job (already launched) to exit.
while pgrep -f "MATLAB.exe" > /dev/null 2>&1 || pgrep -f "matlab.exe" > /dev/null 2>&1; do
    sleep 20
done

# Auto-resume experiment12 until it actually finishes (produces the final
# results file), not just whenever MATLAB happens to exit - protects
# against the heap-corruption crashes seen repeatedly on long runs.
ATTEMPTS=0
while [ ! -f "experiment12_duration_sweep_results.mat" ] && [ $ATTEMPTS -lt 15 ]; do
    ATTEMPTS=$((ATTEMPTS+1))
    echo "=== experiment12 attempt $ATTEMPTS (resuming if progress exists) ==="
    "$MATLAB" -batch "experiment12_duration_sweep" 2>&1
done

if [ -f "experiment12_duration_sweep_results.mat" ]; then
    echo "=== experiment12_duration_sweep COMPLETE ==="
else
    echo "=== experiment12_duration_sweep FAILED after $ATTEMPTS attempts - NOT running experiment3 ==="
    exit 1
fi

echo "=== experiment3_trem_error_sweep.m ==="
"$MATLAB" -batch "experiment3_trem_error_sweep" 2>&1
echo "=== ALL EXPERIMENTS DONE ==="
