#!/bin/sh
# wget --no-check-certificate  https://gitlab.meganet.com.vn/great/wifi_servers_quality/-/raw/master/new_ap_installation.sh -O - -q | sh

###############################################################################################################################
###                                             MEGANET SYSTEM INFO
###############################################################################################################################

# Lay MAC address cua thiet bi hien tai
getCurrentAPMacAddress(){
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
		echo "Not detected MAC: $MAC on this model! Please contact sysadmin@meganet.com.vn for support this device." >&2; exit 1
	fi
}

# Lay MEGANET ID tren Demo MegaNet
getMeganetID()
{
	MEGANET_AP_ID=`wget --no-check-certificate -O - -q "https://demo.meganet.com.vn/api/Prometheus/getDevice?field=ap_number&device=$MAC"`

	if  [ -z "$MEGANET_AP_ID" ] ; then
	  printf "Not found this device on Meganet Portal. \n Please contact sysadmin@meganet.com.vn for free support." >&2; exit 1
	fi	
}

# Lay Local IP tren Demo MegaNet
getLocalNatIP()
{
	LOCAL_NAT_IP=`wget --no-check-certificate -O - -q "https://demo.meganet.com.vn/api/Prometheus/getDevice?field=ip_local&device=$MAC" | tr -d "\""`
	if  [ -z "${#LOCAL_NAT_IP}" ]
	then
	  echo "Cannot generate ip for connecting MegaNet Portal. Please contact sysadmin@meganet.com.vn for free support." >&2; exit 1
	fi
}


# Bat dau qua trinh cai dat
## Khoi tao gia tri
getCurrentAPMacAddress
getMeganetID
getLocalNatIP

## Print thong tin he thong
printf "\n
---------====[ MEGANET INSTALLATION ACCESS POINT PROGRAM ] ====---------

Your Mac Address: $MAC
Your Meganet ID: $MEGANET_AP_ID 
Your Local NAT IP: $LOCAL_NAT_IP \n\n\n"

echo "=================================================================================="
###############################################################################################################################
###                                             AUTO SSSH
###############################################################################################################################

isAutoSSHRunning()
{
    autoSSH_STATUS=`ps  | grep autossh | wc -l`
    if [ $autoSSH_STATUS -gt 1 ]
    then
        printf "AutoSSH: OK\n"
    else 
        /etc/init.d/autossh restart
        printf "AutoSSH: Restarted\n"
    fi
}

generateNewAutoSSHConfig()
{
    echo "config autossh
	option ssh	'-N -T
				-o StrictHostKeyChecking=no
				-o ServerAliveInterval=60
				-o ServerAliveCountMax=10
				-R $LOCAL_NAT_IP:2222:localhost:22 
				-R $LOCAL_NAT_IP:9100:localhost:9100
				-R $LOCAL_NAT_IP:7681:localhost:7681
                -i /etc/dropbear/id_rsa
				 noaccess@prometheus.meganet.com.vn'
	option gatetime	'0'
	option monitorport	'0'
	option poll	'600'
	option enabled	'1'" > /tmp/autossh
}

compareAutoSSHConfig()
{
    generateNewAutoSSHConfig
    currentAutoSSHConfig=`sha256sum /etc/config/autossh  | awk '{print $1}'`
    newAutoSSHConfig=`sha256sum /tmp/autossh  | awk '{print $1}'`
    if [ $currentAutoSSHConfig == $newAutoSSHConfig ]
    then
        echo "AutoSSH Config matched \n"
    else
        echo "Update new AutoSSH Config \n"
        mv /tmp/autossh /etc/config/autossh
    fi
}

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/autossh enable

# Setup AutoSSH
if [ -f "/etc/config/autossh" ]; 
then
    compareAutoSSHConfig
    
else 
    echo "Being generate new AutoSSH config file and put to /tmp/autossh"
    generateNewAutoSSHConfig
    mv /tmp/autossh/ /etc/config/
fi


# Kiem tra AutoSSH da chay chua?
isAutoSSHRunning

echo "=================================================================================="
###############################################################################################################################
###                                             NODE EXPORTER
###############################################################################################################################

isNodeExporterRunning()
{
    nodeExporter_STATUS=`netstat -nltp | grep 9100 | wc -l`
    if [ $nodeExporter_STATUS -gt 0 ]
    then
        printf "Node Exporter: OK\n"
    else 
        /etc/init.d/prometheus-node-exporter-lua restart
        printf "Node Exporter: Restarted\n"
    fi
}

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/prometheus-node-exporter-lua enable

# Kiem tra Node Exporter da chay chua?
isNodeExporterRunning

echo "=================================================================================="
###############################################################################################################################
###                                             PROMETHEUS SERVER
###############################################################################################################################

isPrometheuServerRunning()
{
    prometheusServer_STATUS=`wget --no-check-certificate -O - -q "https://demo.meganet.com.vn/api/Prometheus/getUpExporter?device=$LOCAL_NAT_IP"`
    if [ $prometheusServer_STATUS -eq 0 ]
    then
        /etc/init.d/prometheus-node-exporter-lua restart
        /etc/init.d/autossh restart
        printf "Node Exporter & AutoSSH: Restarted\n"
    else
        printf "Prometheus Server: OK\n"
    fi
}

# Kiem tra phan mem giam sat da chay chua?
isPrometheuServerRunning

echo "=================================================================================="
###############################################################################################################################
###                                             TTYD
###############################################################################################################################

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/ttyd enable

isTTYDRunning()
{
    TTYD_STATUS=`netstat -nltp  | grep 7681 | wc -l `
    if [ $TTYD_STATUS -gt 0 ]
    then
        printf "TTYD: OK\n"
    else 
        /etc/init.d/ttyd restart
        printf "TTYD: Restarted\n"
    fi
}

generateNewTTYDConfig()
{
    
    echo "config ttyd
	option interface '@loopback'
	option command '/bin/sh -l'
" > /tmp/ttyd
}

compareTTYDConfig()
{
    generateNewTTYDConfig
    currentTTYDConfig=`sha256sum /etc/config/ttyd  | awk '{print $1}'`
    newTTYDConfig=`sha256sum /tmp/ttyd  | awk '{print $1}'`
    if [ $currentTTYDConfig == $newTTYDConfig ]
    then
        echo "TTYD Config matched\n"
    else
        echo "Update new TTYD Config\n"
        mv /tmp/ttyd /etc/config/ttyd
    fi
}

# Setup TTYD
if [ -f "/etc/config/ttyd" ]; 
then
    compareTTYDConfig
else 
    echo "Being generate new TTYD config file and put to /tmp/ttyd"
    generateNewTTYDConfig
    mv /tmp/ttyd /etc/config/
fi

# Kiem tra TTYD da chay chua?
isTTYDRunning

echo "=================================================================================="
###############################################################################################################################
###                                             CRONTAB
###############################################################################################################################

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/cron enable

isCrontabRunning()
{
    cron_STATUS=`ps  | grep crond | wc -l `
    if [ $cron_STATUS -gt 0 ]
    then
        printf "Crontabs: OK\n"
    else
        /etc/init.d/cron restart
        printf "Crontabs: Restarted\n"
    fi
}

# Kiem tra Crontab da chay chua?
isCrontabRunning

echo "=================================================================================="
###############################################################################################################################
###                                             MEGANET SCRIPT
###############################################################################################################################

generateNewMeganetScript()
{
    wget --no-check-certificate https://raw.githubusercontent.com/sumeganet/access-point/main/meganet.sh -O /tmp/meganet.sh -q 
}

compareMeganetScript()
{
    generateNewMeganetScript
    currentMeganetScript=`sha256sum /www/meganet.sh  | awk '{print $1}'`
    newMeganetScript=`sha256sum /tmp/meganet.sh  | awk '{print $1}'`
    if [ $currentMeganetScript == $newMeganetScript ]
    then
        echo "Meganet Script matched\n"
    else
        echo "Update new Meganet Script\n"
        mv /tmp/ttyd /etc/config/ttyd
    fi
}

# Setup Meganet Script
if [ -f "/www/meganet.sh" ]; 
then
    compareMeganetScript
else 
    echo "Being download new MegaNet script and put to /tmp/meganet.sh"
    generateNewMeganetScript
    mv /tmp/meganet.sh /www/meganet.sh
fi

echo "=================================================================================="
printf "---------==============[ INSTALLATION COMPLETED! ] =================---------\n"

isAutoSSHRunning #?
isNodeExporterRunning #? 
isPrometheuServerRunning #?
isTTYDRunning #? 
isCrontabRunning #?

printf "\nNote: Please reboot AP to make sure everything working exacely!!\n"
