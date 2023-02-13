#!/bin/bash
# This script launches a container for the target platform
# author: Matias Mattamala
set -e

# Include helpers
source bin/helpers.sh

# Define usage
__usage="
Usage: $(basename $0) --target=TARGET|--image=IMAGE [OPTIONS]

Options:
  --target=<target>        Selected target (available ones): [$(list_targets)]
  --image=<image>          Tag or image id of a docker image (useful to launch other Docker images)

  --stage=<stage>          Use specific stage: [$(list_stages)] (It requires a target to work)
  --git=<git_folder>       Git folder to be mounted (Default: $HOME/git)
  --catkin=<ws_folder>     Catkin workspace folder to be mounted (Default: $HOME/catkin_ws)
  --entrypoint=<file>      Custom entrypoint script to be executed when running the container
  --flags=<docker_flags>   Any extra flags passed do docker run (e.g, to mount additional stuff)
"

# Default target
TARGET=none
IMAGE_ID=none
STAGE=""
GIT_DIR="$HOME/git"
CATKIN_DIR="$HOME/catkin_ws"
ENTRYPOINT_FILE="dummy.sh"
EXTRA_FLAGS=""

# Read arguments
for i in "$@"; do
    case $i in
        --target=*)
            TARGET=${i#*=}
            shift
            ;;
        --stage=*)
            STAGE=${i#*=}
            shift
            ;;
        --image=*|--image-id=*)
            IMAGE_ID=${i#*=}
            shift
            ;;
        --git=*|--git-dir=*)
            GIT_DIR=${i#*=}
            shift
            ;;
        --catkin=*|--catkin-dir=*)
            CATKIN_DIR=${i#*=}
            shift
            ;;
        --entrypoint=*)
            ENTRYPOINT_FILE=${i#*=}
            shift
            ;;
        --flags=*)
            EXTRA_FLAGS=${i#*=}
            shift
            ;;
        *)
            echo "$__usage"
            exit 0
            ;;
    esac
done

ENTRYPOINT_FILEPATH="$(pwd)/entrypoints/${ENTRYPOINT_FILE}"
if [[ "$(check_file_exists $ENTRYPOINT_FILEPATH)" == "false" ]]; then
    ENTRYPOINT_FILEPATH="$(pwd)/entrypoints/dummy.sh"
fi

# Print summary of options
echo " == run.sh =="
echo " Target:          '$TARGET'"
echo " Stage:           '$STAGE'"
echo " Images:          '$IMAGE_ID'"
echo " Mount git:       '$GIT_DIR'"
echo " Mount catkin:    '$CATKIN_DIR'"
echo " Entrypoint file: '$ENTRYPOINT_FILEPATH'"
echo " ============"

if [[ "$TARGET" == "none" && "$IMAGE_ID" == "none" ]]; then
    echo "$__usage"
	exit 0
fi

if [[ "$STAGE" != "" ]]; then
    # Remove number from stage
    STAGE=${STAGE##*-}
fi

# Handle different target cases
if [[ "$TARGET" != "none" ]]; then
    source targets/$TARGET.sh
    check_target_exists

    # Check stage if requested
    if [[ "$STAGE" != "" && "$STAGE" != "all" ]]; then
        IMAGE_TAG=${IMAGE_TAG}-${STAGE##*-}
    fi

else
    IMAGE_TAG=$IMAGE_ID
fi

# Check if image exists, otherwise pull it
if [[ "$(docker images -q $IMAGE_TAG 2> /dev/null)" == "" ]]; then
    echo_warning "Image [$IMAGE_TAG] not found. Pulling from DockerHub..."
    docker pull $IMAGE_TAG
    echo "Done"
fi

# Get architecture of base image and host system
IMAGE_OS=$(docker inspect --format '{{ .Os }})' $IMAGE_TAG)
HOST_OS=$(docker info --format '{{ .OSType }})')

IMAGE_ARCH=$(docker inspect --format '{{ .Architecture }}' $IMAGE_TAG)
HOST_ARCH=$(docker info --format '{{ .Architecture }}')

# Build with emulator if needed
EMULATOR_FLAGS=""
if [[ $(compare_architectures $IMAGE_ARCH $HOST_ARCH) == "false" ]]; then
    echo_warning "Architectures [$IMAGE_ARCH] [$HOST_ARCH] are not the same, running emulation..."
    run_docker_qemu
    EMULATOR_FLAGS="--security-opt seccomp=unconfined"
fi

# Change the gpu flags depending on the platform - Jetson requires different ones
GPU_FLAGS="--runtime nvidia"
if [[ "$JETPACK_VERSION" != "" ]]; then
    GPU_FLAGS="--gpus all"                         # instead of nvidia runtime
    GPU_FLAGS+=" -v /run/jtop.sock:/run/jtop.sock" # Required for jetson-stats to work in the container
fi

# Enable graphical stuff launch in the container
# Reference: http://wiki.ros.org/docker/Tutorials/GUI
XSOCK=/tmp/.X11-unix
XAUTH=/tmp/.docker.xauth
if [ ! -f $XAUTH ]; then
    touch $XAUTH
    xauth_list=$(xauth nlist :0 | sed -e 's/^..../ffff/')
    xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $XAUTH nmerge -
    chmod a+r $XAUTH
fi

# Run docker
docker run -it --rm --net=host \
                    $GPU_FLAGS \
                    --volume=$XSOCK:$XSOCK:rw \
                    --volume=$XAUTH:$XAUTH:rw \
                    --env="QT_X11_NO_MITSHM=1" \
                    --env="XAUTHORITY=$XAUTH" \
                    --env="DISPLAY=$DISPLAY" \
                    -v ${GIT_DIR}:/root/git \
                    -v ${CATKIN_DIR}:/root/catkin_ws \
                    -v "${ENTRYPOINT_FILEPATH}":/custom_entrypoint.sh \
                    --pull "missing" \
                    $EMULATOR_FLAGS \
                    $EXTRA_FLAGS \
                    $IMAGE_TAG
