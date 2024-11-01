#!/bin/bash

TIMEOUT=30

function hca_sriov_dev_path() {
  local hca="$1"; shift

  echo "/sys/class/infiniband/mlx5_$hca/device/sriov"
  return 0
}

function hca_sriov_write_path() {
  local hca="$1"; shift

  echo "/sys/class/infiniband/mlx5_$hca/device/sriov_numvfs"
  return 0
}

function hca_sriov_read_path() {
  local hca="$1"; shift

  echo "/sys/class/infiniband/mlx5_$hca/device/sriov_totalvfs"
  return 0
}

[[ -v "NUMVFS" ]] || {
  (echo "Missing required envvar NUMVFS" >&2)
  exit 3
}

[[ -v "HCA_IDS" ]] || {
  (echo "Missing required envvar HCA_IDS" >&2)
  exit 4
}

# disable autoprobe
echo 0 > /sys/module/mlx5_core/parameters/probe_vf

## TODO: re-add the pci devices here and write 0 to /sys/bus/pci/devices/.../sriov_drivers_autoprobe ...

for hca in $HCA_IDS; do
  hca_w=$(hca_sriov_write_path $hca)
  echo "Evaluating HCA $hca_w..."

  [[ ! -e $hca_w ]] && {
    echo "Missing $hca_w, SRIOV support needs to be enabled and / or mstflint needs to be used to enable SRIOV in firmware on this card"
  } || {

    (($(cat $hca_w) >= $NUMVFS)) || {
      /usr/local/bin/echovfs.sh "$hca_w"
    }

    start=$(date -u +%s)
    dpath=$(hca_sriov_dev_path $hca)

    # set up trust on VFs with a timeout
    while true; do
      vfs=$(ls -d $dpath/[^groups]*)
      (($? == 0)) && {
        for vf in $vfs; do
          echo "ON" > $vf/trust || {
            (echo "Failed to set VF trust on $vf; exiting" >&2)
            exit 4
          }
        done

        # success
        echo "Completed setting VF trust on VFs on $dpath"
        break

      } || {
        now=$(date -u +%s)
        ((now-start > $TIMEOUT)) && {
          (echo "Missing devices on path $dpath within timeout period, ${TIMEOUT}s; exiting" >&2)
          exit 6
        }

        echo "Waiting for SRIOV devices on $dpath..."
        sleep 1
      }
    done
  }

done

exit 0
