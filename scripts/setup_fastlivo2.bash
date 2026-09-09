#!/usr/bin/env bash

# 使用方法：
#   source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash

_FASTLIVO2_WS="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f /opt/ros/noetic/setup.bash ]]; then
  echo "错误：没有找到 ROS Noetic：/opt/ros/noetic/setup.bash" >&2
  return 1 2>/dev/null || exit 1
fi

source /opt/ros/noetic/setup.bash

if [[ -d /home/wxc/catkin_ws/third_party/Sophus/install ]]; then
  export CMAKE_PREFIX_PATH="/home/wxc/catkin_ws/third_party/Sophus/install${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
fi

if [[ ! -f "${_FASTLIVO2_WS}/devel/setup.bash" ]]; then
  echo "错误：工作区尚未编译，请先在 ${_FASTLIVO2_WS} 执行 catkin_make" >&2
  return 1 2>/dev/null || exit 1
fi

source "${_FASTLIVO2_WS}/devel/setup.bash"

# 海康 MVS 自带一个较旧的 libusb。若 /opt/MVS/lib/64 排在系统库前面，
# PCL 会误加载该版本，并在启动 fastlivo_mapping 时找不到 libusb_set_option。
# 先清理重复/冲突项，再让系统库优先，MVS 专用库仍然保留在后面供相机驱动使用。
_FASTLIVO2_LD_LIBRARY_PATH=""
IFS=':' read -r -a _FASTLIVO2_LD_PATHS <<< "${LD_LIBRARY_PATH:-}"
for _FASTLIVO2_LD_PATH in "${_FASTLIVO2_LD_PATHS[@]}"; do
  [[ -z "${_FASTLIVO2_LD_PATH}" ]] && continue
  case "${_FASTLIVO2_LD_PATH}" in
    /usr/lib/x86_64-linux-gnu|/lib/x86_64-linux-gnu|/opt/MVS/lib/64|/opt/MVS/lib/32)
      continue
      ;;
  esac
  case ":${_FASTLIVO2_LD_LIBRARY_PATH}:" in
    *":${_FASTLIVO2_LD_PATH}:"*) continue ;;
  esac
  _FASTLIVO2_LD_LIBRARY_PATH="${_FASTLIVO2_LD_LIBRARY_PATH:+${_FASTLIVO2_LD_LIBRARY_PATH}:}${_FASTLIVO2_LD_PATH}"
done

export LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:/lib/x86_64-linux-gnu${_FASTLIVO2_LD_LIBRARY_PATH:+:${_FASTLIVO2_LD_LIBRARY_PATH}}"

if [[ -d /opt/MVS/lib/64 ]]; then
  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/opt/MVS/lib/64"
fi

unset _FASTLIVO2_WS _FASTLIVO2_LD_LIBRARY_PATH _FASTLIVO2_LD_PATHS _FASTLIVO2_LD_PATH
