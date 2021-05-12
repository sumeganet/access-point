#!/bin/sh
# Contribute: https://github.com/sumeganet/access-point/edit/main/meganet.sh

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

echo "===============================  AUTOSSH   ============================================="
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
        /etc/init.d/autossh reload
        printf "AutoSSH: Reloaded \n"
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
                -p 10422
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
        printf "AutoSSH Config matched \n"
    else
        printf "Update new AutoSSH Config \n"
        mv /tmp/autossh /etc/config/autossh
    fi
}

# Setup AutoSSH
nodeExporter_STATUS=`opkg list-installed | grep autossh | wc -l`
if [ $nodeExporter_STATUS -eq 1 ]
then
    printf "AutoSSH: OK\n"
else 
    /etc/init.d/prometheus-node-exporter-lua reload
    /etc/init.d/autossh reload
    /etc/init.d/network reload
    printf "AutoSSH: Reloaded\n"
fi


if [ -f "/etc/config/autossh" ]; 
then
    compareAutoSSHConfig
    
else 
    printf "Being generate new AutoSSH config file and put to /tmp/autossh"
    generateNewAutoSSHConfig
    mv /tmp/autossh /etc/config/
fi

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/autossh enable

# Kiem tra AutoSSH da chay chua?
isAutoSSHRunning

echo "===============================  NODE EXPORTER   ============================================="
###############################################################################################################################
###                                             NODE EXPORTER
###############################################################################################################################

isNodeExporterRunning()
{
    nodeExporter_STATUS=`netstat -nltp | grep 9100 | wc -l`
    if [ $nodeExporter_STATUS -eq 1 ]
    then
        printf "Node Exporter: OK\n"
    else 
        /etc/init.d/prometheus-node-exporter-lua reload
        printf "Node Exporter: Reloaded\n"
    fi
}

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/prometheus-node-exporter-lua enable

# Kiem tra Node Exporter da chay chua?
isNodeExporterRunning

echo "===============================  PROMETHEUS SERVER   ==========================================="
###############################################################################################################################
###                                             PROMETHEUS SERVER
###############################################################################################################################

isPrometheuServerRunning()
{
    prometheusServer_STATUS=`wget --no-check-certificate -O - -q "https://demo.meganet.com.vn/api/Prometheus/getUpExporter?device=$LOCAL_NAT_IP"`
    if [ $prometheusServer_STATUS -eq 0 ]
    then
        /etc/init.d/prometheus-node-exporter-lua reload
        /etc/init.d/network reload
        printf "Connection is reloaded\n"
    else
        printf "Prometheus Server: OK\n"
    fi
}

# Kiem tra phan mem giam sat da chay chua?dd
isPrometheuServerRunning

echo "===============================  TTYD   ==================================================="
###############################################################################################################################
###                                             TTYD
###############################################################################################################################



isTTYDRunning()
{
    TTYD_STATUS=`netstat -nltp  | grep 127.0.0.1:7681 | wc -l`
    if [ $TTYD_STATUS -gt 0 ]
    then
        printf "TTYD: OK\n"
    else 
        /etc/init.d/ttyd reload
        printf "TTYD: Reloaded\n"
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
        printf "TTYD Config matched\n"
    else
        printf "Update new TTYD Config\n"
        mv /tmp/ttyd /etc/config/ttyd
    fi
}

# Setup TTYD
if [ -f "/etc/config/ttyd" ]; 
then
    compareTTYDConfig
else 
    printf "Being generate new TTYD config file and put to /tmp/ttyd"
    generateNewTTYDConfig
    mv /tmp/ttyd /etc/config/
fi

# Dam bao rang khi reboot, dich vu duoc khoi dong theo
/etc/init.d/ttyd enable

# Kiem tra TTYD da chay chua?
isTTYDRunning

echo "===============================  CRONTAB   ============================================="
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
        /etc/init.d/cron reload
        printf "Crontabs: Reloaded\n"
    fi
}

# Kiem tra Crontab da chay chua?
isCrontabRunning

echo "===============================  OpenNDS   ============================================="
###############################################################################################################################
###                                             OpenNDS
###############################################################################################################################

# Dam bao rang khi reboot, dich vu duoc khoi dong theo


isOpenNDSRunning()
{
    cron_STATUS=`ndsctl status | grep "openNDS Status" | wc -l`
    if [ $cron_STATUS -gt 0 ]
    then
        printf "openNDS: OK\n"
    else
        /usr/sbin/ipset create openndsset hash:ip
        /etc/init.d/odhcpd reload 
        /etc/init.d/firewall reload
        /etc/init.d/network reload
        /etc/init.d/opennds reload
        printf "openNDS: Reloaded\n"
    fi
}

# Kiem tra Crontab da chay chua?
isOpenNDSRunning

echo "===============================  MEGANET SCRIPT   ============================================="
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
    currentMeganetScript=`sha256sum /etc/meganet.sh  | awk '{print $1}'`
    newMeganetScript=`sha256sum /tmp/meganet.sh  | awk '{print $1}'`
    if [ $currentMeganetScript == $newMeganetScript ]
    then
        printf "Meganet Script matched\n"
    else
        printf "Update new Meganet Script\n"
        mv /tmp/meganet.sh /etc/conmeganet.sh
    fi
}

# Setup Meganet Script
if [ -f "/etc/meganet.sh" ]; 
then
    compareMeganetScript
else 
    echo "Being download new MegaNet script and put to /tmp/meganet.sh"
    generateNewMeganetScript
    mv /tmp/meganet.sh /etc/meganet.sh
fi

echo "=================================================================================="
printf "---------==============[ INSTALLATION COMPLETED! ] =================---------\n"

isAutoSSHRunning #?
isNodeExporterRunning #? 
isPrometheuServerRunning #?
isTTYDRunning #? 
isCrontabRunning #?
isOpenNDSRunning #?

printf "\nNote: Please reboot AP to make sure everything working exacely!!\n"
