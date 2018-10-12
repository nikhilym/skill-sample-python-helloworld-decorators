#!/bin/bash

# Script Usage: sh post_creation_venv_hook.sh <SKILL_NAME> <TARGET> <DO_DEBUG>

# Skill name is the preformatted name passed from the CLI, after removing
# special characters.

# Target is the deployment target provided to the CLI. (eg: ALL (Default), LAMBDA etc.)

# Do_debug is boolean value for debug logging

# Run this script from the hooks folder under skill root folder

# The script does the following:
#  - Create a temporary 'lambda_upload' directory under <SKILL_NAME>/lambda folder
#  - Copy the contents of <SKILL_NAME>/lambda/py/ folder into 'lambda_upload'
#  - Copy the contents of site packages in $VIRTUALENV created in <SKILL_NAME>/.venv/ folder
#  - Update the location of this 'lambda_upload' folder to skill.json for zip and upload

display_usage() {
    echo "This script must be provided the skill name and target."
    echo "\nAn additional doDebug boolean input can also be provided for debug."
    echo "\nUsage:\npre_deploy_hook MySkill LAMBDA \n"
}

create_or_update_upload_dir() {
    if [[ -e $uploadDir ]]
    then
        # Folder exists. Cleaning the files under the folder
        rm -rf $uploadDir/
    else
        echo "Creating 'lambda_upload' folder, for gathering dependencies"
        # Step 1: Create lambda_upload folder
        mkdir lambda/lambda_upload
        echo "'lambda_upload' folder created at $skillName/lambda/"
        echo ""
    fi
    return 0
}

# If less than two arguments are supplied, display usage
if [[ $# -lt 2 ]]
then
    display_usage
    exit 1
fi

# Display help if user supplied -h or --help
if [[ $# == "--help" || $# == "-h" ]]
then
    display_usage
    exit 0
fi

#Assign temporary variables
skillName=$1
skillEnvName="${skillName}_env"
target=$2
doDebug=false
uploadDir="lambda/lambda_upload"

if [[ $# -gt 2 ]]
then
    doDebug=$3
fi

if [[ $target != "ALL" && $target != "LAMBDA" ]]
then
    exit 0
fi


echo "###########################"
echo "Checking for lambda/lambda_upload folder existence"
create_or_update_upload_dir

# Step 2: Copy lambda/py contents to upload directory
echo "Copying contents of $skillName/lambda/py folder to $skillName/$uploadDir"
cp -r ./lambda/py/ ./$uploadDir/

# Step 3: Find virtual environment site packages, copy contents to lambda_upload
echo "Copying dependencies installed in $skillEnvName to $skillName/$uploadDir"
SITE=$(.venv/$skillEnvName/bin/python -c 'from distutils.sysconfig import get_python_lib; print(get_python_lib())')
cp -r "$SITE"/ ./$uploadDir/
echo ""

# Step 4: Update the "manifest.apis.custom.endpoint.sourceDir" value in skill.json

# NOTE:
# Couldn't find any cli option to update this value directly, doing this by checking for the
# existence of the key and updating it. Maybe a better way is to execute some cli command that updates
# the sourceDir (do the endpoint:uri check and update sourceDir accordingly)
echo "Updating sourceDir location in skill.json"
if $(grep -q "sourceDir" skill.json); then
    sourceDir=$(grep "sourceDir" skill.json)
    IFS=':' read -ra KV <<< "$sourceDir"
    currentSourceDir=${KV[1]}
    newSourceDir=' "'
    newSourceDir+=${uploadDir}
    newSourceDir+='"'

    sed -i '' "s:$currentSourceDir:$newSourceDir:" skill.json
    echo "Updated sourceDir location to $uploadDir"
    echo "###########################"
    exit 0
else
    exit 1
fi
