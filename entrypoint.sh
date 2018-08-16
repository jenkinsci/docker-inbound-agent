#!/bin/bash

# fetch SSH keys from S3 bucket

mkdir -p .ssh
aws s3 sync ${S3_BUCKET_SSH_KEYS} .ssh/
chown -R 600 .ssh/

jenkins-slave
