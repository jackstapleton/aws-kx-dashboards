#!/bin/bash -x

# install yum packages
sudo yum update -y

# configure aws cli for root
mkdir -p /root/.aws
AZ=$(ec2-metadata -z | cut -d ' ' -f 2)
echo -e "[default]\nregion=${AZ::-1}\noutput=json" >> /root/.aws/config

# get instance id for aws cli calls
export INSTANCEID=$(ec2-metadata -i | cut -d ' ' -f 2)

# retrieve tags
ec2_get_instance_tag () {
    instance_id=$1
    tag=$2
    until [[ -s $HOME/.ec2-tagdata ]]; do
        aws ec2 describe-tags --filter "Name=resource-id,Values=$instance_id" > $HOME/.ec2-tagdata
    done
    cat $HOME/.ec2-tagdata | python -c "import sys, json; print(''.join([x['Value'] for x in json.load(sys.stdin)['Tags'] if x ['Key'] == '$tag']))"
}

export APP_USER=$(ec2_get_instance_tag $INSTANCEID APP_USER)
export APP_GROUP=$(ec2_get_instance_tag $INSTANCEID APP_GROUP)

export INSTALL_DIR=$(ec2_get_instance_tag $INSTANCEID INSTALL_DIR)

export S3_BUCKET=$(ec2_get_instance_tag $INSTANCEID S3_BUCKET)
export S3_INSTALLS=$(ec2_get_instance_tag $INSTANCEID S3_INSTALLS)
export S3_REPO=$(ec2_get_instance_tag $INSTANCEID S3_REPO)
export S3_KX_LIC=$(ec2_get_instance_tag $INSTANCEID S3_KX_LIC)

export GIT_REPO=$(ec2_get_instance_tag $INSTANCEID GIT_REPO)

export KX_DASH_VERSION=$(ec2_get_instance_tag $INSTANCEID KX_DASH_VERSION)
export AMI_NAME$(ec2_get_instance_tag $INSTANCEID AMI_NAME)

# set up user if it does not exist
export APP_USERHOME=/home/${APP_USER}

if id "$APP_USER" &>/dev/null; then

    echo "$APP_USER exists"

else

    echo "Creating $APP_USER"
    groupadd $APP_GROUP
    useradd $APP_USER --shell /bin/bash --home-dir $APP_USERHOME --create-home --gid $APP_GROUP

fi

mkdir -p $INSTALL_DIR
chown -R $APP_USER:$APP_GROUP $INSTALL_DIR

export PACKAGES_DIR=${INSTALL_DIR}/packages
export REPO_DIR=${INSTALL_DIR}/aws-kx-dashboards

# configure aws cli for user
mkdir -p ${APP_USERHOME}/.aws
AZ=$(ec2-metadata -z | cut -d ' ' -f 2)
echo -e "[default]\nregion=${AZ::-1}\noutput=json" >> ${APP_USERHOME}/.aws/config
chown -R $APP_USER:$APP_USER ${APP_USERHOME}/.aws

# download kx-dashboards package
if [[ "$S3_INSTALLS" != "" ]]; then
    sudo -i -u $APP_USER aws s3 sync s3://${S3_BUCKET}/${S3_INSTALLS} ${PACKAGES_DIR}
fi

# download aws-kx-dashboards install code
if [[ "$S3_REPO" != "" ]]; then
    sudo -i -u $APP_USER aws s3 sync s3://${S3_BUCKET}/${S3_REPO} ${REPO_DIR}
fi

if [[ "$GIT_REPO" != "" ]];then
    yum install git -y
    sudo -i -u $APP_USER git clone $GIT_REPO $REPO_DIR
fi

# install miniconda
sudo -i -u $APP_USER wget https://repo.continuum.io/miniconda/Miniconda2-latest-Linux-x86_64.sh -O $APP_USERHOME/conda.sh
export MINICONDA_HOME=/opt/miniconda
mkdir -p $MINICONDA_HOME
chmod 755 $MINICONDA_HOME
chown $APP_USER:$APP_GROUP $MINICONDA_HOME
sudo -i -u $APP_USER bash $APP_USERHOME/conda.sh -b -u -p $MINICONDA_HOME

echo "" >> ${APP_USERHOME}/.bash_profile
echo "source ${MINICONDA_HOME}/etc/profile.d/conda.sh" >> ${APP_USERHOME}/.bash_profile
echo "conda activate" >> ${APP_USERHOME}/.bash_profile

sudo -i -u $APP_USER conda env create --file=${INSTALL_DIR}/aws-kx-dashboards/conda/kx-dashboards.yaml
echo "conda activate kx-dashboards" >> ${APP_USERHOME}/.bash_profile

# download kx licence and place in q home
if [[ "$S3_KX_LIC" != "" ]]; then
    sudo -i -u $APP_USER aws s3 sync s3://${S3_BUCKET}/${S3_KX_LIC} ${MINICONDA_HOME}/envs/kx-dashboards/q/
fi

# unpack and set up dashboards
export KX_DASH_HOME=/opt/kx-dashboards
mkdir -p $KX_DASH_HOME
unzip ${PACKAGES_DIR}/${KX_DASH_VERSION}.zip -d $KX_DASH_HOME
mkdir -p $KX_DASH_HOME/logs
cp -r $REPO_DIR/bin $KX_DASH_HOME/
chmod -R 755 $KX_DASH_HOME
chown -R $APP_USER:$APP_GROUP $KX_DASH_HOME

# set up kx-dashboards systemd service
cp $REPO_DIR/config/kx-dashboards.service /etc/systemd/system/
sed -i "s/APP_USER_PLACEHOLDER/$APP_USER/" kx-dashboards.service
sed -i "s/APP_GROUP_PLACEHOLDER/$APP_GROUP/" kx-dashboards.service
systemctl enable kx-dashboards

# install nginx
sudo amazon-linux-extras install nginx1 -y
NGINX_HOME=/etc/nginx
mv ${NGINX_HOME}/nginx.conf ${NGINX_HOME}/backup-nginx.conf
cp ${REPO_DIR}/config/nginx.conf ${NGINX_HOME}/nginx.conf
systemctl enable nginx

# create the ami
AMI_DATE=$(date +%Y%m%dD%H%M%S)
AMI_NAME=${AZ::-1}-ec2.ami-$AMI_NAME-$AMI_DATE
aws ec2 create-image --instance-id $INSTANCEID --name $AMI_NAME
