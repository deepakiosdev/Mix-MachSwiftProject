//
//  NetworkManager.m
//  MixMachDemo
//
//  Created by dipak on 9/26/16.
//  Copyright © 2016 Deepak. All rights reserved.
//

#import "NetworkManager.h"
#import "Reachability.h"

#define TIME_OUT_INTERVAL_REQUEST       60.0f
#define TIME_OUT_INTERVAL_RESOURCE      60.0f
#define ERROR_CODE_AUTH_TOKEN_EXPIRE    -1
#define CM_PRODUCT_SERVICES           @"CMProductServices_QA.plist"

//pragma mark - Error Codes
enum TRACE_CODES
{
    TRACE_CODE_SUCCESS,
    TRACE_CODE_NETWORK_NOT_AVAILABLE,
    TRACE_CODE_NETWORK_ERROR,
    TRACE_CODE_AUTH_TOKEN_EXPIRED,
    TRACE_CODE_REQ_JSON_PARSE_FAILED,
    TRACE_CODE_RES_JSON_PARSE_FAILED,
    TRACE_CODE_TASK_SESSION_RESUME_SUCCESS,
    TRACE_CODE_TASK_SESSION_RESUME_FAILED,
    TRACE_CODE_TASK_SESSION_PAUSE_SUCCESS,
    TRACE_CODE_TASK_SESSION_PAUSE_FAILED,
    TRACE_CODE_TASK_SESSION_CANCEL_FAILED,
    TRACE_CODE_TASK_SESSION_CANCEL_SUCCCESS,
    TRACE_CODE_FILE_SYSTEM_ERROR,
    TRACE_CODE_DATA_INIT_FAILED,
    TRACE_CODE_CUSTOM_ERROR,
    TRACE_CODE_URL_ERROR
};


@interface NetworkManager () <NSURLSessionDataDelegate, NSURLSessionDownloadDelegate, NSURLSessionTaskDelegate>

@property (nonatomic, strong) NSURLSession          *session;
@property (nonatomic, strong) NSURLSessionTask      *sessionTask;
@property (nonatomic, strong) ProgressHandler       progressHandler;
@property (nonatomic, strong) CompletionHandler     completionHandler;

@end

@implementation NetworkManager

//Get the keys for playback
-(NSString*)getStreamDecryptionKey
{
    if ([CM_PRODUCT_SERVICES rangeOfString:@"dev" options:NSCaseInsensitiveSearch].location != NSNotFound ) {
        return @"#NatarajClassicFineCoffeeStains$";
    }
    
    return @"54G91A8?s7^F97C]Fyj*8&kR2eU+HNg!";
    
}

-(void)configSessionForData
{
    
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfig setHTTPAdditionalHeaders:@{@"Accept": @"application/json",@"Content-Type":@"application/json"}];
    
    sessionConfig.allowsCellularAccess          = YES;
    sessionConfig.timeoutIntervalForRequest     = TIME_OUT_INTERVAL_REQUEST;
    sessionConfig.timeoutIntervalForResource    = TIME_OUT_INTERVAL_RESOURCE;
    sessionConfig.HTTPMaximumConnectionsPerHost = 1;
    
    _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}

-(void)configSessionForDownload
{
    
    NSURLSessionConfiguration *sessionConfig    = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfig.timeoutIntervalForRequest     = TIME_OUT_INTERVAL_REQUEST;
    sessionConfig.timeoutIntervalForResource    = TIME_OUT_INTERVAL_RESOURCE;
    sessionConfig.HTTPMaximumConnectionsPerHost = 1;
    
    _session = [NSURLSession sessionWithConfiguration:sessionConfig delegate:self delegateQueue:[NSOperationQueue mainQueue]];
}


//+(void)asyncDataDownload:(NSString*)urlString withProgressHandler:(void (^)(CGFloat progress))progressHandler andCompletionHandler:(void (^)(id response, NSUInteger errorCode))completionHandler
//{
//    CMRestConnector *restConnector = [[CMRestConnector alloc] init];
//    [restConnector startAsyncDownload:urlString progress:^(CGFloat progressValue)
//     {
//         progressHandler(progressValue);
//     } finished:^(id receivedObj, NSUInteger errorCode)
//     {
//         if(errorCode == TRACE_CODE_SUCCESS) {
//             completionHandler(receivedObj, TRACE_CODE_SUCCESS);
//         }
//         else {
//             completionHandler(receivedObj, errorCode);
//         }
//     }];
//}


-(void)startAsyncDownload:(NSString*)urlString progress:(ProgressHandler)progHandler finished:(CompletionHandler)compHandler
{
    if ([urlString rangeOfString:@"127.0.0.1:8080"].location == NSNotFound)
    {
        if(![Reachability isReachable])
        {
            compHandler(nil, TRACE_CODE_NETWORK_ERROR);
            return;
        }
    }
    
    _progressHandler = progHandler;
    
    [self configSessionForDownload];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:TIME_OUT_INTERVAL_REQUEST];
    [request setValue:@"iPad" forHTTPHeaderField:@"User-Agent"];
    
    _sessionTask = [_session downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error)
                    {
                        if(error) {
                            compHandler(error, TRACE_CODE_NETWORK_ERROR);
                        }
                        else
                        {
                            NSData *data = [NSData dataWithContentsOfURL:location];
                            compHandler(data, TRACE_CODE_SUCCESS);
                        }
                        
                    }];
    
    [self resume];
}

-(NSUInteger)resume
{
    if(!_sessionTask) {
        return TRACE_CODE_TASK_SESSION_RESUME_FAILED;
    }
    
    [_sessionTask resume];
    
    return TRACE_CODE_TASK_SESSION_RESUME_SUCCESS;
}


#pragma mark - NSURLSession delegate methods
-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    CGFloat progress = (CGFloat)totalBytesWritten/(CGFloat)totalBytesExpectedToWrite * 100.0f;
    
    if(_progressHandler) {
        _progressHandler(progress);
    } else {
        
    }
    
//    if([[self delegate] respondsToSelector:@selector(downloadProgress:withProgress:)]) {
//        [[self delegate] downloadProgress:self withProgress:progress];
//    }
}

-(void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location
{
    if(_completionHandler)
    {
        _completionHandler(location, TRACE_CODE_SUCCESS);
        _completionHandler = nil;
    }
    else
    {
//        if([[self delegate] respondsToSelector:@selector(downloadCompleted:withLocation:)]) {
//            [[self delegate] downloadCompleted:self withLocation:location];
//        }
    }
    
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
}

-(void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if(_completionHandler)
    {
        if(error)
        {
            if ([error code] == -1002) {
                _completionHandler(error, TRACE_CODE_DATA_INIT_FAILED);
            } else  {
                _completionHandler(error, TRACE_CODE_NETWORK_ERROR);
            }
            
            _completionHandler = nil;
        }
    }
    
    if (error)
    {
    }
    
}

@end
