#!/bin/bash -x


BASE_DIR=$(dirname $0)

bash ${BASE_DIR}/../aws/ami-builder.sh \
    --user-data-file ${BASE_DIR}/../aws/ami-userdata.sh \
    --aws-ssh-key aws-surface \
    --aws-ami-id ami-08a2aed6e0a6f9c7d \
    --aws-security-group-id sg-07076c90f3312f20d \
    --aws-subnet-id subnet-0fa8ffdae6edb4f14 \
    --aws-iam-role IAM-role.dev-kdb \
    --app-user jack \
    --app-group jack \
    --install-dir /home/jack/install_dir \
    --s3-bucket jack.stapleton.kdb.deployments \
    --s3-installs-path packages \
    --s3-kx-licence licences/kc.lic \
    --git-repo https://github.com/jackstapleton/aws-kx-dashboards.git \
    --kx-dash-version KxDashboards-1.1.2 \
    --ami-name KxDashboards-1.1.2
