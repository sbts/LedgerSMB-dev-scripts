#!/bin/bash

clear;

####
# setup the user and group to run LedgerSMB as
###
LSMB_User='ledgersmb'
LSMB_Group='ledgersmb'
LSMB_installdir='/usr/local/www/ledgersmb'
LSMB_User='dcg'
LSMB_Group='dcg'
LSMB_installdir="/home/dcg/src/1-LedgerSMB/3-profiling"

LOG="/tmp/lsmb-$$.log"

####
# You may need to set the following variables if you are using local::lib and NOT running this script as the installing user
####
#    export PERL5LIB='/home/ledgersmb/perl5/lib/perl5'
#    export PERL_LOCAL_LIB_ROOT='/home/ledgersmb/perl5/lib/perl5'
#    export PERL_MB_OPT=--install_base "/home/ledgersmb/perl5"
#    export PERL_MM_OPT=INSTALL_BASE=/home/ledgersmb/perl5

####
# Run starman and LedgerSMB with as the user $LSMB_User
# Also ensure any local::lib environment variables are correctly set.
#   They are taken from values set above, or if not set from the invoking users environment
#   The PERL_MB_OPT and PERL_MM_OPT variables normally wouldn't be needed to run LedgerSMB,
#   but are needed in the environment used to update any cpan perl modules
####

run() {
sudo -u $LSMB_User bash <<EOScript
    [[ -n "${PERL5LIB}" ]] && {
        export PERL5LIB='${PERL5LIB}';
        [[ -n "${PERL_LOCAL_LIB_ROOT}" ]] && export PERL_LOCAL_LIB_ROOT='$PERL_LOCAL_LIB_ROOT'; # use single quotes to ensure the var retains it's integrity
        [[ -n "${PERL_MB_OPT}" ]] && export PERL_MB_OPT='$PERL_MB_OPT'; # use single quotes to ensure the var retains it's integrity
        [[ -n "${PERL_MM_OPT}" ]] && export PERL_MM_OPT='$PERL_MM_OPT'; # use single quotes to ensure the var retains it's integrity
        PATH="${PERL5LIB:+${PERL5LIB}:}\${PATH}";
    }
    cd "$LSMB_installdir" &&
    starman -l *:5762 -I lib tools/starman.psgi
EOScript
exit
}

profile() {
    echo "=========================="
    echo "=========================="
    echo "== RUNNING THE PROFILER =="
    echo "=========================="
    echo "=========================="
sudo -u $LSMB_User bash <<EOScript
    [[ -n "${PERL5LIB}" ]] && {
        export PERL5LIB='${PERL5LIB}';
        [[ -n "${PERL_LOCAL_LIB_ROOT}" ]] && export PERL_LOCAL_LIB_ROOT='$PERL_LOCAL_LIB_ROOT'; # use single quotes to ensure the var retains it's integrity
        [[ -n "${PERL_MB_OPT}" ]] && export PERL_MB_OPT='$PERL_MB_OPT'; # use single quotes to ensure the var retains it's integrity
        [[ -n "${PERL_MM_OPT}" ]] && export PERL_MM_OPT='$PERL_MM_OPT'; # use single quotes to ensure the var retains it's integrity
        PATH="${PERL5LIB:+${PERL5LIB}:}\${PATH}";
    }
    cd "$LSMB_installdir"
#    perl /usr/bin/starman --workers 1 -l *:5762 -I lib -I old/lib tools/starman-local-dev.psgi
    TGT='tools/starman-development.psgi'
    [[ -r tools/starman-local-dev.psgi ]] && TGT='tools/starman-local-dev.psgi'
#     perl /usr/bin/starman --workers 1 -l *:5762 -I lib -I old/lib --access-log $LOG --server HTTP::Server::PSGI --env development $TGT
#     perl /usr/bin/starman --workers 1 -l *:5762 -I lib -I old/lib --access-log "$LOG" --server HTTP::Server::PSGI --env development $TGT
     perl /usr/bin/starman --workers 1 --listen '0.0.0.0:5762' -I lib -I old/lib --access-log $LOG --server HTTP::Server::PSGI --env development tools/starman-local-dev.psgi
#    nytprofhtml
    pwd
EOScript
exit
}

[[ -n $1 ]] && $1 || run
