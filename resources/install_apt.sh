#!/bin/bash

# This file is part of Plugin openzwave for jeedom.
#
#  Plugin openzwave for jeedom is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  Plugin openzwave for jeedom is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Plugin openzwave for jeedom. If not, see <http://www.gnu.org/licenses/>.

#set -x  # make sure each command is printed in the terminal
PROGRESS_FILE=/tmp/jeedom/openzwave/dependance
touch ${PROGRESS_FILE}
echo 0 > ${PROGRESS_FILE}
echo "Lancement de l'installation/mise à jour des dépendances openzwave"

BASEDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

function apt_install {
  sudo apt-get -y install "$@"
  if [ $? -ne 0 ]; then
    echo "could not install $1 - abort"
    rm ${PROGRESS_FILE}
    exit 1
  fi
}

function pip_install {
  sudo pip install "$@"
  if [ $? -ne 0 ]; then
    echo "could not install $p - abort"
    rm ${PROGRESS_FILE}
    exit 1
  fi
}

if [ $(ps ax | grep z-way-server | grep -v grep | wc -l ) -ne 0 ]; then
  echo "Désactivation du z-way-server"
  sudo service z-way-server stop
  sudo service mongoose stop
  sudo service zbw_connect stop
  sudo update-rc.d -f z-way-server remove
  sudo update-rc.d -f mongoose remove
  sudo update-rc.d -f zbw_connect remove
  ps aux | grep mongoose | awk '{print $2}' | xargs kill -9
  ps aux | grep z-way-server | awk '{print $2}' | xargs kill -9 
  ps aux | grep zbw_connect | awk '{print $2}' | xargs kill -9 
  sudo rm -rf /opt/z-way-server*
fi

if [ ! -d /opt ]; then
  sudo mkdir /opt
fi
echo 10 > ${PROGRESS_FILE}
sudo rm -f /var/lib/dpkg/updates/*
sudo apt-get clean
echo 20 > ${PROGRESS_FILE}
sudo apt-get update
echo 30 > ${PROGRESS_FILE}
echo "Installation des dependances"
apt_install git python3-pip python-dev python3-pyudev python-setuptools python3-louie make build-essential libudev-dev g++ gcc python-lxml unzip libjpeg-dev python3-serial python3-requests
echo 40 > ${PROGRESS_FILE}
# Python
echo "Installation des dependances Python"
pip_install urwid
echo 45 > ${PROGRESS_FILE}
pip_install louie
echo 46 > ${PROGRESS_FILE}
pip_install six
echo 47 > ${PROGRESS_FILE}
pip_install tornado
echo 48 > ${PROGRESS_FILE}

sudo mkdir /opt
if [ -d /opt/python-openzwave ]; then
  cd /opt/python-openzwave
  echo "Désinstallation de la version précédente";
  sudo make uninstall > /dev/null 2>&1
  echo 55 > ${PROGRESS_FILE}
  sudo rm -rf /usr/local/lib/python2.7/dist-packages/libopenzwave*
  sudo rm -rf /usr/local/lib/python2.7/dist-packages/openzwave* 
  cd /opt
  sudo rm -rf /opt/python-openzwave
fi

echo "Installation de Python-OpenZwave"
cd /opt
cp -R ${BASEDIR}/python-openzwave python-openzwave
if [ $? -ne 0 ]; then
  echo "Unable to copy python-openzwave source"
  rm ${PROGRESS_FILE}
  exit 1
fi
echo 60 > ${PROGRESS_FILE}
cd python-openzwave
sudo pip uninstall -y Cython
cd /opt/python-openzwave
sudo rm /opt/python-openzwave/openzwave/cpp/src/command_classes/MultiInstanceAssociation.* > /dev/null 2>&1
sudo make cython-deps
echo 65 > ${PROGRESS_FILE}
sudo make repo-deps
echo 70 > ${PROGRESS_FILE}
cp -R ${BASEDIR}/python-openzwave/openzwave openzwave
if [ $? -ne 0 ]; then
  echo "Unable to copy openzwave"
  rm ${PROGRESS_FILE}
  exit 1
fi
echo 75 > ${PROGRESS_FILE}
cd /opt/python-openzwave
mkdir /opt/python-openzwave/.git
sudo make install-api
echo 80 > ${PROGRESS_FILE}
sudo mkdir /opt/python-openzwave/python-eggs
sudo chown -R www-data:www-data /opt/python-openzwave
sudo chmod -R 777 /opt/python-openzwave
echo 90 > ${PROGRESS_FILE}
if [ -e /dev/ttyAMA0 ];  then 
  sudo sed -i 's/console=ttyAMA0,115200//; s/kgdboc=ttyAMA0,115200//' /boot/cmdline.txt
  sudo sed -i 's|[^:]*:[^:]*:respawn:/sbin/getty[^:]*ttyAMA0[^:]*||' /etc/inittab
fi

if [ -e /dev/ttymxc0 ];  then 
  sudo systemctl mask serial-getty@ttymxc0.service
  sudo systemctl stop serial-getty@ttymxc0.service
fi
if [ -e /dev/ttyAMA0 ];  then 
  sudo systemctl mask serial-getty@ttyAMA0.service
  sudo systemctl stop serial-getty@ttyAMA0.service
fi

RPI_BOARD_REVISION=`grep Revision /proc/cpuinfo | cut -d: -f2 | tr -d " "`
if [[ $RPI_BOARD_REVISION ==  "a02082" || $RPI_BOARD_REVISION == "a22082" || $RPI_BOARD_REVISION == "a020d3" ]]
then
   systemctl disable hciuart
   if [[ ! `grep "dtoverlay=pi3-miniuart-bt" /boot/config.txt` ]]
   then
      echo "Raspberry Pi 3 Detected. If you use a Razberry board you must Disabling Bluetooth"
      echo "Please add 'dtoverlay=pi3-miniuart-bt' to the end of the file /boot/config.txt"
      echo "And reboot your Raspberry Pi"
   fi
fi
echo 100 > ${PROGRESS_FILE}
echo "Everything is successfully installed!"
rm ${PROGRESS_FILE}

