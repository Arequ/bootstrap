#!/bin/bash

apt update -y
apt upgrade -y

apt install unzip

# I never use ARM instances, so please pardon.
aws_zip="awscli-exe-linux-x86_64.zip"
curl "https://awscli.amazonaws.com/${aws_zip}" -o "/tmp/${aws_zip}"
unzip /tmp/$aws_zip
/tmp/aws/install

git_deb="gitlab-runner_amd64.deb"
curl -LJ "https://gitlab-runner-downloads.s3.amazonaws.com/latest/deb/${git_deb}" -o "/tmp/${git_deb}"
dpkg -i /tmp/$git_deb