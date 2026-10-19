/*
This file is part of FAST-LIVO2: Fast, Direct LiDAR-Inertial-Visual Odometry.

Developer: Chunran Zheng <zhengcr@connect.hku.hk>

For commercial use, please contact me at <zhengcr@connect.hku.hk> or
Prof. Fu Zhang at <fuzhang@hku.hk>.

This file is subject to the terms and conditions outlined in the 'LICENSE' file,
which is included as part of this source code package.
*/

#ifndef PREPROCESS_H_
#define PREPROCESS_H_

#include "common_lib.h"
#include <livox_ros_driver/CustomMsg.h>

// 当前硬件：Livox Avia。直接使用过滤后的原始点，不提前提取角点/平面点。
class Preprocess
{
public:
  // msg：输入 Livox 帧；pcl_out：输出 LiDAR 系点云，curvature 借存帧内时间(ms)。
  void process(const livox_ros_driver::CustomMsg::ConstPtr &msg, PointCloudXYZI::Ptr &pcl_out);

  int point_filter_num = 1;  // 每 point_filter_num 个有效点保留一个，计数在距离过滤之前。
  int N_SCANS = 6;           // Avia 扫描线数；line >= N_SCANS 的点不参与处理。
  double blind = 0.01;       // 最小保留距离(m)，由 YAML 覆盖。
  double blind_sqr = 0.0001; // blind²，加载参数后计算，避免逐点开平方。
};

typedef std::shared_ptr<Preprocess> PreprocessPtr;
#endif // PREPROCESS_H_
