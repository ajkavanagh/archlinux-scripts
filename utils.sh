## Ask if you are sure. Question text is in ${1}
# Note, if the DEFAULT_TO_YES environment variable is set to 'yes|y', then assume the response is yes
# returns _yes=1 if yes, else _yes is unset
function are_you_sure {
    unset _yes
    local _default_yes
    _default_yes=${DEFAULT_TO_YES,,}    # to lowercase
    if [[ "$_default_yes" =~ ^(yes|y)$ ]]; then
        _yes=1
    else
        read -r -p "${1} [y/N]:" response
        response=${response,,}          # to lower case
        if [[ "$response" =~ ^(yes|y)$ ]]; then
            _yes=1
        fi
    fi
}


# returns 1 if the function is mounted.
function is_mounted {
    local mount=$1

    is_present=$(cat /proc/mounts | awk '{ print $2 }' | egrep "^${mount}$")
    if [ ! -z "${is_present}" ]; then
        return 1
    fi
    return 0
}


# returns 1 if the system is a kvm
function is_kvm {
    kvm=$(dmesg | grep "kvm-clock"||:)
    echo "kvm is $kvm"
    if [ -z "$kvm" ]; then
        return 0
    fi
    return 1
}
