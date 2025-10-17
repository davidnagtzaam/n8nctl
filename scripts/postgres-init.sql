-- ============================================================================
-- n8n Production Deployment - PostgreSQL Initialization
-- ============================================================================
-- Created by: David Nagtzaam - https://davidnagtzaam.com
--
-- This script initializes the PostgreSQL database with optimal settings
-- for n8n workloads.
-- ============================================================================

-- Ensure UTF8 encoding
ALTER DATABASE n8n SET client_encoding TO 'UTF8';

-- Set timezone to UTC for consistency
ALTER DATABASE n8n SET timezone TO 'UTC';

-- Optimize for n8n's execution storage patterns
ALTER DATABASE n8n SET work_mem TO '16MB';
ALTER DATABASE n8n SET maintenance_work_mem TO '128MB';

-- Enable query statistics (helpful for performance tuning)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create a function to clean old execution data (optional)
-- Uncomment and customize if you want automated cleanup
/*
CREATE OR REPLACE FUNCTION cleanup_old_executions(days_to_keep INTEGER DEFAULT 30)
RETURNS void AS $$
BEGIN
    DELETE FROM execution_entity 
    WHERE "stopedAt" < NOW() - INTERVAL '1 day' * days_to_keep 
    AND "finished" = true;
END;
$$ LANGUAGE plpgsql;

-- Uncomment to schedule automatic cleanup (requires pg_cron extension)
-- SELECT cron.schedule('cleanup-executions', '0 3 * * *', $$SELECT cleanup_old_executions(30)$$);
*/

-- Log successful initialization
DO $$ 
BEGIN 
    RAISE NOTICE 'n8n database initialized successfully';
END $$;
