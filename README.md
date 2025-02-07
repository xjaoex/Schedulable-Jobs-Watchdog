Scheduled Jobs Watchdog
====================================

[[_TOC_]]


Overview
--------

The **Scheduled Jobs Watchdog** is a feature that ensures scheduled jobs are properly maintained in the system. It detects missing jobs based on predefined configurations and can optionally send notifications or reschedule missing jobs.

How It Works
------------

1.  A **watchdog job** is scheduled to run under a specific user context.
2.  The **watchdog job** checks for missing jobs based on predefined regex patterns stored in **SchedulableJobWatchdogConfig__mdt** records.
3.  If a job is missing:
    *   A notification is sent if enabled.
    *   The job is rescheduled if enabled.

Scheduling the Watchdog Job
---------------------------

To schedule a watchdog job under a specific user context, login as that user and execute the following apex :

    SchedulableJobsWatchdogJob.schedule('Service_User');


*   `'Service_User'` is the API name of **SchedulableJobWatchdogSetting__mdt** record.
*   Multiple watchdog jobs can be scheduled for different users, allowing independent job monitoring.
    One **SchedulableJobWatchdogSetting__mdt** record = One watchdog instance.

Configuration
-------------

The feature relies on **SchedulableJobWatchdogSetting__mdt** and **SchedulableJobWatchdogConfig__mdt**:
*   **SchedulableJobWatchdogSetting__mdt**: Stores settings for instance of the watchdog feature.
*   **SchedulableJobWatchdogConfig__mdt**: Defines which jobs to monitor.

Job Monitoring Configuration
----------------------------

Each monitored job is defined in **SchedulableJobWatchdogConfig__mdt**:
*   **JobNameRegex__c**: Regex pattern to match scheduled job by its name.
*   **SendNotification__c**: Flag to enable/disable email notification for missing job.
*   **Reschedule__c**: Flag to enable/disable automatic job rescheduling.
*   **SchedulableJobWatchdogSetting__c**: Reference to parent setting, defining which watchdog job will be monitoring this job.

Difference Between Default and Custom Scheduler Modes
-----------------------------------------------------

The key difference between **Default Scheduler Mode** and **Custom Scheduler Mode** is how job scheduling is handled:
*   **Default Scheduler Mode**: Uses predefined job details from the metadata record (job label, cron expression, and Apex class implementing `Schedulable`). The watchdog directly schedules the job based on these details.

*   **Custom Scheduler Mode**: Allows for advanced scheduling logic by specifying a custom **Scheduler__c** class that implements the `JobScheduler` interface. This approach is useful for jobs requiring dynamic scheduling or additional business logic beyond a simple cron expression.

Setting Up a New Job for Monitoring
-----------------------------------

To configure a new job for monitoring:
1.  Create a new **SchedulableJobWatchdogConfig__mdt** record.

2.  Choose a scheduling mode:

    **a. Default Scheduler Mode:**
    *   Leave **Scheduler__c** empty.
    *   Set **Label** to the job name.
    *   Set **CronExpression__c** with the cron expression used to schedule job.
    *   Set **SchedulableApexClass__c** with the name of Apex class implementing `Schedulable`.

    **b. Custom Scheduler Mode:**
    *   Set **Scheduler__c** to the name of Apex class implementing `JobScheduler`.
    *   **Label, CronExpression__c, SchedulableApexClass__c** are ignored since the custom scheduler handles fully the scheduling logic.
3.  Ensure the **SchedulableJobWatchdogConfig__mdt** record is linked to a **SchedulableJobWatchdogSetting__mdt** record.

4.  If the watchdog job is already scheduled, the newly configured job will be monitored in the next run.


Example
-------

**Example: Default Scheduler Configuration**

    SchedulableJobWatchdogConfig__mdt config = new SchedulableJobWatchdogConfig__mdt(
        Label = 'Daily Data Cleanup',
        JobNameRegex__c = 'Daily Data Cleanup',
        Reschedule__c = true,
        CronExpression__c = '0 0 2 * * ?',
        SendNotification__c = true,
        SchedulableApexClass__c = 'DailyCleanupJob'
    );


**Example: Custom Scheduler Configuration**

    SchedulableJobWatchdogConfig__mdt config = new SchedulableJobWatchdogConfig__mdt(
        Label = 'Advanced Job',
        JobNameRegex__c = 'AdvancedJob.*',
        Reschedule__c = true,
        SendNotification__c = true,
        Scheduler__c = 'CustomJobScheduler'
    );


Summary
-------

*   The watchdog job ensures scheduled jobs are running as expected.
*   It supports both **default scheduling** and **custom scheduling**.
*   Notifications and auto-rescheduling can be enabled per job.
*   New jobs added to the configuration are considered in the next watchdog run.
    This feature helps maintain a robust job scheduling system by automatically handling missing jobs and ensuring reliability in scheduled processes.