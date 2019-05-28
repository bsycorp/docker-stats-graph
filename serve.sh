#!/bin/bash
# generate graph and zip them, then return to user
set -e
rm -f /data/*.csv
for FILENAME in $(cd /data; ls -1 *.data)
do
	FIXED_FILENAME="$FILENAME_calculated.csv"
	cat /data/$FILENAME | sed 's|"||g' | awk -F',' '
	  previousLine!="" {
		  curr=$0;
		  $0=previousLine;
		  previousCpu=$2;
		  previousSystem=$3;
		  previousThrottled=$5;
		  $0=curr;
		  cpuDelta=$2-previousCpu;
		  systemDelta=$3-previousSystem;
		  throttledDelta=$5-previousThrottled;
		  cpuPercent=(cpuDelta/systemDelta)*100;
		  memoryPercent=($6/$7)*100;
		  printf("%s,%2.2f,%i,%2.2f,%i,%i\n", $1, cpuPercent, throttledDelta, memoryPercent, $6, $7);
		  
		  previousLine = $0
	  }
	  previousLine=="" {
	  	previousLine=$0;
	  	next
	  }
	' > /data/$FIXED_FILENAME
	gnuplot -e "filename=\"/data/$FIXED_FILENAME\"; set output \"/output/$FILENAME.png\"" plot-config/cpu-usage.gnuplot > /dev/null 2>&1
done
(cd output; zip /tmp/output.zip * > /dev/null 2>&1)

filename="/tmp/output.zip"
echo "HTTP/1.1 200 OK"
echo "Content-type: application/octet-stream"
echo "Content-Length: $(wc -c < $filename)"
echo "Content-Transfer-Encoding: binary"
echo "Content-Disposition: attachment; filename=graphs.zip"
echo ""
cat $filename