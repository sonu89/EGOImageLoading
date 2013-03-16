//
//  EGOImageLoader.h
//  EGOImageLoading
//
//  Created by Shaun Harrison on 9/15/09.
//  Copyright 2009 enormego. All rights reserved.
//
//  This work is licensed under the Creative Commons GNU General Public License License.
//  To view a copy of this license, visit http://creativecommons.org/licenses/GPL/2.0/
//  or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
//

#import <Foundation/Foundation.h>
#import"EGOImageLoadConnection.h"

@protocol EGOImageLoaderObserver;
@interface EGOImageLoader : NSObject<EGOImageLoadConnectionDelegate> {
@private
	NSDictionary* _currentConnections;
	NSMutableDictionary* currentConnections;
	
	NSLock* connectionsLock;
}

+ (EGOImageLoader*)sharedImageLoader;
+ (EGOImageLoader*)sharedImageLoaderThatCachesInMemoryOnly;
+ (EGOImageLoader*)sharedImageLoaderThatProcessesThumbnails;

- (BOOL)isLoadingImageURL:(NSURL*)aURL;
- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer;
- (UIImage*)imageForURL:(NSURL*)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer;

- (void)cancelLoadForURL:(NSURL*)aURL;
-(void) dumpImageMemoryCacheExceptForImages : (NSArray*) exceptTheseImagesArray;
-(void) timeToDumpmemCache : (NSNotification*) notification;
-(void) clearMemoryCache;
-(void) registerForDumpNotification;
-(void) addNewObjToImagesDict : (UIImage*) newImage forKey : (NSString*) key;
-(UIImage*) getSquareImageFromImage : (UIImage*) img withSideLength : (CGFloat) a;

-(void) setBackgroundImage : (UIImage*) backgroundImage forImageURLString : (NSString*) imgURLStr;
-(void) setForegroundImage : (UIImage*) foregroundImage forImageURLString : (NSString*) imgURLStr;
-(void) setThumbnailImageLength : (CGFloat) thumbnailImageLength forImageURLString : (NSString*) imgURLStr;
-(UIImage*) thumbnailFromImage : (UIImage*) img ForURLString : (NSString*) imgURLStr;

-(void) setMaximumNumberOfImagesAllowedInMemory : (NSInteger) maxNumOfImgs andDumpRatio : (CGFloat) memDumpRatio;

@property(nonatomic,retain) NSDictionary* currentConnections;

//
@property(nonatomic,retain) NSMutableDictionary *imagesDict;
@property(nonatomic,retain) NSMutableArray *imageKeysArray;
@property(nonatomic, assign) BOOL shouldCacheImageInMemoryOnly;
@property(nonatomic, assign) BOOL isRegisteredForDumpNotification;
@property(nonatomic, assign) BOOL shouldProcessThumbnails;
@property (nonatomic, strong) NSMutableDictionary *thumbnailImageLengths;
@property (nonatomic, strong) NSMutableDictionary *thumbnailBackgroundImages;
@property (nonatomic, strong) NSMutableDictionary *thumbnailForegroundImages;

@property (nonatomic, assign) NSInteger maxNumberOfImagesAllowedInMemory;
@property (nonatomic, assign) CGFloat dumpRatio;

//
@end

@protocol EGOImageLoaderObserver<NSObject>
@optional
- (void)imageLoaderDidLoad:(NSNotification*)notification; // Object will be EGOImageLoader, userInfo will contain imageURL and image
- (void)imageLoaderDidFailToLoad:(NSNotification*)notification; // Object will be EGOImageLoader, userInfo will contain error

@end