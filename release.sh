#!/bin/sh -ex

case $(uname) in
    Darwin|Linux)
        zip=zip
        ;;
    *_NT-*)
        exe=.exe
        zip=/c/msys64/usr/bin/zip
        ;;
    *)
        echo "unknown OS: $(uname)" >&2
        exit 1
        ;;
esac

#
# Create zip file.
#

mkdir zeek
cp zeekrunner$exe zeek/
cp -R /usr/local/zeek/* zeek

$zip -r zeek-$(git describe --always --tags).$(go env GOOS)-$(go env GOARCH).zip zeek
