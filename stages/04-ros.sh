#!/bin/bash
# Installing ROS noetic
# author: Matias Mattamala
set -e
echo "Installing OpeROS..."
echo "  WITH_CUDA:       $WITH_CUDA"
echo "  CUDA_VERSION:    $CUDA_VERSION"
echo "  CUDA_ARCH_BIN:   $CUDA_ARCH_BIN"
echo "  JETPACK_VERSION: $JETPACK_VERSION"
echo "  ROS_VERSION:     $ROS_VERSION"

# Read arguments
for i in "$@"
do
case $i in
    -t=*|--version=*)
      ROS_VERSION=${i#*=}
      shift
      ;;
esac
done

echo "Installing ROS ${ROS_VERSION} packages"

# Setup keys
curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# Update repos
apt update -y
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null
apt update -y

# Install ROS
apt install -y ros-${ROS_VERSION}-desktop

# Install other packages
apt install -y \
    ros-dev-tools

# Remove apt repos
rm -rf /var/lib/apt/lists/*
apt-get clean

# Add to .bashrc
echo "source /opt/ros/galactic/setup.bash" >> ~/.bashrc
source ~/.bashrc