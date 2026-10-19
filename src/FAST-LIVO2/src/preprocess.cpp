/*
This file is part of FAST-LIVO2: Fast, Direct LiDAR-Inertial-Visual Odometry.

Developer: Chunran Zheng <zhengcr@connect.hku.hk>

For commercial use, please contact me at <zhengcr@connect.hku.hk> or
Prof. Fu Zhang at <fuzhang@hku.hk>.

This file is subject to the terms and conditions outlined in the 'LICENSE' file,
which is included as part of this source code package.
*/

#include "preprocess.h"

void Preprocess::process(const livox_ros_driver::CustomMsg::ConstPtr &msg, PointCloudXYZI::Ptr &pcl_out)
{
  // pl_full：保留原始索引的临时帧，用于与前一点比较时间；pl_surf：最终输出。
  PointCloudXYZI pl_full;
  PointCloudXYZI &pl_surf = *pcl_out;
  pl_surf.clear();
  const uint32_t plsize = msg->point_num;
  pl_full.resize(plsize);
  pl_surf.reserve(plsize);
  uint32_t valid_num = 0;

  for (uint32_t i = 0; i < plsize; ++i)
  {
    if (msg->points[i].line >= N_SCANS) continue;
    ++valid_num;

    PointType &point = pl_full[i];
    point.x = msg->points[i].x;
    point.y = msg->points[i].y;
    point.z = msg->points[i].z;
    point.intensity = msg->points[i].reflectivity;

    // offset_time 是相对帧起点的纳秒，除以 10^6 转毫秒。后续除以 1000 转秒。
    point.curvature = msg->points[i].offset_time / float(1000000);
    // 保留原版时间跳变补偿：超过 1ms 时，用前一点时间 + 0.004166667ms。
    if (i == 0)
      point.curvature = fabs(point.curvature) < 1.0 ? point.curvature : 0.0;
    else
      point.curvature = fabs(point.curvature - pl_full[i - 1].curvature) < 1.0
                            ? point.curvature
                            : pl_full[i - 1].curvature + 0.004166667f;

    if (valid_num % point_filter_num == 0 &&
        point.x * point.x + point.y * point.y + point.z * point.z >= blind_sqr)
      pl_surf.push_back(point);
  }
}
