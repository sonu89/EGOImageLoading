//
//  EGOImageLoader.m
//  EGOImageLoading
//
//  Created by Shaun Harrison on 9/15/09.
//  Copyright 2009 enormego. All rights reserved.
//
//  This work is licensed under the Creative Commons GNU General Public License License.
//  To view a copy of this license, visit http://creativecommons.org/licenses/GPL/2.0/
//  or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
//

#import "EGOImageLoader.h"
#import "EGOImageLoadConnection.h"
#import "EGOCache.h"

#define MAXNUMBEROFIMAGESINMEMORY 10

static EGOImageLoader* __imageLoader;
static EGOImageLoader* __imageLoaderThatCachesInMemory;
static EGOImageLoader*__imageLoaderThatProcessesThumbnails;

inline static NSString* keyForURL(NSURL* url) {
	return [NSString stringWithFormat:@"EGOImageLoader-%u", [[url description] hash]];
}

#define kImageNotificationLoaded(s) [@"kEGOImageLoaderNotificationLoaded-" stringByAppendingString:keyForURL(s)]
#define kImageNotificationLoadFailed(s) [@"kEGOImageLoaderNotificationLoadFailed-" stringByAppendingString:keyForURL(s)]

@implementation EGOImageLoader
@synthesize currentConnections=_currentConnections;
@synthesize shouldCacheImageInMemoryOnly, isRegisteredForDumpNotification;
@synthesize shouldProcessThumbnails;
@synthesize thumbnailImageLengths;
@synthesize thumbnailBackgroundImages;
@synthesize thumbnailForegroundImages;


//
@synthesize imagesDict,imageKeysArray;

//
NSMutableDictionary *tempDict;
CGFloat dumpRatio=0.7;


-(void) setBackgroundImage : (UIImage*) backgroundImage forImageURLString : (NSString*) imgURLStr
{
   
    if(!self.thumbnailBackgroundImages) self.thumbnailBackgroundImages = [[NSMutableDictionary alloc]init];
    [self.thumbnailBackgroundImages setObject:backgroundImage forKey:imgURLStr];
    
}

-(void) setForegroundImage : (UIImage*) foregroundImage forImageURLString : (NSString*) imgURLStr
{
    if(!self.thumbnailForegroundImages) self.thumbnailForegroundImages = [[NSMutableDictionary alloc]init];
    [self.thumbnailForegroundImages setObject:foregroundImage forKey:imgURLStr];
}

-(void) setThumbnailImageLength : (CGFloat) thumbnailImageLength forImageURLString : (NSString*) imgURLStr
{
    if(!self.thumbnailImageLengths) self.thumbnailImageLengths = [[NSMutableDictionary alloc]init];
    [self.thumbnailImageLengths setObject:[NSNumber numberWithFloat:thumbnailImageLength] forKey:imgURLStr];
    
}

-(void) registerForDumpNotification
{
    if(!isRegisteredForDumpNotification){
        isRegisteredForDumpNotification=YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(justDumpMemCache) name:@"dumpimagememcache" object:nil];
    }
}

-(void) justDumpMemCache
{
    
    if(shouldCacheImageInMemoryOnly){
        NSLog(@"dumpimagememcache notification received...");
        NSLog(@"Before dump number of images : %d     %d",[self.imagesDict count],[self.imageKeysArray count]);
        int numberOfImagesToDump=(int)([self.imageKeysArray count]*dumpRatio);
        NSLog(@"To dump %d images",numberOfImagesToDump);
        NSLog(@"desc of keys: %@",[self.imageKeysArray description]);
        for(int t=0;t<numberOfImagesToDump;t++){
            NSString *urlToDump=[self.imageKeysArray objectAtIndex:t];
            [self.imagesDict removeObjectForKey:urlToDump];
            
        }
        NSLog(@"num of keys afer mage dump : %d",[self.imageKeysArray count]);
        NSLog(@"desc of keys after mage dump: %@",[self.imageKeysArray description]);
        for(int t=0;t<numberOfImagesToDump;t++){
            [self.imageKeysArray removeObjectAtIndex:0];
        }
        
        NSLog(@"After dump number of images : %d     %d",[self.imagesDict count],[self.imageKeysArray count]);
    }
    
}

-(void) timeToDumpmemCache : (NSNotification*) notification
{
    if(shouldCacheImageInMemoryOnly){
        NSLog(@"dumpimagememcache notification received...invoking dumpImageMemoryCacheExceptForImages");
        NSArray *d=[[notification userInfo]objectForKey:@"array"];
        [self dumpImageMemoryCacheExceptForImages:d];
    }
    else NSLog(@"no mem cache");
    
}

-(void) dumpImageMemoryCacheExceptForImages : (NSArray*) exceptTheseImagesArray
{
    
    NSLog(@"Before dump images : %d",[self.imagesDict count]);
    NSLog(@"cache dumping started!");
    if(!tempDict)tempDict=[[NSMutableDictionary alloc]init];
    for(int j=0;j<[exceptTheseImagesArray count];j++){
        if([self.imagesDict objectForKey:[exceptTheseImagesArray objectAtIndex:j]]) [tempDict setObject:[self.imagesDict objectForKey:[exceptTheseImagesArray objectAtIndex:j]] forKey:[exceptTheseImagesArray objectAtIndex:j]];
    }
    [self.imagesDict removeAllObjects];
    [self.imagesDict addEntriesFromDictionary:tempDict];
    [tempDict removeAllObjects];
    NSLog(@"cache dumping ended!");
    NSLog(@"After dump images : %d",[self.imagesDict count]);
}

+ (EGOImageLoader*)sharedImageLoader {
	@synchronized(self) {
		if(!__imageLoader) {
			__imageLoader = [[[self class] alloc] init];
            __imageLoader.shouldCacheImageInMemoryOnly=NO;
		}
	}
	
	return __imageLoader;
}

+ (EGOImageLoader*)sharedImageLoaderThatCachesInMemoryOnly {
	@synchronized(self) {
		if(!__imageLoaderThatCachesInMemory) {
			__imageLoaderThatCachesInMemory = [[[self class] alloc] init];
            __imageLoaderThatCachesInMemory.shouldCacheImageInMemoryOnly=YES;
            [__imageLoaderThatCachesInMemory registerForDumpNotification];
            
		}
	}
	
	return __imageLoaderThatCachesInMemory;
}
+ (EGOImageLoader*)sharedImageLoaderThatProcessesThumbnails{
    @synchronized(self) {
		if(!__imageLoaderThatProcessesThumbnails) {
			__imageLoaderThatProcessesThumbnails = [[[self class] alloc] init];
            __imageLoaderThatProcessesThumbnails.shouldCacheImageInMemoryOnly=NO;
            __imageLoaderThatProcessesThumbnails.shouldProcessThumbnails=YES;
            
		}
	}
	
	return __imageLoaderThatProcessesThumbnails;
}

- (id)init {
	if((self = [super init])) {
		connectionsLock = [[NSLock alloc] init];
		currentConnections = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

-(void) clearMemoryCache
{
    if(self.imageKeysArray) [self.imageKeysArray removeAllObjects];
    if(self.imagesDict) [self.imagesDict removeAllObjects];
}

- (EGOImageLoadConnection*)loadingConnectionForURL:(NSURL*)aURL {
	EGOImageLoadConnection* connection = [[self.currentConnections objectForKey:aURL] retain];
	if(!connection) return nil;
	else return [connection autorelease];
}

- (void)cleanUpConnection:(EGOImageLoadConnection*)connection {
	if(!connection.imageURL) return;
	
	connection.delegate = nil;
	
	[connectionsLock lock];
	[currentConnections removeObjectForKey:connection.imageURL];
	self.currentConnections = [[currentConnections copy] autorelease];
	[connectionsLock unlock];	
}

- (BOOL)isLoadingImageURL:(NSURL*)aURL {
	return [self loadingConnectionForURL:aURL] ? YES : NO;
}

- (void)cancelLoadForURL:(NSURL*)aURL {
	EGOImageLoadConnection* connection = [self loadingConnectionForURL:aURL];
	[connection cancel];
	[self cleanUpConnection:connection];
}

- (void)loadImageForURL:(NSURL*)aURL observer:(id<EGOImageLoaderObserver>)observer {
	if(!aURL) return;
	
	if([observer respondsToSelector:@selector(imageLoaderDidLoad:)]) {
		[[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(imageLoaderDidLoad:) name:kImageNotificationLoaded(aURL) object:self];
	}
	
	if([observer respondsToSelector:@selector(imageLoaderDidFailToLoad:)]) {
		[[NSNotificationCenter defaultCenter] addObserver:observer selector:@selector(imageLoaderDidFailToLoad:) name:kImageNotificationLoadFailed(aURL) object:self];
	}
	
	if([self loadingConnectionForURL:aURL]) {
		return;
	}
	
	EGOImageLoadConnection* connection = [[EGOImageLoadConnection alloc] initWithImageURL:aURL delegate:self];

	[connectionsLock lock];
	[currentConnections setObject:connection forKey:aURL];
	self.currentConnections = [[currentConnections copy] autorelease];
	[connectionsLock unlock];

	[connection start];
	[connection release];
}

- (UIImage*)imageForURL:(NSURL*)aURL shouldLoadWithObserver:(id<EGOImageLoaderObserver>)observer {
	if(!aURL) return nil;
    UIImage* anImage;
	if(!self.shouldCacheImageInMemoryOnly) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            //anImage = [[EGOCache currentCache] imageForKey:keyForURL(aURL)];
        });
       anImage = [[EGOCache currentCache] imageForKey:keyForURL(aURL)];
    }
    else{
        if(!self.imagesDict) self.imagesDict=[[NSMutableDictionary alloc]init];
        if(!self.imageKeysArray) self.imageKeysArray=[[NSMutableArray alloc]init];
        anImage=[self.imagesDict objectForKey:[aURL absoluteString]];
    }
    
    
	
	if(anImage) {
		return anImage;
	} else {
		[self loadImageForURL:(NSURL*)aURL observer:observer];
		return nil;
	}
}


#pragma mark -
#pragma mark URL Connection delegate methods

-(void) addNewObjToImagesDict : (UIImage*) newImage forKey : (NSString*) key
{
    [self.imagesDict setObject:newImage forKey:key];
    [self.imageKeysArray addObject:key];
    if([self.imagesDict count]>MAXNUMBEROFIMAGESINMEMORY){
        NSLog(@"More than %d images in memory, count is %d! Dumping!!!",MAXNUMBEROFIMAGESINMEMORY,[self.imagesDict count]);
        [self.imagesDict removeObjectForKey:[self.imageKeysArray objectAtIndex:0]];
        [self.imageKeysArray removeObjectAtIndex:0];
        NSLog(@"Post dump image count : %d",[self.imagesDict count]);
    }
}

-(UIImage*) getSquareImageFromImage : (UIImage*) img withSideLength : (CGFloat) a
{
    
    /* CGFloat maxLength;
     if(img.size.height>=img.size.width) maxLength=img.size.height;
     else maxLength=img.size.width;
     CGFloat scale=a/maxLength;
     CGFloat newHeight=img.size.height*scale;
     CGFloat newWidth=img.size.width*scale;
     UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
     [img drawInRect:CGRectMake(0,0,newWidth,newHeight)];
     UIImage *img1 = UIGraphicsGetImageFromCurrentImageContext();
     UIGraphicsEndImageContext();
     
     UIImage *backgroundImage = [UIImage imageNamed:@"whitebg50.png"];
     UIImage *watermarkImage = img1;
     UIGraphicsBeginImageContext(backgroundImage.size);
     [backgroundImage drawInRect:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
     [watermarkImage drawInRect:CGRectMake(backgroundImage.size.width/2 - watermarkImage.size.width/2, backgroundImage.size.height/2 - watermarkImage.size.height/2, watermarkImage.size.width, watermarkImage.size.height)];
     UIImage *retImage=UIGraphicsGetImageFromCurrentImageContext();
     UIGraphicsEndImageContext();
     return  retImage;*/
    //NSLog(@"Scaling");
    NSLog(@"processing image!");
    CGFloat minLength;
    if(img.size.height>=img.size.width) minLength=img.size.width;
    else minLength=img.size.height;
    CGFloat scale=a/minLength;
    CGFloat newHeight=img.size.height*scale;
    CGFloat newWidth=img.size.width*scale;
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [img drawInRect:CGRectMake(0,0,newWidth,newHeight)];
    UIImage *img1 = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //UIImage *img1=img;
    //NSLog(@"original img  H:  %f   W:   %f",img1.size.height,img1.size.width);
    
    //NSLog(@"Cropping");
    CGRect cropRect=CGRectMake((img1.size.width-a)/2, (img1.size.height-a)/2, a, a);
    CGImageRef imageRef = CGImageCreateWithImageInRect([img1 CGImage], cropRect);
    UIImage *retImage=[UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    UIImage *backgroundImage = [UIImage imageNamed:@"50x50.png"];
    UIImage *watermarkImage = retImage;
    NSLog(@"bgImage H: %f  W: %f",backgroundImage.size.height,backgroundImage.size.width);
    NSLog(@"waterImage H: %f  W: %f",watermarkImage.size.height,watermarkImage.size.width);
    UIGraphicsBeginImageContext(backgroundImage.size);
    [backgroundImage drawInRect:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
    [watermarkImage drawInRect:CGRectMake(backgroundImage.size.width/2 - watermarkImage.size.width/2, backgroundImage.size.height/2 - watermarkImage.size.height/2, watermarkImage.size.width, watermarkImage.size.height)];
    UIImage *resultImage=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSLog(@"final img  H:  %f   W:   %f",resultImage.size.height,resultImage.size.width);
    return resultImage;
}

-(UIImage*) thumbnailFromImage : (UIImage*) img ForURLString : (NSString*) imgURLStr
{
    CGFloat a = [(NSNumber*)[self.thumbnailImageLengths objectForKey:imgURLStr] floatValue];
    CGFloat minLength;
    if(img.size.height>=img.size.width) minLength=img.size.width;
    else minLength=img.size.height;
    CGFloat scale=a/minLength;
    CGFloat newHeight=img.size.height*scale;
    CGFloat newWidth=img.size.width*scale;
    UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight));
    [img drawInRect:CGRectMake(0,0,newWidth,newHeight)];
    UIImage *img1 = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGRect cropRect=CGRectMake((img1.size.width-a)/2, (img1.size.height-a)/2, a, a);
    CGImageRef imageRef = CGImageCreateWithImageInRect([img1 CGImage], cropRect);
    UIImage *retImage=[UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    UIImage *backgroundImage = [self.thumbnailBackgroundImages objectForKey:imgURLStr];
    UIImage *watermarkImage = retImage;
  
    UIGraphicsBeginImageContext(backgroundImage.size);
    [backgroundImage drawInRect:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
    [watermarkImage drawInRect:CGRectMake(backgroundImage.size.width/2 - watermarkImage.size.width/2, backgroundImage.size.height/2 - watermarkImage.size.height/2, watermarkImage.size.width, watermarkImage.size.height)];
    UIImage *resultImage=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
   
    if([self.thumbnailForegroundImages objectForKey:imgURLStr]){
        //superimpose foreground image
        backgroundImage = resultImage;
        watermarkImage  = [self.thumbnailForegroundImages objectForKey:imgURLStr];
        UIGraphicsBeginImageContext(backgroundImage.size);
        [backgroundImage drawInRect:CGRectMake(0, 0, backgroundImage.size.width, backgroundImage.size.height)];
        [watermarkImage drawInRect:CGRectMake(backgroundImage.size.width/2 - watermarkImage.size.width/2, backgroundImage.size.height/2 - watermarkImage.size.height/2, watermarkImage.size.width, watermarkImage.size.height)];
        resultImage=UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    
    return resultImage;
}

-(void)connectionDidFinishLoading:(EGOImageLoadConnection *)connection {
    NSLog(@"hahahaha connectionDidFinishLoading");
	UIImage* anImage = [UIImage imageWithData:connection.responseData];
	
	if(!anImage) {
		NSError* error = [NSError errorWithDomain:[connection.imageURL host] code:406 userInfo:nil];
		NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoadFailed(connection.imageURL)
																	 object:self
																   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:error,@"error",connection.imageURL,@"imageURL",nil]];
		
		[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
	} else {
        if(shouldProcessThumbnails){
            NSLog(@"may process image!");
            //[self setThumbnailImageLength:50 forImageURLString:[connection.imageURL absoluteString]];
            //[self setBackgroundImage:[UIImage imageNamed:@""] forImageURLString:[connection.imageURL absoluteString]];
            UIImage *theImage = [self thumbnailFromImage:anImage ForURLString:[connection.imageURL absoluteString]];
            //UIImage *theImage=[self getSquareImageFromImage:anImage withSideLength:50];
            
            NSData *theImageData=UIImageJPEGRepresentation(theImage,1.0);
            [[EGOCache currentCache] setData:theImageData forKey:keyForURL(connection.imageURL) withTimeoutInterval:604800];
            theImage=[UIImage imageWithData:theImageData];
            [currentConnections removeObjectForKey:connection.imageURL];
            self.currentConnections = [[currentConnections copy] autorelease];
            NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoaded(connection.imageURL)
                                                                         object:self
                                                                       userInfo:[NSDictionary dictionaryWithObjectsAndKeys:theImage,@"image",connection.imageURL,@"imageURL",nil]];
            
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
            [self cleanUpConnection:connection];
            return;
        }
        else{
            NSLog(@"shouldprocessthumbnails of loader is NO");
        }
        if(!shouldCacheImageInMemoryOnly)[[EGOCache currentCache] setData:connection.responseData forKey:keyForURL(connection.imageURL) withTimeoutInterval:604800];
        else [self addNewObjToImagesDict : anImage forKey : [connection.imageURL absoluteString]];
		[currentConnections removeObjectForKey:connection.imageURL];
		self.currentConnections = [[currentConnections copy] autorelease];
		
		NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoaded(connection.imageURL)
																	 object:self
																   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:anImage,@"image",connection.imageURL,@"imageURL",nil]];
		
		[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
	}

	[self cleanUpConnection:connection];
}

- (void)connection:(EGOImageLoadConnection *)connection didFailWithError:(NSError *)error {
	[currentConnections removeObjectForKey:connection.imageURL];
	self.currentConnections = [[currentConnections copy] autorelease];
	
	NSNotification* notification = [NSNotification notificationWithName:kImageNotificationLoadFailed(connection.imageURL)
																 object:self
															   userInfo:[NSDictionary dictionaryWithObjectsAndKeys:error,@"error",connection.imageURL,@"imageURL",nil]];
	
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];

	[self cleanUpConnection:connection];
}

#pragma mark -

- (void)dealloc {
	self.currentConnections = nil;
    if(tempDict)[tempDict release];
    if(imagesDict)[imagesDict release];
    if(thumbnailBackgroundImages) [thumbnailBackgroundImages release];
    if(thumbnailForegroundImages) [thumbnailForegroundImages release];
    if(thumbnailImageLengths) [thumbnailImageLengths release];
    
	[currentConnections release];
	[connectionsLock release];
	[super dealloc];
}

@end