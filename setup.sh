echo "This is a development version and will not do anything real! Go away if you're not one of the developers!"
sleep 3

#Old backup found? (Mostly when i'm debugging)
if [ -f ~/.rpiwifi/interfaces.backup ]
then
cp -f ~/.rpiwifi/interfaces.backup /etc/network/interfaces
fi

#
# Install the dhcp server and download other needed scripts and configure them too!
#

apt-get install -y git libssl-dev libnl-dev iw bridge-utils
apt-get remove -y ifplugd
rm -f /etc/dhcp/dhcpd.conf
wget -O /etc/dhcp/dhcpd.conf http://www.bartstuff.eu/rpiwifi/dhcp.conf
service dnsmasq stop
rm -f /etc/dnsmasq.conf
wget -O /etc/dnsmasq.conf http://www.bartstuff.eu/rpiwifi/dnsmasq.conf
mkdir ~/.rpiwifi

#changedhcp is not needed as there is no dhcp server ready to be used with PiFi (yet)

#rm -f ~/.rpiwifi/changedhcp.sh
#wget -O ~/.rpiwifi/changehcp.sh http://www.bartstuff.eu/rpiwifi/changedhcp.sh
#chmod +x ~/.rpiwifi/changedhcp.sh
rm -f ~/.rpiwifi/changewifi.sh
wget -O ~/.rpiwifi/changewifi.sh http://www.bartstuff.eu/rpiwifi/changewifi.sh
chmod +x ~/.rpiwifi/changewifi.sh
#~/.rpiwifi/changedhcp.sh 192.168.10.10 192.168.10.50 12h 8.8.8.8 8.8.4.4
ifdown --force wlan0 #Just be sure its down
cp -f /etc/network/interfaces ~/.rpiwifi/interfaces.backup

#
# Setup br0
#

ipaddress=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}'`
netmask=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f4 | awk '{ print $1}'`
broadcast=`/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f3 | awk '{ print $1}'`
gateway=`route -n | grep 'UG[ \t]' | awk '{print $2}'`


printf "auto lo\n\niface lo inet loopback\nauto br0\niface br0 inet static\naddress %s\nnetmask %s\nbroadcast %s\ngateway %s\nbridge-ports eth0 wlan0" $ipaddress $netmask $broadcast $gateway > /etc/network/interfaces

#
# Old way of setting wlan0, not needed anymore with br0
#

#echo "iface wlan0 inet static" >> /etc/network/interfaces
#echo "address 192.168.10.1" >> /etc/network/interfaces
#echo "netmask 255.255.255.0" >> /etc/network/interfaces


#
#Get hostapd and compile it
#

wget -O /tmp/hostapd-2.3.tar.gz http://w1.fi/releases/hostapd-2.3.tar.gz
cd /tmp
tar -zxvf /tmp/hostapd-2.3.tar.gz
cd /tmp/hostapd-2.3/hostapd
cp defconfig .config
sudo make
sudo make install
mkdir /etc/hostapd/
~/.rpiwifi/changewifi.sh raspberry 1 1 0 12345678 WPA-PSK TKIP CCMP nl80211 g 100
echo "/usr/local/bin/hostapd -B /etc/hostapd/hostapd.conf\nexit 0" > /etc/rc.local


#
# Configure ip forwarding and iptable rules
#

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables --flush
sudo iptables --table nat --flush
sudo iptables --delete-chain
sudo iptables --table nat --delete-chain
sudo iptables --table nat --append POSTROUTING --out-interface eth0 -j MASQUERADE
sudo iptables --append FORWARD --in-interface wlan0 -j ACCEPT


#
# Restart the services
#

#echo "\n||| RESTARTING DHCP |||\n"
#service dnsmasq restart
echo "\n||| RESTARTING WIFI |||\n"
killall hostapd
ifdown wlan0 #Should have happend already, but just to be on the safe side
/usr/local/bin/hostapd -B /etc/hostapd/hostapd.conf
echo "\n||| RESTARTING OS |||\n** Connectable after reboot\n**SSID: raspberry\n**Password: 12345678"
sleep 5
reboot
