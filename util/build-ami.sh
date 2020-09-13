#!/bin/bash -x


BASE_DIR=$(dirname $0)

bash -x ${BASE_DIR}/../aws/ami-builder.sh \
    --cli-json-file ${BASE_DIR}/../aws/ami-ec2-cli.json \
    --user-data-file ${BASE_DIR}/../aws/ami-userdata.sh \
    --app-user jack \
    --app-group jack \
    --install-dir /home/jack/install_dir \
    -s3 \
    --s3-bucket jack.stapleton.kdb.deployments \
    --s3-installs-path packages \
    --s3-repo-path aws-kx-dashboards \
    --kx-dash-version KxDashboards-1.1.2 \
    --ami-name KxDashboards-1.1.2
