#!/bin/bash
#
###########################################################################
#
# Author: Teunis van Beelen
#
# Copyright (C) 2024 Teunis van Beelen
#
# Email: teuniz@protonmail.com
#
###########################################################################
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###########################################################################
#
# Version 1.09
#
# This script fixes some possible errors in the header of a file in European Data Format:
#
# - reserved fields: overwrite them with spaces
# - replace non-ASCII or control characters with ' ' (space) or a '.' (dot) in the local patient/recording fields
# - correct the separators of the startdate and starttime fields
# - in case the startdate or starttime isn't readable, reset it to 00:00:00 01-01-1985
# - correct the number of datarecords as advertized in the header and correct the file length
# - correct the header size as advertized in the header
# - correct digital/physical maximum/minimum fields in the header
#
# system requirements: GNU/Linux & Bash & coreutils
#
###########################################################################
#
# EDF header
#
# offset (hex, dec) length
# ---------------------------------------------------------------------
# 0x00      0     8 ascii : version of this data format (0)
# 0x08      8    80 ascii : local patient identification
# 0x58     88    80 ascii : local recording identification
# 0xA8    168     8 ascii : startdate of recording (dd.mm.yy)
# 0xB0    176     8 ascii : starttime of recording (hh.mm.ss)
# 0xB8    184     8 ascii : number of bytes in header record
# 0xC0    192    44 ascii : reserved
# 0xEC    236     8 ascii : number of data records (-1 if unknown)
# 0xF4    244     8 ascii : duration of a data record, in seconds
# 0xFC    252     4 ascii : number of signals
#
#                0 (0x00) + signal_idx * 16 ascii : label (e.g. EEG Fpz-Cz or Body temp)
# numsignals *  16 (0x10) + signal_idx * 80 ascii : transducer type (e.g. AgAgCl electrode)
# numsignals *  96 (0x60) + signal_idx *  8 ascii : physical dimension (e.g. uV or degreeC)
# numsignals * 104 (0x68) + signal_idx *  8 ascii : physical minimum (e.g. -500 or 34)
# numsignals * 112 (0x70) + signal_idx *  8 ascii : physical maximum (e.g. 500 or 40)
# numsignals * 120 (0x78) + signal_idx *  8 ascii : digital minimum (e.g. -2048)
# numsignals * 128 (0x80) + signal_idx *  8 ascii : digital maximum (e.g. 2047)
# numsignals * 136 (0x88) + signal_idx * 80 ascii : prefiltering (e.g. HP:0.1Hz LP:75Hz N:60)
# numsignals * 216 (0xD8) + signal_idx *  8 ascii : nr of samples in each data record
# numsignals * 224 (0xE0) + signal_idx * 32 ascii : reserved
#
# All fields are left aligned and filled up with spaces, no null's.
# Decimal separator (if any) must be a dot.
#
###########################################################################
#
#
export LC_ALL=C
#
#
################################################################################
# check if the necessary tools are installed
################################################################################
if ! command -v dd &> /dev/null
then
    echo "dd could not be found" >&2
    exit 1
fi
#
if ! command -v head &> /dev/null
then
    echo "head could not be found" >&2
    exit 1
fi
#
if ! command -v tr &> /dev/null
then
    echo "tr could not be found" >&2
    exit 1
fi
#
if ! command -v stat &> /dev/null
then
    echo "stat could not be found" >&2
    exit 1
fi
#
if ! command -v truncate &> /dev/null
then
    echo "truncate could not be found" >&2
    exit 1
fi
#
if ! command -v bc &> /dev/null
then
    echo "bc could not be found" >&2
    exit 1
fi
#
#
################################################################################
# check if argument is a regular file
################################################################################
if [ ! -f "$1" ]
  then
    exit 0
  fi
#
################################################################################
# check if filename/path is at least 5 characters long
################################################################################
if (( ${#1} < 5))
  then
    exit 0
  fi
#
################################################################################
# get file size and check if it has the minimum size
################################################################################
file_sz=$((10#$(stat -c%s "$1")))
if ((file_sz < 514))
  then
    echo "file is too small" >&2
    exit 1
  fi
#
is_edf=false
is_edfplus=false
is_bdf=false
is_bdfplus=false
is_biosemi=false
#
################################################################################
# check the version field if the file is EDF or BDF and
# check if file has the correct extension
################################################################################
# deal with null-bytes immediately!
hdr_general=$(head -c 256 "$1" | tr '\000' "\001")
version_field=${hdr_general:0:8}
#
if [ "$version_field" = "0       " ] && ([ ${1: -4} = ".edf" ] || [ ${1: -4} = ".EDF" ] || [ ${1: -4} = ".rec" ] || [ ${1: -4} = ".REC" ])
  then
    is_edf=true
  elif [ "$version_field" = $'\xffBIOSEMI' ] && ([ ${1: -4} = ".bdf" ] || [ ${1: -4} = ".BDF" ])
    then
      is_bdf=true
    else
      echo "Error: header has a wrong version and/or extension" >&2
      exit 1
    fi
#
################################################################################
# check for EDF+/BDF+
################################################################################
var2=${hdr_general:192:5}
#
if [ $is_edf = true ] && ([ "$var2" = "EDF+C" ] || [ "$var2" = "EDF+D" ])
  then
    is_edfplus=true
  elif [ $is_bdf = true ] && ([ "$var2" = "BDF+C" ] || [ "$var2" = "BDF+D" ])
    then
      is_bdfplus=true
    elif [ $is_bdf = true ] && [ "$var2" = "24BIT" ]
      then
        is_biosemi=true
      fi
#
################################################################################
#  fill the reserved field in the general header with spaces
################################################################################
if [ $is_edfplus = true ] || [ $is_bdfplus = true ] || [ $is_biosemi = true ]
  then
    printf '                                       ' | dd of="$1" bs=1 seek=197 count=39 conv=notrunc status=none
#           |<----------- 39 spaces ------------->|
#           |<- file offset: 197
  else
    printf '                                            ' | dd of="$1" bs=1 seek=192 count=44 conv=notrunc status=none
#           |<---------------- 44 spaces ------------->|
#           |<- file offset: 192
  fi
#
if ! [[ ${hdr_general:252:1} =~ ^[0-9]+$ ]]
  then
    echo "Error: cannot read number of signals from header" >&2
    exit 1
  fi
num_signals=$((10#$(echo "${hdr_general:252:4}" | tr -c '\040-\176' " ")))
if (($num_signals < 1)) || (($num_signals > 640))
  then
    echo "Error: number of signals is out of range" >&2
    exit 1
  fi
#
offset=$(($num_signals * 224 + 256))
#
for i in $(seq 0 $(($num_signals - 1)));
do
################################################################################
#  fill the reserved fields of the signal headers with spaces
################################################################################
  printf '                                ' | dd of="$1" bs=1 seek=$offset count=32 conv=notrunc status=none
#         |<-------- 32 spaces --------->|
  offset=$(($offset + 32))
done
#
hdr_sz=$(($num_signals * 256 + 256))
#
hdr_full=$(head -c $hdr_sz "$1" | tr '\000' "\001")
#
################################################################################
# local patient & recording fields: replace non-ASCII and control characters with dots
################################################################################
printf "%s" "${hdr_full:8:160}" | tr -c '\040-\176' "." | dd of="$1" bs=1 seek=8 count=160 conv=notrunc status=none
#
################################################################################
# rest of the header: replace non-ASCII and control characters with spaces
################################################################################
printf "%s" "${hdr_full:168:$(($hdr_sz - 168))}" | tr -c '\040-\176' " " | dd of="$1" bs=1 seek=168 count=$(($hdr_sz - 168)) conv=notrunc status=none
#
################################################################################
# overwrite the separators of the startdate and starttime fields with dots
################################################################################
echo '.' | dd of="$1" bs=1 seek=170 count=1 conv=notrunc status=none
echo '.' | dd of="$1" bs=1 seek=173 count=1 conv=notrunc status=none
echo '.' | dd of="$1" bs=1 seek=178 count=1 conv=notrunc status=none
echo '.' | dd of="$1" bs=1 seek=181 count=1 conv=notrunc status=none
#
#
hdr_general=$(head -c 256 "$1")
#
################################################################################
# check if the startdate and starttime are valid
################################################################################
#
startdatetime_invalid=false
# startdate day:
var4=${hdr_general:168:2}
if [[ $var4 =~ ^[0-9]+$ ]]
  then
    var4=$((10#${var4}))
    if (($var4 < 1)) || (($var4 > 31))
    then
      startdatetime_invalid=true
    fi
  else
    startdatetime_invalid=true
  fi
# startdate month:
var4=${hdr_general:171:2}
if [[ $var4 =~ ^[0-9]+$ ]]
  then
    var4=$((10#${var4}))
    if (($var4 < 1)) || (($var4 > 12))
    then
      startdatetime_invalid=true
    fi
  else
    startdatetime_invalid=true
  fi
# startdate year:
var4=${hdr_general:174:2}
if ! [[ $var4 =~ ^[0-9]+$ ]]
  then
    startdatetime_invalid=true
  fi
# starttime hour:
var4=${hdr_general:176:2}
if [[ $var4 =~ ^[0-9]+$ ]]
  then
    var4=$((10#${var4}))
    if (($var4 < 0)) || (($var4 > 23))
    then
      startdatetime_invalid=true
    fi
  else
    startdatetime_invalid=true
  fi
# starttime minute:
var4=${hdr_general:179:2}
if [[ $var4 =~ ^[0-9]+$ ]]
  then
    var4=$((10#${var4}))
    if (($var4 < 0)) || (($var4 > 59))
    then
      startdatetime_invalid=true
    fi
  else
    startdatetime_invalid=true
  fi
# starttime second:
var4=${hdr_general:182:2}
if [[ $var4 =~ ^[0-9]+$ ]]
  then
    var4=$((10#${var4}))
    if (($var4 < 0)) || (($var4 > 59))
    then
      startdatetime_invalid=true
    fi
  else
    startdatetime_invalid=true
  fi
#
# if the starttime or startdate is invalid, reset it to 00:00:00 01-01-1985
if [ $startdatetime_invalid = true ]
  then
    echo '01.01.8500.00.00' | dd of="$1" bs=1 seek=168 count=16 conv=notrunc status=none
  fi
#
#
hdr_full=$(head -c $hdr_sz "$1")
#
################################################################################
# get the number of samples in a datarecord for each signal and
# calculate the datarecord size in bytes
################################################################################
offset=$(($num_signals * 216 + 256))
datrec_sz=0
#
for i in $(seq 0 $(($num_signals - 1)));
do
  datrec_sz=$(($datrec_sz + $((10#${hdr_full:${offset}:8}))))

  offset=$(($offset + 8))
done
#
if [ $is_edf = true ]
  then
    datrec_sz=$(($datrec_sz * 2))
  else
    datrec_sz=$(($datrec_sz * 3))
  fi
#
################################################################################
# correct the file length and the number of datarecords as advertized in the header
################################################################################
num_datrecs=$((($file_sz - $hdr_sz) / $datrec_sz))
#
if (($num_datrecs < 1))
  then
    echo "file is too small, not enough datarecords in file" >&2
    exit 1
  fi
#
file_sz=$(($hdr_sz + ($num_datrecs * $datrec_sz)))
#
truncate -s $file_sz "$1"
#
printf "%-8i" $num_datrecs | dd of="$1" bs=1 seek=236 count=8 conv=notrunc status=none
#
################################################################################
# correct the header size as advertized in the header
################################################################################
printf "%-8i" $hdr_sz | dd of="$1" bs=1 seek=184 count=8 conv=notrunc status=none
#
################################################################################
# check the digital/physical maximum/minimum fields of the signal headers
################################################################################
if [ $is_bdf = true ]
  then
    digmaxmax=8388607
    digminmin=-8388608
    annot_label="BDF Annotations "
  else
    digmaxmax=32767
    digminmin=-32768
    annot_label="EDF Annotations "
  fi
#
for i in $(seq 0 $(($num_signals - 1)));
do
  signal_label=${hdr_full:$((256 + (i * 16))):16}

  offset_digmin=$(($num_signals * 120 + 256 + (i * 8)))

  digmin=$((${hdr_full:${offset_digmin}:8}))

  offset_digmax=$(($num_signals * 128 + 256 + (i * 8)))

  digmax=$((10#${hdr_full:${offset_digmax}:8}))

  offset_physmin=$(($num_signals * 104 + 256 + (i * 8)))

  physmin=$(bc -l <<< "${hdr_full:${offset_physmin}:8}")

  offset_physmax=$(($num_signals * 112 + 256 + (i * 8)))

  physmax=$(bc -l <<< "${hdr_full:${offset_physmax}:8}")

#  printf "signal: %i   label: $signal_label   digmin: %i   digmax: %i   physmin: $physmin   physmax: $physmax\n" $(($i + 1)) $digmin $digmax

  if ([ $is_edfplus = true ] || [ $is_bdfplus = true ]) && [ "$signal_label" = "$annot_label" ]
    then
      if (($digmax != $digmaxmax))
        then
          printf "%-8i" $digmaxmax | dd of="$1" bs=1 seek=$offset_digmax count=8 conv=notrunc status=none
        fi
      if (($digmin != $digminmin))
        then
          printf "%-8i" $digminmin | dd of="$1" bs=1 seek=$offset_digmin count=8 conv=notrunc status=none
        fi
      if [ $(bc -l <<< "${physmin} != -1") = '1' ]
        then
          printf "-1      " | dd of="$1" bs=1 seek=$offset_physmin count=8 conv=notrunc status=none
        fi
      if [ $(bc -l <<< "${physmax} != 1") = '1' ]
        then
          printf "1       " | dd of="$1" bs=1 seek=$offset_physmax count=8 conv=notrunc status=none
        fi
    elif [ $is_biosemi = true ] && [ "$signal_label" = "Status          " ]
        then
          if (($digmax != $digmaxmax))
            then
              printf "%-8i" $digmaxmax | dd of="$1" bs=1 seek=$offset_digmax count=8 conv=notrunc status=none
            fi
          if (($digmin != $digminmin))
            then
              printf "%-8i" $digminmin | dd of="$1" bs=1 seek=$offset_digmin count=8 conv=notrunc status=none
            fi
          if [ $(bc -l <<< "${physmin} != ${digminmin}") = '1' ]
            then
              printf "-8388608" | dd of="$1" bs=1 seek=$offset_physmin count=8 conv=notrunc status=none
            fi
          if [ $(bc -l <<< "${physmax} != ${digmaxmax}") = '1' ]
            then
              printf "8388607 " | dd of="$1" bs=1 seek=$offset_physmax count=8 conv=notrunc status=none
            fi
      else
        if (($digmin > $digmax))
          then
            tmp=$digmax
            digmax=$digmin
            digmin=$tmp
            tmp=$physmax
            physmax=$physmin
            physmin=$tmp

            printf "%-8i" $digmin | dd of="$1" bs=1 seek=$offset_digmin count=8 conv=notrunc status=none

            printf "%-8i" $digmax | dd of="$1" bs=1 seek=$offset_digmax count=8 conv=notrunc status=none

            printf "%-8s" $physmin | dd of="$1" bs=1 seek=$offset_physmin count=8 conv=notrunc status=none

            printf "%-8s" $physmax | dd of="$1" bs=1 seek=$offset_physmax count=8 conv=notrunc status=none
          fi
        if (($digmin < $digminmin))
          then
            digmin=$digminmin

            printf "%-8i" $digmin | dd of="$1" bs=1 seek=$offset_digmin count=8 conv=notrunc status=none
          fi
        if (($digmin > $digmaxmax))
          then
            digmin=$digmaxmax

            printf "%-8i" $digmin | dd of="$1" bs=1 seek=$offset_digmin count=8 conv=notrunc status=none
          fi
        if (($digmax > $digmaxmax))
          then
            digmax=$digmaxmax

            printf "%-8i" $digmax | dd of="$1" bs=1 seek=$offset_digmax count=8 conv=notrunc status=none
          fi
        if (($digmax < $digminmin))
          then
            digmax=$digminmin

            printf "%-8i" $digmax | dd of="$1" bs=1 seek=$offset_digmax count=8 conv=notrunc status=none
          fi
        if (($digmin == $digmax))
          then
            if (($digmax < $digmaxmax))
              then
                digmax=$(($digmax + 1))

                printf "%-8i" $digmax | dd of="$1" bs=1 seek=$offset_digmax count=8 conv=notrunc status=none
              else
                digmin=$(($digmin - 1))

                printf "%-8i" $digmin | dd of="$1" bs=1 seek=$offset_digmin count=8 conv=notrunc status=none
              fi
          fi
        if [ $physmin = $physmax ]
          then
            if [ $(bc -l <<< "${physmax} < 99999998") = '1' ]
              then
                physmax=$(bc -l <<< "$physmax + 1")

                printf "$physmax        " | dd of="$1" bs=1 seek=$offset_physmax count=8 conv=notrunc status=none
              else
                physmin=$(bc -l <<< "$physmin - 1")

                printf "$physmin        " | dd of="$1" bs=1 seek=$offset_physmin count=8 conv=notrunc status=none
              fi
          fi
      fi
done
#

exit 0
#
#





