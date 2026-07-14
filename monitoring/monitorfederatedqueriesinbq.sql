--To monitor predicate pushdown were sent and to monitor how much data is being sent from BQ using total_bytes_processed column
SELECT 
  job_id,
  DATETIME(creation_time, 'America/Chicago') AS creation_time_central,
  total_bytes_processed,
  query,
  user_email
FROM `bq-project-402513`.`region-us-central1`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
--this filter gives you queries run by AlloyDB service account
WHERE user_email = 'c-xyz@gcp-sa-alloydb.iam.gserviceaccount.com'
ORDER BY creation_time DESC
LIMIT 5;
