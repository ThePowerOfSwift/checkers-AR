//
//  OpenCVWrapper.m
//  Checkers-AR
//
//  Created by Nikolas Chaconas on 10/23/16.
//  Copyright © 2016 Nikolas Chaconas. All rights reserved.
//

#import "OpenCVWrapper.hpp"
#include <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
//unfortunately need to do this to hide all opencv calls from swift
//otherwise I would put these in .hpp
@implementation OpenCVWrapper {
    cv::Mat cameraMatrix;
    cv::Mat distCoeffs;
    std::vector<std::vector<cv::Point2f>> imagePoints;
    std::vector<std::vector<cv::Point3f>> objectPoints;
    cv::Size boardSize;
    cv::Size imageSize;
    std::vector<cv::Mat> rvecs, tvecs;
    double fovx, fovy, focalLength, aspectRatio;
    cv::Point2d principalPoint;
}

//this will come in handy
-(UIImage *) makeMatFromImage: (UIImage *) image {
    cv::Mat imageMat;
    UIImageToMat(image, imageMat);
    //can do all sorts of stuff with the MAT
    //and then convert it back to UIImage for use in swift
    return MatToUIImage(imageMat);
}

//no argument constructor
-(void) initializeCalibrator {
    cameraMatrix = cv::Mat::eye(3, 3, CV_64F);
    distCoeffs = cv::Mat::zeros(4, 1, CV_64F);
    //could change this later
    int squareSize = 1;
    objectPoints.push_back(std::vector <cv::Point3f> ());
    for( int i = 0; i < 6; ++i )
        for( int j = 0; j < 6; ++j )
            objectPoints[0].push_back(cv::Point3f(double( j*squareSize ), double( i*squareSize ), 0));
    std::cout << "\n\n\nsetting board size!@!@$@$!\n\n\n" << std::endl;
    boardSize = cv::Size(6,6);
}

-(UIImage*) findChessboardCorners:(UIImage*) image1 {
    cv::Mat image;
    UIImageToMat(image1, image);
    
    std::vector<cv::Point2f> corners;
    std::cout << "board size is " << boardSize;
    bool found = findChessboardCorners(image, boardSize, corners, CV_CALIB_CB_ADAPTIVE_THRESH + CV_CALIB_CB_NORMALIZE_IMAGE);
    
    if(found) {
        std::cout << "\nimage found\n" << std::endl;
        imageSize = image.size();
        cv::Mat tempView;
        cvtColor(image, tempView, cv::COLOR_BGR2GRAY);
        cornerSubPix( tempView, corners, cv::Size(3,3),
                     cv::Size(-1,-1), cv::TermCriteria( CV_TERMCRIT_EPS+CV_TERMCRIT_ITER, 30, 0.1));
        
        imagePoints.push_back(corners);
    }

    cv::drawChessboardCorners(image, boardSize, corners, true);

    return MatToUIImage(image);
}

//this will store all of the final calibration values
-(void) finishCalibration {
    cv::calibrateCamera(objectPoints, imagePoints, imageSize, cameraMatrix,
                        distCoeffs, rvecs, tvecs, CV_CALIB_FIX_K4|CV_CALIB_FIX_K5);
    
    cv::calibrationMatrixValues(cameraMatrix, imageSize, 0.0f, 0.0f, fovx, fovy, focalLength, principalPoint, aspectRatio);
}

@end
