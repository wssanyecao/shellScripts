#!/bin/bash

# 更新文件的修改时间

# 把最后修改时间放到脚本的顶部

if [ $# -ne 1 ]; then
	echo -e "usage: sh $0 filePath"
	exit 1
fi

filePath=$1

if [ ! -f ${filePath} ]; then
	echo -e "file not found: ${filePath}"
	exit 1
fi

if [  $(echo $(uname -a) | grep -w "Darwin" | wc -w) -ge 1 ]; then
	OS="mac"
elif [ $(echo $(uname -a) | grep -w "Linux" | wc -w) -ge 1 ]; then
	if [ -f /etc/redhat-release ]; then
		OS='centos'
	elif [ -f /etc/lsb-release ]; then
		OS='ubuntu'
	else
		OS='Linux'
	fi
fi

shopt -s expand_aliases
shopt expand_aliases &>/dev/null 

if [ "${OS}" != "mac" ]; then
	alias SED="sed -i"
else
	alias SED="sed -i \"\""
fi

function check_file_mtime()
{
	if [ "${OS}" != "mac" ]; then
		mstime=$(stat -c %Y ${filePath})
		mtime=$(date -d @${mstime} +'%F %T')
	else
		mstime=$(stat -s ${filePath} | awk '{print substr($10,10,10)}')
		mtime=$(date -j -f %s ${mstime} +'%F %T')
	fi
}

function update_mtime()
{
	if [ $(grep "# 作者: 三叶草" ${filePath} | wc -l) -ge 1 ]; then
		ftime=$(grep "最后修改时间" ${filePath} | awk '{print $(NF-1),$NF}')
		if [ "${OS}" == "mac" ]; then
			fstime=$(date -j -f "%F %T" "${ftime}" "+%s")
		else
			fstime=$(date -d "${ftime}" +%s)
		fi
		if [ $((fstime+300)) -gt ${mstime} ]; then
			exit 1
		else
			SED "s/.*最后修改时间.*/# 最后修改时间: ${mtime}/g" ${filePath}
		fi
	else
		content=(
			"######################"
			"最后修改时间"
			"作者"
			"######################"
		)
		SED '2G' ${filePath}
		if [ ${OS} == 'mac' ]; then
			for line in "${content[@]}"; do
				SED '2a\'$'\n'${line}'\'$'\n' ${filePath}
			done
		else
			for line in "${content[@]}"; do
				SED "2a ${line}" ${filePath}
				# echo "=================="
				# cat -n ${filePath}
			done
		fi
		SED "s/作者/# 作者: 三叶草/g" ${filePath}
		SED "s/最后修改时间/# 最后修改时间: ${mtime}/g" ${filePath}

	fi
}

function main()
{
	check_file_mtime
	update_mtime
}

main
shopt -u expand_aliases






