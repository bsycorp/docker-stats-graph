#!/bin/bash
# generate graph and zip them, then return to user
set -e
for FILENAME in $(cd /data; ls -1 *)
do
	gnuplot -e "filename=\"/data/$FILENAME\"; set output \"/output/$FILENAME.png\"" plot-config/cpu-usage.gnuplot > /dev/null 2>&1
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