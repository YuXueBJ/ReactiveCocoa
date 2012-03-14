//
//  GHDLoginViewController.m
//  GHAPIDemo
//
//  Created by Josh Abernathy on 3/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GHDLoginViewController.h"
#import "GHDLoginView.h"
#import "GHGitHubClient.h"
#import "GHJSONRequestOperation.h"
#import "GHUserAccount.h"

@interface GHDLoginViewController ()
@property (nonatomic, assign) BOOL successHidden;
@property (nonatomic, assign) BOOL loginFailedHidden;
@property (nonatomic, assign) BOOL loginEnabled;
@property (nonatomic, assign) BOOL loggingIn;
@property (nonatomic, strong) RACAsyncCommand *loginCommand;
@property (nonatomic, strong) GHDLoginView *view;
@property (nonatomic, strong) GHUserAccount *userAccount;
@property (nonatomic, strong) GHGitHubClient *client;
@property (nonatomic, strong) RACValue *didLoginValue;
@end


@implementation GHDLoginViewController

- (id)init {
	self = [super init];
	if(self == nil) return nil;
	
	self.loginFailedHidden = YES;
	self.successHidden = YES;
	self.loginEnabled = NO;
	self.loggingIn = NO;
	
	self.didLoginValue = [RACValue value];
	
	[[RACSequence combineLatest:[NSArray arrayWithObjects:RACObservable(self.username), RACObservable(self.password), RACObservable(self.loginCommand.numberOfActiveExecutions), nil] reduce:^(NSArray *xs) {
		return [NSNumber numberWithBool:[[xs objectAtIndex:0] length] > 0 && [[xs objectAtIndex:1] length] > 0 && [[xs objectAtIndex:2] unsignedIntegerValue] < 1];
	}] toObject:self keyPath:RACKVO(self.loginEnabled)];
	
	self.loginCommand = [RACAsyncCommand command];
	RACValue *loginResult = [self.loginCommand addAsyncFunction:^(id _) { return [self.client login]; }];

	[self.loginCommand subscribeNext:^(id _) {
		self.userAccount = [GHUserAccount userAccountWithUsername:self.username password:self.password];
		self.client = [GHGitHubClient clientForUserAccount:self.userAccount];
		self.loggingIn = YES;
	}];
	
	[[[loginResult where:^(id x) {
		return [x hasError];
	}] select:^(id x) {
		return [x error];
	}] subscribeNext:^(id x) {
		self.loggingIn = NO;
		self.loginFailedHidden = NO;
		NSLog(@"error logging in: %@", x);
	}];
	
	[[loginResult where:^(id x) {
		return [x hasObject];
	}] subscribeNext:^(id _) {
		self.successHidden = NO;
		self.loggingIn = NO;
		
		self.didLoginValue.value = self.userAccount;
	}];
	
	[[RACSequence merge:[NSArray arrayWithObjects:RACObservable(self.username), RACObservable(self.password), nil]] subscribeNext:^(id _) {
		self.successHidden = self.loginFailedHidden = YES;
	}];
	
	return self;
}


#pragma mark NSViewController

- (void)loadView {
	self.view = [GHDLoginView ghd_viewFromNib];
	
	[self.view.usernameTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.username)];
	[self.view.passwordTextField bind:NSValueBinding toObject:self withKeyPath:RACKVO(self.password)];
	[self.view.successTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.successHidden)];
	[self.view.couldNotLoginTextField bind:NSHiddenBinding toObject:self withKeyPath:RACKVO(self.loginFailedHidden)];
	[self.view.loginButton bind:NSEnabledBinding toObject:self withKeyPath:RACKVO(self.loginEnabled)];
	[self.view.loggingInSpinner bind:NSHiddenBinding toObject:self withNegatedKeyPath:RACKVO(self.loggingIn)];
	
	[self.view.loggingInSpinner startAnimation:nil];
	
	[self.view.loginButton addCommand:self.loginCommand];
}


#pragma mark API

@synthesize username;
@synthesize password;
@dynamic view;
@synthesize successHidden;
@synthesize loginFailedHidden;
@synthesize loginCommand;
@synthesize loginEnabled;
@synthesize loggingIn;
@synthesize userAccount;
@synthesize client;
@synthesize didLoginValue;

- (RACSequence *)refreshAll {
	RACSequence *getUserInfoResult = [self.client fetchUserInfo];
	RACSequence *getReposResult = [self.client fetchUserRepos];
	RACSequence *getOrgsResult = [self.client fetchUserOrgs];
	
	[[[getUserInfoResult where:^(id x) {
		return [x hasObject];
	}] select:^(id x) {
		return [x object];
	}] subscribeNext:^(id x) {
		NSLog(@"user: %@", x);
	}];
	
	RACSequence *results = [RACSequence zip:[NSArray arrayWithObjects:getUserInfoResult, getReposResult, getOrgsResult, nil] reduce:^(NSArray *xs) {
		RACMaybe *first = [xs objectAtIndex:0];
		RACMaybe *second = [xs objectAtIndex:1];
		RACMaybe *third = [xs objectAtIndex:2];
		return [NSNumber numberWithBool:[first hasObject] && [second hasObject] && [third hasObject]];
	}];
	
	return results;
}

@end