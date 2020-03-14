#!/bin/bash -e

# Get tini process id
TINI_PID=$(ps -e | grep tini | awk '{print $1;}')

# Set default cron schedule (12 hours)
CRON_SCHEDULE=${CRON_SCHEDULE:-"0 */12 * * *"}

# Take the current envars and put them in a file so cron knows about them
printenv | sed 's/^\(.*\)$/export \1/g' > /root/app_env.sh

# Create the cron file and redirect output of script to tini (PID-1 in most cases)
echo "${CRON_SCHEDULE//\"} /usr/bin/script.sh > /proc/${TINI_PID}/fd/1 2>/proc/${TINI_PID}/fd/2" | crontab -

# Set cron to run in the foreground
exec crond -f -l 8