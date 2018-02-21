## Synopsis

ami-builder is a python based utility that launches an AWS EC2 instance using a config file as input. You may customize the instance as you see fit and then it will be saved as an AMI for future use. You may supply AWS credentials as arguments, run from a machine where your AWS environment is set up, or use in instance with a profile.

Config files are stored in ./configs 
Command files are stored in ./command_files. They will be run in order listed in the yaml file.

usage: ami-builder.py [-h] [--region REGION]
                           [--aws_access_key AWS_ACCESS_KEY]
                           [--aws_secret_key AWS_SECRET_KEY] [--config CONFIG]
                           [--key KEY] [--update-only] [--deregister]

optional arguments:
  -h, --help            show this help message and exit
  --region REGION       AWS region to build your AMI
  --aws_access_key AWS_ACCESS_KEY
                        AWS Access Key
  --aws_secret_key AWS_SECRET_KEY
                        AWS Secret Key
  --config CONFIG       Full path to config file
  --key KEY             Full path to build SSH private key
  --update-only         Just run a yum update
  --deregister          De-register source AMI

## Config files

Config files are YAML must contain the following:

MAIN SECTION:

config_name: The name of the YAML config file

source_ami: This AMI must be available in the region you are building your instance. At this time, only RedHat/CentOS based AMIS are supported.

instance_type: The flavor of instance desired for the build. Once again, must be available in your chosen region.

security_group: Security group to apply to your instance. The AMI builder machine MUST have access on port 22.

subnet: Subnet for your instance. Should be one where your instance has access to any yum repos you set up at a minimum.

name: A name for your instance. This is applied to the value of the tage "Name" and is usually displayed as the first custom in the AWS EC2 UI.

rootuser: The sudo enabled user on the source ami.

ami_name: Brief name for AMI

ami_description: Less brief description of what AMI contians

Disks:

This section will read in up to eight disk devices to attach to your instance. If EBS volumes, you should add a value for each for size in GB. If ephemeral, use the ephemeral identifier, like "ephemeral0", to associate that with the device. Make sure you are using the correct instance type if using ephemeral drives. Not all instances have them and this utility does not check that.

Example:

Disks:
    sda: 100
    sdb: 100
    sdc: ephemeral0

Packages:

List all the packages you wish to install here.

PackageGroups:

List all the package groups you wish to install here.

Repos:

List yum repos by name and include the baseurl. Example:

Repos:
    sigma-centos-7:
        baseurl:         http://sigma-yum.s3.amazonaws.com/sigma-centos-7

CommandFiles:

A list of files with commands to run on the host from a bash shell. These files will be run in order presented. Put the files in ./command_files

## Execution

./ami-builder-03132017-yaml.py --region us-east-1 --config ./configs/genesis-ami.yaml --key ./keys/ami-builder.pem

This will use the config file "genesis-ami.yaml" to build your AMI.

## Installation

Copy the whole ami-builder directory over to a machine with boto and python2 installed. 
