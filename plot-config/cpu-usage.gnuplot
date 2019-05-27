set term png size 2000, 1000
set timefmt "%Y-%m-%dT%H:%M:%SZ"
set format x "%H:%M:%S"
set format y '%.02s%cB'
set xdata time
set ylabel "CPU Usage"
set xlabel "Time"
set grid
set key off
set datafile separator ","
plot filename usi 1:2 with lines