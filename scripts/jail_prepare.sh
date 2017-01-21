#!/bin/sh

set -e

BASEJAIL_CPDIRS="root etc var"
BASEJAIL_LNDIRS="bin sbin lib libexec"
BASEJAIL_MKDIRS="usr usr/local tmp dev proc"
BASEJAIL="10.2-RELEASE"

ZPOOL="jails"
ZPOOL_MOUNT="/jails"
SOURCE_MIRROR="ftp://ftp.freebsd.org"
SOURCE_PATH="/pub/FreeBSD/releases/amd64/amd64/${BASEJAIL}"
BASEJAILS_MOUNT="${ZPOOL_MOUNT}/basejails"
BASEJAILS_ZVOL="${ZPOOL}/basejails"

INSTANCE="$1"
INSTANCE_DIR="${ZPOOL_MOUNT}/thinjails/$INSTANCE"
INSTANCE_ZVOL="${ZPOOL}/thinjails/$INSTANCE"

CONFIG_DIR="${ZPOOL_MOUNT}/configs"

if [ -z $INSTANCE ];
then
	echo "No instance name given as first parameter"
	exit 1;
fi

if [ ! -d "${BASEJAILS_MOUNT}/${BASEJAIL}" ];
then
	zfs create -p $BASEJAILS_ZVOL/$BASEJAIL
	# basejail download
	fetch ${SOURCE_MIRROR}${SOURCE_PATH}/base.txz -o /tmp/${BASEJAIL}_base.txz
	fetch ${SOURCE_MIRROR}${SOURCE_PATH}/lib32.txz -o /tmp/${BASEJAIL}_lib32.txz
	# extract basejail packages
	tar -xf /tmp/${BASEJAIL}_base.txz -C ${BASEJAILS_MOUNT}/${BASEJAIL}
	tar -xf /tmp/${BASEJAIL}_lib32.txz -C ${BASEJAILS_MOUNT}/${BASEJAIL}
fi

mkdir -p $CONFIG_DIR

if [ ! -f "${CONFIG_DIR}/${INSTANCE}.fstab" ];
then
	echo "${BASEJAILS_MOUNT}/${BASEJAIL} ${INSTANCE_DIR}/basejail  nullfs   ro   0     0" > ${CONFIG_DIR}/${INSTANCE}.fstab
	echo "" >> ${CONFIG_DIR}/${INSTANCE}.fstab
fi


if [ 0 -eq $(zfs list | grep -c "${INSTANCE_ZVOL}") ];
then
	echo "Preparing ZFS volume: ${INSTANCE_ZVOL}"
	zfs create -p $INSTANCE_ZVOL
fi

cd ${INSTANCE_DIR}
CWD=$(pwd)

echo "Preparing jail instance in $CWD"

if [ 0 -eq $(mount -l | grep -c "${INSTANCE_DIR}/basejail") ];
then
	mkdir -p basejail
	mount -t nullfs -o ro /jails/basejails/$BASEJAIL basejail
fi

# copy dirs from basejail
for _CPDIR in $BASEJAIL_CPDIRS;
do
	if [ ! -e ${_CPDIR} ];
	then
		cp -an basejail/${_CPDIR} ./${_CPDIR}
	fi
done;

# symlink dir from basejail
for _LNDIR in ${BASEJAIL_LNDIRS};
do
	if [ ! -L ${_LNDIR} ];
	then
		ln -snf basejail/${_LNDIR} ./${_LNDIR}
	fi
done;

for _MKDIR in ${BASEJAIL_MKDIRS};
do
	if [ ! -d ${_MKDIR} ];
	then
		mkdir -p ${_MKDIR}
	fi
done;

# symlink usr dir from basejail while keeping /usr/local/ writable
cd  usr
for _USRDIR in $(ls ../basejail/usr/);
do
	if [ ! -L ${_USRDIR} ];
	then
		case "${_USRDIR}" in
			local|obj|src)	;;
			*)	ln -snf ../basejail/usr/${_USRDIR} ${_USRDIR}
					;;
		esac
	fi
done;
cd $CWD

echo "Current directory layout"
ls -ahl $CWD

umount $INSTANCE_DIR/basejail
echo "Done"
exit 0;
