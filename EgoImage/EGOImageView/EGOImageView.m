//
//  EGOImageView.m
//  EGOImageLoading
//
//  Created by Shaun Harrison on 9/15/09.
//  Copyright 2009 enormego. All rights reserved.
//
//  This work is licensed under the Creative Commons GNU General Public License License.
//  To view a copy of this license, visit http://creativecommons.org/licenses/GPL/2.0/
//  or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
//

#import "EGOImageView.h"
#import "EGOImageLoader.h"

@implementation EGOImageView
@synthesize imageURL, placeholderImage, delegate;
@synthesize memoryCaching;


- (id)initWithPlaceholderImage:(UIImage*)anImage {
	return [self initWithPlaceholderImage:anImage delegate:nil];	
}

- (id)initWithPlaceholderImage:(UIImage*)anImage delegate:(id<EGOImageViewDelegate>)aDelegate {
	if((self = [super initWithImage:anImage])) {
		self.placeholderImage = anImage;
		self.delegate = aDelegate;
	}
	
	return self;
}

-(void) gotAnImage : (NSNotification*) notification
{
   NSDictionary *dict=[notification userInfo];
    EGOImageView *gotImgView=(EGOImageView*)[dict objectForKey:@"imgview"];
    if(gotImgView==nil)NSLog(@"NIL gotImgView");
    if(gotImgView!=self) return;
    UIImage *gotImage=[dict objectForKey:@"img"];
    if(gotImage==nil)NSLog(@"NIL gotImg");
    self.image=gotImage;
    [self setNeedsDisplay];
    /*dispatch_async(dispatch_get_main_queue(), ^(void){
        NSDictionary *dict=[notification userInfo];
        EGOImageView *gotImgView=(EGOImageView*)[dict objectForKey:@"imgview"];
        if(gotImgView!=self) return;
        UIImage *gotImage=[dict objectForKey:@"img"];
        self.image=gotImage;
        [self setNeedsDisplay];
    });*/
    
}

- (void)setImageURL:(NSURL *)aURL {
	[imageURL release];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(gotAnImage:) name:@"gotanimage" object:nil];
    
    self.placeholderImage = [UIImage imageNamed:@"icon.png"]; 
    self.contentMode = UIViewContentModeScaleAspectFit;
	if(!aURL) {
        
        self.image = self.placeholderImage;
		imageURL = nil;
        
		return;
	} else {
		imageURL = [aURL retain];
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];
    UIImage* anImage;
    if(!self.memoryCaching){
        //AppDelegate *d=(AppDelegate*)[[UIApplication sharedApplication]delegate];
        //NO ASYNC
        UIImage *theImg=[[EGOImageLoader sharedImageLoader] imageForURL:aURL shouldLoadWithObserver:self];
        if(theImg) {
            // NSLog(@"cached image");
            self.image = theImg;
            
        } else {
            self.image = self.placeholderImage;
            // NSLog(@"downloading image");
            [self.delegate egoImageView:self startedDownloadingImageForURL : aURL];
            
        }
       /* dispatch_async(dispatch_get_main_queue(), ^(void){
            UIImage *theImg=[[EGOImageLoader sharedImageLoader] imageForURL:aURL shouldLoadWithObserver:self];
            if(theImg) {
                // NSLog(@"cached image");
                self.image = theImg;
                
            } else {
                self.image = self.placeholderImage;
                // NSLog(@"downloading image");
                [self.delegate egoImageView:self startedDownloadingImageForURL : aURL];
                
            }
        });*/
        //USING NOTIFCIATIONS
        //dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^
        //dispatch_get_main_queue()
       /* dispatch_async(dispatch_get_main_queue(), ^(void){
            UIImage *theImg=[[EGOImageLoader sharedImageLoader] imageForURL:aURL shouldLoadWithObserver:self];
            if(theImg) {
                // NSLog(@"cached image");
                [[NSNotificationCenter defaultCenter] postNotificationName:@"gotanimage" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                              self, @"imgview",theImg,@"img",
                                                                                                              nil]];
                
            } else {
                // NSLog(@"downloading image");
                [[NSNotificationCenter defaultCenter] postNotificationName:@"gotanimage" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                              self, @"imgview",self.placeholderImage,@"img",
                                                                                                              nil]];
                [self.delegate egoImageView:self startedDownloadingImageForURL : aURL];
                
            }
        });*/
        
        
        return;
    }
    else {
        [[EGOImageLoader sharedImageLoaderThatCachesInMemoryOnly]registerForDumpNotification];
        anImage=[[EGOImageLoader sharedImageLoaderThatCachesInMemoryOnly] imageForURL:aURL shouldLoadWithObserver:self];
    }
	
	if(anImage) {
       // NSLog(@"cached image");
       /* dispatch_async(dispatch_get_main_queue(), ^(void){
            
        });*/
        self.image = anImage;
        
	} else {
		self.image = self.placeholderImage;
       // NSLog(@"downloading image");
        [self.delegate egoImageView:self startedDownloadingImageForURL : aURL];
        
	}
}

#pragma mark -
#pragma mark Image loading

- (void)cancelImageLoad {
    if(!memoryCaching)[[EGOImageLoader sharedImageLoader] cancelLoadForURL:self.imageURL];
    else [[EGOImageLoader sharedImageLoaderThatCachesInMemoryOnly] cancelLoadForURL:self.imageURL];
    NSLog(@"cancelled");
}

- (void)imageLoaderDidLoad:(NSNotification*)notification {
    //NSLog(@"imageLoaderDidLoad");
    NSURL *urlUsed=[[notification userInfo] objectForKey:@"imageURL"];
    //if([self.delegate respondsToSelector:@selector(canRespondToImageDownloadStartAndFinish)])[self.delegate egoImageView:self finishedDownloadingImageForURL : urlUsed];
    [self.delegate egoImageView:self finishedDownloadingImageForURL : urlUsed];
    if(![[[notification userInfo] objectForKey:@"imageURL"] isEqual:self.imageURL]) return;

	UIImage* anImage = [[notification userInfo] objectForKey:@"image"];
	dispatch_async(dispatch_get_main_queue(), ^(void){
        self.image = anImage;
        [self setNeedsDisplay];
        if([self.delegate respondsToSelector:@selector(imageViewLoadedImage:)]) {
            [self.delegate imageViewLoadedImage:self];
        }
    });
    
	
		
}

- (void)imageLoaderDidFailToLoad:(NSNotification*)notification {
    NSLog(@"imageLoaderDidFailToLoad");
    NSURL *urlUsed=[[notification userInfo] objectForKey:@"imageURL"];
    //if([self.delegate respondsToSelector:@selector(canRespondToImageDownloadStartAndFinish)])[self.delegate egoImageView:self finishedDownloadingImageForURL : urlUsed];
    [self.delegate egoImageView:self finishedDownloadingImageForURL : urlUsed];
	if(![[[notification userInfo] objectForKey:@"imageURL"] isEqual:self.imageURL]) return;
	
	if([self.delegate respondsToSelector:@selector(imageViewFailedToLoadImage:error:)]) {
		[self.delegate imageViewFailedToLoadImage:self error:[[notification userInfo] objectForKey:@"error"]];
	}
}



-(void) dumpImageMemoryCacheExceptForImages : (NSArray*) urlArray
{
    if(!self.memoryCaching) return;
    [[EGOImageLoader sharedImageLoaderThatCachesInMemoryOnly]dumpImageMemoryCacheExceptForImages : urlArray];
}

#pragma mark -
- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	self.imageURL = nil;
	self.placeholderImage = nil;
    [super dealloc];
}

@end
