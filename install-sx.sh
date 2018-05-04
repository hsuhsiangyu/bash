#!/bin/bash
#
# Script to install libbitcoin, libwallet and sx tools.
#
# Install dependencies and compiles the source code from git for Debian 7 / Ubuntu 13.10 or Fedora GNU/Linux distributions.
#
# Requires sudo. 
#
# To execute this script, run:
# <sudo bash install-sx.sh>
#
# To read help instructions run:
# <sudo bash install-sx.sh --help>
#
#

set -e
echo
echo " [+] Welcome to S(pesmilo)X(changer)."
echo

# Defaults
INSTALL_PREFIX=/usr/local
CONF_DIR=/etc
RUN_LDCONFIG=ldconfig
ROOT_INSTALL=1
TOOLCHAIN_BRANCH="version1"
TOOLCHAIN_BRANCH_KEEP=0
TOOLCHAIN_TESTNET=
NCORE=`nproc`

usage() {
    echo " [+] Install script usage:"
    echo
    echo " [sudo] bash install-sx.sh [<--argument> <value> [...]]"
    echo
    echo " If no arguments are provided, defaults will be used, and sudo is mandatory."
    echo
    echo " Default path for installation is $INSTALL_PREFIX"
    echo " Default path for the conf files is $CONF_DIR"
    echo " Stable versions of toolchain packages (from git $TOOLCHAIN_BRANCH branches) will be installed for libbitcoin, libwallet and sx tools."
    echo
    echo " Optional arguments:"
    echo " --prefix <path>  Path prefix to install to, e.g. /home/user/usr"
    echo " --branch <name>  libbitcoin toolchain branch to use, e.g. develop"
    echo " --branch-keep    Don't check out from git for libbitcoin toolchain or dependencies, takes no value"
    echo " --testnet        Build for testnet, takes no value"
}

# Parse arguments.
argc=0
while [ $# -ne 0 ]; do
    argc=$[$argc + 1]
    case $1 in
	--help)
	    usage
	    exit
	    ;;
        --prefix)
	    shift
	    if [[ "$1" = /* ]]; then
		# Absolute path
		INSTALL_PREFIX=$1
	    else
		# Relative path
		INSTALL_PREFIX=`pwd`/$1
	    fi
	    CONF_DIR=$INSTALL_PREFIX/etc
	    RUN_LDCONFIG=
	    ROOT_INSTALL=0
	    ;;
	--branch)
	    shift
	    TOOLCHAIN_BRANCH=$1
	    ;;
	--branch-keep)
	    TOOLCHAIN_BRANCH_KEEP=1
	    ;;
	--testnet|--enable-testnet)
	    TOOLCHAIN_TESTNET="--enable-testnet"
	    ;;
	*)
	    echo "[+] ERROR: Invalid argument \"$1\"."
	    echo
	    usage
	    exit
	    ;;
    esac
    shift
done

if [ `id -u` != "0" -a $ROOT_INSTALL -eq 1 ]; then
    echo
    echo "[+] ERROR: This script must be run as root or be provided an install prefix." 1>&2
    echo
    usage
    exit
fi

BIN_DIR=$INSTALL_PREFIX/bin
SRC_DIR=$INSTALL_PREFIX/src
TOOLCHAIN_LD_LIBRARY_PATH=$INSTALL_PREFIX/lib
TOOLCHAIN_PKG_CONFIG_PATH=$INSTALL_PREFIX/lib/pkgconfig

export LD_LIBRARY_PATH=$TOOLCHAIN_LD_LIBRARY_PATH:$LD_LIBRARY_PATH
export PKG_CONFIG_PATH=$TOOLCHAIN_PKG_CONFIG_PATH:$PKG_CONFIG_PATH

mkdir -p $BIN_DIR
mkdir -p $SRC_DIR
mkdir -p $TOOLCHAIN_LD_LIBRARY_PATH
mkdir -p $TOOLCHAIN_PKG_CONFIG_PATH

#
strip_spaces(){
    echo $* | awk '$1=$1'
}

continue_or_exit(){
    read -p "Continue installation? [y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

install_dependencies(){
    flavour_id=`cat /etc/*-release | egrep -i "^ID=" | cut -f 2 -d "="`
    echo " Flavour: $flavour_id."
    echo
    if [ "$flavour_id" = "debian" ]; then
        D_DEPENDENCIES="\
            git build-essential autoconf apt-utils libtool \
            libboost-all-dev pkg-config libgmp-dev libcurl4-openssl-dev \
            libleveldb-dev libconfig++-dev libncurses5-dev wget"
        if [ "$ROOT_INSTALL" = 1 ]; then
            apt-get -y remove libzmq*
            apt-get -y install $D_DEPENDENCIES
        else
            echo "Run this command before continuing:"
            echo
            echo "  sudo apt-get remove libzmq*"
            echo "  sudo apt-get -y install $(strip_spaces $D_DEPENDENCIES)"
            echo
            continue_or_exit
        fi
    elif [ "$flavour_id" = "ubuntu" ]; then
        U_DEPENDENCIES="\
            git build-essential autoconf apt-utils libtool \
            pkg-config libgmp-dev libcurl4-openssl-dev libleveldb-dev \
            libconfig++8-dev libncurses5-dev libboost$U_BOOST-all-dev wget"
        if [ "$ROOT_INSTALL" = 1 ]; then
            apt-get -y remove libzmq*
            # Ubuntu dependencies (some people have libboost1.53-dev installed,
            # mine which is installed rather than error out.  Defaults onto 1.49)
            for BOOST_VER in 1.49 1.53 ; do
                dpkg -s "libboost$BOOST_VER-dev" >/dev/null 2>&1 && U_BOOST=$BOOST_VER
            done
            [[  $U_BOOST && ${U_BOOST-x} ]] && echo "Found libboost $U_BOOST" || export U_BOOST=1.49 ; echo "Defaulting to libboost $U_BOOST"

            apt-get -y --force-yes install $U_DEPENDENCIES
        else
            echo "Run this command before continuing:"
            echo
            echo "  sudo apt-get remove libzmq*"
            echo "  sudo apt-get -y --force-yes install $(strip_spaces $U_DEPENDENCIES)"
            echo
            continue_or_exit
        fi
    elif [ "$flavour_id" = "fedora" ]; then
        F_DEPENDENCIES="\
            gcc-c++ git autoconf libtool boost-devel pkgconfig \
            libcurl-devel openssl-devel leveldb-devel libconfig \
            libconfig-devel ncurses-devel wget"
        if [ "$ROOT_INSTALL" = 1 ]; then
            yum -y install $F_DEPENDENCIES
        else
            echo "Run this command before continuing:"
            echo
            echo "yum -y install $(strip_spaces $F_DEPENDENCIES)"
            echo
            continue_or_exit
        fi
    elif [ "$flavour_id" = "arch" ]; then
        A_DEPENDENCIES="\
            gcc git autoconf libtool boost pkg-config curl openssl \
            leveldb libconfig ncurses wget"
        if [ "$ROOT_INSTALL" = 1 ]; then
            pacman -S --asdeps --needed --noconfirm $A_DEPENDENCIES
        else
            echo "Run this command before continuing:"
            echo
            echo "pacman -S --asdeps --needed --noconfirm $(strip_spaces $A_DEPENDENCIES)"
            echo
            continue_or_exit
        fi
    else
        echo
        echo " [+] ERROR: GNU/Linux flavour not supported: $flavour_id" 1>&2
        echo 
        echo " Please, review the script."
        echo
        exit
    fi
}

install_libsecp256k1(){
    if [ $TOOLCHAIN_BRANCH_KEEP -eq 0 ]; then
	cd $SRC_DIR
	if [ -d "secp256k1-git" ]; then
            echo
            echo " --> Updating secp256k1..."
            echo
            cd secp256k1-git
            git remote set-url origin https://github.com/libbitcoin/secp256k1.git
            git pull --rebase
	else
            echo
            echo " --> Downloading secp256k1 from git..."
            echo
            git clone https://github.com/libbitcoin/secp256k1.git secp256k1-git -b version1
	fi
    fi

    cd $SRC_DIR/secp256k1-git
    echo
    echo " --> Beginning build process now...."
    echo
    autoreconf -i
    ./configure --prefix $INSTALL_PREFIX
    make -j $NCORE
    make install
    $RUN_LDCONFIG
    echo
    echo " o/ secp256k1 now installed."
    echo
}

install_libbitcoin(){
    if [ $TOOLCHAIN_BRANCH_KEEP -eq 0 ]; then
	cd $SRC_DIR
	if [ -d "libbitcoin-git" ]; then
            echo
            echo " --> Updating libbitcoin..."
            echo
            cd libbitcoin-git
            git remote set-url origin https://github.com/libbitcoin/libbitcoin.git
            git pull --rebase
	else
            echo
            echo " --> Downloading libbitcoin from git..."
            echo
            git clone https://github.com/libbitcoin/libbitcoin.git libbitcoin-git -b version1
	fi
    fi

    cd $SRC_DIR/libbitcoin-git
    echo
    echo " --> Beginning build process now...."
    echo
    [ $TOOLCHAIN_BRANCH_KEEP -eq 0 ] && git checkout $TOOLCHAIN_BRANCH
    autoreconf -i
    ./configure --enable-leveldb --prefix $INSTALL_PREFIX $TOOLCHAIN_TESTNET
    make -j $NCORE
    make install
    $RUN_LDCONFIG
    echo
    echo " o/ libbitcoin now installed."
    echo
}

install_libwallet(){
    if [ $TOOLCHAIN_BRANCH_KEEP -eq 0 ]; then
	cd $SRC_DIR
	if [ -d "libwallet-git" ]; then
            echo
            echo " --> Updating Libwallet..."
            echo
            cd libwallet-git
            git remote set-url origin https://github.com/spesmilo/libwallet.git
            git pull --rebase
	else
            echo
            echo " --> Downloading Libwallet from git..."
            echo
            git clone https://github.com/spesmilo/libwallet.git libwallet-git -b version1
	fi
    fi

    cd $SRC_DIR/libwallet-git
    echo
    echo " --> Beginning build process now...."
    echo
    [ $TOOLCHAIN_BRANCH_KEEP -eq 0 ] && git checkout $TOOLCHAIN_BRANCH
    autoreconf -i
    ./configure --prefix $INSTALL_PREFIX $TOOLCHAIN_TESTNET
    make -j $NCORE
    make install
    $RUN_LDCONFIG
    echo
    echo " o/ Libwallet now installed."
    echo
}

install_sx(){
    rm -rf $BIN_DIR/sx-*
    if [ $TOOLCHAIN_BRANCH_KEEP -eq 0 ]; then
	cd $SRC_DIR
	if [ -d "sx-git" ]; then
            echo
            echo " --> Updating SX..."
            echo
            cd sx-git
            git remote set-url origin https://github.com/spesmilo/sx.git
            git pull --rebase
	else
            echo
            echo " --> Downloading SX from git..."
            echo
            git clone https://github.com/spesmilo/sx.git sx-git -b version1
	fi
    fi

    cd $SRC_DIR/sx-git
    echo
    echo " --> Beginning build process now...."
    echo
    [ $TOOLCHAIN_BRANCH_KEEP -eq 0 ] && git checkout $TOOLCHAIN_BRANCH
    autoreconf -i
    ./configure --sysconfdir $CONF_DIR --prefix $INSTALL_PREFIX
    make -j $NCORE
    make install
    $RUN_LDCONFIG
    if [ "$flavour_id" = "arch" ]; then
        sed -i 's/python/python2/' $INSTALL_PREFIX/bin/sx
    fi
    echo
    echo " o/ SX tools now installed."
    echo
}

show_finish_install_info(){
    echo " --> Installation finished!"
    echo
    echo " Config Files are in: $CONF_DIR"
    echo "   sx configuration file: ~/.sx.cfg (see $INSTALL_PREFIX/share/sx/sx.cfg for an example config file)"
    echo
    echo " Documentation available in $INSTALL_PREFIX/share/doc:"
    echo "   libbitcoin: $INSTALL_PREFIX/share/doc/libbitcoin/"
    echo "   libwallet:  $INSTALL_PREFIX/share/doc/libwallet/"
    echo "   sx:         $INSTALL_PREFIX/share/doc/sx/"
    echo
    if [ "$ROOT_INSTALL" = "0" ]; then
        echo
        echo " Add these lines to your ~/.bashrc"
        echo "   export LD_LIBRARY_PATH=$TOOLCHAIN_LD_LIBRARY_PATH"
        echo "   export PKG_CONFIG_PATH=$TOOLCHAIN_PKG_CONFIG_PATH"
        echo "   export PATH=$BIN_DIR:\$PATH"
    fi
    echo
    echo " **************************************************************"
    echo " * libbitcoin and SX 1.0 are now installed!                   *"
    echo " * If you wish to upgrade to the latest versions, then        *"
    echo " * check out https://github.com/libbitcoin/                   *"
    echo " * SX is now renamed libbitcoin-explorer (BX)                 *"
    echo " **************************************************************"
    echo
}

install_dependencies
install_libsecp256k1
install_libbitcoin
install_libwallet
install_sx
show_finish_install_info

