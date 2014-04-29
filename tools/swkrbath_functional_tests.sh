#!/bin/bash

# Copyright (c) 2014 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This program expects to be run by tox in a virtual python environment
# so that it does not pollute the host development system

sudo_env()
{
    sudo bash -c "PATH=$PATH $*"
}

cleanup()
{
        sudo service memcached stop
        sudo_env swift-init main stop
        sudo rm -rf /etc/swift > /dev/null 2>&1
        for acct in /mnt/gluster-object/* ; do
            sudo rm -rf /mnt/gluster-object/${acct}/* > /dev/null 2>&1
            sudo setfattr -x user.swift.metadata /mnt/gluster-object/${acct} > /dev/null 2>&1
        done
}

quit()
{
    echo "$1"
    exit 1
}


fail()
{
    cleanup
    quit "$1"
}

### MAIN ###

# Only run if there is no configuration in the system
if [ -x /etc/swift ] ; then
    quit "/etc/swift exists, cannot run functional tests."
fi

# Check the directories exist
DIRS="/mnt/gluster-object /mnt/gluster-object/test /mnt/gluster-object/test2 /mnt/gluster-object/gsmetadata"
for d in $DIRS ; do
    if [ ! -x $d ] ; then
        quit "$d must exist on an XFS or GlusterFS volume"
    fi
done

export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf

# Install the configuration files
sudo mkdir /etc/swift > /dev/null 2>&1
sudo cp -r test/functional_auth/swiftkerbauth/conf/* /etc/swift || fail "Unable to copy configuration files to /etc/swift"

# Create the ring files
accounts=""
for acct in /mnt/gluster-object/* ; do
    acct=`basename $acct`
    accounts="$acct $accounts"
done
sudo_env gluster-swift-gen-builders $accounts || fail "Unable to create ring files"

# Start the services
sudo service memcached start || fail "Unable to start memcached"
sudo_env swift-init main start || fail "Unable to start swift"

mkdir functional_tests > /dev/null 2>&1

echo "== SwiftKerbAuth: Functional Tests =="


nosetests -v --exe \
    --with-xunit \
    --xunit-file functional_tests/gluster-swift-swiftkerbauth-generic-functional-TC-report.xml \
    --with-html-output \
    --html-out-file functional_tests/gluster-swift-swiftkerbauth-generic-functional-result.html \
    test/functional_auth/swiftkerbauth || fail "Functional tests failed"

cleanup
exit 0
