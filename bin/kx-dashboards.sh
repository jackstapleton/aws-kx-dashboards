#!/bin/bash -x

echo "Starting Kx Dashboards as $USER"

source /opt/miniconda/etc/profile.d/conda.sh
conda activate kx-dashboards

# set up the log name
LOG=/opt/kx-dashboards/logs/kx-dashboards-server

# move into dash directory so dash.q can load other files
cd /opt/kx-dashboards/dash

# start dashboards as server
q dash.q -u 1 -p 10001 > $LOG.log 2> $LOG.err < /dev/null &

# save pid of process to file for systemd to monitor
echo $! > /opt/kx-dashboards/run/kx-dashboards.pid
