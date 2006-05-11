#!/bin/sh

ENVCACHE=${HOME}/.environment
MPD_CONF=/etc/mpd.conf
MPD_STATE=$(grep state ${MPD_CONF} | sed -e 's/.*"\(\/.*\)"$/\1/')
if [ -r "${ENVCACHE}" ]; then
    # If there's a file with cached environment variables on this
    # machine, look for relevant stuff and source it.
    grep '^PREF_MPD_HOST=[^ ]\+$' "${ENVCACHE}" | while read SETTING; do
        eval "${SETTING}"
    done
fi

HOSTS="${MPD_HOST} ${PREF_MPD_HOST} messenger localhost"

for HOST in $HOSTS; do 
    # Work through the host list in order, testing connections to
    # the server for each. If we get something (_anything_) back on
    # stdin, set that host as MPD_HOST and break.
    if [ -n "$(MPD_HOST="${HOST}" mpc 2>/dev/null)" ]; then
        MPD_HOST=${HOST}
        break
    fi
done

# If we don't have anything to talk to, die now.
[ "${MPD_HOST}" ] || exit 1

MPC_COMMAND=
INCREMENT=7
CURVOL=$(MPD_HOST=${MPD_HOST} mpc volume | sed -e 's/[^0-9]//g')
MINVOL=30
MAXVOL=75
FORMAT="[[%artist% - ]%title%|%name%|%file%]"

if [ $# -eq 0 ]; then
    # Open ncmpc in a new window if it's not running; otherwise,
    # pause/resume playback.
    if [ ! "$(pgrep -lf "ncmpc --host ${MPD_HOST}")" ]; then
        term -e "ncmpc --host ${MPD_HOST}"
    else
        MPD_HOST=${MPD_HOST} mpc toggle
    fi
else
    # Twiddle a knob.
    case $1 in
        toggle)
            MPC_COMMAND="toggle"
            ;;
        volume)
            MPC_COMMAND="volume $2"
            ;;
        up|down|query|slide|ncmpc)
            # just ignore -- they're special
            ;;
        next)
            MPC_COMMAND="next"
            ;;
        prev)
            MPC_COMMAND="prev"
            ;;
        stop)
            MPC_COMMAND="stop"
            ;;
        *)
            echo "Bad command: $1."
            exit 1
            ;;
    esac
    [ "${MPC_COMMAND}" ] && MPD_HOST=${MPD_HOST} mpc ${MPC_COMMAND} >/dev/null 2>&1 && exit

    case $1 in
        query)
            MPD_HOST=${MPD_HOST} mpc --format "${FORMAT}"
            ;;
        ncmpc)
            term -e "ncmpc --host ${MPD_HOST}"
            ;;
    esac

    # Special tricky slides
    case $1 in
        down)
            while [ ${CURVOL} -gt ${MINVOL} ]; do
                MPD_HOST=${MPD_HOST} mpc volume -${INCREMENT} >/dev/null 2>&1
                CURVOL=$(MPD_HOST=${MPD_HOST} mpc volume | sed -e 's/[^0-9]//g')
            done
            ;;
        up)
            while [ ${CURVOL} -lt ${MAXVOL} ]; do
                MPD_HOST=${MPD_HOST} mpc volume +${INCREMENT} >/dev/null 2>&1
                CURVOL=$(MPD_HOST=${MPD_HOST} mpc volume | sed -e 's/[^0-9]//g')
            done
            ;;
        slide)
            # The modulo bits are intended to smooth the slide;
            # there may be a better method, but it seems rather
            # efficient to do it this way.
            # TODO: This doesn't make sense; if $INC only
            # increments when [$((INC % 2)) -eq 0], the 
            INCINC=0
            if [ ${CURVOL} -gt 50 ]; then
                INC=1
                while [ ${CURVOL} -gt ${MINVOL} ]; do
                    # Slide down
                    MPD_HOST=${MPD_HOST} mpc volume -${INC} >/dev/null 2>&1
                    CURVOL=$(MPD_HOST=${MPD_HOST} mpc volume | sed -e 's/[^0-9]//g')
                    if [ $((INCINC % 7)) -eq 0 -a ${INC} -lt 4 ]; then
                        INC=$((INC + 1))
                    fi
                    INCINC=$((INCINC + 1))
                done
            else
                INC=4
                while [ ${CURVOL} -lt ${MAXVOL} ]; do
                    # Slide up
                    MPD_HOST=${MPD_HOST} mpc volume +${INC} >/dev/null 2>&1
                    CURVOL=$(MPD_HOST=${MPD_HOST} mpc volume | sed -e 's/[^0-9]//g')
                    if [ $((INCINC % 7)) -eq 0 -a ${INC} -gt 1 ]; then
                        INC=$((INC - 1))
                    fi
                    INCINC=$((INCINC + 1))
                done
            fi
            ;;
    esac
fi
