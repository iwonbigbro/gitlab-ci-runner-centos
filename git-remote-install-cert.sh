#!/bin/bash

# Copyright (C) 2014 Craig Phillips.  All rights reserved.

git_remote_install_cert_sh=$(readlink -f "$BASH_SOURCE")

function usage() {
    cat <<USAGE
Usage: ${git_remote_install_cert_sh##*/} https://<hostname>.<domainname>/
Summary:
    Installs the SSL certificate obtained from the host provided.  Global Git
    configuration is updated, setting http.sslCAPath to the directory
    ~/.gitcerts, under which the certficate is installed.

Options:
    -v --verbose             Verbose output.
USAGE
}

function err() {
    echo >&2 "${git_remote_install_cert_sh##*/}: $*"
    exit 1
}

exec 3>/dev/null

while (( $# > 0 )) ; do
    case $1 in
    (-v|--verbose)
        exec 3>&2
        ;;
    (-\?|--help)
        usage
        exit 0
        ;;
    (*)
        break
        ;;
    esac
    shift
done

if [[ ! $1 ]] ; then
    err "Missing URL"
fi

if [[ $1 =~ ^https://([^/]+)/?$ ]] ; then
    server=${BASH_REMATCH[1]}
    username=${server%%@*}
    server=${server##*@}

    url=${BASH_REMATCH[0]}/
    url=${url/$username@/}

    [[ $server ]] || err "No match"

    if [[ ! $server =~ :[0-9]+$ ]] ; then
        server+=:443
    fi
else
    err "Invalid URL: $1"
fi

certtmp=$(UMASK=0077 mktemp)
trap "rm -f $certtmp" EXIT

echo "Requesting certificate from the server..."
openssl 2>&3 s_client -connect $server </dev/null | \
    awk >$certtmp '
        BEGIN {
            f = 0;
        } 
        f == 1 || /^-----BEGIN CERTIFICATE-----/ {
            f = 1;
            print;
        }
        /^-----END CERTIFICATE-----/ {
            exit;
        }
    '

if (( $? != 0 )) ; then
    err "Failed to get certificate from: $server"
fi

[[ -s $certtmp ]] || err "Failed to obtain certificate"

cert="$HOME/.gitcerts/${server%:*}.crt"

mkdir -m 0700 -p ${cert%/*} ||
    err "Failed to create Git certificate store"

mv $certtmp $cert ||
    err "Failed to import certificate"

echo "Certificate installed to: $cert"
git config --global http.sslCAPath "$HOME/.gitcerts" ||
    err "Failed to set 'http.sslCAPath' configuration setting"
