#!/bin/bash

NUMVFS=${NUMVFS:=32}

function readfail_break_fn() {
  local val=$1; shift

  ((val >= 0)) && return 1 || return 0
} 

function unchangedval_break_fn() {
  local val=$1; shift

  ((val != NUMVFS)) && return 1 || return 0
} 

function current_vfs() {
  local hca_path=$1; shift
  local READ_RETRY_LIMIT=$1; shift
  local break_fn=$1; shift

  local CURRENT_VFS=-1

  # retry read of hca_path a few times before giving up...
  for ((ct=0; ct < $READ_RETRY_LIMIT; ct++)); do
    $break_fn $CURRENT_VFS && return 0

    ((ct > 0)) && sleep 1
    CURRENT_VFS="$(cat $hca_path)"
  done
  
  echo "Failed waiting for $hca_path to meet condition $break_fn, exiting" >&2
  return 6
}

(($# != 1)) && {
  (echo "Missing required arg 'hca_path'" >&2)
  exit 4
}

hca_path="$1"; shift

init_vfs=$(current_vfs $hca_path 4 readfail_break_fn) || exit $?

((init_vfs != NUMVFS)) && {
  echo "${NUMVFS}" > $hca_path
  ex=$?
  ((ex > 0)) && {
    echo "Error writing desired value ($NUMVFS) to $hca_path, (read: $hca_path); exiting with $ex" >&2
    ls -la $hca_path
    exit $ex
  } || {
    current_vfs $hca_path 10 unchangedval_break_fn && {
      echo "Succeeded writing to $hca_path, (read: $hca_path)" >&2
    } || {
      echo "Failed to read back desired value $NUMVFS at $hca_path" >&2
      exit 9
    }
  }
} || {
  echo "No need to write to $hca_path, value is already desired $NUMVFS" >&2
}

exit 0
