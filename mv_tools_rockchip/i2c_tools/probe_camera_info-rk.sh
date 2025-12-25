#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_JSON="$SCRIPT_DIR/auto_camera_index.json"

# Check if gawk is installed
if ! command -v gawk >/dev/null 2>&1; then
    echo "Error: 'gawk' is not installed."
    echo "Please install it first:"
    echo "  On Debian/Ubuntu: sudo apt install gawk"
    echo "  On CentOS/RHEL:   sudo yum install gawk"
    echo "  On macOS:         brew install gawk"
    exit 1
fi

awk=gawk

camera_infos=()

for media in /dev/media*; do
    TOPOLOGY=$(media-ctl -d "$media" -p)

    # 找出 stream_cif_mipi_id0 对应的 video node
    target_video_node=$(echo "$TOPOLOGY" | awk '
    /entity [0-9]+: stream_cif_mipi_id0/ { found = 1 }
    /device node name/ && found {
        if (match($0, /\/dev\/video[0-9]+/, m)) {
            print m[0]
            exit
        }
    }')

    # 提取 sensor 信息
    result=$(echo "$TOPOLOGY" | $awk -v media="$media" -v force_video="$target_video_node" '
    BEGIN {
        RS = ""
    }
    /subtype Sensor/ {
        entity_name = ""
        subdev_node = ""
        i2c_bus = "unknown"
        video_node = force_video

        if (match($0, /entity [0-9]+: ([^\n]+) \(/, m)) {
            entity_name = m[1]
        }

        if (match($0, /device node name ([^\n]+)/, m2)) {
            subdev_node = m2[1]
        }

        if (match(entity_name, /([0-9]+)-0*([0-9a-fA-F]+)/, m3)) {
            i2c_bus = m3[1]
        }

        printf("{")
        printf("\"media_node\": \"%s\",", media)
        printf("\"video_node\": \"%s\",", video_node)
        printf("\"video_subnode\": \"%s\",", subdev_node)
        printf("\"media_entity_name\": \"%s\",", entity_name)
        printf("\"i2c_bus\": \"%s\"", i2c_bus)
        printf("}")
    }')

    if [ -n "$result" ]; then
        camera_infos+=("$result")
    fi
done

# 输出为 JSON 文件
{
  echo "["
  len=${#camera_infos[@]}
  for ((i = 0; i < len; i++)); do
    if [ $i -gt 0 ]; then
      echo ","
    fi
    echo "  ${camera_infos[i]}"
  done
  echo
  echo "]"
} > "$OUTPUT_JSON"

echo "Done -- > $OUTPUT_JSON"
