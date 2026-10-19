# FAST-LIVO2：Avia 实机学习版

当前入口是 [docs/学习导航.md](docs/学习导航.md)。建议同时打开
`src/main.cpp`、`src/LIVMapper.cpp` 和 `include/LIVMapper.h` 阅读。

此版本围绕当前 Livox Avia + Livox IMU + MVS 相机整理，保留 LIO、VIO、
彩色点云、轨迹、地图保存及回放所需代码。原项目说明和论文链接保存在
[docs/UPSTREAM_README.md](docs/UPSTREAM_README.md)，许可证仍为 [LICENSE](LICENSE)。

```text
main.cpp
  → LIVMapper.cpp           初始化、IMU处理、LIO/VIO调度
  → LIVMapper_sync.cpp      传感器回调、缓存、时间同步
  → IMU_Processing.cpp      IMU初始化、状态传播、去畸变
  → voxel_map.cpp           点面残差、迭代滤波、体素平面地图
  → vio.cpp                 视觉patch、光度残差、视觉更新
  → LIVMapper_output.cpp    ROS输出、图像着色、PCD保存
```

## 启动

在 `/home/wxc/fastlivo2_ws` 下编译：

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
catkin_make --pkg fast_livo -j2 -l2
rospack find fast_livo
```

`rospack find` 应返回 `/home/wxc/fastlivo2_ws/src/FAST-LIVO2`。
现有 VS Code 实时建图/录包/回放任务继续使用；回放文件仍通过工作区根目录的
`fastlivo2_replay.json` 配置。手动启动算法仍使用：

```bash
roslaunch fast_livo mapping_avia.launch
```

手动模式还需要原有 Livox/MVS 驱动或 bag 提供三路数据；Ctrl+C 结束算法。

## 范围

- 雷达输入固定为 `livox_ros_driver/CustomMsg`。`preprocess/lidar_type` 保留为兼容参数，只允许 `1`。
- 使用过滤后的原始点，不再提供旧的角点/平面点预提取；`feature_extract_enabled` 必须为 `false`。
- 保留相机开关、ONLY_LIO/ONLY_LO/LIVO、原视觉选项、局部地图滑动、PCD/COLMAP、MAVROS 和高频 IMU 输出。
- 删除其他雷达/数据集的处理器、配置和 RViz 示例，以及没有实际发布数据的占位话题。
- 相机模型、实机标定、时间偏移、算法数值公式和现有驱动均沿用当前版本。

具体改动、验证范围和源码阅读顺序见学习导航。
