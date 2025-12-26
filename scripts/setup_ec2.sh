#!/bin/bash

# UPDATE & INSTALL SYSTEM DEPENDENCIES
echo "Update system and install Python..."
sudo yum update -y
sudo yum install -y python3 python3-pip git

# SETUP DIRECTORY STRUCTURE
echo "Creating project directory..."
mkdir -p ~/badr-data-platform/src/producer
mkdir -p ~/badr-data-platform/logs

# SET ENVIRONMENT VARIABLES
#append these to .bashrc so they persist after you log out
echo "Setting environment variables..."
{
    echo "export BRONZE_BUCKET_NAME='badr-datalake-bronze-us-east-1'"
    echo "export AWS_DEFAULT_REGION='us-east-1'"
} >> ~/.bashrc
source ~/.bashrc

# INSTALL PYTHON LIBRARIES
echo "Installing Python dependencies..."
pip3 install boto3 faker

# AUTOMATE THE PRODUCER
#use Crontab to run the producer every 5 minutes.
echo "Scheduling Producer via Cron..."
SCRIPT_PATH="/home/ec2-user/badr-data-platform/src/producer/producer.py"
LOG_PATH="/home/ec2-user/badr-data-platform/logs/producer.log"

# Create a temporary cron file to avoid duplicates
crontab -l > mycron 2>/dev/null
echo "*/5 * * * * /usr/bin/python3 $SCRIPT_PATH >> $LOG_PATH 2>&1" >> mycron
crontab mycron
rm mycron

echo "EC2 Setup Complete. Producer scheduled to run every 5 minutes."