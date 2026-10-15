#!/usr/bin/env bash

set -e

workspace_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
run_mode="${1:-live}"
case "$run_mode" in
  live|record|replay) ;;
  *) printf '用法：bash scripts/run_fastlivo2.bash live|record|replay [bag完整路径]\n' >&2; exit 2 ;;
esac

exec 9>"${workspace_dir}/.fastlivo2-task.lock"
if ! flock -n 9; then
  printf '已有一键任务正在运行，请先在对应终端按 Ctrl+C 停止。\n' >&2
  exit 1
fi

source "${workspace_dir}/scripts/setup_fastlivo2.bash"
set -eo pipefail

if [[ "$(rospack find fast_livo)" != "${workspace_dir}/src/FAST-LIVO2" ]]; then
  printf '错误：fast_livo 指向其他工作区，请检查 ROS 环境。\n' >&2
  exit 1
fi

python3 - "${workspace_dir}" "$run_mode" <<'PY'
import json
import os
import sys
import rosgraph

workspace_dir = sys.argv[1]
master = rosgraph.Master('/fastlivo2_task_preflight')
try:
    publishers, subscribers, services = master.getSystemState()
except OSError:
    pass
else:
    active_nodes = {
        node for topic, nodes in publishers + subscribers + services for node in nodes
    }
    conflicts = active_nodes.intersection({
        '/laserMapping', '/livox_lidar_publisher', '/mvs_camera_trigger',
        '/rviz', '/republish', '/fastlivo2_bag_record', '/fastlivo2_bag_player',
    })
    if conflicts:
        sys.exit('已有相关节点运行，请先停止：' + ', '.join(sorted(conflicts)))

if sys.argv[2] == 'replay':
    sys.exit(0)

config_path = os.path.join(
    workspace_dir, 'src/livox_ros_driver/config/livox_lidar_config.json'
)
with open(config_path, encoding='utf-8') as config_file:
    sync_config = json.load(config_file).get('timesync_config', {})
if sync_config.get('enable_timesync'):
    serial_device = sync_config.get('device_name', '')
    if not serial_device or not os.access(serial_device, os.R_OK | os.W_OK):
        sys.exit('同步器串口不存在或不可读写：' + serial_device
                 + '\n请检查 USB 连接、JSON 中的 device_name 和串口权限。')
    print('时间同步串口：' + serial_device + '（同步是否成功仍需查看驱动日志）')
else:
    print('注意：当前配置未启用硬件时间同步。')
PY

if [[ "$run_mode" == replay ]]; then
  bag_path="${2:-}"
  if [[ -z "$bag_path" ]]; then
    bag_path="$(python3 - "${workspace_dir}" <<'PY'
import json
import os
import sys

workspace_dir = sys.argv[1]
config_path = os.path.join(workspace_dir, 'fastlivo2_replay.json')
try:
    with open(config_path, encoding='utf-8') as config_file:
        config = json.load(config_file)
    bag_path = config.get('bag_path') if isinstance(config, dict) else None
    if not isinstance(bag_path, str) or not bag_path.strip():
        sys.exit('请在 ' + config_path + ' 中填写非空字符串 bag_path。')
    bag_path = os.path.expanduser(bag_path)
    if not os.path.isabs(bag_path):
        bag_path = os.path.join(workspace_dir, bag_path)
    print(bag_path)
except (OSError, ValueError) as error:
    sys.exit('读取回放配置失败：' + config_path + '\n' + str(error))
PY
    )"
  fi
  if [[ -z "$bag_path" || ! -f "$bag_path" || ! -r "$bag_path" ]]; then
    printf '错误：请提供存在且可读的 bag 文件完整路径：%s\n' "$bag_path" >&2
    exit 1
  fi
  bag_path="$(readlink -f -- "$bag_path")"
  python3 - "$bag_path" <<'PY'
import sys
import rosbag

expected_topics = {
    '/livox/lidar': 'livox_ros_driver/CustomMsg',
    '/livox/imu': 'sensor_msgs/Imu',
    '/left_camera/image': 'sensor_msgs/Image',
}
try:
    with rosbag.Bag(sys.argv[1], 'r') as bag:
        topic_info = bag.get_type_and_topic_info().topics
        for topic, message_type in expected_topics.items():
            info = topic_info.get(topic)
            if info is None or info.message_count == 0 or info.msg_type != message_type:
                sys.exit('bag 缺少有效话题或消息类型不匹配：' + topic
                         + '，预期类型：' + message_type)
        print('bag 检查通过，时长约 %.1f 秒。' % (bag.get_end_time() - bag.get_start_time()))
except rosbag.ROSBagException as error:
    sys.exit('无法读取 bag：' + str(error))
PY
  printf '回放文件：%s\n' "$bag_path"
  printf '将启动 FAST-LIVO2、RViz 和 bag 播放器，无需连接传感器。\n'
  printf '默认原速回放；播放结束保留地图窗口，在本终端按 Ctrl+C 退出全部回放节点。\n'
  exec roslaunch --sigint-timeout=60 --sigterm-timeout=15 \
    "${workspace_dir}/scripts/fastlivo2_replay.launch" "bag_path:=${bag_path}"
fi

record_enabled=false
bag_path="${workspace_dir}/bags/unused.bag"
if [[ "$run_mode" == record ]]; then
  record_enabled=true
  mkdir -p "${workspace_dir}/bags"
  available_kb="$(df -Pk "${workspace_dir}/bags" | awk 'END {print $4}')"
  if (( available_kb < 2097152 )); then
    printf '错误：录包目录剩余空间不足 2 GiB，请先腾出空间。\n' >&2
    exit 1
  fi
  bag_path="${workspace_dir}/bags/avia_camera_$(date +%Y%m%d_%H%M%S)_$$.bag"
  printf '录包文件：%s\n' "$bag_path"
else
  printf '当前模式：实时建图，不录包。\n'
fi

printf '即将启动雷达、相机、FAST-LIVO2 和 RViz，请保持设备静止。\n'
printf '在本任务终端按 Ctrl+C 停止全部节点；录包模式请等待保存完成后再关闭终端。\n'
exec roslaunch --sigint-timeout=60 --sigterm-timeout=15 \
  "${workspace_dir}/scripts/fastlivo2_all.launch" \
  "record:=${record_enabled}" "bag_path:=${bag_path}"
