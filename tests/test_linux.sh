#!/usr/bin/env bash
#  vim:ts=4:sts=4:sw=4:et
#
#  Author: Hari Sekhon
#  Date: 2015-10-07 13:41:58 +0100 (Wed, 07 Oct 2015)
#
#  https://github.com/harisekhon/nagios-plugins
#
#  License: see accompanying Hari Sekhon LICENSE file
#
#  If you're using my code you're welcome to connect with me on LinkedIn and optionally send me feedback to help improve or steer this or other code I publish
#
#  https://www.linkedin.com/in/harisekhon
#

set -euo pipefail
[ -n "${DEBUG:-}" ] && set -x
srcdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$srcdir/..";

. ./tests/utils.sh

#[ `uname -s` = "Linux" ] || exit 0

echo "
# ============================================================================ #
#                                   L i n u x
# ============================================================================ #
"

#export DOCKER_IMAGE="harisekhon/nagios-plugins"
export DOCKER_CONTAINER_BASE="nagios-plugins-linux-test"

export MNTDIR="/tmp/nagios-plugins"

if ! is_docker_available; then
    echo 'WARNING: Docker not found, skipping Linux checks!!!'
    exit 0
fi

docker_exec(){
    local cmd="$@"
    docker exec "$DOCKER_CONTAINER" $MNTDIR/$*
}

# TODO: build specific versions to test for CentOS 6 + 7, Ubuntu 14.04 + 16.04, Debian Wheezy + Jessie, Alpine builds
test_linux(){
    local distro="$1"
    local version="$2"
    local DOCKER_IMAGE
    local DOCKER_CONTAINER
    if [[ "$distro" = *centos* ]]; then
        DOCKER_IMAGE="harisekhon/$distro-github:$version"
    elif [[ "$distro" = *ubuntu* ]]; then
        DOCKER_IMAGE="harisekhon/$distro-github:$version"
    elif [[ "$distro" = *debian* ]]; then
        DOCKER_IMAGE="harisekhon/$distro-github:$version"
    elif [[ "$distro" = *alpine* ]]; then
        DOCKER_IMAGE="harisekhon/$distro-github:$version"
    else
        die "unrecognized distro supplied: '$distro'"
    fi
    DOCKER_CONTAINER="$DOCKER_CONTAINER_BASE-$distro-$version"
    echo "Setting up Linux $distro $version test container"
    DOCKER_OPTS="-v $srcdir/..:$MNTDIR"
    DOCKER_CMD="tail -f /dev/null"
    launch_container "$DOCKER_IMAGE" "$DOCKER_CONTAINER"
    #docker exec "$DOCKER_CONTAINER" yum install -y net-tools
    if [ -n "${NOTESTS:-}" ]; then
        exit 0
    fi
    hr
    docker_exec check_disk_write.pl -d .
    hr
    hr
    docker_exec check_linux_auth.pl -u root -g root -v
    hr
    docker_exec check_linux_context_switches.pl || : ; sleep 1; docker_exec check_linux_context_switches.pl -w 10000 -c 50000
    hr
    docker_exec check_linux_duplicate_IDs.pl
    hr
    # temporary fix until slow DockerHub automated builds trickle through ethtool in docker images
    docker exec -i "$DOCKER_CONTAINER" sh <<EOF
which yum && yum install -y ethtool && exit
which apt-get && apt-get update && apt-get install -y ethtool && exit
which apk && apk add ethtool && exit
:
EOF
    hr
    docker_exec check_linux_interface.pl -i eth0 -v -e -d Full
    echo "sleeping for 1 sec before second run to check stats code path + re-load from state file"
    sleep 1
    docker_exec check_linux_interface.pl -i eth0 -v -e -d Full
    hr
    # making this much higher so it doesn't trip just due to test system load
    docker_exec check_linux_load_normalized.pl -w 99 -c 99
    hr
    docker_exec check_linux_load_normalized.pl -w 99 -c 99 --cpu-cores-perfdata
    hr
    docker_exec check_linux_ram.py -v -w 20% -c 10%
    hr
    docker_exec check_linux_system_file_descriptors.pl
    hr
    #docker_exec check_linux_timezone.pl -T UTC -Z /usr/share/zoneinfo/UTC -A UTC -v
    # Alpine doesn't have zoneinfo installation
    docker_exec check_linux_timezone.pl -T UTC -Z /etc/localtime -A UTC -v
    hr
    delete_container
}

section "CentOS"
for version in $(ci_sample latest); do
    test_linux centos "$version"
done

section "Ubuntu"
for version in $(ci_sample latest); do
    test_linux ubuntu "$version"
done

section "Debian"
for version in $(ci_sample latest); do
    test_linux debian "$version"
done

section "Alpine"
for version in $(ci_sample latest); do
    test_linux alpine "$version"
done

# ============================================================================ #
#                                     E N D
# ============================================================================ #
# old local checks don't run on Mac
exit 0

$perl -T ./check_linux_timezone.pl -T UTC -Z /usr/share/zoneinfo/UTC -A UTC
hr
if [ -x /usr/bin/yum ]; then
    $perl -T ./check_yum.pl
    $perl -T ./check_yum.pl --all-updates || :
    hr
    ./check_yum.py
    ./check_yum.py --all-updates || :
    hr
fi

echo; echo
