//
//  OpenCVWrapper.h
//  Checkers-AR
//
//  Created by Nikolas Chaconas on 10/23/16.
//  Copyright © 2016 Nikolas Chaconas. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@interface OpenCVWrapper : NSObject
-(void) initializeCalibrator;
-(UIImage *) makeMatFromImage: (UIImage *) image;
-(UIImage *) findChessboardCorners:(UIImage *) image1;
@end
