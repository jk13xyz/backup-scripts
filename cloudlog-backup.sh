#!/bin/bash

# Define paths
docker_volume="/var/lib/docker/volumes/cloudlog_cloudlog-backup/_data"
backup_dir="/home/jens/backup/cloudlog"

# Ensure backup directory exists
mkdir -p "$backup_dir"

# Copy the latest logbook file
latest_logbook=$(ls -t "$docker_volume"/logbook_* | head -n 1)
if [ -n "$latest_logbook" ]; then
    cp "$latest_logbook" "$backup_dir"
fi

# Copy the latest notes file
latest_notes=$(ls -t "$docker_volume"/notes_* | head -n 1)
if [ -n "$latest_notes" ]; then
    cp "$latest_notes" "$backup_dir"
fi

# Retain the 7 newest files and delete older files
cd "$backup_dir" || exit
ls -t | tail -n +8 | xargs rm -f