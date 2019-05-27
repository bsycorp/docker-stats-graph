#!/bin/bash
INCLUDE_FILTER="."
EXCLUDE_FILTER="POD"
SERVE_PORT="10001"

# apply filter, find docker container ids we want to monitor
if [ ! -S /var/run/docker.sock ]; then
	echo "Need to make docker socket available at: /var/run/docker.sock"
	exit 1
fi

curl --silent --unix-socket /var/run/docker.sock http://localhost/containers/json | jq -r "[.[].Names[0][1:],.[].Id] | @csv"
CONTAINERS=$(curl --silent --unix-socket /var/run/docker.sock http://localhost/containers/json | jq -r "[.[].Names[0][1:],.[].Id] | @csv" | sed 's|"||g')
echo "Going to monitor $(echo $CONTAINERS | cut -d',' -f 2 | xargs)"
mkdir -p data

for CONTAINER in $(echo $CONTAINERS)
do
	{
		CONTAINER_NAME=$(echo $CONTAINER | cut -d',' -f 1)
		CONTAINER_ID=$(echo $CONTAINER | cut -d',' -f 2)
		echo "Monitoring $CONTAINER_ID - \"$CONTAINER_NAME\""
		curl --silent --unix-socket /var/run/docker.sock http://localhost/containers/$CONTAINER_ID/stats \
			| jq --unbuffered -r "[.read, .cpu_stats.cpu_usage.total_usage, .cpu_stats.throttling_data.throttled_time, .memory_stats.usage, .memory_stats.limit] | @csv" \
			>> "data/$CONTAINER_NAME.data"
	} &
done

# start server to return recorded data
{
 python -m CGIHTTPServer $SERVE_PORT
} &

# wait for background processes to complete and fail if they do, possible they will run forevs then an outside process will have to kill this process.
# FAIL=0
# for job in `jobs -p`
# do
#     wait $job || let "FAIL+=1"
# done

# if [ "$FAIL" != "0" ]; then
#     exit $FAIL
# fi
