#!/bin/bash

######################
# 作者: 三叶草
# 最后修改时间: 2021-04-16 12:58:39
######################

# 查看用户列表

LOCALDIR=$(cd `dirname $0`;pwd)
CONFIGPATH="${LOCALDIR}/config.ini"

if [ -f ${CONFIGPATH} ];then
    source ${CONFIGPATH}
else
    echo "${CONFIGPATH} 配置文件找不到，请核查"
    exit 1
fi

[ -d ${OVPN_EASYRSA_PATH} ] || {
    echo "${OVPN_EASYRSA_PATH} 路径找不到，请核查"
    exit 1
}

cd "$OVPN_EASYRSA_PATH/pki"

if [ -e crl.pem ]; then
    cat ca.crt crl.pem > cacheck.pem
else
    cat ca.crt > cacheck.pem
fi

COLUMNS=$(stty size | awk '{print $NF}')
printf "%-${COLUMNS}s" "=" | sed "s/ /=/g"
# echo -e "name\tbegin\tend\tstatus"
printf "%-20s %-30s %-30s %-10s\n" name begin end status
for name in issued/*.crt; do
    path=$name
    begin=$(openssl x509 -noout -startdate -in $path | awk -F= '{ print $2 }')
    end=$(openssl x509 -noout -enddate -in $path | awk -F= '{ print $2 }')

    name=${name%.crt}
    name=${name#issued/}
    if [ "$name" != "$OVPN_SERVER_IP" ]; then
        # check for revocation or expiration
        command="openssl verify -crl_check -CAfile cacheck.pem $path"
        result=$($command)
        if [ $(echo "$result" | wc -l) == 1 ] && [ "$(echo "$result" | grep ": OK")" ]; then
            status="VALID"
        else
            result=$(echo "$result" | tail -n 1 | grep error | cut -d" " -f2)
            case $result in
                10)
                    status="EXPIRED"
                    ;;
                23)
                    status="REVOKED"
                    ;;
                *)
                    status="INVALID"
            esac
        fi
        # echo -e "$name\t$begin\t$end\t$status"
        printf "%-20s %-30s %-30s %-10s\n" "${name}" "${begin}" "${end}" "${status}"
    fi
done
printf "%-${COLUMNS}s" "=" | sed "s/ /=/g"


# Clean
rm cacheck.pem