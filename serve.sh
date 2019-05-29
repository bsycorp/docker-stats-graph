#!/bin/bash
# generate graph and zip them, then return to user
set -e
rm -f /data/*.csv
rm -f /output/*
rm -f /tmp/output.zip

for RAW_OUTPUT in $(cd /data; ls -1 *.data)
do
	CALCULATION_OUTPUT="$RAW_OUTPUT-calculated.csv"
	cat /data/$RAW_OUTPUT | sed 's|"||g' | awk -F',' '
	  previousLine!="" {
		  curr=$0;
		  $0=previousLine;
		  previousCpu=$2;
		  previousSystem=$3;
		  previousThrottled=$5;
		  $0=curr;
		  cpuDelta=$2-previousCpu;
		  systemDelta=$3-previousSystem;
		  numCpus=$4;
		  throttledDelta=$5-previousThrottled;
		  scaledCpuPercent=(cpuDelta/systemDelta)*100;
		  cpuPercent=scaledCpuPercent*numCpus;
		  memoryPercent=($6/$7)*100;
		  printf("%s,%2.2f,%i,%2.2f,%i,%i\n", $1, scaledCpuPercent, cpuPercent, throttledDelta, memoryPercent, $6, $7);
		  
		  previousLine = $0
	  }
	  previousLine=="" {
	  	previousLine=$0;
	  	next
	  }
	' > /data/$CALCULATION_OUTPUT
	GRAPH_TITLE=$(basename -s .data $RAW_OUTPUT | sed 's|_|-|g')
	gnuplot -e "filename=\"/data/$CALCULATION_OUTPUT\"; set output \"/output/$RAW_OUTPUT.png\"; set title \"$GRAPH_TITLE\"" plot-config/cpu-memory-usage.gnuplot > /dev/null 2>&1
done
(cd output; zip /tmp/output.zip * /data/* > /dev/null 2>&1)

ZIP_OUTPUT="/tmp/output.zip"
echo "HTTP/1.1 200 OK"
echo "Content-type: application/octet-stream"
echo "Content-Length: $(wc -c < $ZIP_OUTPUT)"
echo "Content-Transfer-Encoding: binary"
echo "Content-Disposition: attachment; ZIP_OUTPUT=graphs.zip"
echo ""
cat $ZIP_OUTPUT
