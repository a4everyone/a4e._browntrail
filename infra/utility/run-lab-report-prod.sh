#!/bin/bash

if [ -z "$3" ]; then
    echo Error:please specify lab name
    exit 1
fi

INPUT_SHARE_NAME=a4elab-input
INPUT_FOLDER=$3/bucket

source $1/$2

if [ -z $INPUT_DATA_FILE_NAME ]; then
    echo ERROR: could not find value for INPUT_DATA_FILE_NAME
    exit 1
fi

eval $(azure-admin s $4)

azure storage file upload $1/$INPUT_DATA_FILE_NAME $INPUT_SHARE_NAME $INPUT_FOLDER

if [[ ! $2 == "request.sh" ]]; then
    cp $1/$2 $1/request.sh
    trap "rm -f $1/request.sh" HUP INT QUIT KILL TERM EXIT
fi

azure storage file upload $1/request.sh $INPUT_SHARE_NAME $INPUT_FOLDER
azure storage file upload $1/request.sh $INPUT_SHARE_NAME $3/control/go
