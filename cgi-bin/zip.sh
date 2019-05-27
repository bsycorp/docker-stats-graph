#!/bin/bash
# generate graph and zip them, then return to user
set -x
mkdir -p output > /dev/null
for FILENAME in $(cd data; ls -1 *)
do
	gnuplot -e "filename=data/$FILENAME; set output output/$FILENAME.png" plot-config/cpu-usage.gnuplot > /dev/null
done
(cd output; zip ../output.zip *)

echo "Content-Type: application/octet-stream"
cat output.zip