#!/bin/bash
./lbserver &
SERVER_PID=$!
sleep 2

for i in {1..10}; do
    ./lbclient &
done

wait

echo "Server started at: $(date)"
curl -s localhost:50051/stat | jq .
kill $SERVER_PID