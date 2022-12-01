#!/usr/bin/env bash

dir=$1
file=wireguard_key_"$(hostname)"
A
umask 077
chmod 700 "$dir"

wg genkey > "$dir/$file"
wg pubkey < "$dir/$file"
