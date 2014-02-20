#ifndef GLOBALS_H
#define GLOBALS_H

#include <CoreFoundation/CoreFoundation.h>
#include <opencv2/opencv.hpp>
#include <stdlib.h>


#if __APPLE__
#else // Assumed to be windows
#define M_PI 3.1415926
#endif

typedef std::map<const char*, cv::Mat> MatDict;
typedef std::vector<cv::Point> ContourType;
typedef std::vector<ContourType> ContourContainerType;

#endif