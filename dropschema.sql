DROP VIEW IF EXISTS AllLoops_ViewActive;
DROP INDEX IF EXISTS AllLoops_IndexTransactionId;
DROP TABLE IF EXISTS AllLoops;

DROP VIEW IF EXISTS AllLoopsStats_ViewActive;
DROP INDEX IF EXISTS AllLoopsStats_IndexActive;
DROP TABLE IF EXISTS AllLoopsStats;

DROP TABLE IF EXISTS CandinateTransaction;

DROP TABLE IF EXISTS CurrentChains;

DROP TABLE IF EXISTS LastUserTransaction;

DROP VIEW IF EXISTS ProcessedTransactions_ViewIncludedHerusticDesc;
DROP VIEW IF EXISTS ProcessedTransactions_ViewIncludedHerusticAsc;
DROP VIEW IF EXISTS ProcessedTransactions_ViewIncluded;
DROP INDEX IF EXISTS ProcessedTransactions_IndexValue;
DROP INDEX IF EXISTS ProcessedTransactions_IndexToUserId;
DROP INDEX IF EXISTS ProcessedTransactions_IndexFromUserId;

DROP TABLE IF EXISTS ProcessedTransactions;
DROP TABLE IF EXISTS OriginalTransactions;
