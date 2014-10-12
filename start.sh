echo "|| Starting Hostapd ||"
killall hostapd
/usr/local/bin/hostapd -B /etc/hostapd/hostapd.conf