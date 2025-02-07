public with sharing class SchedulableJobsWatchdogBatch implements Database.Batchable<sObject>, Database.Stateful {

    private String settingName;

    public SchedulableJobsWatchdogBatch(String settingName) {
        this.settingName = settingName;
    }

    public Iterable<SObject> start(Database.BatchableContext context) {
        return
                Test.isRunningTest()
                        ? new List<SchedulableJobWatchdogConfig__mdt>()
                        : [
                        SELECT Label, JobNameRegex__c, Reschedule__c, CronExpression__c, SendNotification__c, Scheduler__c, SchedulableApexClass__c
                        FROM SchedulableJobWatchdogConfig__mdt
                        WHERE SchedulableJobWatchdogSetting__r.DeveloperName = :settingName
                ];
    }

    public void execute(Database.BatchableContext context, List<SObject> records) {

        for (SchedulableJobWatchdogConfig__mdt config : (List<SchedulableJobWatchdogConfig__mdt>)records) {
            try {
                // Check job existence using regex
                Boolean jobFound = checkJobExists(config.JobNameRegex__c);

                if (!jobFound) {
                    // Handle notification if enabled
                    if (config.SendNotification__c) {
                        sendNotification(config);
                    }

                    // Handle rescheduling if enabled
                    if (config.Reschedule__c) {
                        rescheduleJob(config);
                    }
                }
            } catch (Exception e) {
                // Log any exception that occurs during processing
                Logger.error(
                        JSON.serialize(new Map<String, Object>{
                                'Config' => JSON.serialize(config),
                                'Error Message' => e.getMessage(),
                                'Stack Trace' => e.getStackTraceString()
                        }), e
                );
            }
        }

        Logger.saveLog();
    }

    public void finish(Database.BatchableContext context) {

    }

    // Helper method to check if a job exists based on regex
    private Boolean checkJobExists(String jobNameRegex) {

        Pattern pattern = Pattern.compile(jobNameRegex);

        List<String> inProgressStatuses = new List<String> {
                'EXECUTING', 'ACQUIRED', 'PAUSED', 'WAITING'
        };

        List<CronTrigger> scheduledJobs = [
                SELECT
                        Id, CronJobDetail.Name
                FROM
                        CronTrigger
                WHERE
                        NextFireTime >= :Datetime.now() OR State IN :inProgressStatuses
        ];

        for (CronTrigger job : scheduledJobs) {
            Matcher matcher = pattern.matcher(job.CronJobDetail.Name);
            if (matcher.matches()) {
                return true;
            }
        }
        return false;
    }

    // Helper method to reschedule a job
    private void rescheduleJob(SchedulableJobWatchdogConfig__mdt config) {

        String schedulerTypeString = config.Scheduler__c;

        JobScheduler scheduler = String.isNotBlank(schedulerTypeString)
                ? (JobScheduler)Type.forName(schedulerTypeString).newInstance()
                : new DefaultScheduler(config);

        Logger.info('Rescheduling job ' + config.Label + '...');

        scheduler.scheduleJob();
    }

    private void sendNotification(SchedulableJobWatchdogConfig__mdt config) {

        String currentEnvironmentName =  System.DomainParser.parse(URL.getOrgDomainUrl()).getSandboxName();
        currentEnvironmentName = String.isBlank(currentEnvironmentName) ? 'PROD' : currentEnvironmentName;

        String missingJobMessage = 'A scheduled job matching the regex pattern '
                + config.JobNameRegex__c
                + ' is missing in ' + currentEnvironmentName + ' environment.';
        if (config.Reschedule__c) {
            missingJobMessage += ' An attempt to schedule the missing job will be initiated. Please monitor the outcome of this attempt in Setup > Scheduled Jobs.';
        } else {
            missingJobMessage += ' Please schedule the job manually, following the job specification.';
        }

        Logger.error(missingJobMessage).addTag('Missing Job');
    }

    public class DefaultScheduler implements JobScheduler {

        private SchedulableJobWatchdogConfig__mdt config;

        public DefaultScheduler(SchedulableJobWatchdogConfig__mdt config) {
            this.config = config;
        }

        public void scheduleJob() {
            System.schedule(config.Label, config.CronExpression__c, (Schedulable)Type.forName(config.SchedulableApexClass__c).newInstance());
        }
    }
}