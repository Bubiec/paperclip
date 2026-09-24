UPDATE "heartbeat_runs"
SET "retry_of_run_id" = NULL
WHERE "retry_of_run_id" = "id";--> statement-breakpoint
ALTER TABLE "heartbeat_runs" ADD CONSTRAINT "heartbeat_runs_retry_of_run_id_not_self_check" CHECK ("heartbeat_runs"."retry_of_run_id" is null or "heartbeat_runs"."retry_of_run_id" <> "heartbeat_runs"."id");