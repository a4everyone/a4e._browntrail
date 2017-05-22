#! /bin/bash
KEYS_DIR=~/a4e/infra/keys

function cleanup {
    rm -rf ftp/.keys
}

trap cleanup HUP INT QUIT KILL TERM EXIT

mkdir ftp/.keys
cp ${KEYS_DIR}/keys-website/ftp-* ftp/.keys

docker build -t a4everyone/ftp:release ./ftp

if [ $? -eq 0 ] && [[ $1 == "push" ]]; then
    docker push a4everyone/ftp:release
fi
