@isTest
public class SchedulableJobsWatchdogBatchTest {

    private static final String JOB_NAME = 'Schedulable Job Mock Test';
    private static final String SECOND_JOB_NAME = 'Another Job Name';
    private static final String SCHEDULABLE_APEX_CLASS = 'SchedulableJobsWatchdogBatchTest.TestJobScheduler';

    private static SchedulableJobWatchdogConfig__mdt generateConfig(Map<String, Object> fieldsMap) {
        SchedulableJobWatchdogConfig__mdt config = new SchedulableJobWatchdogConfig__mdt(
                Label = JOB_NAME,
                JobNameRegex__c = JOB_NAME,
                Reschedule__c = true,
                CronExpression__c = '0 0 12 * * ?',
                SendNotification__c = true,
                Scheduler__c = null,
                SchedulableApexClass__c = SCHEDULABLE_APEX_CLASS
        );

        if (fieldsMap != null) {
            for (String fieldName : fieldsMap.keySet()) {
                config.put(fieldName, fieldsMap.get(fieldName));
            }
        }

        return config;
    }

    @isTest
    static void testSchedulingTwoJobsAndSendingEmailForOne() {

        SchedulableJobsWatchdogBatch batchJob = new SchedulableJobsWatchdogBatch('');

        Test.startTest();
        batchJob.start(null);
        batchJob.execute(null, new List<SchedulableJobWatchdogConfig__mdt>{
                generateConfig(null),
                generateConfig(new Map<String, Object> {
                        'Label' => SECOND_JOB_NAME,
                        'JobNameRegex__c' => SECOND_JOB_NAME,
                        'SendNotification__c' => false,
                        'CronExpression__c' => '0 0 13 * * ?'
                })
        });
        batchJob.finish(null);
        Test.stopTest();

        // Verify if 1 LogEntryTag__c triggering the notification created
        Assert.areEqual(1, [SELECT Id, Name, Tag__r.Name FROM LogEntryTag__c WHERE Tag__r.Name = 'Missing Job'].size(), 'There should be only one LogEntryTag__c created, to trigger the notification for one job.');
        // Verify if both jobs scheduled accordingly to configuration
        List<CronTrigger> jobs = [SELECT Id, CronJobDetail.Name, NextFireTime,  PreviousFireTime, StartTime, State FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME];
        Assert.areEqual(1, jobs.size(), 'There should be one job scheduled, with name ' + JOB_NAME);
        CronTrigger job = jobs.get(0);
        Assert.areEqual(12, job.NextFireTime.hourGmt(), 'Job should be scheduled to run in noon.');
        jobs = [SELECT Id, CronJobDetail.Name, NextFireTime,  PreviousFireTime, StartTime, State FROM CronTrigger WHERE CronJobDetail.Name = :SECOND_JOB_NAME];
        Assert.areEqual(1, jobs.size(), 'There should be one job scheduled, with name ' + SECOND_JOB_NAME);
        job = jobs.get(0);
        Assert.areEqual(13, job.NextFireTime.hourGmt(), 'Job should be scheduled to run at 1PM.');

    }

    @isTest
    static void testSchedulingAndSendingEmailForOneJob() {

        SchedulableJobsWatchdogBatch batchJob = new SchedulableJobsWatchdogBatch('');

        Test.startTest();
        batchJob.start(null);
        batchJob.execute(null, new List<SchedulableJobWatchdogConfig__mdt>{generateConfig(null)});
        batchJob.finish(null);
        Test.stopTest();

        // Verify if LogEntryTag__c triggering the notification created
        Assert.areEqual(1, [SELECT Id, Name, Tag__r.Name FROM LogEntryTag__c WHERE Tag__r.Name = 'Missing Job'].size(), 'LogEntryTag__c triggering the notification should be created.');
        // Verify if job scheduled accordingly to configuration
        List<CronTrigger> jobs = [SELECT Id, CronJobDetail.Name, NextFireTime,  PreviousFireTime, StartTime, State FROM CronTrigger WHERE CronJobDetail.Name = :JOB_NAME];
        Assert.areEqual(1, jobs.size(), 'There should be one job scheduled, with name ' + JOB_NAME);
        CronTrigger job = jobs.get(0);
        Assert.areEqual(12, job.NextFireTime.hourGmt(), 'Job should be scheduled to run in noon.');
    }

    @isTest
    static void testSchedulingJobWhenOneMatchedAlreadyScheduled() {

        SchedulableJobWatchdogConfig__mdt config = generateConfig(new Map<String, Object> {
                'JobNameRegex__c' => JOB_NAME + '.*',
                'Scheduler__c' => SCHEDULABLE_APEX_CLASS
        });

        //initial scheduling
        SchedulableJobsWatchdogBatch batchJob = new SchedulableJobsWatchdogBatch('');
        batchJob.start(null);
        batchJob.execute(null, new List<SchedulableJobWatchdogConfig__mdt>{
                config
        });
        batchJob.finish(null);

        // Verify if both jobs scheduled accordingly to configuration
        List<CronTrigger> jobs = [SELECT Id, CronJobDetail.Name, NextFireTime,  PreviousFireTime, StartTime, State FROM CronTrigger WHERE CronJobDetail.Name LIKE :JOB_NAME + '%'];
        Assert.areEqual(1, jobs.size(), 'There should be one job scheduled, with name starting with ' + JOB_NAME);
        Assert.areNotEqual(JOB_NAME, jobs.get(0).CronJobDetail.Name, 'Job name should have suffix.');

        Test.startTest();

        //scheduling with different name but matching the regex
        batchJob = new SchedulableJobsWatchdogBatch('');
        batchJob.start(null);
        batchJob.execute(null, new List<SchedulableJobWatchdogConfig__mdt>{
                config
        });
        batchJob.finish(null);
        Test.stopTest();

        //Verify if second job was not scheduled
        jobs = [SELECT Id, CronJobDetail.Name, NextFireTime,  PreviousFireTime, StartTime, State FROM CronTrigger WHERE CronJobDetail.Name LIKE :JOB_NAME + '%'];
        Assert.areEqual(1, jobs.size(), 'There should be one job scheduled, with name starting with ' + JOB_NAME);
    }

    public class TestJobScheduler implements JobScheduler, Schedulable {

        public void execute(SchedulableContext context) {
            System.debug('Executed');
        }

        public void scheduleJob() {
            System.schedule(JOB_NAME + Crypto.getRandomInteger(), '0 0 12 * * ?', new TestJobScheduler());
        }
    }
}