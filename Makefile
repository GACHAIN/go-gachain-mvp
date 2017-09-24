.DEFAULT_GOAL := all


go-bindata:
	go get -u github.com/jteeuwen/go-bindata/...

static-files:
	rm -rf $GOPATH/src/github.com/GACHAIN/go-gachain-mvp/packages/static/static.go
	${GOPATH}/bin/go-bindata -o="${GOPATH}/src/github.com/GACHAIN/go-gachain-mvp/packages/static/static.go" -pkg="static" -prefix="${GOPATH}/src/github.com/GACHAIN/go-gachain-mvp/" ${GOPATH}/src/github.com/GACHAIN/go-gachain-mvp/static/...

build:
	go build github.com/GACHAIN/go-gachain-mvp

install:
	go install github.com/GACHAIN/go-gachain-mvp

all:
	make go-bindata
	make static-files
	make install
