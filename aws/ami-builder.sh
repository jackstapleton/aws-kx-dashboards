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
            AMI_NAME=$2
            shift
            ;;
        *)
            shift

   esac
done

# build tags command snippet
APP_USER_TAG="{\"Key=APP_USER,Value=$APP_USER\"}"
APP_GROUP_TAG="{\"Key=APP_GROUP,Value=$APP_GROUP\"}"
INSTALL_DIR_TAG="{\"Key=INSTALL_DIR,Value=$INSTALL_DIR\"}"

TAGS="$APP_USER_TAG,$APP_GROUP_TAG,$INSTALL_DIR_TAG"

# check package download tag options
if [[ "$S3_INSTALLS" != "null" ]]; then

    if [[ "$S3_BUCKET" == "null" ]]; then
        echo "Must specify a an S3 bucket if using S3 to download packages..."
        read -p 'S3 Bucket: ' S3_BUCKET
    fi

    TAGS="$TAGS,{\"Key=S3_INSTALLS,Value=$S3_INSTALLS\"}"

else
    echo "ERROR: must use --installs-path"
    echo "exiting"
    exit 1
fi

# check repo download tag options
if [[ "$S3_REPO" != "null" ]]; then

    if [[ "$S3_BUCKET" == "null" ]]; then
        echo "Must specify a an S3 bucket if using S3 to download the repo..."
        read -p 'S3 Bucket: ' S3_BUCKET
    fi

    TAGS="$TAGS,{\"Key=S3_REPO,Value=$S3_REPO\"}"

elif [[ "$GIT_REPO" != "null" ]]; then

    TAGS="$TAGS,{\"Key=GIT_REPO,Value=$GIT_REPO\"}"

else
    echo "ERROR: must use one of --s3-repo-path, --git-repo"
    echo "exiting"
    exit 1
fi

# add s3 bucket tag if needed
if [[ "$S3_BUCKET" != "null" ]]; then
    TAGS="$TAGS,{\"Key=S3_BUCKET,Value=$S3_BUCKET\"}"
fi

# add kx version and ami name tag
if [[ "$KX_DASH_VERSION" == "null" ]]; then
    echo "Must specify a version name for Kx Dashboards e.g. KxDashboards-1.0.0 ..."
    echo "Should match zip file name, e.g. KxDashboards-1.0.0"
    read -p 'Kx Dashboards Version: ' KX_DASH_VERSION_TAG
fi

if [[ "$AMI_NAME" == "null" ]]; then
    AMI_NAME=$(echo $KX_DASH_VERSION)
fi

TAGS="$TAGS,{\"Key=KX_DASH_VERSION,Value=$KX_DASH_VERSION\"},{\"Key=AMI_NAME,Value=$AMI_NAME\"}"

# create instance which will create the ami from
eval "aws ec2 run-instances --cli-input-json file://$CLI_FILE --user-data file://$USER_DATAFILE --tag-specifications ResourceType=instance,Tags=["$TAGS"]" > .tmp_ami_info.json

# look for ami
# terminate instance
# return ami

rm .tmp_ami_info.json
