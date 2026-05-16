# Custom plugin for zsh
#
# Common functions
#
# Author: Thomas Bendler <code@thbe.org>
# Date:   Wed Jan  1 23:54:03 CET 2020
#

### Command enhancement functions (must stay as shell functions — use cd) ###
.1() { cd ../ ; }                                  # Go back 1 directory level
.2() { cd ../../ ; }                               # Go back 2 directory levels
.3() { cd ../../../ ; }                            # Go back 3 directory levels
.4() { cd ../../../../ ; }                         # Go back 4 directory levels
.5() { cd ../../../../../ ; }                      # Go back 5 directory levels
.6() { cd ../../../../../../ ; }                   # Go back 6 directory levels
mcd() { mkdir -p "$1" && cd "$1" ; }               # mcd: Makes new Dir and jumps inside

# All other functions moved to bin/:
# root         → bin/root
# f            → bin/f
# c            → bin/c
# path         → bin/path
# show_options → bin/show-options
# fix_stty     → bin/fix-stty
# mount        → bin/list-mounts
# fastping     → bin/fast-ping
# j            → bin/j
# hibernate    → bin/hibernate
# sleepmode    → bin/sleep-mode
# safesleep    → bin/safe-sleep
# smartsleep   → bin/smart-sleep
# cowdate      → bin/cowdate
# myip         → bin/my-ip
# netCons      → bin/net-cons
# flushDNS     → bin/flush-dns (already existed, removed duplicate)
# lsock        → bin/lsock
# lsockU       → bin/lsock-udp
# lsockT       → bin/lsock-tcp
# ipInfo0      → bin/ip-info-en0
# ipInfo1      → bin/ip-info-en1
# openPorts    → bin/open-ports
# showBlocked  → bin/show-blocked
# httpHeaders  → bin/http-headers
# ttop         → bin/ttop
# dush         → bin/dush (already existed, removed duplicate)
# numFiles     → bin/num-files
# ql           → bin/ql
# zipf         → bin/zipf
# trash        → bin/trash
# extract      → bin/extract
# makefile_1mb  → bin/make-file-1mb
# makefile_5mb  → bin/make-file-5mb
# makefile_10mb → bin/make-file-10mb
