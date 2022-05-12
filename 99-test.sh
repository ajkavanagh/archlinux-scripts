#!/bin/bash
set -ex

source ./vars.sh
source ./utils.sh

echo "here"

is_kvm || {
    echo "Is on a kvm"
    exit 0
}

echo "Is not a kvm"
