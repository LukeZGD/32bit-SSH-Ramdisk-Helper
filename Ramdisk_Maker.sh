#!/bin/bash

## Ramdisk_Maker - Copyright 2019-2020, @Ralph0045

echo "**** SSH Ramdisk_Maker 2.0 ****"
echo made by @Ralph0045

if [[ $OSTYPE == "linux"* ]]; then
    . /etc/os-release 2>/dev/null
    platform="linux"
elif [[ $OSTYPE == "darwin"* ]]; then
    platform="macos"
elif [[ $OSTYPE == "msys" ]]; then
    platform="win"
fi
partialzip="../../bin/partialzip_$platform"
xpwntool="../../bin/xpwntool_$platform"
hfsplus="../../bin/hfsplus_$platform"
iBoot32Patcher="../../bin/iBoot32Patcher_$platform"

if [ $# -lt 2 ]; then
echo "Usage:

-d      specify device by model
-i      specify iOS version (if not specified, it will use earliest version available)

[example]

ramdisk_maker -d iPhone10,6 -i 14.0
"
exit
fi

args=("$@")

for i in {0..4}
 do
    
    if [ "${args[i]}" = "-d" ]; then
        device=${args[i+1]}
    fi
    
    if [ "${args[i]}" = "-i" ]; then
        version=${args[i+1]}
    fi
done

## Check if 32/64 bit

type=$(echo ${device:0:6})

if [ "$type" = "iPhone" ]; then
    number=$(echo ${device:6} | awk -F, '{print $1}')
    if [ "$number" -gt "5" ]; then
        is_64="true"
    fi
else
    type=$(echo ${device:0:4})
    number=$(echo ${device:4} | awk -F, '{print $1}')
    if [ "$type" = "iPad" ]; then
        if [ "$number" -gt "3" ]; then
            is_64="true"
        fi
    else
        if [ "$type" = "iPod" ]; then
            if [ "$number" -gt "5" ]; then
                is_64="true"
            fi
        fi
    fi
fi

if [ "$is_64" = "true" ]; then
    echo "64-bit not supported"
    exit 1
fi

if [ -e "firmware.json" ]; then
echo firmware.json is present
else
echo "firmware.json isn't present"
echo Downloading it
curl https://api.ipsw.me/v2.1/firmwares.json --output firmware.json &> /dev/null
echo Done!
fi

## Define BoardConfig
boardcfg="$((cat firmware.json) | grep $device -A4 | grep BoardConfig | sed 's/"BoardConfig"//' | sed 's/: "//' | sed 's/",//' | xargs)"
{
if [ -z "$version" ]; then
    ipsw_link=$(curl "https://api.ipsw.me/v2.1/$device/earliest/url")
    version=$(curl "https://api.ipsw.me/v2.1/$device/earliest/info.json" | grep version | sed s+'"version": "'++ | sed s+'",'++ | xargs)
    BuildID=$(curl "https://api.ipsw.me/v2.1/$device/earliest/info.json" | grep buildid | sed s+'"buildid": "'++ | sed s+'",'++ | xargs)
else
    ipsw_link=$(curl "https://api.ipsw.me/v2.1/$device/$version/url")
    BuildID=$(curl "https://api.ipsw.me/v2.1/$device/$version/info.json" | grep buildid | sed s+'"buildid": "'++ | sed s+'",'++ | xargs)
fi
} &> /dev/null

iOS_Vers=`echo $version | awk -F. '{print $1}'`

{
## Define RootFS name

RootFS="$((curl "https://www.theiphonewiki.com/wiki/Firmware_Keys/$iOS_Vers.x") | grep "$BuildID"_"" |  grep $device -m 1| awk -F_ '{print $1}' | awk -F"wiki" '{print "wiki"$2}')"
} &> /dev/null

mkdir -p SSH-Ramdisk-$device/work
cd SSH-Ramdisk-$device/work

## Get wiki keys page

echo Downloading firmware keys...

curl "https://www.theiphonewiki.com/$RootFS"_"$BuildID"_"($device)" --output temp_keys.html &> /dev/null

if [ -e "temp_keys.html" ]; then
echo Done!
else
echo Failed to download firmware keys
fi

# Get firmware keys, components and decrypt them

$partialzip $ipsw_link BuildManifest.plist BuildManifest.plist &> /dev/null

images="iBSS.iBEC.applelogo.DeviceTree.kernelcache.RestoreRamDisk"

#rm ../../$device.sh
for i in {1..6}
 do
    temp_type="$((echo $images) | awk -v var=$i -F. '{print $var}' | awk '{print tolower($0)}')"
    temp_type2="$((echo $images) | awk -v var=$i -F. '{print $var}')"
    
    eval "$temp_type"_iv="$((cat temp_keys.html) | grep "$temp_type-iv" | awk -F"</code>" '{print $1}' | awk -F"-iv\"\>" '{print $2}')"
    eval "$temp_type"_key="$((cat temp_keys.html) | grep "$temp_type-key" | awk -F"</code>" '{print $1}' | awk -F"$temp_type-key\"\>" '{print $2}')"
    iv=$temp_type"_iv"
    key=$temp_type"_key"
    
    if [ "$temp_type2" = "RestoreRamDisk" ]; then
        component="$((cat BuildManifest.plist) | grep $boardcfg -A 3000 | grep $temp_type2 -A 100| grep dmg -m 1 | sed s+'<string>'++ | sed s+'</string>'++ | xargs)"
    else
        component="$((cat BuildManifest.plist) | grep $boardcfg -A 3000 | grep $temp_type2 | grep string -m 1 | sed s+'<string>'++ | sed s+'</string>'++ | xargs)"
    fi
    
    echo Downloading $component...
    
    $partialzip $ipsw_link $component $temp_type2 &> /dev/null
    
    echo Done!
    
    if [ "$is_64" != "true" ]; then
        #echo "File+=($component)" >> ../../$device.sh
        #echo "IV+=(${!iv})" >> ../../$device.sh
        #echo "Key+=(${!key})" >> ../../$device.sh
        if [ "$temp_type2" = "RestoreRamDisk" ]; then
            $xpwntool $temp_type2 RestoreRamDisk.dec.img3 -iv ${!iv} -k ${!key} -decrypt &> /dev/null
        else
            $xpwntool $temp_type2* $temp_type2.dec.img3 -iv ${!iv} -k ${!key} -decrypt
        fi
    fi
done
#echo "IPSW_URL=$ipsw_link" >> ../../$device.sh

echo Making ramdisk...

if [ "$is_64" != "true" ]; then
    $xpwntool RestoreRamDisk.dec.img3 RestoreRamDisk.raw.dmg
    if [[ $platform == "macos" ]]; then
        hdiutil resize -size 30MB RestoreRamDisk.raw.dmg
        mkdir ramdisk_mountpoint
        hdiutil attach -mountpoint ramdisk_mountpoint/ RestoreRamDisk.raw.dmg
        tar -xvf ../../resources/ssh.tar -C ramdisk_mountpoint/
        hdiutil detach ramdisk_mountpoint
    else
        $hfsplus RestoreRamDisk.raw.dmg grow 31457280
        $hfsplus RestoreRamDisk.raw.dmg untar ../../resources/ssh.tar
    fi
    $xpwntool RestoreRamDisk.raw.dmg ramdisk.dmg -t RestoreRamDisk.dec.img3
    mv -v ramdisk.dmg ../
    $xpwntool iBSS.dec.img3 iBSS.raw
    $iBoot32Patcher iBSS.raw iBSS.patched -r
    $xpwntool iBSS.patched iBSS -t iBSS.dec.img3
    mv -v iBSS ../
    $xpwntool iBEC.dec.img3 iBEC.raw
    $iBoot32Patcher iBEC.raw iBEC.patched -r -d -b "rd=md0 -v amfi=0xff cs_enforcement_disable=1"
    $xpwntool iBEC.patched iBEC -t iBEC.dec.img3
    mv -v iBEC ../
    mv -v applelogo.dec.img3 ../applelogo
    mv -v DeviceTree.dec.img3 ../devicetree
    mv -v kernelcache.dec.img3 ../kernelcache
    cd ..
    rm -rf work
    cd ..
fi

echo Done!
