#!/bin/bash
# Copyright 2021 Authors of KubeArmor
# SPDX-License-Identifier: Apache-2.0

realpath() {
    CURR=$PWD

    cd "$(dirname "$0")"
    LINK=$(readlink "$(basename "$0")")

    while [ "$LINK" ]; do
        cd "$(dirname "$LINK")"
        LINK=$(readlink "$(basename "$1")")
    done

    REALPATH="$PWD/$(basename "$1")"
    echo "$REALPATH"

    cd $CURR
}

export KUBEARMOR_HOME=`dirname $(realpath "$0")`/../..

# install build dependencies
sudo dnf -y update
sudo dnf install -y bison cmake ethtool flex git iperf libstdc++-static \
                    python-netaddr python-pip gcc gcc-c++ make zlib-devel \
                    elfutils-libelf-devel  python-pip cmake make \
                    luajit luajit-devel kernel-devel \
                    http://repo.iovisor.org/yum/extra/mageia/cauldron/x86_64/netperf-2.7.0-1.mga6.x86_64.rpm
sudo pip install pyroute2

# install binary clang
sudo dnf install -y clang clang-devel llvm llvm-devel llvm-static ncurses-devel

# install and compile BCC
cd
git clone https://github.com/iovisor/bcc.git
mkdir bcc/build; cd bcc/build
cmake .. && make && sudo make install
if [ $? != 0 ]; then
    echo "Failed to install bcc"
    exit
fi
cd

# install go
wget https://dl.google.com/go/go1.15.3.linux-amd64.tar.gz
tar -xvf go1.15.3.linux-amd64.tar.gz
sudo mv go /usr/local
rm go1.15.3.linux-amd64.tar.gz
echo "export GOPATH=$HOME/go" >> ~/.bashrc
echo "export GOROOT=/usr/local/go" >> ~/.bashrc
echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc
source ~/.bashrc

# copy cil templates
sudo cp -r $KUBEARMOR_HOME/KubeArmor/templates /usr/share/

# download protoc
mkdir -p /tmp/build/protoc; cd /tmp/build/protoc
wget https://github.com/protocolbuffers/protobuf/releases/download/v3.14.0/protoc-3.14.0-linux-x86_64.zip -O /tmp/build/protoc/protoc-3.14.0-linux-x86_64.zip

# install protoc
unzip protoc-3.14.0-linux-x86_64.zip
sudo mv bin/protoc /usr/local/bin/

# download protoc-gen-go
go get -u google.golang.org/grpc
go get -u github.com/golang/protobuf/protoc-gen-go

# install kubebuilder
curl -L https://go.kubebuilder.io/dl/2.3.1/$(go env GOOS)/$(go env GOARCH) | tar -xz -C /tmp/build/
sudo mv /tmp/build/kubebuilder_2.3.1_$(go env GOOS)_$(go env GOARCH) /usr/local/kubebuilder

if [[ $(hostname) = kubearmor-dev* ]]; then
    echo >> /home/vagrant/.bashrc
    echo 'export PATH=$PATH:/usr/local/kubebuilder/bin' >> /home/vagrant/.bashrc
elif [ -z "$GOPATH" ]; then
    echo >> ~/.bashrc
    echo 'export PATH=$PATH:/usr/local/kubebuilder/bin' >> ~/.bashrc
fi

# install kustomize
cd /tmp/build/
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
sudo mv kustomize /usr/local/kubebuilder/bin

# remove downloaded files
cd; sudo rm -rf /tmp/build
