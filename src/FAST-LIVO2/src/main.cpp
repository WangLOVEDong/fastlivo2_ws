#include "LIVMapper.h"

int main(int argc, char **argv)
{
  // argc/argv：命令行参数；nh：ROS 节点句柄；it：图像通信接口。
  ros::init(argc, argv, "laserMapping");
  ros::NodeHandle nh;
  image_transport::ImageTransport it(nh);
  // mapper：总调度器。run() 内按同步测量事件依次执行 IMU、LIO 和 VIO。
  LIVMapper mapper(nh);
  mapper.initializeSubscribersAndPublishers(nh, it);
  mapper.run();
  return 0;
}
