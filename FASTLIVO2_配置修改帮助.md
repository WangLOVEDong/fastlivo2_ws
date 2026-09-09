# FAST-LIVO2 配置修改帮助

本文对应普通工作区：`/home/wxc/fastlivo2_ws`。

目标：下次运行前，知道“该改哪个文件、改哪一行、改完重启谁、如何判断是否生效”。

---

## 0. 修改前的总原则

1. 一次只改一类参数。例如先只改曝光，不同时修改曝光、增益、外参和时间偏移。
2. 先保存原值，或者在 YAML 中保留 `修改前` 注释。
3. `.yaml`、`.json` 配置修改后 **不需要编译**，但必须重启读取它的节点。
4. `.cpp`、`.h`、`CMakeLists.txt` 修改后才需要编译。
5. LiDAR-IMU 时间同步异常与图像过曝是两类问题；相机参数不能修复 `IMU and LiDAR not synced`。

---

## 1. 当前涉及的三个相机配置文件

| 文件 | 作用 | 改完后要重启 |
|---|---|---|
| `src/mvs_ros_pkg/config/left_camera_trigger.yaml` | 相机硬件：分辨率、触发、曝光、增益、图像格式、话题 | 相机驱动 |
| `src/FAST-LIVO2/config/camera_pinhole.yaml` | FAST-LIVO2 相机模型：内参、畸变、图像尺寸 | FAST-LIVO2 算法 |
| `src/FAST-LIVO2/config/avia.yaml` | 图像开关、时间偏移、LiDAR-相机外参、VIO 参数 | FAST-LIVO2 算法 |

当前图像尺寸应保持一致：

```text
left_camera_trigger.yaml: width=1440, height=1080
camera_pinhole.yaml:      cam_width=1440, cam_height=1080
```

---

## 2. 相机画面全白/室外过曝：优先改这里

文件：`src/mvs_ros_pkg/config/left_camera_trigger.yaml`

### 2.1 当前基线配置

```yaml
TriggerEnable: 1
ExposureAutoMode: 0
ExposureTime: 10000
GainAuto: 2
Gain: 12
PixelFormat: 0
```

含义：

- `TriggerEnable: 1`：外部触发采图。保持不变；它决定触发方式，不是曝光时间。
- `ExposureAutoMode`：曝光模式。`0` 手动，`1` 自动调一次，`2` 连续自动。
- `ExposureTime`：手动曝光时间，单位微秒。`10000` 即 10 ms。
- `GainAuto`：增益模式。`0` 手动，`1` 自动调一次，`2` 连续自动。
- `Gain`：手动增益；只有 `GainAuto: 0` 时才实际生效。
- `PixelFormat: 0`：RGB8。当前视觉链路推荐保持此值。

### 2.2 方案 A：光照稳定时，使用固定低曝光（推荐先试）

适用：晴天室外、光照变化不大、希望视觉亮度稳定。

将上述段落改为：

```yaml
TriggerEnable: 1
ExposureAutoMode: 0
ExposureTime: 2000
GainAuto: 0
Gain: 0
PixelFormat: 0
```

解释：

- `2000 us = 2 ms`，比原来的 10 ms 短五倍。
- `Gain: 0` 避免电子增益继续放大强光。
- 若仍大面积发白，将 `ExposureTime` 单独降到 `1000`，再不够可试 `500`。
- 若画面太暗，只将 `ExposureTime` 逐步增加，例如 `500 → 1000 → 2000`；不要同时改增益。

### 2.3 方案 B：室内外频繁切换，连续自动曝光

适用：从阴影进入阳光、室内外来回移动。

```yaml
TriggerEnable: 1
ExposureAutoMode: 2
GainAuto: 2
PixelFormat: 0
```

解释：

- 相机按外部触发频率采图，自动曝光不会主动把 10 Hz 改成其他频率。
- 自动模式会改变每帧曝光时间和增益，可能使相邻帧亮度变化较大。
- 因此该方案更适合先排除“纯白图像”；长期建图通常再找一个合适的固定曝光值。

### 2.4 方案 C：启动时自动调一次，然后固定

适用：环境亮度基本稳定，但不确定初始曝光值。

```yaml
ExposureAutoMode: 1
GainAuto: 1
```

解释：相机启动后自动调节一次，随后锁定；通常比连续自动曝光更利于 VIO 的亮度一致性。

### 2.5 修改相机参数后的固定操作

```text
1. Ctrl+C 停止 FAST-LIVO2 算法终端（若正在运行）。
2. Ctrl+C 停止相机驱动终端。
3. 修改 left_camera_trigger.yaml 并保存。
4. 重新启动相机驱动。
5. 用 rqt_image_view 或 RViz 查看 /left_camera/image。
6. 图像可用后，再重新启动 FAST-LIVO2 算法。
```

相机驱动启动命令：

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
rosrun mvs_ros_pkg grabImgWithTrigger \
  /home/wxc/fastlivo2_ws/src/mvs_ros_pkg/config/left_camera_trigger.yaml
```

查看图像：

```bash
rqt_image_view /left_camera/image
```

---

## 3. 不要因过曝而改的参数

以下参数与相机曝光不是一回事，过曝时不要动：

```yaml
# avia.yaml
time_offset:
  img_time_offset: 0.1
  imu_time_offset: 0.0

extrin_calib:
  Rcl: [...]
  Pcl: [...]
```

- `img_time_offset`：图像与 LiDAR/IMU 的时间偏移，单位秒。只能通过同步实验确定。
- `imu_time_offset`：IMU 时间偏移，单位秒。不能用于修复相机亮度。
- `Rcl`：9 个数的旋转矩阵。
- `Pcl`：3 个数的平移向量，单位米。
- `Rcl/Pcl` 是 LiDAR-相机标定结果，必须成对修改；相机或雷达支架位置变化后才重新标定。

---

## 4. FAST-LIVO2 是否使用相机

文件：`src/FAST-LIVO2/config/avia.yaml`

```yaml
common:
  img_topic: "/left_camera/image"
  img_en: 1
  lidar_en: 1

imu:
  imu_en: true
```

- `img_topic`：算法订阅的 `sensor_msgs/Image` 话题。
- `img_en: 1`：完整 LIVO，使用 LiDAR + IMU + Camera。
- `img_en: 0`：ONLY_LIO，忽略图像，只使用 LiDAR + IMU。
- `lidar_en: 1`、`imu_en: true`：当前均应保持启用。

如果修改 `img_en`、`img_topic`、`img_time_offset`、`Rcl/Pcl` 或 VIO 参数：

```text
重新 rosparam load 对应 YAML，然后重启 fastlivo_mapping。
```

不需要重新编译。

---

## 5. 相机模型参数：只有重新标定后才修改

文件：`src/FAST-LIVO2/config/camera_pinhole.yaml`

```yaml
cam_model: Pinhole
cam_width: 1440
cam_height: 1080
cam_fx: ...
cam_fy: ...
cam_cx: ...
cam_cy: ...
cam_d0: ...
cam_d1: ...
cam_d2: ...
cam_d3: ...
```

- `cam_fx/cam_fy`：焦距，单位像素。
- `cam_cx/cam_cy`：主点坐标，单位像素。
- `cam_d0~cam_d3`：畸变参数。

这些数必须来自与当前 `1440×1080`、当前镜头焦距和当前相机 ROI 对应的一次标定。

以下情况需要重新标定或重新检查：

```text
改变分辨率、ROI、镜头焦距、镜头本体、相机本体。
```

---

## 6. LiDAR-IMU 时间同步异常：与相机分开处理

若算法终端出现：

```text
IMU and LiDAR not synced
imu loop back
```

先检查 Livox 硬件同步器，而不是改相机参数。

Livox 时间同步配置文件：

```text
src/livox_ros_driver/config/livox_lidar_config.json
```

关键项：

```json
"timesync_config": {
  "enable_timesync": true,
  "device_name": "/dev/ttyACM0"
}
```

运行 Livox 驱动后应出现：

```text
RMC data parse success!
Set lidar[0] sync time status[0] response[0]
```

若没有上述日志，先检查：

```bash
ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
```

注意：`ttyACM0/ttyACM1` 编号可能因 USB 枚举顺序改变；确认实际同步器端口后，再修改 JSON 并重启 Livox 驱动。

---

## 7. 当前启动顺序（完整 LIVO）

```text
终端 1：Livox 驱动，确认 RMC 时间同步成功。
终端 2：相机驱动，确认 /left_camera/image 图像正常。
终端 3：加载 avia.yaml、camera_pinhole.yaml，启动 fastlivo_mapping。
终端 4：RViz 查看地图和图像。
终端 5：需要采集时，rosbag record 保存三路原始话题。
```

相机、LiDAR、IMU 原始话题：

```text
/left_camera/image
/livox/lidar
/livox/imu
```

---

## 8. 改完配置后的检查清单

```text
[ ] 相机画面不是整片白色、也不是整片黑色。
[ ] /left_camera/image 发布稳定。
[ ] 图像分辨率与 camera_pinhole.yaml 一致。
[ ] Livox 日志出现 RMC 同步成功信息。
[ ] 算法终端没有 IMU and LiDAR not synced / imu loop back。
[ ] 启动后设备静止，等待 IMU 初始化完成，再开始移动。
```
