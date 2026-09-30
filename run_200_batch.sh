#!/bin/bash
MATLAB="/c/Program Files/Polyspace/R2019a/bin/matlab.exe"
cd "C:/Users/Hp/AppData/Local/Temp/claude/C--Users-Hp/cee4e524-2cfc-4e22-a4ea-7e58ae9c1ada/scratchpad"
echo "=== plot_ablation_study_200.m ==="
"$MATLAB" -batch "run('plot_ablation_study_200.m')" 2>&1
echo "=== plot_reps_vs_success_tradeoff_200.m ==="
"$MATLAB" -batch "run('plot_reps_vs_success_tradeoff_200.m')" 2>&1
echo "=== per_sensitivity_analysis_200.m ==="
"$MATLAB" -batch "run('per_sensitivity_analysis_200.m')" 2>&1
echo "=== plot_slot_utilization_vs_traffic_200.m ==="
"$MATLAB" -batch "run('plot_slot_utilization_vs_traffic_200.m')" 2>&1
echo "=== ALL DONE ==="
