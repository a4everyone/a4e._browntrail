#! /bin/bash
set -e

while [ $# -gt 0 ]; do
    
    case $1 in
        -p|--push):
            test -z "$PUSH_IMAGE" || (echo 'ERR: duplicate command -push' && false)
            PUSH_IMAGE=true
            ;;
        -t|--tag):
            test -z "$IMAGE_FULL_NAME" || (echo "ERR: duplicate command -t" && false)
            shift
            IMAGE_FULL_NAME="$1"
            ;;
        -o|--other-arg):
            test -z "$OTHER_ARGS" || (echo "ERR: duplicate command -o" && false)
            shift
            echo OTHER_ARGS is "$1"
            OTHER_ARGS="$1"
            ;;
        *)
            echo "Unexpected command $1" && false
            ;;
    esac
    
    shift
done

test -n "$IMAGE_FULL_NAME" || (echo "ERR: no image specified" && false)

if [[ ! "$IMAGE_FULL_NAME" =~ ^a4everyone/ ]]; then
    echo "INFO: Image name ${IMAGE_FULL_NAME} will be prefixed with a4everyone/"
    IMAGE_FULL_NAME="a4everyone/${IMAGE_FULL_NAME}"
fi
if [[ ! "$IMAGE_FULL_NAME" =~ :.+$ ]]; then
    echo "INFO: Image name ${IMAGE_FULL_NAME} will be suffixed with :latest"
    IMAGE_FULL_NAME="${IMAGE_FULL_NAME}:latest"
fi
if [[ "${IMAGE_FULL_NAME##*:}" == "base" ]]; then
    BASE_BUILD="true"
    echo "INFO: Building a base image"
fi

IMAGE_BASE_NAME=${IMAGE_FULL_NAME#*/}
IMAGE_BASE_NAME=${IMAGE_BASE_NAME%:*}

if [ ! -d ${IMAGE_BASE_NAME} ]; then
    echo "ERR: Don't know how to build ${IMAGE_BASE_NAME}"
    false
fi

function cleanup {
    rm -f ${A4E_PROJ_ROOT}/.dockerignore
}
trap cleanup HUP INT QUIT KILL TERM EXIT ERR

#~ if [[ -z "${BASE_BUILD}" ]]; then 
    cp ./${IMAGE_BASE_NAME}/.dockerignore ${A4E_PROJ_ROOT}/
    docker build -t ${IMAGE_FULL_NAME} -f ./${IMAGE_BASE_NAME}/Dockerfile ${OTHER_ARGS} ${A4E_PROJ_ROOT}
#~ else
    #~ test -r ./${IMAGE_BASE_NAME}/.dockerignore-base && \
    #~ cp ./${IMAGE_BASE_NAME}/.dockerignore-base ${A4E_PROJ_ROOT}/.dockerignore
    #~ docker build -t ${IMAGE_FULL_NAME} -f ./${IMAGE_BASE_NAME}/Dockerfile-base ${A4E_PROJ_ROOT}
#~ fi

if [ $? -eq 0 ] && [[ -n "${PUSH_IMAGE}" ]]; then
    docker push ${IMAGE_FULL_NAME}
fi
