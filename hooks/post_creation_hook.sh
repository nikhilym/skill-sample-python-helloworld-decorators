#!/bin/bash

# Script Usage: sh post_creation_hook.sh <SKILL_NAME> <DO_DEBUG>

# Skill name is the preformatted name passed from the CLI, after removing
# special characters.

# Do_debug is boolean value for debug logging

# The script does the following:
#  - Create a '.venv' directory under <SKILL_NAME> folder
#  - Find if python3 is installed.
#    - If yes, try creating virtual environment using built-in venv
#           - If that fails, install virtualenv and create virtualenv
#    - If no, install virtualenv and create virtualenv
#  - If virtual environment is created, use container pip to install dependencies from lambda/py/requirements.txt
#  - Provide message on activation script location and additional dependencies


display_usage() {
    echo "This script must be provided the skill name."
    echo "\nAn additional doDebug boolean input can also be provided for debug."
    echo "\nThe script will create a .venv folder and a virtualenv container in the location where the script is called."
    echo "\nUsage:\npost_creation_hook MySkill \n"
}

create_using_virtualenv () {
    # Check for virtualenv installation or install
    if $1 -m pip install virtualenv; then
        echo "Using virtualenv library!!"
        # Try creating env
        if $1 -m virtualenv "$envLoc"; then
            return 0
        else
            echo "There was a problem creating virtualenv"
            return 1
        fi
    else
        echo "There was a problem installing virtualenv"
        return 1
    fi
}

create_env () {
    # Check for Python3 installation
    if command -v python3 &> /dev/null; then
        PYTHON=python3
        # Use Python3's venv script to create virtualenv.
        if $PYTHON -m venv "$envLoc"; then
            echo "Using Python3's venv script!!"
            return 0
        else
            # No venv script present (< Py 3.3). Install using virtualenv
            return create_using_virtualenv $PYTHON
        fi
    else
        # Python2 environment. Install using virtualenv
        PYTHON=python
        return create_using_virtualenv $PYTHON
    fi
    return 1
}

install_dependencies() {
    # Install dependencies at lambda/py/requirements.txt
    return $("$envLoc"/bin/python -m pip -q install -r "$skillDir"/lambda/py/requirements.txt)
}


# If less than two arguments are supplied, display usage
if [[ $# -lt 1 ]]
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
doDebug=false

if [[ $# -gt 1 ]]
then
    doDebug=$2
fi

skillDir="$skillName"
echo "Creating virtualenv for $skillName"
mkdir "$skillName"/.venv

# Add _env to skill name for env name
skillEnvName="${skillName}_env"

# Get relative location of the environment
envLoc="$skillName"/.venv/"$skillEnvName"

# Create container and install the dependencies
echo "###########################"
echo "Creating virtual environment container for $skillName"
if create_env; then
    echo "Created $skillEnvName virtualenv at $envLoc"
    echo "###########################"
    echo ""
    echo "Installing Dependencies"
    if install_dependencies; then
        echo "Dependencies installed!!"
        echo "###########################"
        echo ""
        echo "Activate the environment before installing any other dependencies"
        echo "On Linux/Mac run 'source $envLoc/bin/activate'"
        echo "On Windows, run '$envLoc\Scripts\Activate'"
        echo ""
        exit 0
    else
        echo "There was a problem installing dependencies"
        exit 1
    fi
else
    exit 1
fi
