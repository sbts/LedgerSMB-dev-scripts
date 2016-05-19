#!/bin/bash

Version='VERSION: 0.0.1'

clear;

show_help() {
    cat <<-EOF
	$Version
	usage: start-lsmb.sh -h | [-v] [-w num] [-m num] [-P] [-p port] [-c conf_file] [ [-d working_dir] ]
	    -h : this help
	    -v : make the script more verbose
	    -V : version
	    -p : specify a different port to run starman on
	           default: 5000
	        NOTE: you can force to bind to an external interface by specifying
	              127.0.0.1:5000
	
	    -d : specify a working directory (the LedgerSMB install directory)
	           default: ./ (the current dir)
	
	    -c : location of a ledgersmb.conf file to use for this instance
	           default: ./ledgersmb.conf
	
	    -w : The number of workers to start
	           default: 5
	
	    -m : max-requests arg for starman
	           default: 1000
	
	    -P : preload-app arg for starman
	           default: not set
	
	    -L : filename for the Error Log
	           Default: no file, use stdout
	
	    -E : enable loading of development modules
	            equivalent to plackup option '-E development'
	         which causes "plackup" to load the middleware components: AccessLog, StackTrace, and Lint
	
	    -D : daemonize if possible
	         Not all backends respect this option
	
	    -O : opts : Additional Options for starman
	
	
	
	    The working Directory can also be given without the -d
	
	    This script starts a starman instance running LedgerSMB on port 8080 by default
	
	    The defaults can be overridden by setting some keys in ledgersmb.conf or using arguments on the commandline 
	    the ledgersmb.conf entry should look like
	        [starman]
	        port = 5000
	        dir = /usr/share/ledgersmb
	        verbose = true
	        workers = 5
	        max-requests = 1000
	        ## pidFile is just the basename the port number and extension will be automatically appended
	        ##   eg: /tmp/ledgersmb-5000.pid
	        pidFile = /tmp/ledgersmb
	        ## logFile is just the basename the port number and extension will be automatically appended
	        ##   eg: /tmp/ledgersmb-5000.log
	        LogFile = /tmp/ledgersmb
	
	        ## Run as a Daemon if possible
	        ## This passes the -D argument to "plackup" although the backend may choose not to support this
	        #daemonize = true
	
	        ## Set the Development flag when running Starman/plackup
	        ## This causes "plackup" to load the middleware components: AccessLog, StackTrace, and Lint
	        #develop = true
	
	        ## Other Options to pass direct to PlackUP
	        #otherOpts = --no-default-middleware
	        
	        
	        
	EOF
    exit 0
}



# try and get arguments from ledgersmb.conf via Sysconfig.pm if possible else direct from the file
GetConfigFromFile() {
    if [[ -r "$confFile" ]]; then # if confFile exists and is readable
        local _Key=''
        local _Value=''
        local _inSection=false
        local _Key=''
        while read _Key E _Value; do
            if [[ $_Key =~ ^\[starman] ]]; then _inSection=true; fi
            if $_inSection; then
                if [[ $_Key =~ ^\[ ]] && ! [[ $_Key =~ ^\[starman] ]]; then break; fi
                case $_Key in
                            port) PORT="${_Value:-5000}" ;;
                             dir) WorkingDir="${_Value:-/usr/share/ledgersmb}" ;;
                         verbose) Verbose=true ;;
                         workers) workers="--workers ${_Value:-5}" ;;
                    max-requests) maxRequests="--max-requests ${_Value:-1000}" ;;
                         pidFile) pidFile="--pid ${_Value:-/tmp/ledgersmb}" ;;
                         LogFile) logFile="--error-log ${_Value:-/tmp/ledgersmb}" ;;
                         Develop) if ${_Value:false}; then develop='-E development'; else develop=''; fi ;;
                         Daemonize) if ${_Value:false}; then daemonize='-D'; else daemonize=''; fi ;;
#fixme#        --pid
#           Specify the pid file path. Use it with "-D|--daemonize" option, described in "plackup -h".
                       otherOpts) opts="$_Value" ;;
                esac
            fi
        done
    fi
}

GetConfig() {
    confFile='./ledgersmb.conf'

    if [[ $HOSTNAME =~ '-dev' ]]; then # be verbose on development systems
        Verbose=true;
    fi

    if [[ $@ =~ '-V' ]]; then
        echo "$Version"
        exit 0;
    fi

    if [[ $@ =~ '-c' ]]; then
        getopts "c:" opt
        confFile=$OPTARG
    fi

    if [[ $@ =~ '-d' ]]; then
        getopts "d:" opt
        WorkingDir="$OPTARG"
    fi

    ## A dirname can be passed on the commandline or in ledgersmb.conf
    ## This is used as the installation dir to start LedgerSMB from
    if [[ -n $WorkingDir ]] && [[ -d "$WorkingDir" ]]; then # change to the dir specified by argument or config
        cd "$WorkingDir"
    fi

    # check to see if we are in a new dir structure
    if [[ -r lib/LedgerSMB.pm ]]; then
        libDir='lib';
        lib='-I lib' # If it's a new structure pass the lib dir to starman
    else
        libDir='.'
        lib=''
    fi

    read User < <(stat -c "%U" $libDir/LedgerSMB.pm;)
    Group="$User";  # Unless we are root we can only set the group to then same as the calling user, or a group the user is a member of
                    # We don't want the group to be the same as the file group, as that group should have write permissions
#    Group='nogroup' # we actually should drop starman group privlidges to nobody but can only do that if we are root or a member of group nobody which is a bad idea
                    # and we don't want to do it conditionally on being root as that could leave tempfiles/directories owned by the wrong user which causes all sorts of problems.

    canGetConfig=false;
    if [[ -r "$confFile" ]]; then # if confFile exists and is readable
        if [[ -n "$libDir" ]]; then # if we are on a new tree there is a chance that Sysconfig.pm can give us config values
            read OPTARG < <(perl $libDir/LedgerSMB/Sysconfig.pm "$confFile" -get main CommandLineControl)
            if [[ "$OPTARG" == 'true' ]]; then
                canGetConfig=true;
            fi
        fi

        if [[ -r "$confFile" ]]; then # if confFile exists and is readable
            if [[ -r "$canGetConfig" ]]; then # Sysconfig.pm can give us config values
                GetConfigFromFile < <(perl $libDir/LedgerSMB/Sysconfig.pm "$confFile" -get starman '*')
            else
                GetConfigFromFile <"$confFile"
            fi
        fi
    fi

    # now override anything we already have with options passed on the commandline
    while getopts "h?vp:d:c:w:m:P:L:O:ED" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        d)  ## argument : -d Directory to run LedgerSMB out of
            ##               default: ./
            ## 
            ## 
#                if [[ -n $OPTARG ]]; then
#                    WorkingDir="$OPTARG"
#                fi
            ;;
        c)  ## argument : -c filename : location of a ledgersmb.conf file to use for this instance
            ##               default: ./ledgersmb.conf
            ## 
            ## 
#                if [[ -n $OPTARG ]]; then
#                    confFile="$OPTARG"
#                fi
            ;;
        v)  ## argument : -v
            ##                default: disabled
            ## generate some extra output on stdout from this script
            ## It's mainly usefull for development systems
            ## so is automatically enabled if the hostname contains '-dev'
            ## 
            ## 
                    Verbose=true;
            ;;
        p)  ## argument : -p port
            ##               default: 8080
            ## The port number to start starman on
            ## If it is not provided on the commandline
            ## We will try and retrieve it from ledgersmb.conf before using the script default
            ## 
            ## 
                if [[ -n $OPTARG ]]; then
                    PORT=$OPTARG
                fi
            ;;
        w)  ## argument : -w num : The number of workers to start
            ##               default: 5
            ## 
            ## 
                if [[ -n $OPTARG ]]; then
                    workers="--workers $OPTARG"
                fi
            ;;
        m)  ## argument : -m : max-requests arg for starman
            ##               default: 1000
            ## 
            ## 
                if [[ -n $OPTARG ]]; then
                    maxRequests="--max-requests $OPTARG"
                fi
            ;;
        P)  ## argument : -P : preload-app arg for starman
            ##               default: not set
            ## 
            ## 
                if [[ -n $OPTARG ]]; then
                    preloadApp='--preload-app'
                fi
            ;;
        L)  ## argument : -L : filename for the Error Log
            ##               default: no file, use stdout
            ## 
            ## 
                if [[ -n $OPTARG ]]; then
                    logFile="-error-log $OPTARG"
                fi
            ;;
        O)  ## argument : -O : Additional Options for starman and / or plackup
            ## 
            ## 
                if [[ -n $OPTARG ]]; then
                    opts="$OPTARG"
                fi
            ;;
        E)  ## argument : -E : enable loading of development modules
            ##               default: not enabled
            ## 
            ## 
                develop='-E development'
            ;;
        D)  ## argument : -D : daemonize if possible
            ## 
            ## 
                daemonize='-D'
#fixme#        --pid
#           Specify the pid file path. Use it with "-D|--daemonize" option, described in "plackup -h".

            ;;
#        )  ## argument : -
#            ##               default: 
#            ## 
#            ## 
#                if [[ -n $OPTARG ]]; then
#                    =$OPTARG
#                fi
#            ;;
        *)  echo "ERROR: Unknown Argument '$opt $OPTARG'"
            show_help
            ;;
        esac
    done

    shift $((OPTIND-1))

    [ "$1" = "--" ] && shift
    declare -g extra_args="$@"
    
    # #### Fixme this port handling may break if an IPv6 address is used without a port
    if ! [[ $PORT =~ : ]]; then PORT=":${PORT}"; fi # add a colon leading the port if it's missing
    local _Port=${PORT##*:}
    local _IF=${PORT%:*}
    PORT="${_IF:-127.0.0.1}:${_Port:-5000}"; # Create full host:port with defaults
}

Echo() { ## echo function for when Verbose output is requested
    if $Verbose; then
        echo -e "\n\n\n\n\n\n\n\n\n\n\n";
    fi
}

GetConfig "$@"

echo CWD=$PWD
echo libDir=$libDir

if ! [[ -r tools/starman.psgi ]]; then # make sure we have a psgi script to run
    echo "please run this script from the top level of a ledgersmb repository"
    echo "or provide a directory on the command line"
    echo "you can also pass an argument of -v to get some extra ouput to the console"
    exit 1
fi

if [[ ! $USER =~ root ]] && (( ${PORT##*:} <1024 )); then # system user of root is the only one that can run on privlidged ports
    cat <<-EOF
	=======================================
	==            FATAL ERROR            ==
	=======================================
	==   Only root can run starman       ==
	==   on ports below 1024             ==
	=======================================
	EOF
    exit 9
fi

if [[ $User =~ root ]]; then # user root is bad as we open our entire system to attack
    cat <<-EOF
	=======================================
	==            FATAL ERROR            ==
	=======================================
	==   You can't run with LedgerSMB    ==
	==   Owned by root, it's not safe    ==
	=======================================
	EOF
    exit 9
fi
if [[ $User =~ nobody ]]; then # user nobody is bad as our tempfiles become vulnerable
    cat <<-EOF
	=======================================
	==            FATAL ERROR            ==
	=======================================
	==   You can't run with LedgerSMB    ==
	==  Owned by nobody, it's not safe   ==
	=======================================
	EOF
    exit 9
fi

export ConfigFile="$confFile"
# Start Starman on the requested port or 8080 by default
echo
echo; echo starman --user $User --group $Group $lib --listen $PORT $workers $maxRequests $preloadApp $logFile $pidFile $opts tools/starman.psgi; echo
echo " starting Starman server for LedgerSMB with ConfigFile: $ConfigFile"
echo
starman --user $User --group $Group $lib --listen $PORT $workers $maxRequests $preloadApp $logFile $pidFile $develop $opts tools/starman.psgi

# ## info on running plack directly via systemd and other.
# ## also info on an available debugger for plack
# ## https://vector.im/develop/#/room/!qyoLumPqusaXqFJNyK:matrix.org/$146117615327737EPQyV:matrix.org


# this perl snippet will printout the ConfigFile Environment Variable
# print STDERR "test $ENV{ConfigFile}\n";
