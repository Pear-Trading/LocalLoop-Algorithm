DROP VIEW AllLoops_ViewActive;
DROP INDEX AllLoops_IndexTransactionId;
DROP TABLE AllLoops;

DROP VIEW AllLoopsStats_ViewActive;
DROP INDEX AllLoopsStats_IndexActive;
DROP TABLE AllLoopsStats;

DROP TABLE CandinateTransaction;

DROP TABLE CurrentChains;

DROP TABLE LastUserTransaction;

DROP VIEW ProcessedTransactions_ViewIncludedHerusticDesc;
DROP VIEW ProcessedTransactions_ViewIncludedHerusticAsc;
DROP VIEW ProcessedTransactions_ViewIncluded;
DROP INDEX ProcessedTransactions_IndexValue;
DROP INDEX ProcessedTransactions_IndexToUserId;
DROP INDEX ProcessedTransactions_IndexFromUserId;

DROP TABLE ProcessedTransactions;
DROP TABLE OriginalTransactions;
