#!/bin/bash
while getopts "hi:e:d:" option; do
  case $option in
    h) echo "usage: $(basename $0) [-i include] [-e exclude] [-p port] [-d docker host]"; exit ;;
    i) RECORD_INCLUDE_FILTER=$OPTARG ;;
    e) RECORD_EXCLUDE_FILTER=$OPTARG ;;
    p) RECORD_SERVE_PORT=$OPTARG ;;
	d) RECORD_DOCKER_HOST_TRANSPORT=$OPTARG ;;
    ?) echo "error: option -$OPTARG is not implemented"; exit ;;
  esac
done

if [ -z "$RECORD_INCLUDE_FILTER" ]; then
	RECORD_INCLUDE_FILTER="."
fi

if [ -z "$RECORD_EXCLUDE_FILTER" ]; then
	RECORD_EXCLUDE_FILTER="POD"
fi

if [ -z "$RECORD_SERVE_PORT" ]; then
	RECORD_SERVE_PORT="10001"
fi

if [ -z "$RECORD_DOCKER_HOST_TRANSPORT" ]; then
	RECORD_DOCKER_HOST_TRANSPORT="socket"
fi

if [ "$RECORD_DOCKER_HOST_TRANSPORT" == "socket" ]; then
	# apply filter, find docker container ids we want to monitor
	if [ ! -S /var/run/docker.sock ]; then
		echo "Need to make docker socket available at: /var/run/docker.sock"
		exit 1
	fi
	CURL_CMD="curl --silent --unix-socket /var/run/docker.sock http://localhost"

elif [ "$RECORD_DOCKER_HOST_TRANSPORT" == "tcp" ]; then
	CURL_CMD="curl --silent http://localhost:2375"
	
else
	echo "Unsupported docker host transport, only support socket or tcp"
	exit 1
fi

CONTAINERS=$($CURL_CMD/containers/json | jq -r ".[] | [.Names[0][1:],.Id] | @csv" | sed 's|"||g' | grep $RECORD_INCLUDE_FILTER | grep -v $RECORD_EXCLUDE_FILTER)
mkdir -p data

while read -r CONTAINER; do
	CONTAINER_NAME=$(echo "$CONTAINER" | cut -d',' -f 1)
	CONTAINER_ID=$(echo "$CONTAINER" | cut -d',' -f 2)
	echo "Monitoring $CONTAINER_NAME ($CONTAINER_ID)"
	{
		$CURL_CMD/containers/$CONTAINER_ID/stats | \
		jq --unbuffered -r "[.read, .cpu_stats.cpu_usage.total_usage, .cpu_stats.system_cpu_usage, (.cpu_stats.cpu_usage.percpu_usage | length), .cpu_stats.throttling_data.throttled_time, .memory_stats.usage, .memory_stats.limit] | @csv" \
		>> "data/$CONTAINER_NAME.data"
	} &
done <<< "$CONTAINERS"

{
	# start server to return recorded data
	mkdir -p output
	echo "Listening on port $RECORD_SERVE_PORT"
	socat tcp-l:$RECORD_SERVE_PORT,reuseaddr,fork exec:/serve.sh
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
