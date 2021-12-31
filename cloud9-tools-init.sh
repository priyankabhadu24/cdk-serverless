#!/bin/bash
# set -euxo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

function _logger() {
    echo -e "$(date) ${YELLOW}[*] $@ ${NC}"
}

## -----------------------------------------------
cwd=$(pwd)
_logger "-------------------------------------------------------------------------"
_logger "Preparing your environment ..."

date
# echo "LANG=en_US.utf-8" >> /etc/environment
# echo "LC_ALL=en_US.UTF-8" >> /etc/environment
sudo bash -c "echo LANG=en_US.utf-8 >> /etc/environment"
sudo bash -c "echo LC_ALL=en_US.UTF-8 >> /etc/environment"

echo '=== INSTALL and CONFIGURE default software components ==='

sudo yum -y update 
sudo yum -y remove aws-cli

_logger "Python3.8 >> Lambda runtime compatible !!!"
# sudo yum install -y amazon-linux-extras
# amazon-linux-extras | grep -i python
sudo amazon-linux-extras enable python3.8
sudo yum install -y python3.8

## [Note - yum issue] Nake 2.7 as default python
# sudo ln -sf /usr/bin/python2.7 /usr/bin/python

# sudo rm /usr/bin/python
# sudo ln -s /usr/bin/python3.8 /usr/bin/python
# virtualenv dh-env --python=/usr/bin/python3.8 --always-copysource dh-env/bin/activate
# sudo update-alternatives --install /usr/bin/python python /usr/bin/python2.7 1
# sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.8 1
# sudo update-alternatives --list | grep python
# alternatives --set python /usr/bin/python3.8
# sudo -H -u ec2-user bash -c "pip install --user -U boto boto3 botocore awscli aws-sam-cli"
sudo -H -u ec2-user bash -c "pip install --user -U boto boto3 botocore aws-sam-cli"

echo "Installing the AWS CLI version 2 ..."
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
rm -rf awscliv2.zip aws

## Check for AWS Region --------------------------
export AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/\(.*\)[a-z]/\1/')
if [ -z "$AWS_REGION" ]
then
    ## metadata might err, this is a safeguard
    exit 0
fi

## Export Default Env Variables ------------------
echo "export AWS_REGION=${AWS_REGION}" >> ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region

export NVM_VER=$(curl --silent "https://github.com/nvm-sh/nvm/releases/latest" | sed 's#.*tag/\(.*\)\".*#\1#') #v0.39.1
export CDK_VER=$(curl --silent "https://github.com/DevAx101/cdk/releases/latest" | sed 's#.*tag/\(.*\)\".*#\1#') #v.1.0.1
export PACKER_VER=1.7.8

## Clone CDK and install dependencies ------------
echo "Cloning CDK Repo ..."
cd ~/environment
# git clone --depth 1 --branch $CDK_VER https://github.com/DevAx101/cdk.git >/dev/null 2>&1
git clone https://github.com/DevAx101/cdk.git >/dev/null 2>&1
cd $cwd
echo "Installing dependencies ..."
sudo yum -y remove aws-cli
sudo yum install golang jq gettext bash-completion -y -q -e 0 >/dev/null 2>&1
echo "Enabling utilities scripts ..."
chmod +x cloud9-ebs-resize.sh
# _logger "Resizing AWS Cloud9 Volume >> 250GB ..."
# ./cloud9-ebs-resize.sh 250

_logger "NVM & Node.js 14.x >> Lambda runtime compatible !!!"
echo "Installing nvm ..."
rm -rf ~/.nvm
export NVM_DIR=
curl --silent -o- "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VER/install.sh" | bash
source ~/.nvm/nvm.sh 
# nvm install --lts 
# nvm alias default stable
nvm install lts/fermium
nvm alias default lts/fermium

## npm packages ----------------------------------
echo "Installing framework and libs ..."
# npm install -g serverless pnpm hygen yarn docusaurus >/dev/null 2>&1
npm install -g serverless pnpm yarn cdk @aws-amplify/cli >/dev/null 2>&1

## packer ----------------------------------------
echo "Installing packer ..."
wget -q "https://releases.hashicorp.com/packer/$PACKER_VER/packer_${PACKER_VER}_linux_amd64.zip" -O packer_${PACKER_VER}_linux_amd64.zip
unzip "packer_${PACKER_VER}_linux_amd64.zip" >/dev/null 2>&1
sudo mv packer /usr/local/bin/ >/dev/null 2>&1
rm -f "packer_${PACKER_VER}_linux_amd64.zip" >/dev/null 2>&1

#F Finishing up ----------------------------------
echo "Finishing up ..."
echo -e "alias cdk-ami-list='aws ec2 describe-images --owners self --query \"reverse(sort_by(Images[*].{Id:ImageId,Name:Name, Created:CreationDate}, &Created))\" --filters \"Name=name,Values=${STAGE_NAME}*\" --output table'" >> ~/.bashrc 
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 
source ~/.bashrc 

echo '=== PREPARE REBOOT in 1 minute with at ==='
FILE=$(mktemp) && echo $FILE && echo '#!/bin/bash' > $FILE && echo 'reboot -f --verbose' >> $FILE && at now + 1 minute -f $FILE
echo "Bootstrap completed with return code $?"

# sudo bash -c "echo alias python=/usr/bin/python3.8 >> ~/.bashrc"
echo alias python=/usr/bin/python3.8 >> ~/.bashrc
# echo "alias python='/usr/bin/python3.8'" >> ~/.bashrc
. ~/.bashrc

## Because yum does not support Python3
# echo "Replace python by python2.7 in /usr/bin/yum !!!"
# sudo sed -i 's/python/python2.7/' /usr/bin/yum

_logger "[+] Verify Prerequisites ..."
echo "[x] Verify Git client":        $(git --version)
echo "[x] Verify jq":                $(jq   --version)
echo "[x] Verify AWS CLI version 2": $(aws --version)
echo "[x] Verify AWS SAM":           $(sam --version)
echo "[x] Verify Node.js":           $(node --version)
echo "[x] Verify CDK":               $(cdk --version)
echo "[x] Verify Python":            $(python -V)
echo "[x] Verify Python3":           $(python3 -V)
echo "[x] Verify Pip3":              $(pip3 -V)
# echo "[x] Verify Terraform":         $(terraform -v)
# echo "[x] Verify kubectl":           $(kubectl version --client)
# echo "[x] Verify eksctl":            $(eksctl version)
# echo "[x] Verify helm3":             $(helm version --short)
# echo "[x] Verify k9s":               $(k9s version --short)
# echo "[x] Verify Java":              $(java --version)
# echo "[x] Verify Maven":             $(mvn --version)

echo ""
echo "Your AWS Cloud9 Environment is ready to use. "
echo "-------------------------------------------------------------------------"