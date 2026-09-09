

#include <ros/ros.h>
// PCL specific includes
#include <sensor_msgs/PointCloud2.h>
#include <pcl_conversions/pcl_conversions.h>
#include <pcl/point_cloud.h>
#include <pcl/point_types.h>
//添加引用
#include <pcl/PCLPointCloud2.h>
#include <pcl/filters/passthrough.h>
 
ros::Publisher pub;
 
void cloud_cb (const sensor_msgs::PointCloud2ConstPtr& cloud_msg)
{
  pcl::PCLPointCloud2* cloud = new pcl::PCLPointCloud2; 
  pcl::PCLPointCloud2ConstPtr cloudPtr(cloud);
  pcl::PCLPointCloud2 cloud_filtered;
  pcl_conversions::toPCL(*cloud_msg, *cloud);
  pcl::PassThrough<pcl::PCLPointCloud2> pass;
  pass.setInputCloud (cloudPtr);
  pass.setFilterFieldName ("x");
  pass.setFilterLimits (1, 30);
  pass.filter (cloud_filtered);
 
  sensor_msgs::PointCloud2 cloud_pt;
  pcl_conversions::moveFromPCL(cloud_filtered, cloud_pt);
 
  pub.publish (cloud_pt);
}
 
int main (int argc, char** argv)
{
  ros::init (argc, argv, "PassThrough");
  ros::NodeHandle nh;
  ros::Subscriber sub = nh.subscribe<sensor_msgs::PointCloud2> ("/livox/lidar", 1, cloud_cb);
  pub = nh.advertise<sensor_msgs::PointCloud2> ("/livox/lidar/filter", 1);
  ros::spin ();
}
