# FAST-LIVO2 一键任务

在 VS Code 中打开整个 `/home/wxc/fastlivo2_ws` 文件夹。

1. 接好 Avia、相机和时间同步器，确认 JSON 中的串口正确。
2. 保持设备静止，选择菜单「终端 → 运行任务」。
3. 选择「FAST-LIVO2：实时建图 + RViz（不录包）」或「FAST-LIVO2：实时建图 + RViz + 录制 bag」。
4. 等待 IMU 初始化和实际地图更新，再移动设备。
5. 在该任务终端按 `Ctrl+C`，停止本任务启动的全部节点。

两个任务都包含雷达驱动、海康相机驱动、FAST-LIVO2 和一个地图 RViz。
无需先手动启动 roscore；roslaunch 会在没有 ROS Master 时自动启动。
如果已有独立 ROS Master，则复用它，退出任务时不会关闭该独立 Master。
三个任务不能同时运行，也不要同时运行原来的手动启动命令。

录包任务录制 `/livox/lidar`、`/livox/imu`、`/left_camera/image`，
保存在工作区的 `bags/avia_camera_日期_时间_进程号.bag`。
终端会显示完整保存路径和 `Recording to` 日志；启动成功不代表各话题一定有数据。
录包时按 `Ctrl+C` 会停止录包以及本任务的驱动、算法和 RViz，
并为正常退出预留 60 秒；等待终端结束后再关闭终端。
请勿点击垃圾桶强制关闭终端或直接断电，否则可能留下 `.bag.active`。
录完用 `rosbag info 实际文件路径.bag` 检查时长、话题和消息数量。

也可在工作区终端运行：

```bash
bash scripts/run_fastlivo2.bash live
bash scripts/run_fastlivo2.bash record
```

脚本参数 `live` 表示不录包，`record` 表示同时录包。
`record` 使用 512 MiB 的 rosbag 缓冲区，启动前要求至少 2 GiB 可用空间；
图像数据较大，请持续留意磁盘空间和丢帧警告。
相机的逐帧日志写入 ROS 日志目录，避免淹没任务终端。

## 回放已有 bag

1. 停止实时建图和录包任务，无需连接雷达、相机或同步器。
2. 打开工作区根目录的 `fastlivo2_replay.json`，修改 `bag_path` 并保存：

   ```json
   {
     "bag_path": "/home/wxc/fastlivo2_ws/bags/avia_camera_20261015_113203_24128.bag"
   }
   ```

   `bag_path` 是要播放的 bag 文件路径，包含文件名；保留 JSON 的双引号。
   可以填写绝对路径，也可以填写相对工作区根目录的路径，例如 `bags/文件名.bag`。
3. 点击「终端 → 运行任务 → FAST-LIVO2：回放 bag + RViz（读取本地配置）」，无需粘贴路径。
4. 任务检查文件及三个传感器话题，自动启动 ROS（如需要）、FAST-LIVO2、RViz 和播放器。
5. 播放器使用 bag 的 `/clock` 仿真时间，以原速回放，并留出启动延迟。
6. 播放结束后保留 RViz 供查看地图；在任务终端按 `Ctrl+C` 退出。

回放任务不会启动实物驱动，也不会录制新 bag；使用当前 `avia.yaml` 和相机标定配置。
请使用与录制时设备安装和标定相匹配的配置。
回放启用 `use_sim_time=true`，实时任务会显式恢复为 `false`。
回放只发布点云、IMU、图像三个话题，避免其他 bag 内输出与算法节点冲突。

也可以直接在工作区终端运行：

```bash
bash scripts/run_fastlivo2.bash replay
```

脚本第一个参数 `replay` 选择回放模式，默认读取 `fastlivo2_replay.json`。
每次启动都会重新读取配置；修改后保存，再运行任务即可，无需编译。
终端命令仍可选填第二个参数，临时覆盖配置中的 bag 路径。
