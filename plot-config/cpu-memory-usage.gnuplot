set term png size 2000, 1000
set timefmt "%Y-%m-%dT%H:%M:%SZ"
set format x "%H:%M:%S"
set format y '%02.f%%'
set xdata time
set ylabel "Usage percentage"
set xlabel "Time"
set yrange [0:100]
set grid
set key left
set datafile separator ","
plot filename usi 1:2 title 'CPU usage' with lines, \
     filename usi 1:4 title 'Memory usage' with lines