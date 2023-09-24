#!/bin/bash
clear
Font_Black="\033[30m"
Font_Red="\033[31m"
Font_Green="\033[32m"
Font_Yellow="\033[33m"
Font_Blue="\033[34m"
Font_Purple="\033[35m"
Font_SkyBlue="\033[36m"
Font_White="\033[37m"
Font_Suffix="\033[0m"

mirror="https://pkg.zeroteam.top"
service_name="PortForwardGo"
proxy=""
listen=""
ver=""

echo -e "${Font_SkyBlue}PortForwardGo installation script${Font_Suffix}"

while [ $# -gt 0 ]; do
    case $1 in
    --api)
        api=$2
        shift
        ;;
    --secret)
        secret=$2
        shift
        ;;
    --license)
        license=$2
        shift
        ;;
    --service)
        service_name=$2
        shift
        ;;
    --proxy)
        proxy=$2
        shift
        ;;
    --listen)
        listen=$2
        shift
        ;;
    --china)
        proxy="internal"
        listen="auto"
        ;;
    --mirror)
        mirror=$2
        shift
        ;;
    --version)
        ver=$2
        shift
        ;;
    *)
        echo -e "${Font_Red} Unknown param: $1 ${Font_Suffix}"
        exit
        ;;
    esac
    shift
done

if [ -z "${api}" ]; then
    echo -e "${Font_Red}param 'api' not found${Font_Suffix}"
    exit 1
fi

if [ -z "${secret}" ]; then
    echo -e "${Font_Red}param 'secret' not found${Font_Suffix}"
    exit 1
fi

if [ -z "${license}" ]; then
    echo -e "${Font_Red}param 'license' not found${Font_Suffix}"
    exit 1
fi

if [ -z "${service_name}" ]; then
    echo -e "${Font_Red}param 'service' not found${Font_Suffix}"
    exit 1
fi

if [ -z "${mirror}" ]; then
    echo -e "${Font_Red}param 'mirror' not found${Font_Suffix}"
    exit 1
fi

echo -e "${Font_Yellow} ** Checking system info...${Font_Suffix}"
case $(uname -m) in
x86)
    arch="386"
    ;;
i386)
    arch="386"
    ;;
x86_64)
    cpu_flags=$(cat /proc/cpuinfo | grep flags | head -n 1 | awk -F ':' '{print $2}')
    if [[ ${cpu_flags} == *avx512* ]]; then
        arch="amd64v4"
    elif [[ ${cpu_flags} == *avx2* ]]; then
        arch="amd64v3"
    elif [[ ${cpu_flags} == *sse3* ]]; then
        arch="amd64v2"
    else
        arch="amd64v1"
    fi
    ;;
armv7*)
    arch="armv7"
    ;;
aarch64)
    arch="arm64"
    ;;
s390x)
    arch="s390x"
    ;;
*)
    echo -e "${Font_Red}Unsupport architecture${Font_Suffix}"
    exit 1
    ;;
esac

if [[ ! -e "/usr/bin/systemctl" ]] && [[ ! -e "/bin/systemctl" ]]; then
    echo -e "${Font_Red}Not found systemd${Font_Suffix}"
    exit 1
fi

if [[ "${listen}" == "auto" ]]; then
    listen=""

    default_out_ip=$(curl -4sL --connect-timeout 5 myip.ipip.net | awk '{print $2}' | awk -F ： '{print $2}')
    default_in_ip="${default_out_ip}"

    bind_ips=$(ip address show | grep inet | grep -v inet6 | grep -v host | grep -v docker | grep -v tun | grep -v tap | awk '{print $2}' | awk -F "/" '{print $1}')
    for bind_ip in ${bind_ips[@]}; do
        out_ip=$(curl -4sL --connect-timeout 5 --interface ${bind_ip} myip.ipip.net | awk '{print $2}' | awk -F ： '{print $2}')
        if [[ -z "${out_ip}" ]]; then
            continue
        fi

        echo -e "${Font_SkyBlue}网卡绑定IP ${bind_ip} 外网IP ${out_ip}${Font_Suffix}"

        if [[ "${out_ip}" != "${default_out_ip}" ]]; then
            default_in_ip="${out_ip}"
            listen="${bind_ip}"
        fi
    done

    echo ""

    if [[ -z "${listen}" ]]; then
        echo -e "${Font_Green}未获取到入口IP 可能是单IP机器${Font_Suffix}"
        echo -e "${Font_Green}外网IP ${default_out_ip}${Font_Suffix}"
    else
        echo -e "${Font_Green}入口绑定IP ${listen} 外网IP ${default_in_ip}${Font_Suffix}"
        echo -e "${Font_Green}出口外网IP ${default_out_ip}${Font_Suffix}"
    fi
fi

while [ -f "/etc/systemd/system/${service_name}.service" ]; do
    read -p "Service ${service_name} is exists, please input a new service name: " service_name
done

dir="/opt/${service_name}"
while [ -d "${dir}" ]; do
    read -p "${dir} is exists, please input a new dir: " dir
done

echo -e "${Font_Yellow} ** Checking release info...${Font_Suffix}"
if [[ -z "$ver" ]]; then
    ver=$(curl -sL "${mirror}/api/latest?repo=PortForwardGo")
    if [ -z "${ver}" ]; then
        echo -e "${Font_Red}Unable to get releases info${Font_Suffix}"
        exit 1
    fi
    echo -e " Detected lastet verion: " ${ver}
else
    echo -e " Use specified manually verion: " ${ver}
fi

echo -e "${Font_Yellow} ** Download release info...${Font_Suffix}"

curl -L -o /tmp/PortForwardGo.tar.gz "${mirror}/PortForwardGo/${ver}/PortForwardGo_${ver}_linux_${arch}.tar.gz"
if [ ! -f "/tmp/PortForwardGo.tar.gz" ]; then
    echo -e "${Font_Red}Download failed${Font_Suffix}"
    exit 1
fi

tar -xvzf /tmp/PortForwardGo.tar.gz -C /tmp/
if [ ! -f "/tmp/PortForwardGo" ]; then
    echo -e "${Font_Red}Decompression failed${Font_Suffix}"
    exit 1
fi

if [ ! -f "/tmp/systemd/PortForwardGo.service" ]; then
    echo -e "${Font_Red}Decompression failed${Font_Suffix}"
    exit 1
fi

if [ ! -f "/tmp/examples/backend.json" ]; then
    echo -e "${Font_Red}Decompression failed${Font_Suffix}"
    exit 1
fi

mkdir -p ${dir}
chmod 777 /tmp/PortForwardGo
mv /tmp/PortForwardGo ${dir}

sed -i "s#{api}#${api}#g" /tmp/examples/backend.json
sed -i "s#{secret}#${secret}#g" /tmp/examples/backend.json
sed -i "s#{license}#${license}#g" /tmp/examples/backend.json
sed -i "s#{proxy}#${proxy}#g" /tmp/examples/backend.json
sed -i "s#{listen}#${listen}#g" /tmp/examples/backend.json
mv /tmp/examples/backend.json ${dir}

mv /tmp/systemd/PortForwardGo.service /etc/systemd/system/${service_name}.service
sed -i "s#{dir}#${dir}#g" /etc/systemd/system/${service_name}.service

rm -rf /tmp/*

echo -e "${Font_Yellow} ** Optimize system config...${Font_Suffix}"

if [[ -z "${listen}" ]]; then
    echo "net.ipv4.ip_local_port_range = 60000 65535" >/etc/sysctl.d/97-system-port-range.conf
    echo -e "${Font_Green}已修改系统对外连接占用端口为 60000-65535, 配置文件 /etc/sysctl.d/97-system-port-range.conf${Font_Suffix}"
else
    echo "net.ipv4.ip_local_port_range = 1024 65535" >/etc/sysctl.d/97-system-port-range.conf
    echo -e "${Font_Green}已修改系统对外连接占用端口为 1024-65535, 配置文件 /etc/sysctl.d/97-system-port-range.conf${Font_Suffix}"
fi

echo -e "${Font_Yellow} ** Starting program...${Font_Suffix}"
systemctl daemon-reload
systemctl enable --now ${service_name}

echo -e "${Font_Green} [Success] Completed installation${Font_Suffix}"
