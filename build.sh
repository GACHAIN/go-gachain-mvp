#!/bin/bash

VCS_URL="https://support%40gachain.org@github.com/GACHAIN/go-gachain-mvp.git"
VCS_BRANCH="develop"
GOPATH="/root/gocode"
BIN="$GOPATH/bin/go-gachain-mvp"
ROOT="/root/gocode/src/github.com/GACHAIN/go-gachain-mvp"
STATIC="$ROOT/packages/static"
BINDATA="bindata.sh"
BUILD="go install"
SERVICE="gachain.service"

echo "Set GOPATH to $GOPATH"
export GOPATH=$GOPATH

echo "Remove $BIN"
rm -f $BIN

echo "Remove $STATIC"
rm -rf "$STATIC"

echo "Change directory to $ROOT"
cd $ROOT

if [ "$1" = "pull" ]
then
    git checkout $VCS_BRANCH
    git pull
fi

echo "Run $BINDATA"
bash $BINDATA

echo "Run $BUILD"
$BUILD

echo "Restart $SERVICE"
systemctl restart $SERVICE
