#!/bin/bash
set -e

number_clusters=$(awk -F '=' '/^number_k8s/ {gsub(/[[:space:]]/, "", $2); print $2}' 00-config.toml)

echo "Creating VM......"

for ((i=0; i<number_clusters; i++)); do
    suffix=$(printf "%02d" "$i")

    echo "Starting VM ${suffix}......"

    python3 create-vm.py "$suffix" &
    echo "Wait for 8 Secs"
    sleep 8
done

wait

echo "All VM have been created."

total=60
for ((elapsed=0; elapsed<=total; elapsed++)); do
    remaining=$((total - elapsed))
    percent=$((elapsed * 100 / total))
    filled=$((percent / 2))
    empty=$((50 - filled))
    bar=$(printf "%${filled}s" | tr ' ' '#')
    space=$(printf "%${empty}s")
    printf "\r[%s%s] %3d%% | %3d sec remaining" "$bar" "$space" "$percent" "$remaining"
    sleep 1
done

echo
echo "VM isready......"