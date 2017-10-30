# Installation

## Requirements

* Go >=1.6
* git

## Build

Clone:
```
git clone https://github.com/GACHAIN/go-gachain-mvp.git $GOPATH/src/github.com/GACHAIN/go-gachain-mvp
```

Build GACHAIN:
```
go get -u github.com/jteeuwen/go-bindata/...
$GOPATH/bin/go-bindata -o="$GOPATH/src/github.com/GACHAIN/go-gachain-mvp/packages/static/static.go" -pkg="static" -prefix="$GOPATH/src/github.com/GACHAIN/go-gachain-mvp/" $GOPATH/src/github.com/GACHAIN/go-gachain-mvp/static/...
go install github.com/GACHAIN/go-gachain-mvp
```

# Running
Application requires running PostgreSQL server

Create gachain directory and copy binary:
```
mkdir ~/gachain
cp $GOPATH/bin/go-gachain-mvp ~/gachain
```

Run GACHAIN:
```
~/gachain/go-gachain-mvp
```
Open GACHAIN: http://localhost:7079/


Rebuild and restart application
```
build.sh [pull]
```
Specify "pull" as first parameter to update source code before building

----------


### Questions?
email: support@gachain.org
