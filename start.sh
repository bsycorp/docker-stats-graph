#!/bin/bash
while getopts "ui:e:s:d:h:c:p:" option; do
  case $option in
    u) echo "usage: $(basename $0) [-i include] [-e exclude] [-s result port] [-d docker transport] [-h docker host] [-c docker socket path] [-p docker port]"; exit ;;
    i) STATS_INCLUDE_FILTER=$OPTARG ;;
    e) STATS_EXCLUDE_FILTER=$OPTARG ;;
    s) STATS_SERVE_PORT=$OPTARG ;;
    d) STATS_DOCKER_HOST_TRANSPORT=$OPTARG ;;
    h) STATS_DOCKER_HOST=$OPTARG ;;
    c) STATS_DOCKER_SOCKET=$OPTARG ;;
    p) STATS_DOCKER_PORT=$OPTARG ;;
    ?) echo "error: option -$OPTARG is not implemented"; exit ;;
  esac
done

if [ -z "$STATS_INCLUDE_FILTER" ]; then
	STATS_INCLUDE_FILTER="."
fi

if [ -z "$STATS_EXCLUDE_FILTER" ]; then
	STATS_EXCLUDE_FILTER="POD"
fi

if [ -z "$STATS_SERVE_PORT" ]; then
	STATS_SERVE_PORT="10180"
fi

if [ -z "$STATS_SERVE_INTERFACE" ]; then
	STATS_SERVE_INTERFACE="0.0.0.0"
fi

if [ -z "$STATS_DOCKER_HOST" ]; then
	STATS_DOCKER_HOST="localhost"
fi

if [ -z "$STATS_DOCKER_PORT" ]; then
	STATS_DOCKER_PORT="2375"
fi

if [ -z "$STATS_DOCKER_SOCKET" ]; then
	STATS_DOCKER_SOCKET="/var/run/docker.sock"
fi

if [ -z "$STATS_DOCKER_HOST_TRANSPORT" ]; then
	STATS_DOCKER_HOST_TRANSPORT="socket"
fi

if [ "$STATS_DOCKER_HOST_TRANSPORT" == "socket" ]; then
	# apply filter, find docker container ids we want to monitor
	if [ ! -S $STATS_DOCKER_SOCKET ]; then
		echo "Need to make docker socket available at: $STATS_DOCKER_SOCKET"
		exit 1
	fi
	CURL_CMD="curl --silent --unix-socket $STATS_DOCKER_SOCKET http://$STATS_DOCKER_HOST"

elif [ "$STATS_DOCKER_HOST_TRANSPORT" == "tcp" ]; then
	CURL_CMD="curl --silent http://$STATS_DOCKER_HOST:$STATS_DOCKER_PORT"	
else
	echo "Unsupported docker host transport, only support socket or tcp"
	exit 1
fi

# try to find containers upto 10 times if we don't find any
for i in {1..10}; do
	echo "Finding containers with filter: $STATS_INCLUDE_FILTER and excluding $STATS_EXCLUDE_FILTER"
	CONTAINERS=$($CURL_CMD/containers/json | jq -r ".[] | [.Names[0][1:],.Id] | @csv" | sed 's|"||g' | grep $STATS_INCLUDE_FILTER | grep -v $STATS_EXCLUDE_FILTER)
	if [ -z "$CONTAINERS" ]; then
		sleep 2
	else
		break
	fi
done

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
	echo "Listening on port $STATS_SERVE_PORT"
	socat tcp-l:$STATS_SERVE_PORT,reuseaddr,fork,bind=$STATS_SERVE_INTERFACE exec:/serve.sh
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
