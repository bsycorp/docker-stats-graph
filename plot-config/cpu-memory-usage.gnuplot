set term png size 2000, 1000
set timefmt "%Y-%m-%dT%H:%M:%SZ"
set format x "%H:%M:%S"
set xdata time
set xlabel "Time"
set ylabel "Scaled usage percentage"
set yrange [0:100]
set format y '%02.f%%'
set ytics nomirror
set y2label "Usage percentage ms"
set y2range [0:]
set format y2 '%02.f%%'
set y2tics
set grid
set key left
set datafile separator ","
plot filename usi 1:2 title 'Scaled CPU usage' with lines lt rgb "dark-green" lw 2, \
	 filename usi 1:3 title 'Normal CPU usage' with lines lt rgb "purple" lw 2 axis x1y2, \
     filename usi 1:4 title 'CPU throttling' with filledcurves below lt rgb "#ffc8c8" lw 0.5, \
     filename usi 1:5 title 'Memory usage' with lines lt rgb "orange" lw 2