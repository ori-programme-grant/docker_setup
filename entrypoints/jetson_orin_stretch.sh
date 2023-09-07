#!/bin/bash
# This is to be used on Stretch

# User specific enviornment configuration
export ENV_WORKSTATION_NAME=jetson
export PROCMAN_DEPUTY=stretch_orin

# Assess if ament_ws can be sourced
ament_ws=$(echo ~/ament_ws/install/setup.bash)
if [ -f "$ament_ws" ]
then
    # Assess if procman is build
    procman_ros=$(echo ~/ament_ws/build/procman_ros)
    if [ -d "$procman_ros" ]; then
        source ~/.bashrc && source ~/ament_ws/install/setup.bash  
        echo "Warning: procman_ros is not build within the ament_ws. Therefore the deputy cannot be started!"
    else
        source ~/.bashrc && source ~/ament_ws/install/setup.bash  && ros2 run procman_ros deputy -i $PROCMAN_DEPUTY
    fi
else
    echo "Warning: ament_ws does not exist!"
fi
