#!/bin/bash


# add command line argument defaults
APP_USER=ec2-user
APP_GROUP=ec2-user
INSTALL_DIR=null

BASE_DIR=$(dirname $0)
USER_DATA_FILE=${BASE_DIR}/ami-user-data.sh

KX_DASH_VERSION=null
AMI_NAME=null

S3_BUCKET=null
S3_INSTALLS=null
S3_REPO=null
S3_KX_LIC=null

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

        --aws-ssh-key )
            AWS_SSH_KEY=$2
            shift
            ;;
        --aws-ami-id )
            AWS_AMI_ID=$2
            shift
            ;;
        --aws-security-group-id )
            AWS_SECURITY_GROUP_ID=$2
            shift
            ;;
        --aws-subnet-id )
            AWS_SUBNET_ID=$2
            shift
            ;;
        --aws-iam-role )
            AWS_IAM_ROLE=$2
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
        --s3-kx-licence )
            S3_KX_LIC=$2
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

# check if default cli file is needed
if [[ "$CLI_FILE" == "" ]]; then

    CLI_FILE=.tmp_ec2_cli.json
    cp ${BASE_DIR}/ami-ec2-cli.json $CLI_FILE

    echo "No CLI file inputted"
    echo "Using default with command line arguments"

    # get needed aws variables
    if [[ "$AWS_AMI_ID" == "" ]]; then
        echo "Must specify an AWS AMI Id to start the ec2 instance..."
        echo "e.g. ami-08a2aed6e0a6f9c7d (Amazon Linux 2)"
        read -p 'AWS AMI Id: ' AWS_AMI_ID
    fi

    if [[ "$AWS_SSH_KEY" == "" ]]; then
        echo "Must specify an AWS ssh key to reach the ec2 instance..."
        read -p 'AWS ssh key name: ' AWS_SSH_KEY
    fi

    if [[ "$AWS_SECURITY_GROUP_ID" == "" ]]; then
        echo "Must specify an AWS security group id which allows ssh traffic..."
        read -p 'AWS security group id: ' AWS_SECURITY_GROUP_ID
    fi

    if [[ "$AWS_SUBNET_ID" == "" ]]; then
        echo "Must specify an AWS subnet id to deploy the ec2 instance..."
        read -p 'AWS subnet id: ' AWS_SUBNET_ID
    fi

    if [[ "$AWS_IAM_ROLE" == "" ]]; then
        echo "Must specify an AWS IAM role for the instance..."
        echo "Needs s3 and ec2 permissions"
        read -p 'AWS IAM role: ' AWS_IAM_ROLE
    fi

    # overwrite aws variables into cli file
    sed -i "s/AWS_AMI_ID_PLACEHOLDER/$AWS_AMI_ID/" $CLI_FILE
    sed -i "s/AWS_SSH_KEY_PLACEHOLDER/$AWS_SSH_KEY/" $CLI_FILE
    sed -i "s/AWS_SECURITY_GROUP_ID_PLACEHOLDER/$AWS_SECURITY_GROUP_ID/" $CLI_FILE
    sed -i "s/AWS_SUBNET_ID_PLACEHOLDER/$AWS_SUBNET_ID/" $CLI_FILE
    sed -i "s/AWS_IAM_ROLE_PLACEHOLDER/$AWS_IAM_ROLE/" $CLI_FILE
fi

# build tags command snippet
APP_USER_TAG="{\"Key=APP_USER,Value=$APP_USER\"}"
APP_GROUP_TAG="{\"Key=APP_GROUP,Value=$APP_GROUP\"}"
INSTALL_DIR_TAG="{\"Key=INSTALL_DIR,Value=$INSTALL_DIR\"}"

TAGS="$APP_USER_TAG,$APP_GROUP_TAG,$INSTALL_DIR_TAG"

# check package download tag options
if [[ "$S3_INSTALLS" != "null" ]]; then

    if [[ "$S3_BUCKET" == "null" ]]; then
        echo "Must specify an S3 bucket if using S3 to download packages..."
        read -p 'S3 Bucket: ' S3_BUCKET
    fi

    TAGS="$TAGS,{\"Key=S3_INSTALLS,Value=$S3_INSTALLS\"}"

else
    echo "ERROR: must use --installs-path"
    echo "exiting"
    exit 1
fi

# check package download tag options
if [[ "$S3_KX_LIC" != "null" ]]; then

    if [[ "$S3_BUCKET" == "null" ]]; then
        echo "Must specify an S3 bucket if using S3 to download kx licence..."
        read -p 'S3 Bucket: ' S3_BUCKET
    fi

    TAGS="$TAGS,{\"Key=S3_KX_LIC,Value=$S3_KX_LIC\"}"

else
    echo "ERROR: must use --s3-kx-licence to specify a path to your licence"
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
if [[ -n ".tmp_ec2_cli.json" ]] ; then rm .tmp_ec2_cli.json ; fi
