# FAST-LIVO2 驱动工作区

本工作区使用 ROS Noetic，源码位于 `src/`：

- `FAST-LIVO2`：FAST-LIVO2 主程序，ROS 包名是 `fast_livo`
- `livox_ros_driver`：Livox LiDAR/IMU 驱动
- `mvs_ros_pkg`：海康 MVS GigE 相机驱动
- `rpg_vikit`：FAST-LIVO2 所需的 `vikit_common` 和 `vikit_ros`

## 编译

```bash
cd /home/wxc/fastlivo2_ws
source /opt/ros/noetic/setup.bash
export CMAKE_PREFIX_PATH="/home/wxc/catkin_ws/third_party/Sophus/install${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
catkin_make -DCMAKE_BUILD_TYPE=Release
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
```

## 当前传感器话题约定

- LiDAR：`/livox/lidar`
- Livox IMU：`/livox/imu`
- 相机：`/left_camera/image`

`FAST-LIVO2/launch/mapping_avia.launch` 只启动 FAST-LIVO2、图像转发和 RViz，
不会自动启动 Livox 或 MVS 驱动。首次上电建议分别验证设备后再启动它。

```bash
# 终端 1：Livox
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
roslaunch livox_ros_driver livox_lidar.launch

# 终端 2：海康 MVS 相机
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
roslaunch mvs_ros_pkg mvs_camera_trigger.launch

# 终端 3：FAST-LIVO2
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
roslaunch fast_livo mapping_avia.launch
```

## 上机前需要确认

- `src/livox_ros_driver/config/livox_lidar_config.json` 中的 `broadcast_code` 是否对应现场 LiDAR；
- 该 JSON 中 `enable_connect` 和 `device_name` 是否符合现场设备；
- `src/mvs_ros_pkg/config/left_camera_trigger.yaml` 中的分辨率、曝光、增益和图像话题是否符合相机；
- 相机与 LiDAR 的网卡、IP 和物理链路是否正常；
- `src/FAST-LIVO2/config/avia.yaml` 中的相机-LiDAR 外参是否为当前传感器安装姿态。

这些值与硬件绑定，当前只保留朋友提供的原始配置，没有凭空替换。
