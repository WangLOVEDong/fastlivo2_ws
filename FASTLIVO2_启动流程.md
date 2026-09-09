# FAST-LIVO2 实机启动流程（Livox Avia + 海康相机）

本文档适用于工作区：

```text
/home/wxc/fastlivo2_ws
```

## 一、启动前的机械要求

1. 雷达可以水平、抬头或低头安装，算法不要求雷达必须水平。
2. 雷达和相机必须保持标定时的相对位置和相对角度。
3. 如果整套设备一起倾斜，现有雷达—相机外参仍然有效。
4. 如果只转动雷达、相机没有一起转，现有外参会失效，需要恢复机械位置或重新标定。
5. 启动算法前先把设备固定好，避免松动和振动。

## 二、为什么使用四个终端

| 终端 | 作用 | 启动内容 |
| --- | --- | --- |
| 终端 1 | ROS 主节点 | `roscore` |
| 终端 2 | 雷达驱动 | Livox 点云和 IMU |
| 终端 3 | 相机驱动 | 海康图像和相机信息 |
| 终端 4 | FAST-LIVO2 | 状态估计、建图和 RViz |

每个终端都要单独执行环境脚本：

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
```

不要在这些终端中 source `fastlivo2_rtk_ws`。

## 三、项目编译流程

### 什么时候需要编译

以下改动通常需要重新编译：

- 修改 `.cpp`、`.h`、`CMakeLists.txt` 或 `package.xml`。
- 第一次把源码放入工作区，或者工作区还没有 `devel/setup.bash`。
- 修改了编译依赖、增加了源文件或改变了可执行程序。

以下改动通常不需要重新编译，重新启动相应节点即可：

- 修改 `.yaml`、`.launch`、`.json` 或 RViz 配置。
- 修改本文档或普通注释文件。

编译前应先停止正在使用待编译程序的节点。最稳妥的方法是按正常停止顺序停止算法、相机和雷达，再进行编译；不要一边运行旧程序，一边误以为它已经使用新编译结果。

### 方法 A：编译整个工作区（最常用）

打开一个新终端执行：

```bash
cd /home/wxc/fastlivo2_ws
source /opt/ros/noetic/setup.bash
export CMAKE_PREFIX_PATH="/home/wxc/catkin_ws/third_party/Sophus/install${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
catkin_make -j12 -l12
```

命令和参数含义：

- `cd`：进入需要编译的工作区根目录。
- `source /opt/ros/noetic/setup.bash`：加载 ROS Noetic 基础环境。
- `CMAKE_PREFIX_PATH`：CMake 查找依赖安装目录的变量；这里加入项目所需的 Sophus。
- `catkin_make`：编译当前 catkin 工作区。
- `-j12`：最多同时运行 12 个编译任务。
- `-l12`：系统负载达到 12 时不再继续增加新任务，避免机器过载。

如果机器卡顿或内存不足，可以降低并行数：

```bash
catkin_make -j4 -l4
```

### 方法 B：只编译改过的包（更快）

只修改 FAST-LIVO2 算法源码时：

```bash
cd /home/wxc/fastlivo2_ws
source /opt/ros/noetic/setup.bash
export CMAKE_PREFIX_PATH="/home/wxc/catkin_ws/third_party/Sophus/install${CMAKE_PREFIX_PATH:+:${CMAKE_PREFIX_PATH}}"
catkin_make --pkg fast_livo -j12 -l12
```

只修改海康相机驱动源码时：

```bash
cd /home/wxc/fastlivo2_ws
source /opt/ros/noetic/setup.bash
catkin_make --pkg mvs_ros_pkg -j12 -l12
```

只修改 Livox 驱动源码时：

```bash
cd /home/wxc/fastlivo2_ws
source /opt/ros/noetic/setup.bash
catkin_make --pkg livox_ros_driver -j12 -l12
```

`--pkg` 后面填写的是 ROS 包名，不是文件夹名：

- FAST-LIVO2 包名：`fast_livo`
- 相机驱动包名：`mvs_ros_pkg`
- Livox 驱动包名：`livox_ros_driver`

如果包之间的依赖也发生改变，优先使用方法 A 编译整个工作区。

### 怎样判断编译成功

必须看终端最后部分，而不是只看进度百分比。完整编译成功时通常会看到：

```text
[100%] Built target fastlivo_mapping
```

并且最后没有：

```text
error:
undefined reference
make: ***
Invoking "make ..." failed
```

黄色或紫色的 `warning`、`note` 不一定会导致失败；最终出现 `Built target` 且命令正常返回，才表示对应目标成功。

编译完成后，在每个要重新启动的终端重新执行：

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
```

已经运行的 ROS 进程不会自动换成新程序，必须停止并重新启动对应节点。

### 不要随便清空编译目录

日常修改直接再次执行 `catkin_make`，它会进行增量编译。不要把删除 `build`、`devel` 当作日常步骤；只有确认缓存损坏或构建系统异常时才考虑清理，并且要先明确删除范围。

## 四、完全从头启动

### 第 1 步：启动 ROS Master（终端 1）

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
roscore
```

看到下面内容表示成功：

```text
started core service [/rosout]
```

这个终端要一直保留。不要在运行过程中对终端 1 按 `Ctrl+C`，否则所有 ROS 节点都会失去 ROS Master。

### 第 2 步：启动 Livox 雷达（终端 2）

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
roslaunch livox_ros_driver livox_lidar_msg.launch
```

必须使用 `livox_lidar_msg.launch`，不要使用 `livox_lidar.launch`。

- `livox_lidar_msg.launch` 设置 `xfer_format=1`，发布 `livox_ros_driver/CustomMsg`。
- `livox_lidar.launch` 设置 `xfer_format=0`，发布 `sensor_msgs/PointCloud2`。
- 当前 FAST-LIVO2 的 `livox_pcl_cbk()` 回调函数要求 `CustomMsg`。

看到以下关键信息表示雷达连接成功：

```text
Broadcast Code: 3JE3N31001C0211
Lidar start sample success
Set imu rate success
```

### 第 3 步：确认雷达话题（新建临时终端）

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
rostopic list | grep livox
rostopic type /livox/lidar
```

应该看到：

```text
/livox/imu
/livox/lidar
livox_ros_driver/CustomMsg
```

检查完可以关闭这个临时终端，不影响前面的节点。

### 第 4 步：启动海康相机（终端 3）

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
roslaunch mvs_ros_pkg mvs_camera_trigger.launch
```

看到以下内容表示相机开始采集：

```text
Successfully created handle for device 0
Finish all params set! Start grabbing...
```

源码目前使用 `ROS_ERROR` 打印每帧时间，所以连续出现下面这种红色信息不代表采图失败：

```text
Time -> image_msg_current: ...
```

只要 `/left_camera/image` 持续发布，图像就是正常的。

### 第 5 步：让设备完全静止

在启动 FAST-LIVO2 前：

1. 把设备放在实际使用姿态，可以抬头或低头。
2. 保证雷达与相机之间没有发生相对转动。
3. 设备静止约 **2 秒**，确认手已经离开设备，不再晃动。

### 第 6 步：启动 FAST-LIVO2（终端 4）

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash
rospack find fast_livo
roslaunch fast_livo mapping_avia.launch
```

`rospack find fast_livo` 应输出：

```text
/home/wxc/fastlivo2_ws/src/FAST-LIVO2
```

启动后继续保持整套设备静止，不要立刻拿起来移动。

## 五、IMU 初始化到底需要多久

当前配置位于：

```text
/home/wxc/fastlivo2_ws/src/FAST-LIVO2/config/avia.yaml
```

关键参数是：

```yaml
imu:
  imu_en: true
  imu_int_frame: 30

uav:
  gravity_align_en: true
```

变量含义：

- `imu_en`：是否使用 IMU。
- `imu_int_frame`：传给 `ImuProcess::set_imu_init_frame_num()` 的初始化样本阈值，当前为 30。
- `MAX_INI_COUNT`：`ImuProcess` 内部保存的初始化阈值，由 `imu_int_frame` 设置。
- `init_iter_num`：已经累计的初始化 IMU 样本数量。
- `mean_acc`：初始化期间加速度计读数的平均值，用来估计重力方向。
- `mean_gyr`：初始化期间陀螺仪读数的平均值。
- `state_inout.gravity`：算法估计出的重力向量。
- `gravity_align_en`：是否把初始世界坐标系对齐到重力方向。

初始化不是简单地“固定等待 30 秒”。`init_iter_num` 按收到的 IMU 样本累加，一组雷达数据中可能包含多个 IMU 样本，所以达到 30 通常很快。

本机最近一次日志中：

```text
IMU Initializing: 3.3 %
IMU Initializing: 70.0 %
IMU Initials: Gravity: -0.0843 -0.0918 -9.8092
```

从第一次打印初始化进度到完成大约只有 **0.1 秒**。但是日志出现之前还包括节点启动、话题连接和第一批同步数据等待，因此实际操作不要只等 0.1 秒。

推荐判断标准：

1. 最准确的方法：等终端出现 `IMU Initials: Gravity:`。
2. 日常操作：启动 `mapping_avia.launch` 后保持静止 **3～5 秒**。
3. 如果没有看到初始化完成日志，继续保持静止，不要移动。
4. 初始化完成后，先缓慢平移，再缓慢转动，避免一开始快速甩动设备。

因此，完整的静止策略是：

```text
启动算法前静止约 2 秒
        +
启动算法后静止 3～5 秒，或直到看到 IMU Initials: Gravity
```

## 六、怎样判断初始化质量

正常重力向量的模长应该接近 `9.81 m/s²`。例如：

```text
Gravity: -0.0843 -0.0918 -9.8092
```

它的 Z 分量接近 `-9.81`，X、Y 分量接近 0，说明这次初始化时设备姿态接近水平且结果合理。

如果设备以抬头姿态启动，初始化过程中原始重力方向可以倾斜；开启 `gravity_align_en` 后，算法会把世界坐标系的竖直方向对齐到重力。因此雷达抬头本身不会必然导致地图歪。

以下情况容易造成地图倾斜或漂移：

1. IMU 初始化期间移动、转动或用手晃动设备。
2. 雷达和相机之间的机械角度与标定时不同。
3. 设备支架松动，运行时雷达或相机发生相对位移。
4. IMU 数据异常、时间戳跳变或话题中断。
5. RViz 观察视角倾斜——这种情况地图本身可能没有歪。

## 七、运行后的快速检查

在另一个临时终端执行：

```bash
source /home/wxc/fastlivo2_ws/scripts/setup_fastlivo2.bash

rostopic type /livox/lidar
rostopic hz /livox/lidar
rostopic hz /livox/imu
rostopic hz /left_camera/image
```

其中 `rostopic hz` 会持续运行。检查数值后在这个临时终端按 `Ctrl+C`，只会停止当前检查命令，不应影响其他终端中的驱动和算法。

## 八、正常停止顺序

建议按以下顺序分别按 `Ctrl+C`：

1. 终端 4：停止 FAST-LIVO2。
2. 终端 3：停止相机。
3. 终端 2：停止雷达。
4. 终端 1：最后停止 `roscore`。

不要先停止终端 1，否则其余节点会同时失去 ROS Master。

## 九、两个容易误判的问题

### 1. 启动算法后，相机 RViz 窗口消失

相机 launch 和 FAST-LIVO2 launch 都把 RViz 节点命名为 `/rviz`。后启动的 FAST-LIVO2 RViz 会替换先前的相机 RViz，但这不等于相机驱动停止。

使用下面命令确认相机是否还在发布：

```bash
rostopic hz /left_camera/image
```

### 2. 出现 PointCloud2 与 CustomMsg 类型冲突

典型信息：

```text
wants topic /livox/lidar to have datatype livox_ros_driver/CustomMsg
but our version has sensor_msgs/PointCloud2
Dropping connection
```

说明终端 2 启动错了文件。停止雷达驱动并重新执行：

```bash
roslaunch livox_ros_driver livox_lidar_msg.launch
```
