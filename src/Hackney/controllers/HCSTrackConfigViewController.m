//
//  HCSTrackConfigViewController.m
//  CycleStreets
//
//  Created by Neil Edwards on 20/01/2014.
//  Copyright (c) 2014 CycleStreets Ltd. All rights reserved.
//

#import "HCSTrackConfigViewController.h"
#import "AppConstants.h"
#import "UserLocationManager.h"
#import "RMMapView.h"
#import "CycleStreets.h"
#import "UIView+Additions.h"
#import "GlobalUtilities.h"
#import "UIActionSheet+BlocksKit.h"
#import "HCBackgroundLocationManager.h"
#import "HCSMapViewController.h"
#import "PickerViewController.h"
#import "HCSUserDetailsViewController.h"
#import "PhotoWizardViewController.h"
#import "TripManager.h"
#import "Trip.h"
#import "User.h"
#import "RMUserLocation.h"
#import "UserManager.h"
#import "SettingsManager.h"
#import "CoreDataStore.h"

#import <CoreLocation/CoreLocation.h>

static NSString *const LOCATIONSUBSCRIBERID=@"HCSTrackConfig";

@interface HCSTrackConfigViewController ()<RMMapViewDelegate,UIActionSheetDelegate,UIPickerViewDelegate,HCBackgroundLocationManagerDelegate>


// hackney
@property (nonatomic, strong) TripManager								*tripManager;
@property (nonatomic,strong)  Trip										*currentTrip;


@property (nonatomic, strong) IBOutlet RMMapView						* mapView;//map of current area
@property (nonatomic, strong) IBOutlet UILabel							* attributionLabel;// map type label


@property(nonatomic,weak) IBOutlet UILabel								*trackDurationLabel;
@property(nonatomic,weak) IBOutlet UILabel								*trackSpeedLabel;
@property(nonatomic,weak) IBOutlet UILabel								*trackDistanceLabel;

@property(nonatomic,weak) IBOutlet UIButton								*actionButton;
@property (weak, nonatomic) IBOutlet UIView								*actionView;


@property (nonatomic,assign)  CLLocationDistance						currentDistance;

@property (nonatomic, strong) CLLocation								* lastLocation;// last location
@property (nonatomic, strong) CLLocation								* currentLocation;



// opration

@property (nonatomic,strong)  NSTimer									*trackTimer;


// state
@property (nonatomic,assign)  BOOL										isRecordingTrack;
@property (nonatomic,assign)  BOOL										shouldUpdateDuration;
@property (nonatomic,assign)  BOOL										didUpdateUserLocation;
@property (nonatomic,assign)  BOOL										userInfoSaved;


-(void)updateUI;


@end

@implementation HCSTrackConfigViewController



//
/***********************************************
 * @description		NOTIFICATIONS
 ***********************************************/
//

-(void)listNotificationInterests{
	
	[self initialise];
    
	[notifications addObject:GPSLOCATIONCOMPLETE];
	[notifications addObject:GPSLOCATIONUPDATE];
	[notifications addObject:GPSLOCATIONFAILED];
	[notifications addObject:MAPSTYLECHANGED];
	[notifications addObject:HCSDISPLAYTRIPMAP];
	[notifications addObject:MAPUNITCHANGED];
	
	[super listNotificationInterests];
	
}

-(void)didReceiveNotification:(NSNotification*)notification{
	
	[super didReceiveNotification:notification];
	
	NSString		*name=notification.name;
	
	
	
	if([name isEqualToString:HCSDISPLAYTRIPMAP]){
		[self displayUploadedTripMap];
	}
	
	if([name isEqualToString:MAPSTYLECHANGED]){
		[self didNotificationMapStyleChanged];
	}
	
	if([name isEqualToString:MAPUNITCHANGED]){
		[self didNotificationMapUnitChanged];
	}
	
}



- (void) didNotificationMapStyleChanged {
	self.mapView.tileSource = [CycleStreets tileSource];
	//_attributionLabel.text = [MapViewController mapAttribution];
}


- (void) didNotificationMapUnitChanged {
	
	[self updateUIForDistance];
	
	[self updateUIForSpeed];
	
}


#pragma mark - Location updates


- (void)mapView:(RMMapView *)mapView didUpdateUserLocation:(RMUserLocation *)userLocation{
	
	CLLocation *location=userLocation.location;
	CLLocationDistance deltaDistance = [location distanceFromLocation:_lastLocation];
	
	self.lastLocation=_currentLocation;
	self.currentLocation=location;
	
    
	if ( !_didUpdateUserLocation ){
		
		[_mapView setCenterCoordinate:_currentLocation.coordinate animated:YES];
		
		_didUpdateUserLocation = YES;
		
	}else if ( deltaDistance > 1.0 ){
		
		[_mapView setCenterCoordinate:_currentLocation.coordinate animated:YES];
	}
	
	if ( _isRecordingTrack ){
		
		[self didReceiveUpdatedLocation:_currentLocation];
		
		[self updateUIForDistance];
		
		[self updateUIForSpeed];
		
	}
	
}


#pragma mark - HCBackgroundLocationManagerDelegate method


-(void)didReceiveUpdatedLocation:(CLLocation*)location{
	
	BetterLog(@"%@",location);
	
	[_tripManager addCoord:location];
	
}


-(void)updateUIForDistance{
	
	
	if ( _isRecordingTrack ){
		
		if([SettingsManager sharedInstance].routeUnitisMiles==YES){
			float totalMiles = _currentDistance/1600;
			_trackDistanceLabel.text=[NSString stringWithFormat:@"%3.1f miles", totalMiles];
		}else {
			float	kms=_currentDistance/1000;
			_trackDistanceLabel.text=[NSString stringWithFormat:@"%4.1f km", kms];
		}
	
	}else{
		_trackDistanceLabel.text = [NSString stringWithFormat:@"0.0 %@",[SettingsManager sharedInstance].routeUnitisMiles ? @"miles" : @"km"];
	}
	
	
}

//TODO: for map & here, speed is m/s this conversion seems wrong

-(void)updateUIForSpeed{
	
	if ( _isRecordingTrack && _currentLocation.speed >= 0 ){
		
		double kmh=(_currentLocation.speed*TIME_HOUR)/1000;
	
		if([SettingsManager sharedInstance].routeUnitisMiles==YES) {
			double mileSpeed = kmh/1.609;
			_trackSpeedLabel.text= [NSString stringWithFormat:@"%2.0f mph", mileSpeed];
		}else {
			_trackSpeedLabel.text= [NSString stringWithFormat:@"%2.1f km/h", kmh];
		}
	}else{
		_trackSpeedLabel.text = [NSString stringWithFormat:@"0.0 %@",[SettingsManager sharedInstance].routeUnitisMiles ? @"mph" : @"kmh"];
	}
	
}






// assess wether user has been in the same place too long
-(void)determineUserLocationStopped{
	
	
	// compare last lcoation and new location
	
	// if same within certain accurcy > start auto stop timer
	
	// next location does not compare clear timer
	
	// if timer expires auto stop Trip and save
	
	
	
}


//
/***********************************************
 * @description			VIEW METHODS
 ***********************************************/
//

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.tripManager=[TripManager sharedInstance];
	
	[HCBackgroundLocationManager sharedInstance].delegate=self;

	[self hasUserInfoBeenSaved];
	
    [self createPersistentUI];
}


-(void)viewWillAppear:(BOOL)animated{
    
    [self createNonPersistentUI];
    
    [super viewWillAppear:animated];
}


-(void)createPersistentUI{
	
	
	[RMMapView class];
	[_mapView setDelegate:self];
	_mapView.showsUserLocation=YES;
	_mapView.zoom=15;
	_mapView.tileSource=[CycleStreets tileSource];
	
	
	
	UIButton *button=[[UIButton alloc]initWithFrame:CGRectMake(0, 0, 33, 33)];
	[button setImage:[UIImage imageNamed:@"UIButtonBarCompose.png"] forState:UIControlStateNormal];
	//[button setTitle:@"Report" forState:UIControlStateNormal];
	[button addTarget:self action:@selector(didSelectPhotoWizardButton:) forControlEvents:UIControlEventTouchUpInside];
	UIBarButtonItem *barbutton=[[UIBarButtonItem alloc] initWithCustomView:button];
	[self.navigationItem setRightBarButtonItem:barbutton animated:NO];
	
	
	[self updateUIForSpeed];
	[self updateUIForDistance];
	
	//TODO: UI styling
	[_actionButton addTarget:self action:@selector(didSelectActionButton:) forControlEvents:UIControlEventTouchUpInside];
	
	
}

-(void)createNonPersistentUI{
    
	
}



-(void)updateUI{
	
	if ( _shouldUpdateDuration )
	{
		NSDate *startDate = [[_trackTimer userInfo] objectForKey:@"StartDate"];
		NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:startDate];
		
		static NSDateFormatter *inputFormatter = nil;
		if ( inputFormatter == nil )
			inputFormatter = [[NSDateFormatter alloc] init];
		
		[inputFormatter setDateFormat:@"HH:mm:ss"];
		NSDate *fauxDate = [inputFormatter dateFromString:@"00:00:00"];
		[inputFormatter setDateFormat:@"HH:mm:ss"];
		NSDate *outputDate = [[NSDate alloc] initWithTimeInterval:interval sinceDate:fauxDate];
		
		self.trackDurationLabel.text = [inputFormatter stringFromDate:outputDate];
	}
	
	
}


- (void)resetDurationDisplay
{
	[self updateUIForDistance];
	[self updateUIForSpeed];
}

-(void)resetTimer{
	
	if(_trackTimer!=nil)
		[_trackTimer invalidate];
}



#pragma mark - RMMap delegate



-(void)doubleTapOnMap:(RMMapView*)map At:(CGPoint)point{
	
}

- (void) afterMapMove: (RMMapView*) map {
	[self afterMapChanged:map];
}


- (void) afterMapZoom: (RMMapView*) map byFactor: (float) zoomFactor near:(CGPoint) center {
	[self afterMapChanged:map];
}

- (void) afterMapChanged: (RMMapView*) map {
		
}



#pragma mark - UI events


-(IBAction)didSelectActionButton:(id)sender{
	
	if(_isRecordingTrack == NO){
		
        BetterLog(@"start");
        
        // start the timer if needed
        if ( _trackTimer == nil )
        {
			[self resetDurationDisplay];
			self.trackTimer = [NSTimer scheduledTimerWithTimeInterval:0.5f
													 target:self selector:@selector(updateUI)
												   userInfo:[self newTripTimerUserInfo] repeats:YES];
        }
        
       
        _isRecordingTrack = YES;
		self.currentTrip=[[TripManager sharedInstance] createTrip];
		[[TripManager sharedInstance] startTrip];
		
		_mapView.userTrackingMode=RMUserTrackingModeFollow;
		
		[self updateActionStateForTrip];
        
        // set flag to update counter
        _shouldUpdateDuration = YES;
		
    }else {
		
		__weak __block HCSTrackConfigViewController *weakSelf=self;
		UIActionSheet *actionSheet=[UIActionSheet sheetWithTitle:@""];
		
		[actionSheet addButtonWithTitle:@"Finish" handler:^{
			[weakSelf initiateSaveTrip];
		}];
		[actionSheet setDestructiveButtonWithTitle:@"Reset" handler:^{
			[weakSelf resetRecordingInProgress];
			[[TripManager sharedInstance] removeCurrentRecordingTrip];
		}];
		
		
		[actionSheet setCancelButtonWithTitle:@"Continue" handler:^{
			_shouldUpdateDuration=YES;
		}];
		
		
		
		[actionSheet showInView:[[[UIApplication sharedApplication]delegate]window]];
		
    }
	
}



-(void)updateActionStateForTrip{
	
	if(_isRecordingTrack){
		
		[_actionButton setTitle:@"Finish" forState:UIControlStateNormal];
		
		[UIView animateWithDuration:0.4 animations:^{
			_actionView.backgroundColor=UIColorFromRGB(0xCB0000);
		}];
		
	}else{
		
		[_actionButton setTitle:@"Start" forState:UIControlStateNormal];
		
		[UIView animateWithDuration:0.4 animations:^{
			_actionView.backgroundColor=UIColorFromRGB(0x509720);
		}];
		
	}
	
}


- (void)initiateSaveTrip{
	
	[[NSUserDefaults standardUserDefaults] setInteger:0 forKey: @"pickerCategory"];
    [[NSUserDefaults standardUserDefaults] synchronize];
	
	
	if ( _isRecordingTrack ){
		
		UINavigationController *nav=nil;
		
		if([[UserManager sharedInstance] hasUser]){
			
			PickerViewController *tripPurposePickerView = [[PickerViewController alloc] initWithNibName:@"TripPurposePicker" bundle:nil];
			tripPurposePickerView.delegate=self;
			
			nav=[[UINavigationController alloc]initWithRootViewController:tripPurposePickerView];
			
		}else{
			
			HCSUserDetailsViewController *userController=[[HCSUserDetailsViewController alloc]initWithNibName:[HCSUserDetailsViewController nibName] bundle:nil];
			userController.tripDelegate=self;
			userController.viewMode=HCSUserDetailsViewModeSave;
			nav=[[UINavigationController alloc]initWithRootViewController:userController];
			
		}
		
		[self.navigationController presentViewController:nav animated:YES	completion:^{
			
		}];
		
	}
    
}



-(void)dismissTripSaveController{
	
	[self.navigationController dismissModalViewControllerAnimated:YES];
	
}

- (void)displayUploadedTripMap{
	
    [self resetRecordingInProgress];
    
}


#pragma mark - UI Events

-(IBAction)didSelectPhotoWizardButton:(id)sender{
	
	PhotoWizardViewController *photoWizard=[[PhotoWizardViewController alloc]initWithNibName:[PhotoWizardViewController nibName] bundle:nil];
	photoWizard.extendedLayoutIncludesOpaqueBars=NO;
	photoWizard.edgesForExtendedLayout = UIRectEdgeNone;
	photoWizard.isModal=YES;
	
	[self presentViewController:photoWizard animated:YES completion:^{
		
	}];
	
}



#pragma mark - Trip methods

- (BOOL)hasUserInfoBeenSaved
{
	BOOL response = NO;
	
	NSError *error;
	NSArray *fetchResults=[[CoreDataStore mainStore] allForEntity:@"User" error:&error];
	
	if ( fetchResults.count>0 ){
		
		if ( fetchResults != nil ){
			
			User *user = (User*)[fetchResults objectAtIndex:0];
			
			self.userInfoSaved = [user userInfoSaved];
			response = _userInfoSaved;
			
		}else{
			// Handle the error.
			NSLog(@"no saved user");
			if ( error != nil )
				NSLog(@"PersonalInfo viewDidLoad fetch error %@, %@", error, [error localizedDescription]);
		}
	}else{
		NSLog(@"no saved user");
	}
		
	
	return response;
}


- (NSDictionary *)newTripTimerUserInfo
{
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSDate date], @"StartDate",
			[NSNull null], @"TripManager", nil ];
}



- (void)resetRecordingInProgress
{
	[[TripManager sharedInstance] resetTrip];
	_isRecordingTrack=NO;
	
	[self updateActionStateForTrip];
	
	_mapView.userTrackingMode=RMUserTrackingModeNone;
	
	[self resetDurationDisplay];
	[self resetTimer];
}







#pragma mark TripPurposeDelegate methods

- (NSString *)setPurpose:(unsigned int)index
{
	NSString *purpose = [_tripManager setPurpose:index];
	return [self updatePurposeWithString:purpose];
}


- (NSString *)getPurposeString:(unsigned int)index
{
	return [_tripManager getPurposeString:index];
}

- (NSString *)updatePurposeWithString:(NSString *)purpose
{
	// only enable start button if we don't already have a pending trip
	if ( _trackTimer == nil )
		_actionButton.enabled = YES;
	
	_actionButton.hidden = NO;
	
	return purpose;
}

- (NSString *)updatePurposeWithIndex:(unsigned int)index
{
	return [self updatePurposeWithString:[_tripManager getPurposeString:index]];
}



- (void)didCancelSaveJourneyController
{
	[self.navigationController dismissModalViewControllerAnimated:YES];
    
	[[TripManager sharedInstance] startTrip];
	_isRecordingTrack = YES;
	_shouldUpdateDuration = YES;
}


- (void)didPickPurpose:(unsigned int)index
{
	_isRecordingTrack = NO;
    [[TripManager sharedInstance]resetTrip];
	_actionButton.enabled = YES;
	[self resetTimer];
	
	[_tripManager setPurpose:index];
}


//
/***********************************************
 * @description			MEMORY
 ***********************************************/
//
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
}


@end