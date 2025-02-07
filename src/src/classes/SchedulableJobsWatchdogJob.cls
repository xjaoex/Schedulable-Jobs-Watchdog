public with sharing class SchedulableJobsWatchdogJob implements Schedulable {

    private final SchedulableJobWatchdogSetting__mdt setting;
    @TestVisible
    private final static String UNIT_TEST_JOB_NAME = 'SchedulableJobsWatchdogJob Unit Test';

    public static void schedule(String schedulableJobWatchdogSettingName) {
        SchedulableJobWatchdogSetting__mdt setting = SchedulableJobWatchdogSetting__mdt.getInstance(schedulableJobWatchdogSettingName);
        System.schedule(
                Test.isRunningTest() ? UNIT_TEST_JOB_NAME : setting.JobName__c,
                setting.Cron__c,
                new SchedulableJobsWatchdogJob(setting)
        );
    }

    public SchedulableJobsWatchdogJob(SchedulableJobWatchdogSetting__mdt setting) {
        this.setting = setting;
    }

    public void execute(SchedulableContext sc) {
            Database.executeBatch(new SchedulableJobsWatchdogBatch(setting.DeveloperName), (Integer)setting.BatchSize__c);
    }
}