@IsTest
private class SchedulableJobsWatchdogJobTest {

    @isTest
    static void testSchedule() {
        Test.startTest();
        SchedulableJobsWatchdogJob.schedule('Service_User');
        Test.stopTest();

        // Verify if job scheduled
        List<CronTrigger> jobs = [SELECT Id, CronJobDetail.Name, NextFireTime,  PreviousFireTime, StartTime, State FROM CronTrigger WHERE CronJobDetail.Name = :SchedulableJobsWatchdogJob.UNIT_TEST_JOB_NAME];
        Assert.areEqual(1, jobs.size(), 'There should be one job scheduled, with name ' + SchedulableJobsWatchdogJob.UNIT_TEST_JOB_NAME);
    }
}