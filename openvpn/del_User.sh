#!/bin/bash

######################
# 作者: 三叶草
# 最后修改时间: 2021-04-16 12:42:59
######################

# 删除用户

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

function check_exist() {
    local username="$1"
    checkPathArr=(
        ${OVPN_EASYRSA_PATH}/pki/reqs/${username}.req
        ${OVPN_EASYRSA_PATH}/pki/private/${username}.key
        ${OVPN_EASYRSA_PATH}/pki/issued/${username}.crt
    )
    for path in ${checkPathArr[@]}; do
        [ -f ${path} ] || {
            echo "用户 ${username} 不存在，请核查"
            exit 1
        }
    done
}

function revoke_user()
{
    local username="$1"
    cd ${OVPN_EASYRSA_PATH}
    # 不能使用自动输入 中间会出现一个 删除确认 这个设置还是有必要保留的
    echo "=================================="
    echo "删除用户 ${username}"
    echo "=================================="
    /bin/expect <<-EOF
spawn ./easyrsa revoke ${username}
expect {
"Continue with revocation*" {send "yes\\r";exp_continue;}
"Enter pass phrase for *" {send "${OVPN_CA_PASSWD}\\r"}
}
expect eof
EOF
    echo "生成吊销证书名单 $OVPN_EASYRSA_PATH/pki/crl.pem"
    echo "=================================="
    /bin/expect <<-EOF
spawn ./easyrsa gen-crl
expect {
"Enter pass phrase for *" {send "${OVPN_CA_PASSWD}\\r"}
}
expect eof
EOF
    # ./easyrsa revoke "${username}"
    # ./easyrsa gen-crl
    cp -f "$OVPN_EASYRSA_PATH/pki/crl.pem" "$OVPN_PATH/server/crl.pem"
    chmod 644 "$OVPN_PATH/server/crl.pem"
    rm -f ${OVPN_PATH}/client/${username}.ovpn
    echo "=================================="
    echo "用户已移除 ${username}"
    echo "=================================="
}

function update_openvpn_config()
{
    if [ $(cat ${OVPN_PATH}/server/openvpn.conf | grep "crl-verify" | wc -l) -ne 1 ]; then
        echo "crl-verify ${OVPN_PATH}/server/crl.pem" >> ${OVPN_PATH}/server/openvpn.conf
        # 可能会出错，具体要看openvpn的服务名是啥
        systemctl restart openvpn-server@openvpn
    fi
}

[ $# -ne 2 ] && { echo "Usage: $0 -n delUserName";exit 1; }

while getopts "n:h" opt; do
    case "$opt" in
        n)
            username=$OPTARG
            check_exist ${username}
            revoke_user ${username}
            update_openvpn_config
        ;;
        h|?)
            { echo "Usage: $0 -n delUserName";exit 1; }
        ;;
    esac
done
