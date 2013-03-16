//
//  EGOImageButton.m
//  EGOImageLoading
//
//  Created by Shaun Harrison on 9/30/09.
//  Copyright 2009 enormego. All rights reserved.
//
//  This work is licensed under the Creative Commons GNU General Public License License.
//  To view a copy of this license, visit http://creativecommons.org/licenses/GPL/2.0/
//  or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
//

#import "EGOImageButton.h"


@implementation EGOImageButton
@synthesize imageURL, placeholderImage, delegate;
@synthesize memoryCaching;
@synthesize thumbnailProcessing;

- (id)initWithPlaceholderImage:(UIImage*)anImage {
	return [self initWithPlaceholderImage:anImage delegate:nil];	
}

- (id)initWithPlaceholderImage:(UIImage*)anImage delegate:(id<EGOImageButtonDelegate>)aDelegate {
	if((self = [super initWithFrame:CGRectZero])) {
		self.placeholderImage = anImage;
		self.delegate = aDelegate;
		[self setBackgroundImage:self.placeholderImage forState:UIControlStateNormal];
	}
	
	return self;
}



-(void) setThumbnailImageLength : (CGFloat) thumbnailImageLength forImageURLString : (NSString*) imgURLStr
{
    [[EGOImageLoader sharedImageLoaderThatProcessesThumbnails] setThumbnailImageLength : thumbnailImageLength forImageURLString:imgURLStr];
}

-(void) setBackgroundImage  : (UIImage*) bgImg forImageURLString : (NSString*) imgURLStr
{
    [[EGOImageLoader sharedImageLoaderThatProcessesThumbnails] setBackgroundImage:bgImg forImageURLString:imgURLStr];
}

-(void) setForegroundImage  : (UIImage*) fgImg forImageURLString : (NSString*) imgURLStr
{
    [[EGOImageLoader sharedImageLoaderThatProcessesThumbnails] setForegroundImage:fgImg forImageURLString:imgURLStr];
}

- (void)setImageURL:(NSURL *)aURL {
	[imageURL release];
    
    self.placeholderImage = [UIImage imageNamed:@"icon.png"]; 
    //self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    //self.contentMode = UIViewContentModeScaleAspectFit;

	if(!aURL) {
		[self setBackgroundImage:self.placeholderImage forState:UIControlStateNormal];
		imageURL = nil;
		return;
	} else {
		imageURL = [aURL retain];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    UIImage* anImage;
	if(!self.memoryCaching){
        if(thumbnailProcessing){
            NSLog(@"This egoimagebtn will use sharedImageLoaderThatProcessesThumbnails");
            anImage=[[EGOImageLoader sharedImageLoaderThatProcessesThumbnails]imageForURL:aURL shouldLoadWithObserver:self];
        }
        else  anImage = [[EGOImageLoader sharedImageLoader] imageForURL:aURL shouldLoadWithObserver:self];
    }
    else {
        [[EGOImageLoader sharedImageLoaderThatCachesInMemoryOnly]registerForDumpNotification];
        anImage=[[EGOImageLoader sharedImageLoaderThatCachesInMemoryOnly] imageForURL:aURL shouldLoadWithObserver:self];
    }

	
	if(anImage) {
		
        
        [self setBackgroundImage:anImage forState:UIControlStateNormal];
        
	} else {
		[self setBackgroundImage:self.placeholderImage forState:UIControlStateNormal];
	}
}



#pragma mark -
#pragma mark Image loading

- (void)cancelImageLoad {
	[[EGOImageLoader sharedImageLoader] cancelLoadForURL:self.imageURL];
}

- (void)imageLoaderDidLoad:(NSNotification*)notification {
	if(![[[notification userInfo] objectForKey:@"imageURL"] isEqual:self.imageURL]) return;
	
	UIImage* anImage = [[notification userInfo] objectForKey:@"image"];
	
    [self setBackgroundImage:anImage forState:UIControlStateNormal];
	[self setNeedsDisplay];
	
	if([self.delegate respondsToSelector:@selector(imageButtonLoadedImage:)]) {
		[self.delegate imageButtonLoadedImage:self];
	}	
}

- (void)imageLoaderDidFailToLoad:(NSNotification*)notification {
	if(![[[notification userInfo] objectForKey:@"imageURL"] isEqual:self.imageURL]) return;
	
	if([self.delegate respondsToSelector:@selector(imageButtonFailedToLoadImage:error:)]) {
		[self.delegate imageButtonFailedToLoadImage:self error:[[notification userInfo] objectForKey:@"error"]];
	}
}

#pragma mark -
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	self.imageURL = nil;
	self.placeholderImage = nil;
    [super dealloc];
}

@end
