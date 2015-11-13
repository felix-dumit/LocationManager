//
//  INTULocationRequestTests.m
//  LocationManagerTests
//
//  Copyright (c) 2014-2015 Intuit Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import <Specta/Specta.h>
#import <Expecta/Expecta.h>
#import <OCMock/OCMock.h>

#import "INTULocationManager.h"

@interface INTULocationManager (Spec) <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager *locationManager;
@end

SpecBegin(LocationManager)

__block INTULocationManager *subject;
__block CLLocation *location;

before(^{
    subject = [[INTULocationManager alloc] init];
    subject.locationManager = OCMClassMock(CLLocationManager.class);

    location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(1, 1)
                                                         altitude:CLLocationDistanceMax
                                               horizontalAccuracy:kCLLocationAccuracyBest
                                                 verticalAccuracy:kCLLocationAccuracyBest
                                                        timestamp:[NSDate date]];
});


describe(@"location services state", ^{
    it(@"should indicate if location services are disabled", ^{
        id classMock = OCMClassMock(CLLocationManager.class);
        OCMStub(ClassMethod([classMock locationServicesEnabled])).andReturn(NO);

        expect([INTULocationManager locationServicesState]).to.equal(INTULocationServicesStateDisabled);

        [classMock stopMocking];
    });

    it(@"should use the appropriate state based on authorization status", ^{
        id classMock = OCMClassMock(CLLocationManager.class);
        OCMStub(ClassMethod([classMock locationServicesEnabled])).andReturn(YES);
        OCMStub(ClassMethod([classMock authorizationStatus])).andReturn(kCLAuthorizationStatusNotDetermined);

        expect([INTULocationManager locationServicesState]).to.equal(INTULocationServicesStateNotDetermined);

        [classMock stopMocking];
    });
});

describe(@"forcing a request to complete", ^{
    it(@"should immediately call the request's completion block", ^{
        __block BOOL called = NO;
        INTULocationRequestID requestID = [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyCity timeout:10 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            called = YES;
        }];
        [subject forceCompleteLocationRequest:requestID];
        expect(called).will.beTruthy();
    });

});

describe(@"After requesting a location", ^{
    it(@"can be cancelled", ^{
        INTULocationRequestID requestID = [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:10 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            failure(@"was not cancelled");
        }];

        [subject cancelLocationRequest:requestID];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
    });
});

describe(@"After subscribing for significant location changes", ^{
    it(@"can be cancelled", ^{
        INTULocationRequestID requestID = [subject subscribeToSignificantLocationChangesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            failure(@"was not cancelled");
        }];
        
        [subject cancelLocationRequest:requestID];
        
        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
    });
});

describe(@"Timeouts", ^{
    it(@"calls the request callback on location update after a timeout", ^{
        __block NSInteger callbackCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.1 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            callbackCount++;
        }];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        expect(callbackCount).will.equal(1);
    });

    it(@"does not call the request callback on subsequent updates after timeout", ^{
        __block NSInteger callbackCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.1 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            callbackCount++;
        }];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];

        expect(callbackCount).will.equal(1);
    });

});

describe(@"subscribing for location updates with a block", ^{
    it(@"calls the block on location update", ^{
        __block BOOL called = NO;
        [subject subscribeToLocationUpdatesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            called = YES;
        }];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        
        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });

        expect(called).to.beTruthy();
    });

    it(@"passes the location", ^{
        waitUntil(^(DoneCallback done) {
            [subject subscribeToLocationUpdatesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                expect(currentLocation).to.equal(location);
                done();
            }];
            [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        });

    });
});

describe(@"subscribing for significant location changes with a block", ^{
    it(@"calls the block on location change", ^{
        __block BOOL called = NO;
        [subject subscribeToSignificantLocationChangesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            called = YES;
        }];
        
        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        
        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });
        
        expect(called).to.beTruthy();
    });
    
    it(@"passes the location", ^{
        waitUntil(^(DoneCallback done) {
            [subject subscribeToSignificantLocationChangesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
                expect(currentLocation).to.equal(location);
                done();
            }];
            [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        });
        
    });
});

describe(@"when you want to wait for user auth", ^{
    it(@"doesnt send a callback until it is agreed", ^{
        __block NSInteger callbackCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.1 delayUntilAuthorized:YES block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            callbackCount++;
        }];

        id classMock = OCMClassMock(CLLocationManager.class);
        OCMStub(ClassMethod([classMock authorizationStatus])).andReturn(kCLAuthorizationStatusNotDetermined);


        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        expect(callbackCount).to.equal(0);

        OCMStub(ClassMethod([classMock authorizationStatus])).andReturn (kCLAuthorizationStatusAuthorizedAlways);
        [subject locationManager:subject.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusAuthorizedAlways];

        expect(callbackCount).will.equal(1);
    });
});

describe(@"authorization status changes", ^{
    it(@"clears out pending requests when it is denied", ^{
        __block NSInteger callbackCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.1 delayUntilAuthorized:YES block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            callbackCount++;
        }];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        expect(callbackCount).to.equal(0);

        [subject locationManager:subject.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusDenied];

        expect(callbackCount).will.equal(1);
    });

    it(@"clears out pending requests when restricted", ^{
        __block NSInteger callbackCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.1 delayUntilAuthorized:YES block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            callbackCount++;
        }];

        [subject locationManager:subject.locationManager didUpdateLocations:@[location]];
        expect(callbackCount).to.equal(0);

        [subject locationManager:subject.locationManager didChangeAuthorizationStatus:kCLAuthorizationStatusRestricted];

        expect(callbackCount).will.equal(1);
    });
});

describe(@"when the location manager fails", ^{
    it(@"should complete all non-recurring requests", ^{
        __block NSInteger singleCallbackCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.1 delayUntilAuthorized:YES block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            singleCallbackCount++;
        }];

        NSError *error = [NSError errorWithDomain:@"domain" code:1337 userInfo:@{}];
        [subject locationManager:subject.locationManager didFailWithError:error];

        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });

        expect(singleCallbackCount).to.equal(1);

        // Fail it a second time and ensure it doesn't get called a second time
        [subject locationManager:subject.locationManager didFailWithError:error];

        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });

        expect(singleCallbackCount).to.equal(1);
    });

    it(@"should keep alive all recurring requests", ^{
        __block NSInteger recurringCallbackCount = 0;
        [subject subscribeToLocationUpdatesWithDesiredAccuracy:INTULocationAccuracyBlock block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            recurringCallbackCount++;
        }];

        NSError *error = [NSError errorWithDomain:@"domain" code:1337 userInfo:@{}];
        [subject locationManager:subject.locationManager didFailWithError:error];

        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });

        expect(recurringCallbackCount).to.equal(1);

        // Fail it a second time and see if it's still called
        [subject locationManager:subject.locationManager didFailWithError:error];

        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });

        expect(recurringCallbackCount).to.equal(2);
    });
});

describe(@"multiple simultaneous location requests", ^{
    it(@"calls each request block correctly", ^{
        id classMock = OCMClassMock(CLLocationManager.class);
        OCMStub(ClassMethod([classMock locationServicesEnabled])).andReturn(YES);
        OCMStub(ClassMethod([classMock authorizationStatus])).andReturn(kCLAuthorizationStatusAuthorizedWhenInUse);
        
        __block NSInteger singleCallbackACount = 0;
        __block NSInteger singleCallbackASuccessCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyRoom timeout:0.0 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            singleCallbackACount++;
            if (status == INTULocationStatusSuccess) {
                singleCallbackASuccessCount++;
            }
        }];
        
        __block NSInteger singleCallbackBCount = 0;
        __block NSInteger singleCallbackBSuccessCount = 0;
        [subject requestLocationWithDesiredAccuracy:INTULocationAccuracyBlock timeout:0.0 block:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            singleCallbackBCount++;
            if (status == INTULocationStatusSuccess) {
                singleCallbackBSuccessCount++;
            }
        }];
        
        __block NSInteger subscriptionCallbackCount = 0;
        [subject subscribeToLocationUpdatesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            subscriptionCallbackCount++;
        }];
        
        __block NSInteger significantChangesCallbackCount = 0;
        [subject subscribeToSignificantLocationChangesWithBlock:^(CLLocation *currentLocation, INTULocationAccuracy achievedAccuracy, INTULocationStatus status) {
            significantChangesCallbackCount++;
        }];
        
        
        CLLocation *inaccurateLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(1, 1)
                                                                       altitude:CLLocationDistanceMax
                                                             horizontalAccuracy:2000.0
                                                               verticalAccuracy:2000.0
                                                                      timestamp:[[NSDate date] dateByAddingTimeInterval:-3600]];
        [subject locationManager:subject.locationManager didUpdateLocations:@[inaccurateLocation]];
        
        waitUntil(^(DoneCallback done) {
           dispatch_after(0.5, dispatch_get_main_queue(), ^{
               done();
           });
        });
        
        expect(singleCallbackACount).to.equal(0);
        expect(singleCallbackASuccessCount).to.equal(0);
        expect(singleCallbackBCount).to.equal(0);
        expect(singleCallbackBSuccessCount).to.equal(0);
        expect(subscriptionCallbackCount).to.equal(1);
        expect(significantChangesCallbackCount).to.equal(1);
        
        CLLocation *somewhatAccurateLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(1, 1)
                                                                             altitude:CLLocationDistanceMax
                                                                   horizontalAccuracy:50.0
                                                                     verticalAccuracy:5.0
                                                                            timestamp:[NSDate date]];
        [subject locationManager:subject.locationManager didUpdateLocations:@[somewhatAccurateLocation]];
        
        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });
        
        expect(singleCallbackACount).to.equal(0);
        expect(singleCallbackASuccessCount).to.equal(0);
        expect(singleCallbackBCount).to.equal(1);
        expect(singleCallbackBSuccessCount).to.equal(1);
        expect(subscriptionCallbackCount).to.equal(2);
        expect(significantChangesCallbackCount).to.equal(2);
        
        CLLocation *veryAccurateLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(1, 1)
                                                                         altitude:CLLocationDistanceMax
                                                               horizontalAccuracy:5.0
                                                                 verticalAccuracy:5.0
                                                                        timestamp:[NSDate date]];
        [subject locationManager:subject.locationManager didUpdateLocations:@[veryAccurateLocation]];
        
        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });
        
        expect(singleCallbackACount).to.equal(1);
        expect(singleCallbackASuccessCount).to.equal(1);
        expect(singleCallbackBCount).to.equal(1);
        expect(singleCallbackBSuccessCount).to.equal(1);
        expect(subscriptionCallbackCount).to.equal(3);
        expect(significantChangesCallbackCount).to.equal(3);
        
        CLLocation *anotherVeryAccurateLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(1, 1)
                                                                                altitude:CLLocationDistanceMax
                                                                      horizontalAccuracy:5.0
                                                                        verticalAccuracy:5.0
                                                                               timestamp:[NSDate date]];
        [subject locationManager:subject.locationManager didUpdateLocations:@[anotherVeryAccurateLocation]];
        
        waitUntil(^(DoneCallback done) {
            dispatch_after(0.5, dispatch_get_main_queue(), ^{
                done();
            });
        });
        
        expect(singleCallbackACount).to.equal(1);
        expect(singleCallbackASuccessCount).to.equal(1);
        expect(singleCallbackBCount).to.equal(1);
        expect(singleCallbackBSuccessCount).to.equal(1);
        expect(subscriptionCallbackCount).to.equal(4);
        expect(significantChangesCallbackCount).to.equal(4);
        
        [classMock stopMocking];
    });
});

xdescribe(@"when determining whether a location update fulfills a request", ^{
    // The logic comparing a request's desired accuracy to the CLLocation's properties
    // (all the stuff regarding staleness + horizontal location accuracy threshold)
    // should be tested, but it seems complex enough we figured we were better off letting
    // someone with more domain knowledge of how it works handle it.
    //
    // You should write these tests!
});

SpecEnd
