#!/bin/bash

# 修改cobbler配置

# 配置DHCP相关IP地址
SUBNET="192.168."

if [ ! -d "/ISO" ]; then
    echo "directory \"/ISO/\" not exists"
    exit 1
fi

function prefix_to_mask() {
    rpm -q --whatprovides bc >/dev/null 2>&1
    [ $? -ne 0 ] && yum install bc -y >/dev/null 2>&1

    bin_prefix=""
    prefix_cnt1=${1}
    for i in $(seq 1 ${prefix_cnt1}); do
        bin_prefix="${bin_prefix}1"
    done
    prefix_cnt2=$((32 - ${prefix_cnt1}))
    for i in $(seq 1 ${prefix_cnt2}); do
        bin_prefix="${bin_prefix}0"
    done

    INTERNAL_mask=""
    for i in $(seq 0 8 31); do
        val=${bin_prefix:${i}:8}
        tmp_mask=$(echo "obase=10;ibase=2;${val}" | bc)
        if [ "${INTERNAL_mask}" = "" ]; then
            INTERNAL_mask="${tmp_mask}"
        else
            INTERNAL_mask="${INTERNAL_mask}.${tmp_mask}"
        fi
    done
    echo ${INTERNAL_mask}
}


ipPrefix=$(ip a | grep "inet [0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}" | grep -v 127 | awk '{print $2}')
ip=$(echo ${ipPrefix} | awk -F '/' '{print $1}')
subnet=$(echo ${ip} | awk -F '.' '{print $1"."$2"."$3".0"}')
netmask=$(prefix_to_mask $(echo ${ipPrefix} | awk -F '/' '{print $2}'))
startip=$(echo ${ip} | awk -F '.' '{print $1"."$2"."$3".100"}')
endip=$(echo ${ip} | awk -F '.' '{print $1"."$2"."$3".200"}')



function install()
{
    checkArray=(cobbler cobbler-web dhcp tftp tftp-server httpd pykickstart fence-agents net-tools)
    for item in ${checkArray[@]};do
        count=$(rpm -qa | grep ${item} | wc -l)
        if [[ ${count} -ne 0 ]];then
            echo "${item} is install"
        else
            echo "installing ${item}"
            yum -y install ${item}
        fi
    done
}


function set_profile() {
    sed -i "s/^server:.*/server: ${ip}/g" /etc/cobbler/settings
    sed -i "s/^next_server:.*/next_server: ${ip}/g" /etc/cobbler/settings
    sed -i "s/manage_dhcp: 0/manage_dhcp: 1/g" /etc/cobbler/settings
    sed -i "s/pxe_just_once: 0/pxe_just_once: 1/g" /etc/cobbler/settings
    sed -ri "/default_password_crypted/s#(.*: ).*#\1\"$(openssl passwd -1 -salt 'abc' '123321')\"#" /etc/cobbler/settings
    sed -i "/disable/ s/yes/no/" /etc/xinetd.d/tftp
    sed -i "s/subnet [0-9].*netmask.*/subnet ${subnet} netmask ${netmask} {/g" /etc/cobbler/dhcp.template
    sed -i "/option routers.*192/d" /etc/cobbler/dhcp.template
    sed -i "/option domain-name-servers/d" /etc/cobbler/dhcp.template
    sed -i "s#option subnet-mask.*[0-9].*#option subnet-mask\t\t${netmask};#g" /etc/cobbler/dhcp.template
    sed -i "s/range dynamic-bootp.*/range dynamic-bootp\t${startip} ${endip};/g" /etc/cobbler/dhcp.template
    /usr/bin/cobbler get-loaders
    cobbler sync
}

function service() {
    opt=$1
    serviceArray=(httpd dhcpd rsyncd tftp cobblerd)
    for item in ${serviceArray[@]}; do
        echo "\n=======${item} ${opt}======="
        systemctl ${opt} ${item} | grep Active
        sleep 2
    done
}

function loadISO() {
    discPath="/var/www/cobbler/ks_mirror/"
    for iso in $(ls /ISO | grep -i ".iso" | egrep -iv "office|windows|ubuntu");do
        isoPath="${discPath}/${iso%.*}-x86_64"
        mkdir -p ${isoPath}
        mount -t iso9660 -o loop /ISO/${iso} ${isoPath}/
        cobbler import --arch=x86_64 --name=${iso%.*} --path=${isoPath}
    done
}

function main()
{
    install
    service start
    set_profile
    service restart
    service status
    loadISO
}

main

echo -e "请通过 https://${ip}/cobbler_web 访问网页设置 默认账号密码均为 cobbler"