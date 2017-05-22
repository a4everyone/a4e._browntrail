#!/bin/bash
VOLUMES_INPUT_PATH=~/a4e/volumes/input/dev${LAB_IDX}

if [ ! -d $VOLUMES_INPUT_PATH/control ]; then
    echo ERROR: $VOLUMES_INPUT_PATH/control missing
    exit 1
fi

source $1$2

if [ -z $INPUT_DATA_FILE_NAME ]; then
    echo ERROR: could not find value for INPUT_DATA_FILE_NAME
    exit 1
fi

cp $1/$INPUT_DATA_FILE_NAME $VOLUMES_INPUT_PATH/bucket/
cp $1/$2 $VOLUMES_INPUT_PATH/bucket/request.sh

echo 'sugar sprice and everything nice' > $VOLUMES_INPUT_PATH/control/go
