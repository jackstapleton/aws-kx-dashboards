#!/bin/bash


# add command line argument defaults
APP_USER=ec2-user
APP_GROUP=ec2-user
INSTALL_DIR=null

BASE_DIR=$(dirname $0)
CLI_FILE=${BASE_DIR}/ami-ec2-cli.json
USER_DATA_FILE=${BASE_DIR}/ami-user-data.sh

KX_DASH_VERSION=null
AMI_NAME=null

S3_BUCKET=null
S3_INSTALLS=null
S3_REPO=null

GIT_REPO=null


for arg in "$@"
do
    case $arg in

        --cli-json-file )
            CLI_FILE=$2
            shift
            ;;
        --user-data-file )
            USER_DATAFILE=$2
            shift
            ;;

        --app-user )
            APP_USER=$2
            shift
            ;;
        --app-group )
            APP_GROUP=$2
            shift
            ;;
        --install-dir )
            INSTALL_DIR=$2
            shift
            ;;

        --s3-bucket )
            S3_BUCKET=$2
            shift
            ;;
        --s3-installs-path )
            S3_INSTALLS=$2
            shift
            ;;
        --s3-repo-path )
            S3_REPO=$2
            shift
            ;;

        --git-repo )
            GIT_REPO=$2
            shift
            ;;

        --kx-dash-version )
            KX_DASH_VERSION=$2
            shift
            ;;
        --ami-name )
            $AMI_NAME=$2
            shift
            ;;
        *)
            shift

   esac
done

APP_USER_TAG="{\"Key=APP_USER,Value=$APP_USER\"}"
APP_GROUP_TAG="{\"Key=APP_GROUP,Value=$APP_GROUP\"}"
INSTALL_DIR_TAG="{\"Key=INSTALL_DIR,Value=$INSTALL_DIR\"}"

S3_BUCKET_TAG="{\"Key=S3_BUCKET,Value=$S3_BUCKET\"}"
S3_INSTALLS_TAG="{\"Key=S3_INSTALLS,Value=$S3_INSTALLS\"}"
S3_REPO_TAG="{\"Key=S3_REPO,Value=$S3_REPO\"}"

GIT_REPO_TAG="{\"Key=GIT_REPO,Value=$GIT_REPO\"}"

KX_DASH_VERSION_TAG="{\"Key=KX_DASH_VERSION,Value=$KX_DASH_VERSION\"}"
AMI_NAME_TAG="{\"Key=AMI_NAME,Value=$AMI_NAME\"}"

TAGS="$APP_USER_TAG,$APP_GROUP_TAG,$INSTALL_DIR_TAG,$S3_BUCKET_TAG,$S3_INSTALLS_TAG,$S3_REPO_TAG"
TAGS="$TAGS,$GIT_REPO_TAG,$KX_DASH_VERSION_TAG,$AMI_NAME_TAG"


eval "aws ec2 run-instances --cli-input-json file://$CLI_FILE --user-data file://$USER_DATAFILE --tag-specifications ResourceType=instance,Tags=[$TAGS]" > .tmp_ami_info.json


# look for ami

# terminate instance

# return ami
