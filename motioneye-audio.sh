#!/usr/bin/env bash
debug=true
log=/tmp/MotionEyeAudio.log
$debug && (date -Iseconds >> $log)

# Set variables
operation=$1
$debug && (echo "operation=$operation" >> $log)
camera_id=$2
$debug && (echo "camera_id=$camera_id" >> $log)
#motion_thread_id=$2
#$debug && (echo "motion_thread_id=$motion_thread_id" >> $log)
file_path=$3
$debug && (echo "file_path=$file_path" >> $log)
camera_name=$4
$debug && (echo "camera_name=$camera_name" >> $log)

#camera_id="$(python -c 'import motioneye.motionctl; print motioneye.motionctl.motion_camera_id_to_camera_id('${motion_thread_id}')')"
#$debug && (echo "camera_id=$camera_id" >> $log)
motion_config_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
$debug && (echo "motion_config_dir=$motion_config_dir" >> $log)
motion_camera_conf="${motion_config_dir}/camera-${camera_id}.conf"
$debug && (echo "motion_camera_conf=$motion_camera_conf" >> $log)
# Below line was a temporary fix replacing camera ID with camera name due to cameraID/thread mismatch - motion_thread_id should fix this
# motion_camera_conf="$( egrep -l \^camera_name.${camera_name} ${motion_config_dir}/*.conf)"
netcam="$(if grep -q 'netcam_highres' ${motion_camera_conf};then echo 'netcam_highres'; else echo 'netcam_url'; fi)"
$debug && (echo "netcam=$netcam" >> $log)
extension="$(echo ${file_path} | sed 's/^/./' | rev | cut -d. -f1  | rev)"
$debug && (echo "extension=$extension" >> $log)

case ${operation} in
    start)
        credentials="$(grep netcam_userpass ${motion_camera_conf} | sed -e 's/netcam_userpass.//')"
	$debug && (echo "credentials=$credentials" >> $log)
        stream="$(grep ${netcam} ${motion_camera_conf} | sed -e "s/${netcam}.//")"
	$debug && (echo "stream=$stream" >> $log)
        #full_stream="$(echo ${stream} | sed -e "s/\/\//\/\/${credentials}@/")"
	#$debug && (echo "ffmpeg -y -i \"${full_stream}\" -c:a aac ${file_path}.aac" >> $log)
        #ffmpeg -y -i "${full_stream}" -c:a aac ${file_path}.aac 2>&1 1>/dev/null &
	$debug && (echo "amixer --card 1 sset 'Mic' 100%" >> $log)
	amixer --card 1 sset 'Mic' 100%
	$debug && (echo "arecord -f S16_LE -c 1 -r 22050 -D plughw:1,0 | ffmpeg -i - -c:a aac -y ${file_path}.aac" >> $log)
	arecord -f S16_LE -c 1 -r 22050 -D plughw:1,0 | ffmpeg -i - -c:a aac -y ${file_path}.aac 2>&1 1>/dev/null &
        ffmpeg_pid=$!
        echo ${ffmpeg_pid} > /tmp/motion-audio-ffmpeg-camera-${camera_id}
        # echo ${ffmpeg_pid} > /tmp/motion-audio-ffmpeg-camera-${camera_name}
        ;;

    stop)
        # Kill the ffmpeg audio recording for the clip
        kill $(cat /tmp/motion-audio-ffmpeg-camera-${camera_id})
        rm -f /tmp/motion-audio-ffmpeg-camera-${camera_id}
        # kill $(cat /tmp/motion-audio-ffmpeg-camera-${camera_name})
        # rm -rf $(cat /tmp/motion-audio-ffmpeg-camera-${camera_name})

        # Merge the video and audio to a single file, and replace the original video file
        $debug && (echo "ffmpeg -y -i ${file_path} -i ${file_path}.aac -c:v copy -c:a copy ${file_path}.temp.${extension};" >> $log)
        ffmpeg -y -i ${file_path} -i ${file_path}.aac -c:v copy -c:a copy ${file_path}.temp.${extension};
        mv -f ${file_path}.temp.${extension} ${file_path};

        # Remove audio file after merging
        rm -f ${file_path}.aac;
        ;;

    *)
        # echo "Usage ./motioneye-audio.sh start <camera-id> <full-path-to-moviefile>"
        echo "Usage ./motioneye-audio.sh start <camera-name> <full-path-to-moviefile>"
        exit 1
esac
