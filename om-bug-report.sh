#!/bin/sh
# Based on nvidia-bug-report
# Adapted and modified for OpenMandriva
# by TPG (tpgxyz@gmail.com)
# www.openmandriva.org

BASE_LOG_FILENAME="om-bug-report-$(date +%Y%m%d%H%M%S).log"
COMP_CMD="cat"

set_filename() {
    LOG_FILENAME=$BASE_LOG_FILENAME
    OLD_LOG_FILENAME="$BASE_LOG_FILENAME.old"
}

usage_bug_report_message() {
    printf '%s\n' "Please include the '$LOG_FILENAME' file when reporting"
    printf '%s\n' "your bug via the https://issues.openmandriva.org ."
}

usage() {
    printf '%s\n' ""
    printf '%s\n' "$(basename $0): OpenMandriva bug reporting shell script."
    printf '%s\n' ""
    usage_bug_report_message
    printf '%s\n' ""
    printf '%s\n' "$(basename $0) [OPTION]..."
    printf '%s\n' "    -h / --help"
    printf '%s\n' "        Print this help output and exit."
    printf '%s\n' "    -o / --output-file <file>"
    printf '%s\n' "        Write output to <file>."
    printf '%s\n' "        Default: write to om-bug-report.log(.zst)."
    printf '%s\n' "    -c / --compress"
    printf '%s\n' "        If zstd is available, the output file"
    printf '%s\n' "        will be automatically compressed, and \".zst\" "
    printf '%s\n' "        will be appended to the filename."
    printf '%s\n' "    -u / --user"
    printf '%s\n' "        Make the file owned by the given user and put it"
    printf '%s\n' "        in the user's home directory unless -o was given"
    printf '%s\n' "        with an absolute path"
    printf '%s\n' ""
}

OMDV_BUG_REPORT_CHANGE='$Change: 004 $'
OMDV_BUG_REPORT_VERSION="$(printf '%s\n' "$OMDV_BUG_REPORT_CHANGE" | tr -c -d "[:digit:]")"

# Set the default filename so that it won't be empty in the usage message
set_filename

# Parse arguments: Optionally set output file, or printf help
SAVED_FLAGS=$@
while [ "$1" != "" ]; do
    case $1 in
        -o | --output-file )    if [ -z $2 ]; then
                                    usage
                                    exit 1
                                elif [ "$(printf '%s\n' "$2" | cut -c 1)" = "-" ]; then
                                    printf '%s\n' "Warning: Questionable filename"\
                                         "\"$2\": possible missing argument?"
                                fi
                                BASE_LOG_FILENAME="$2"
                                if [ -n "$PW_DIR" -a "$(echo $BASE_LOG_FILENAME |cut -b1)" != "/" ]; then
                                    BASE_LOG_FILENAME="$PW_DIR/$BASE_LOG_FILENAME"
                                fi
                                # override the default filename
                                set_filename
                                shift
                                ;;
        -c | --compress )       if ! command -v zstd 2>&1 > /dev/null ; then
                                    printf '%s\n' "zstd compression program is missing."
                                    printf '%s\n' "zstd compression program is missing."
                                else
                                    COMP_CMD="zstd -15 -T0 -c"
                                    LOG_FILENAME="$BASE_LOG_FILENAME.zst"
                                    OLD_LOG_FILENAME="$BASE_LOG_FILENAME.old.zst"
                                fi
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        -u | --user )           USERNAME="$2"
                                shift
                                P="$(grep "^$USERNAME:" /etc/passwd)"
                                if [ "$?" != "0" ]; then
                                    echo "No such user $USERNAME"
                                    exit 1
                                fi
                                PW_UID="$(echo $P |cut -d: -f3)"
                                PW_GID="$(echo $P |cut -d: -f4)"
                                PW_DIR="$(echo $P |cut -d: -f6)"
                                if [ -n "$BASE_LOG_FILENAME" -a "$(echo $BASE_LOG_FILENAME |cut -b1)" != "/" ]; then
                                    BASE_LOG_FILENAME="$PW_DIR/$BASE_LOG_FILENAME"
                                    set_filename
                                fi
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

#
# echo_metadata() - echo metadata of specified file
#

echo_metadata() {
    printf "*** ls: "
    /bin/ls -l --full-time "$1" 2> /dev/null

    if [ $? -ne 0 ]; then
        # Run dumb ls -l. We might not get one-second mtime granularity, but
        # that is probably okay.
        ls -l "$1"
    fi
}

#
# append() - append the contents of the specified file to the log
#

append() {
    (
        printf '%s\n' "____________________________________________"
        printf '%s\n' ""

        if [ ! -f "$1" ]; then
            printf '%s\n' "*** $1 does not exist"
        elif [ ! -r "$1" ]; then
            printf '%s\n' "*** $1 is not readable"
        else
            printf '%s\n' "*** $1"
            echo_metadata "$1"
            cat  "$1"
        fi
        printf '%s\n' ""
    ) | $COMP_CMD >> $LOG_FILENAME
}

#
# append_silent() - same as append(), but don't printf anything
# if the file does not exist
#

append_silent() {
    (
        if [ -f "$1" ] && [ -r "$1" ]; then
            printf '%s\n' "____________________________________________"
            printf '%s\n' ""
            printf '%s\n' "*** $1"
            echo_metadata "$1"
            cat  "$1"
            printf '%s\n' ""
        fi
    ) | $COMP_CMD >> $LOG_FILENAME
}

#
# append_glob() - use the shell to expand a list of files, and invoke
# append() for each of them
#

append_glob() {
    for i in $(ls $1 2> /dev/null;); do
        append "$i"
    done
}

#
# append_file_or_dir_silent() - if $1 is a regular file, append it; otherwise,
# if $1 is a directory, append all files under it.  Don't printf anything if the
# file does not exist.
#

append_file_or_dir_silent() {
    if [ -f "$1" ]; then
        append "$1"
    elif [ -d "$1" ]; then
        append_glob "$1/*"
    fi
}

#
# append_binary_file() - Encode a binary file into a ascii string format
# using 'base64' and append the contents output to the log file
#

append_binary_file() {
    (
        base64="$(command -v base64)"

        if [ -n "$base64" ] && [ -x "$base64" ]; then
                if [ -f "$1" ] && [ -r "$1" ]; then
                    printf '%s\n' "____________________________________________"
                    printf '%s\n' ""
                    printf '%s\n' "base64 \"$1\""
                    printf '%s\n' ""
                    base64 "$1" 2> /dev/null
                    printf '%s\n' ""
                fi
        else
            printf '%s\n' "Skipping $1 output (base64 not found)"
            printf '%s\n' ""
        fi

    ) | $COMP_CMD >> $LOG_FILENAME
}

#
# Start of script
#

# check that we are root (needed for `lspci -vxxx` and potentially for
# accessing kernel log files)

if [ "$(id -u)" -ne 0 ]; then
    printf '%s\n' "ERROR: Please run $(basename $0) as root."
    exit 1
fi

# move any old log file (zipped) out of the way

if [ -f $LOG_FILENAME ]; then
    mv $LOG_FILENAME $OLD_LOG_FILENAME
fi

# make sure what we can write to the log file

touch $LOG_FILENAME 2> /dev/null

if [ $? -ne 0 ]; then
    printf '%s\n' ""
    printf '%s\n' "ERROR: Working directory is not writable; please cd to a directory"
    printf '%s\n' "       where you have write permission so that the $LOG_FILENAME"
    printf '%s\n' "       file can be written."
    printf '%s\n' ""
    exit 1
fi

# printf a start message to stdout

printf '%s\n' ""
printf '%s\n' "om-bug-report.sh will now collect information about your"
printf '%s\n' "system and create the file '$LOG_FILENAME'."
printf '%s\n' "It may take several seconds to run."
printf '%s\n' ""
printf '%s\n' "Running $(basename $0)...";

# printf prologue to the log file

(
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""
    printf '%s\n' "Start of OpenMandriva bug report log file.  Please include this file, along"
    printf '%s\n' "with a detailed description of your problem, when reporting a bug"
    printf '%s\n' "via the https://issues.openmandriva.org ."
    printf '%s\n' ""
    printf '%s\n' "om-bug-report.sh Version: $OMDV_BUG_REPORT_VERSION"
    printf '%s\n' ""
    printf '%s\n' "Generation date: $(date)"
    printf '%s\n' "uname: $(uname -a)"
    printf '%s\n' "command line flags: $SAVED_FLAGS"
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

# hostnamectl information

(
    printf '%s\n' ""
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""
    printf '%s\n' "System host infrmation:"
    printf '%s\n' ""
    hostnamectl 2> /dev/null
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

# append useful files
append "/etc/system-release"
append_silent "/etc/os-release"

# append environment output

(
    printf '%s\n' ""
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""
    printf '%s\n' "Environment settings:"
    printf '%s\n' ""
    systemctl show-environment 2> /dev/null
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

append_silent "/etc/vconsole.conf"
append_silent "/etc/default/grub"

# append useful /proc files
append "/proc/uptime"
append "/proc/cmdline"
append "/proc/cpuinfo"
append "/proc/interrupts"
append "/proc/meminfo"
append "/proc/modules"
append "/proc/version"
append "/proc/asound/cards"
append "/proc/asound/pcm"
append "/proc/asound/modules"
append "/proc/asound/devices"
append "/proc/asound/version"
append "/proc/asound/timers"
append "/proc/asound/hwdep"

for CARD in /proc/asound/card[0-9]*; do
    for CODEC in $CARD/codec*; do
        [ -d $CODEC ] && append_glob "$CODEC/*"
        [ -f $CODEC ] && append "$CODEC"
    done
    for ELD in $CARD/eld*; do
        [ -f $ELD ] && append "$ELD"
    done
done

# lspci information

(
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""

    lspci="$(command -v lspci)"

    if [ -n "$lspci" ] && [ -x "$lspci" ]; then
        printf '%s\n' "$lspci"
        printf '%s\n' ""
        $lspci -v 2> /dev/null
        printf '%s\n' ""
    else
        printf '%s\n' "Skipping lspci output (lspci not found)"
        printf '%s\n' ""
    fi
) | $COMP_CMD >> $LOG_FILENAME

# lsusb information

(
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""

    lsusb="$(command -v lsusb)"

    if [ -n "$lsusb" ] && [ -x "$lsusb" ]; then
        printf '%s\n' "$lsusb"
        printf '%s\n' ""
        $lsusb 2> /dev/null
        printf '%s\n' ""
    else
        printf '%s\n' "Skipping lsusb output (lsusb not found)"
        printf '%s\n' ""
    fi
) | $COMP_CMD >> $LOG_FILENAME

# dmidecode

(
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""

    dmidecode="$(command -v dmidecode)"

    if [ -n "$dmidecode" ] && [ -x "$dmidecode" ]; then
        printf '%s\n' "$dmidecode"
        printf '%s\n' ""
        $dmidecode 2> /dev/null
        printf '%s\n' ""
    else
        printf '%s\n' "Skipping dmidecode output (dmidecode not found)"
        printf '%s\n' ""
    fi
) | $COMP_CMD >> $LOG_FILENAME

# append coredumpctl --list output

(
    printf '%s\n' ""
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""
    printf '%s\n' "List available coredumps:"
    printf '%s\n' ""
    coredumpctl list 2> /dev/null
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

# append systemctl --failed output

(
    printf '%s\n' ""
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""
    printf '%s\n' "Systemd failed units:"
    printf '%s\n' ""
    systemctl --no-pager --failed 2> /dev/null
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

# append systemctl unit files with theirs statuses

(
    printf '%s\n' ""
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""
    printf '%s\n' "Systemd units files:"
    printf '%s\n' ""
    systemctl --no-pager list-unit-files 2> /dev/null
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

# printf cc & c++ and ld version info

(
    if [ -n "$(command -v cc)" ]; then
        printf '%s\n' "____________________________________________"
        printf '%s\n' ""
        cc -v 2>&1
    fi

    if [ -n "$(command -v c++)" ]; then
        printf '%s\n' "____________________________________________"
        printf '%s\n' ""
        c++ -v 2>&1
    fi

    if [ -n "$(command -v ld)" ]; then
        printf '%s\n' "____________________________________________"
        printf '%s\n' ""
        ld -v 2>&1
    fi
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

# append journalctl output

(
    printf '%s\n' ""
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""
    printf '%s\n' "Systemd boot log:"
    printf '%s\n' ""
    journalctl --no-hostname -b 2> /dev/null
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

# Append any Xorg/Wayland logs found in home directories
cat /etc/passwd \
    | cut -d : -f 6 \
    | sort | uniq \
    | while read DIR; do
	[ -e "$DIR/.xsession-errors" ] && append_silent "$DIR/.xsession-errors"
	[ -e "$DIR/.local/share/sddm/wayland-session.log" ] && append_silent "$DIR/.local/share/sddm/wayland-session.log"
	[ -e "$DIR/.local/share/sddm/xorg-session.log" ] && append_silent "$DIR/.local/share/sddm/xorg-session.log"
    done

xconfig_file_list=
NEW_LINE="
"

for log_basename in /var/log/Xorg; do
    for i in 0 1 2 3 4 5 6 7; do
        for log_suffix in log ; do
            log_filename="${log_basename}.${i}.${log_suffix}"
            append_silent "${log_filename}"

            # look for the X configuration files/directories referenced by this X log
            if [ -f ${log_filename} ] && [ -r ${log_filename} ]; then
                config_file="$(grep "Using config file" ${log_filename} | cut -f 2 -d \")"
                config_dir="$(grep "Using config directory" ${log_filename} | cut -f 2 -d \")"
                sys_config_dir="$(grep "Using system config directory" ${log_filename} | cut -f 2 -d \")"
                for j in "$config_file" "$config_dir" "$sys_config_dir"; do
                    if [ "$j" ]; then
                        # multiple of the logs we find above might reference the
                        # same X configuration file; keep a list of which X
                        # configuration files we find, and only append X
                        # configuration files we have not already appended
                        printf '%s\n' "${xconfig_file_list}" | grep ":${j}:" > /dev/null
                        if [ "$?" != '0' ]; then
                            xconfig_file_list="${xconfig_file_list}:${j}:"
                            if [ -d "$j" ]; then
                                append_glob "$j/*.conf"
                            else
                                append "$j"
                            fi
                        fi
                    fi
                done
            fi

        done
    done
done

# append installed rpm package list output

(
    printf '%s\n' ""
    printf '%s\n' "____________________________________________"
    printf '%s\n' ""
    printf '%s\n' "Installed RPM packages:"
    printf '%s\n' ""
    rpm -qa | sort -u 2> /dev/null
    printf '%s\n' ""
) | $COMP_CMD >> $LOG_FILENAME

sync > /dev/null 2>&1

(
    printf '%s\n' "____________________________________________"

    # printf epilogue to log file

    printf '%s\n' ""
    printf '%s\n' "End of OpenMandriva bug report log file."
) | $COMP_CMD >> $LOG_FILENAME

# Done

printf '%s\n' "... done."
if [ -n "$PW_UID" -a -n "$PW_GID" ]; then
    chown "$PW_UID:$PW_GID" "$LOG_FILENAME"
fi
usage_bug_report_message
printf '%s\n' ""

#EOF
