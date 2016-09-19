#import "NSDate+WMFMostReadDate.h"
#import "NSCalendar+WMFCommonCalendars.h"

NSInteger const WMFPageviewDataAvailabilityThreshold = 12;

@implementation NSDate (WMFMostReadDate)

- (instancetype)wmf_bestMostReadFetchDate {
    NSInteger currentUTCHour = [[NSCalendar wmf_utcGregorianCalendar] component:NSCalendarUnitHour fromDate:self];
    NSInteger daysPrior = currentUTCHour < WMFPageviewDataAvailabilityThreshold ? -2 : -1;
    NSDate *fetchDate = [[NSCalendar wmf_utcGregorianCalendar] dateByAddingUnit:NSCalendarUnitDay
                                                                          value:daysPrior
                                                                         toDate:self
                                                                        options:NSCalendarMatchStrictly];
    NSParameterAssert(fetchDate);
    return fetchDate;
}

@end
