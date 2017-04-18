#!/bin/bash

set -e

SDCARD="/dev/mmcblk0"
PARAMETER_FILE="parameter"
SDCARDIMG="SD.img"
LOADERMERGEDFILE="rk3399_loader_v1.07.105.bin"


declare -a PARTITIONS
declare -a USER_FORMAT_PARTITIONS
declare -i PARTITION_INDEX

#USER_FORMAT_PARTITIONS=(userboot linuxroot)
USER_FORMAT_PARTITIONS=(boot)
#USER_FORMAT_PARTITIONS=(userboot)

ERROR()
{
    echo $*
    exit 1
}

DD()
{
    [ -b ${SDCARD} ] && dd $*
}

GENERATE_IDBLOCK_DATA()
{
    ./boot_merger --gensdboot $LOADERMERGEDFILE
}

CREATE_PARTITIONS_ON_SDCARD()
{
	#echo -n "$0: Calculating partition sizes for '${SDCARD}' ... "
        PARTITIONS=()
        START_OF_PARTITION=0
        PARTITION_INDEX=0
	for PARTITION in `cat ${PARAMETER_FILE} | grep '^CMDLINE' | sed 's/ //g' | sed 's/.*:\(0x.*[^)])\).*/\1/' | sed 's/,/ /g'`; do
        	PARTITION_NAME=`echo ${PARTITION} | sed 's/\(.*\)(\(.*\))/\2/'`
        	PARTITION_START=`echo ${PARTITION} | sed 's/.*@\(.*\)(.*)/\1/'`
        	PARTITION_LENGTH=`echo ${PARTITION} | sed 's/\(.*\)@.*/\1/'`

            PARTITIONS+=("$PARTITION_NAME")
            PARTITION_INDEX+=1

            eval "${PARTITION_NAME}_START_PARTITION=${PARTITION_START}"
            eval "${PARTITION_NAME}_LENGTH_PARTITION=${PARTITION_LENGTH}"
            eval "${PARTITION_NAME}_INDEX_PARTITION=${PARTITION_INDEX}"
	done

    for PARTITION in ${USER_FORMAT_PARTITIONS[@]}; do
        PSTART=${PARTITION}_START_PARTITION
        PLENGTH=${PARTITION}_LENGTH_PARTITION
        PINDEX=${PARTITION}_INDEX_PARTITION
        PSTART=${!PSTART}
        PLENGTH=${!PLENGTH}
        PINDEX=${!PINDEX}
        [[ ${PSTART} -eq 0 ]] && echo "Creating ${PARTITION} Partition ERROR!" && exit
        echo "Creating ${PARTITION} Partition, index ${PINDEX}, start ${PSTART}, length ${PLENGTH}"

        #PBEGIN=$(((${PSTART} + 0x2000 ) * 512 / 1024 /1024))
        PBEGIN=$(((${PSTART} + 0x2000 )))
        if [ "${PLENGTH}" == "-" ]; then
            PEND=
        else
            #PENDM=$(((${PSTART} + ${PLENGTH} -1 + 0x2000 ) * 512 / 1024 /1024))
            #PEND=${PENDM}M
            PEND=$(((${PSTART} + ${PLENGTH} -1 + 0x2000 )))
        fi

        echo "sgdisk -n ${PINDEX}:${PBEGIN}:${PEND} -t ${PINDEX}:0700 ${SDCARDIMG}"
        #sgdisk -n ${PINDEX}:${PBEGIN}:${PEND} -t ${PINDEX}:0700 ${SDCARDIMG}
        sgdisk -n ${PINDEX}:${PBEGIN}:${PEND} -t ${PINDEX}:0700 ${SDCARDIMG}
#        mkfs.ext4 -F -L ${PARTITION} ${SDCARD}p${PINDEX}

        #echo "sgdisk -n ${PINDEX}:${PBEGIN}M:${PEND} -t ${PINDEX}:0700 ${SDCARDIMG}"
        #sgdisk -n ${PINDEX}:${PBEGIN}M:${PEND} -t ${PINDEX}:0700 ${SDCARDIMG}
        #mkfs.ext4 -F -L ${PARTITION} ${SDCARDIMG}${PINDEX}

	done

    sleep 5
}

PREPARE_SDCARD()
{

    sleep 3
    sgdisk -Z ${SDCARDIMG}
    sleep 3
}

FLASH_IMAGR_TO_PARTITION()
{
    ./rkcrc -p ${PARAMETER_FILE} parameter.img

    dd if=parameter.img      of=${SDCARDIMG} seek=$(((0x000000 + 0x2000))) ibs=1M conv=sync,fsync
    dd if=uboot.img          of=${SDCARDIMG} seek=$(((0x002000 + 0x2000))) ibs=1M conv=sync,fsync
    dd if=trust.img          of=${SDCARDIMG} seek=$(((0x004000 + 0x2000))) ibs=1M conv=sync,fsync
    dd if=linux-resource.img of=${SDCARDIMG} seek=$(((0x006000 + 0x2000))) ibs=1M conv=sync,fsync
    dd if=linux-kernel.img   of=${SDCARDIMG} seek=$(((0x00E000 + 0x2000))) ibs=1M conv=sync,fsync
    #dd if=buildrootfs.img    of=${SDCARDIMG} seek=$(((0x018000 + 0x2000))) ibs=1M conv=sync,fsync
    dd if=../ubuntu1604arm64-rootfs.img of=${SDCARDIMG} seek=$(((0x01A000 + 0x2000))) ibs=1M conv=sync,fsync

    rm -rf parameter.img
}

FLASH_LOADER()
{
    GENERATE_IDBLOCK_DATA
    dd if=SD.bin            of=${SDCARDIMG} conv=sync,fsync
}


FLASH_LOADER
FLASH_IMAGR_TO_PARTITION

#[ ! -b ${SDCARD} ] && ERROR "${SDCARD} not found!"
#DD if=${SDCARDIMG} of=${SDCARD} conv=sync,fsync

PREPARE_SDCARD
CREATE_PARTITIONS_ON_SDCARD

