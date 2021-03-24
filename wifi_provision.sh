#!/bin/sh
# wget --no-check-certificate  https://gitlab.meganet.com.vn/great/wifi_servers_quality/-/raw/master/new_ap_installation.sh -O - -q | sh

# MAC ADDRESS
currentAPMacAddress(){
	## Mac should be in br-lan or br-wan
	local MAC_BRLAN=`ifconfig | grep br-lan | awk '{print $5}'` 
	local MAC_BRWAN=`ifconfig | grep br-wan | awk '{print $5}'` 

	if [ "${#MAC_BRLAN}" -gt 1 ]                                       
	then                                                   
	    MAC=$MAC_BRLAN
	elif [ "${#MAC_BRWAN}" -gt 1 ]
	then
		MAC=$MAC_BRWAN
	else
		echo "Not detected MAC: $MAC on this model! Please contact vancuong.phan@meganet.com.vn for support this device." >&2; exit 1
	fi
}

# MEGANET ID
getMeganetID()
{
	MEGANET_AP_ID=`wget --no-check-certificate -O - -q "https://demo.meganet.com.vn/api/Prometheus/getDevice?field=ap_number&device=$MAC"`

	if  [ -z "$MEGANET_AP_ID" ] ; then
	  printf "Not found this device on Meganet Portal. \n Please contact vancuong.phan@meganet.com.vn for free support." >&2; exit 1
	fi	
}

# LOCAL NAT IP
getLocalNatIP()
{
	LOCAL_NAT_IP=`wget --no-check-certificate -O - -q "https://demo.meganet.com.vn/api/Prometheus/getDevice?field=ip_local&device=$MAC" | tr -d "\""`
	if  [ -z "${#LOCAL_NAT_IP}" ]
	then
	  echo "Cannot generate ip for connecting MegaNet Portal. Please contact vancuong.phan@meganet.com.vn for free support." >&2; exit 1
	fi
}

statusAutoSSH()
{
	local STATUS=`ps  | grep autossh | wc -l`
	if [ $STATUS -gt 1 ]
	then
		printf "\nSSH: OK\n"
	else 
		printf "\nSSH: Not OK\n"
	fi
}
statusNodeExporter()
{
	local STATUS=`netstat -nltp | grep 9100 | wc -l`
	if [ $STATUS -gt 0 ]
	then
		printf "Node Exporter: OK\n"
	else 
		printf "Node Exporter: Not OK\n"
	fi
}
statusMonitoring()
{
	local STATUS=`cat /etc/crontabs/root | grep 00_meganet_monitoring.sh | wc -l`
	if [ $STATUS -gt 0 ]
	then
		printf "Monitoring: OK\n"
	else 
		printf "Monitoring: Not OK\n"
	fi
}
statusTTYD()
{
	local STATUS=`netstat -nltp  | grep 7681 | wc -l `
	if [ $STATUS -gt 0 ]
	then
		printf "TTYD: OK\n"
	else 
		printf "TTYD: Not OK\n"
	fi
}

printOnlyEqual()
{
	printf "\n=====================================================================\n"
}

# STARTING PROCESS INSTALLATION
## INIT ALL FUNCTION
currentAPMacAddress
getMeganetID
getLocalNatIP

## Print System Information to user

printf "\n
---------====[ MEGANET INSTALLATION ACCESS POINT PROGRAM ] ====---------

Your Mac Address: $MAC
Your Meganet ID: $MEGANET_AP_ID 
Your Local NAT IP: $LOCAL_NAT_IP \n"

## Hostname Setup ##
printOnlyEqual
printf "\n---------====[ SETTING HOSTNAME FOR THIS DEVICE ] ====---------\n"
### Hostname is MEGANET_AP_ID
uci set system.@system[0].hostname=$MEGANET_AP_ID
printf "\nuci set system hostname: OK!\n"
uci commit system
printf "\nuci commit system hostname: OK!\n"
echo $(uci get system.@system[0].hostname) > /proc/sys/kernel/hostname
printf "\nset kernel hostname: OK!\n"

### Print message to user
printf "\nYOUR HOSTNAME: `cat /proc/sys/kernel/hostname`\n"
printf "\nSETUP HOSTNAME HAS COMPLETED!\n"

## Repository Setup ##
printOnlyEqual
printf "\n---------====[ SETTING REPOSITORY FOR THIS DEVICE ] ====---------\n"
### Backup current repository
cp /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.`date +"%Y-%m-%d_%H-%M-%S"`
printf "\nBackup current repository: OK!\n"
### Update new repository
echo "src/gz openwrt_core http://downloads.openwrt.org/releases/19.07.5/targets/ath79/generic/packages
src/gz openwrt_kmods http://downloads.openwrt.org/releases/19.07.5/targets/ath79/generic/kmods/4.14.209-1-b84a5a29b1d5ae1dc33ccf9ba292ca1d
src/gz openwrt_base http://downloads.openwrt.org/releases/19.07.5/packages/mips_24kc/base
src/gz openwrt_freifunk http://downloads.openwrt.org/releases/19.07.5/packages/mips_24kc/freifunk
src/gz openwrt_luci http://downloads.openwrt.org/releases/19.07.5/packages/mips_24kc/luci
src/gz openwrt_packages http://downloads.openwrt.org/releases/19.07.5/packages/mips_24kc/packages
src/gz openwrt_routing http://downloads.openwrt.org/releases/19.07.5/packages/mips_24kc/routing
src/gz openwrt_telephony http://downloads.openwrt.org/releases/19.07.5/packages/mips_24kc/telephony" > /etc/opkg/distfeeds.conf
printf "\nupdate new repository: OK!\n\n"

opkg update
printf "\n\nRun update new repository: OK!\n"

printf "\nSETUP REPOSITORY HAS COMPLETED!\n"

## Repository Setup ##
printOnlyEqual
printf "\n---------====[ SETTING LIBRARY AND PACKAGES FOR THIS DEVICE ] ====---------\n"
### Install packges - this one depending on ## Repository Setup ## Part
opkg install prometheus-node-exporter-lua-nat_traffic prometheus-node-exporter-lua-netstat prometheus-node-exporter-lua-openwrt prometheus-node-exporter-lua-textfile prometheus-node-exporter-lua-wifi prometheus-node-exporter-lua-wifi_stations autossh ttyd
printf "\nInstall packages from new repository: OK!\n"
### Restart service and enable (run when reboot device)
/etc/init.d/prometheus-node-exporter-lua enable
/etc/init.d/prometheus-node-exporter-lua restart
printf "\nStart services and auto startup attaching: OK!\n"
printf "\nSETUP REPOSITORY HAS COMPLETED!\n"

## Setup Access in
printOnlyEqual
printf "\n---------====[ SETTING ACCESS IN ] ====---------\n"
mkdir -p /root/.ssh
printf "\nCreate authorized folder: OK\n"
touch /root/.ssh/authorized_keys
printf "\nCreate authorized file: OK\n"
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC437Fne1EH7fBQ6SfIYZUIolJf9FxwVCG4PnabznhhAXPzUYzHkMusoTiRTmoddUg66ru2vGxJvI/w3Q/6Qtf83l00UYXH26C4KMdDlGDgOMS8TveAR4Zud01OBRl+KfEJV3f8O1GRpJt6PVBEihG/rtYZNmi8jSDoFAVgw+XRnLgM3S6w+CZCPpqQNxS75n3NiL6ciZQNUR0CdS/c+hdQQdPO1fyTMBVuZk09EdPvzEyhp7tmJxTrtX7F74s4DYwjjVujeCGXLEvZOa1lAWLbrfWex3O2h+Sqy5D8gRXXoWdB+ftDVJh+KjG2dmzhsrXXQFYfB496kGL6U2xV9Zn7 access_in" > /root/.ssh/authorized_keys
printf "\nSetup key for access in: OK\n"
chmod 700 /root/.ssh/
chmod 600 /root/.ssh/authorized_keys
printf "\nSet security permission for authorized folder and file: OK\n"
printf "\nSETUP ACCESS [IN] HAS COMPLETED!\n"

## Setup Access out
printOnlyEqual
printf "\n---------====[ SETTING ACCESS OUT ] ====---------\n"
echo "-----BEGIN RSA PRIVATE KEY-----
MIIEogIBAAKCAQEAvMeMiLzdSh4qKqovSWoVIGTfQm97F6Qpqb/AYmV7ehj7iRNM
MLxaPI/nPJcZvGL/7p4S8vD8kIkjD8HIUggINm9Ng9SFYfFlG1yJDqnTQxeWkMdN
nT32hPV0SanNx/OS+4eYzR4nvwMerrYT3CPhfHQ/JGUSTo97J3r9+kve0NxvamsF
qobxsr9gjnG5mCgPnQDNTEmtRh4nTAjyJLmZo3AOouMLh9UXNd5Hv45skxRRJuF3
9kuGxy/YKRTpBwjdLul08J+lRmbrNrSrAeZeAsdMa+TAhhkp0ikgxVB2oFoCfuRl
FhTCfcu+6itSIO5GwLgxXh/uJuPTg2Qq35lswQIDAQABAoIBAAJdaZhI7WjBSfvw
19jOmGcofFeDuAIKz27N9SYGaW6VI4mLEVhG88ZwcxAiQHNItjYSCuC6Ph+9aBAJ
eG32pcuwx0LQhb89W+vk0964J+peQEeeB43hudXekU9e7jIEDiJSh4qCRzMwYdEE
fOk0Fd4OQsA89+a+C2fqNYZOLwNkygp0lxGuaM8ZKuDHgkRKZJYGd8V8GltMiVID
+LT5I4+0PYtT77a1G1GZ6itSb60mcPtFWU/X4I/U1MSvc+jJCzJFP8qEe3caBG1p
+J1aZAplSAN5IUE2l7/PEyCvxDL9FCbvHmdTrTQ9a8JyHGQJwTWcfk30HHJ71Zi8
ng94DOUCgYEA3VDS9cZRxZsmr7jm+A4mrIoevu/p/2vYbhE9fyxuQG0rC1gK5iRY
b/Mdtzn5+3oFXZT/e07FfFtERPGkp/yC6FgfNUpjzTDnWW4Hv9JO9UYSQKcn+x8v
/vlkLbxBRXmkUwnf7WOGeBsjjMznlHdkpctcBBF9O1CmwTWbp762/YMCgYEA2l1f
dcUwV5aDLtLtRm9Loy1e2G5/iJ8PliJh1JXPFFmRBKyatJ9pUAstJc6q5Jktd958
dyNBUKu4QBzdhAHOnW7RFt/Vkv2mYaFDNFx9t7Fhqe9pSiDMzcz5qnT69avEm88M
KFuI0vx/qPUUtTJhBABdwySX+M9KdFjxHIOx/WsCgYBUyeZIqtYhMrO7lsdGOYWv
jKsC079+T773TDuXQVpr7GcVTYG/ciU/npC/5cJUCgeMNs06XI9keULKdxlyElfE
1B4AuKNLtXSs2m61mskNRu8vPdsfZm9o6/rpWrpW96dw+NOFix+1XBBenRIL20IA
Es0J8flchCWe1/7uYS6SKQKBgGq9B6OGvwmhbgBeZFNwpbVewSTkZny+25yUs+N5
Ux7sZSG2yWyPG6hfvjLj4c8aPQqB+6800YGAXvEf6vvS8k8sUxJuWXSffkvsyu/2
YhF/qHCrsXjlrZbPoh67Tcz2qIVM4PF9RNV1TWWmXvfvZ1LQZwSzh4G8ufVDYKCC
k2d/AoGAQtgUlN8l5psZfrgFoAOkwphvp50sE61Sxww1HO+qVaWlEp3119C6iLwD
KiKe84SGAFj/UwumtFYz4bzAqBYVcbQZvzZ2MK2nEjaDSI59Br7aQlthEMg2BEXM
AVN26KwjzDRbQZAPf497+/gH8YuikvJKdzu01rO4riQNYSQALVw=
-----END RSA PRIVATE KEY-----" > /root/.ssh/id_rsa
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8x4yIvN1KHioqqi9JahUgZN9Cb3sXpCmpv8BiZXt6GPuJE0wwvFo8j+c8lxm8Yv/unhLy8PyQiSMPwchSCAg2b02D1IVh8WUbXIkOqdNDF5aQx02dPfaE9XRJqc3H85L7h5jNHie/Ax6uthPcI+F8dD8kZRJOj3snev36S97Q3G9qawWqhvGyv2COcbmYKA+dAM1MSa1GHidMCPIkuZmjcA6i4wuH1Rc13ke/jmyTFFEm4Xf2S4bHL9gpFOkHCN0u6XTwn6VGZus2tKsB5l4Cx0xr5MCGGSnSKSDFUHagWgJ+5GUWFMJ9y77qK1Ig7kbAuDFeH+4m49ODZCrfmWzB wifi_devices" > /root/.ssh/id_rsa.pub
printf "Setup key for access out: OK\n"
chmod 600 /root/.ssh/id_rsa
printf "\nSet security permission for authorized file: OK\n"

printf "\nSETUP ACCESS [OUT] HAS COMPLETED!\n"

## Setup Access out
printOnlyEqual
printf "\n---------====[ SETTING AUTO SSH CONNECTION ] ====---------\n"
echo "config autossh
	option ssh	'-N -T
				-o StrictHostKeyChecking=no
				-o ServerAliveInterval=60
				-o ServerAliveCountMax=10
				-R $LOCAL_NAT_IP:2222:localhost:22 
				-R $LOCAL_NAT_IP:9100:localhost:9100
				-R $LOCAL_NAT_IP:7681:localhost:7681
				 noaccess@ip1.meganet.com.vn'
	option gatetime	'0'
	option monitorport	'0'
	option poll	'600'
	option enabled	'1'" > /etc/config/autossh

printf "\nSetup config auto ssh connection: OK \n"
/etc/init.d/autossh start # Reboot instead restart service!
/etc/init.d/autossh enable
printf "\nStart service and auto startup attaching: OK!\n"

printf "\nSETUP AUTO SSH HAS COMPLETED!\n"

## Setup TTYD
printOnlyEqual
printf "\n---------====[ SETTING TTYD ] ====---------\n"
echo "config ttyd
	option interface '@loopback'
	option command '/bin/sh -l'
" > /etc/config/ttyd
printf "\nSetup config ttyd: OK \n"
/etc/init.d/ttyd restart
/etc/init.d/ttyd enable
printf "\nStart service and auto startup attaching: OK!\n"

printf "SETUP AUTO SSH HAS COMPLETED!\n"

## Setup MONITORING
printOnlyEqual
printf "\n---------====[ SETTING MONITORING CONNECTION ] ====---------\n"

### Check exist monitoring cron?
MONITOR_EXIST=`cat /etc/crontabs/root | grep 00_meganet_monitoring.sh | wc -l`

if [ $MONITOR_EXIST -eq 0 ]
then
	printf "\n Monitor doesn't exist. Starting generate brand new & add to crontab!\n"

    echo "STATUS=\`wget --no-check-certificate -O - -q 'https://demo.meganet.com.vn/api/Prometheus/getUpExporter?device=$LOCAL_NAT_IP'\`
if [ \$STATUS -eq 0 ]
then
    printf 'Monitoring detect services down!\n'
    /etc/init.d/prometheus-node-exporter-lua restart
    /etc/init.d/autossh restart
    printf 'Restart services has completed!\n'
else
    printf 'Monitoring script is ok!'
fi
" > /tmp/00_meganet_monitoring.sh
	printf "\nGenerate monitoring srcipt: OK \n"
    echo "5 * * * * /bin/sh /tmp/00_meganet_monitoring.sh" >> /etc/crontabs/root
    printf "\nCrontab added: OK \n"
    # Restart service
    /etc/init.d/cron restart
    /etc/init.d/cron enable
    printf "\nStart service and auto startup attaching: OK!\n"
else
    printf "\nCrontab has already added monitoring, we don't need to add this one anymore.\n"
fi

sh /tmp/00_meganet_monitoring.sh
printf "\nFinally testing monitoring: OK"
printf "\nSETUP MONITORING HAS COMPLETED!\n"

##################### FINAL CHECKOUT PRINT STATUS PACKAGES ############################
printOnlyEqual
printf "\n---------====[ FINAL CHECKOUT PRINT STATUS SERVICES ] ====---------\n"

statusAutoSSH
statusNodeExporter
statusMonitoring
statusTTYD

printf "=========== INSTALLATION COMPLETED! ============\n"
printf "Note: Please reboot AP to make sure everything working exacely!!\n"
