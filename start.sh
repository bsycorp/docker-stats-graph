#!/bin/bash
while getopts "hi:e:" option; do
  case $option in
    h) echo "usage: $(basename $0) [-i include] [-e exclude] [-p port]"; exit ;;
    i) INCLUDE_FILTER=$OPTARG ;;
    e) EXCLUDE_FILTER=$OPTARG ;;
    p) SERVE_PORT=$OPTARG ;;
    ?) echo "error: option -$OPTARG is not implemented"; exit ;;
  esac
done

if [ -z "$INCLUDE_FILTER" ]; then
	INCLUDE_FILTER="."
fi

if [ -z "$EXCLUDE_FILTER" ]; then
	EXCLUDE_FILTER="POD"
fi

if [ -z "$SERVE_PORT" ]; then
	SERVE_PORT="10001"
fi

# apply filter, find docker container ids we want to monitor
if [ ! -S /var/run/docker.sock ]; then
	echo "Need to make docker socket available at: /var/run/docker.sock"
	exit 1
fi

CONTAINERS=$(curl --silent --unix-socket /var/run/docker.sock http://localhost/containers/json | jq -r ".[] | [.Names[0][1:],.Id] | @csv" | sed 's|"||g' | grep $INCLUDE_FILTER | grep -v $EXCLUDE_FILTER)
mkdir -p data

while read -r CONTAINER; do
	CONTAINER_NAME=$(echo "$CONTAINER" | cut -d',' -f 1)
	CONTAINER_ID=$(echo "$CONTAINER" | cut -d',' -f 2)
	echo "Monitoring $CONTAINER_NAME ($CONTAINER_ID)"
	{
		curl --silent --unix-socket /var/run/docker.sock http://localhost/containers/$CONTAINER_ID/stats \
			| jq --unbuffered -r "[.read, .cpu_stats.cpu_usage.total_usage, .cpu_stats.throttling_data.throttled_time, .memory_stats.usage, .memory_stats.limit] | @csv" \
			>> "data/$CONTAINER_NAME.data"
	} &
done <<< "$CONTAINERS"

{
	# start server to return recorded data
	mkdir -p /output
	echo "Listening on port $SERVE_PORT"
	socat tcp-l:$SERVE_PORT,reuseaddr,fork exec:/serve.sh
} &

# wait for background processes to complete and fail if they do, possible they will run forevs then an outside process will have to kill this process.
FAIL=0
for job in `jobs -p`
do
    wait $job || let "FAIL+=1"
done

if [ "$FAIL" != "0" ]; then
    exit $FAIL
fi
