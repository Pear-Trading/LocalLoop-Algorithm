DROP VIEW IF EXISTS Loops_ViewActive;
DROP INDEX IF EXISTS Loops_IndexTransactionId;
DROP TABLE IF EXISTS Loops;

DROP VIEW IF EXISTS LoopInfo_ViewIncludedInactiveHerusticDesc;
DROP VIEW IF EXISTS LoopInfo_ViewIncludedInactiveHerusticAsc;
DROP VIEW IF EXISTS LoopInfo_ViewIncludedInactive;
DROP VIEW IF EXISTS LoopInfo_ViewIncluded;
DROP VIEW IF EXISTS LoopInfo_ViewInactive;
DROP VIEW IF EXISTS LoopInfo_ViewActive;
DROP INDEX IF EXISTS LoopInfo_IndexActive;
DROP TABLE IF EXISTS LoopInfo;

DROP TABLE IF EXISTS CandidateTransactions;

DROP TABLE IF EXISTS BranchedTransactions;

DROP VIEW IF EXISTS CandidateTransactions_ViewIncludedHerusticDesc;
DROP VIEW IF EXISTS CandidateTransactions_ViewIncludedHerusticAsc;
DROP VIEW IF EXISTS CandidateTransactions_ViewIncluded;
DROP TABLE IF EXISTS CurrentChains;

DROP TABLE IF EXISTS CurrentChainsStats;

DROP TABLE IF EXISTS LastUserTransaction;

DROP VIEW IF EXISTS ProcessedTransactions_ViewIncludedHerusticDesc;
DROP VIEW IF EXISTS ProcessedTransactions_ViewIncludedHerusticAsc;
DROP VIEW IF EXISTS ProcessedTransactions_ViewIncluded;
DROP INDEX IF EXISTS ProcessedTransactions_IndexValue;
DROP INDEX IF EXISTS ProcessedTransactions_IndexToUserId;
DROP INDEX IF EXISTS ProcessedTransactions_IndexFromUserId;

DROP TABLE IF EXISTS ProcessedTransactions;
DROP TABLE IF EXISTS OriginalTransactions;

