#!/usr/bin/env bash

#--------------------------------------------------------------------------
#
# Copyright 2014 Cumulus Networks, inc  all rights reserved
#
#--------------------------------------------------------------------------

SIGNRELEASE=1
while getopts ":n" opt; do
    case $opt in
      n)
        SIGNRELEASE=0
        ;;
      \?)
        echo "Invalid option"
        exit 1
	;;
    esac
done

# check pre-reqs
TOOLMISSING=0
tools=(apt-ftparchive dpkg-deb dpkg-scanpackages gpg)
for TOOL in ${tools[@]}; do
    if ! hash $TOOL 2>/dev/null; then
       echo "** ERROR ** $TOOL not installed"
       TOOLMISSING=$[$TOOLMISSING +1]
    fi
done
if [[ $TOOLMISSING -gt 0 ]]
then
    echo "$TOOLMISSING tools/cmds missing"
    exit 1
fi

# clean up
if [ ! -e repo-build ]; then
    mkdir repo-build
else
    rm -rf repo-build/*
fi

# sync git submodules
/usr/bin/git submodule init
/usr/bin/git submodule update
/usr/bin/git submodule foreach git pull origin master

if [ $? -ne 0 ]
then
    echo "git submodules failed to update; build will be incomplete"
    exit 1
fi

architectures=(amd64 i386 powerpc)

# loop through repos
for R in `find pkgs/* -maxdepth 0 -type d`
do

    REPO=$(echo $R | sed -e "s/pkgs\///")

    echo ""
    echo "$REPO repo..."
    echo ""

    # create empty repos
    for ARCH in ${architectures[@]}; do
        mkdir -p repo-build/$REPO/binary-$ARCH
    done

    # loop through packages
    for P in `find pkgs/$REPO/* -maxdepth 0 -type d`
    do
        PKG=$(echo $P | sed -e "s/pkgs\/$REPO\///")
        if [ ! -e pkgs/$REPO/$PKG/debian/DEBIAN/control ]; then
            echo "** WARNING ** skipping $REPO/$PKG no control file"
        else
            if ! dpkg-deb --build pkgs/$REPO/$PKG/debian repo-build/$REPO/binary-amd64/${PKG}_amd64.deb
            then
                echo "** ERROR ** while building $REPO/$PKG"
                exit 1
            fi
        fi
    done

    # generate package lists
    for ARCH in ${architectures[@]}; do
        if ! dpkg-scanpackages -a $ARCH repo-build/$REPO/binary-$ARCH /dev/null | sed -e 's/Filename: repo-build\//Filename: dists\/cldemo\//' > repo-build/$REPO/binary-$ARCH/Packages
        then
            echo "** ERROR ** while generating repo for  $REPO $ARCH"
            exit 1
        fi
    done

done

# create dependencies graph
mkdir -p output/
DEPENDFILES="dependencies_`date +%Y%m%d_%H%M`"
DEPENDPNG="output/$DEPENDFILES.png"
DEPENDDOT="output/$DEPENDFILES.dot"
./depends.py -p pkgs/workbench -t png -o $DEPENDPNG -d $DEPENDDOT
cp -f $DEPENDPNG output/dependencies_latest.png
cp -f $DEPENDDOT output/dependencies_latest.dot

# create Release file
echo ""
if ! apt-ftparchive -c ftparchive.conf release repo-build/ | sed -e 's/dists\/cldemo\///g' > repo-build/Release
then
    echo "** ERROR *** problem creating Release file"
    exit 1
else
    echo "Created Release file"
fi

if [ $SIGNRELEASE -eq 1 ]; then
    # signing Release
    echo ""
    if ! gpg -a --yes --homedir /mnt/repo/keyrings/cldemo --default-key 9804E228 --output repo-build/Release.gpg --detach-sig repo-build/Release
    then
        echo "** ERROR *** problem signing Release file"
        exit 1
    else
        echo "Signed Release file"
    fi
fi

# copy static content
cp -R repo-static/* repo-build/

echo ""
echo "Done"
echo ""

exit 0
