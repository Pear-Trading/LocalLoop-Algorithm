CREATE TABLE OriginalTransactions (
  TransactionId INTEGER PRIMARY KEY NOT NULL,
  FromUserId INTEGER NOT NULL,
  ToUserId INTEGER NOT NULL,
  Value INTEGER
);

CREATE TABLE ProcessedTransactions (
  TransactionId INTEGER PRIMARY KEY NOT NULL,
  FromUserId INTEGER NOT NULL,
  ToUserId INTEGER NOT NULL,
  Value INTEGER NOT NULL, 
  Included INTEGER NOT NULL DEFAULT 1, 
  HeuristicValue INTEGER
);

CREATE INDEX ProcessedTransactions_IndexFromUserId 
ON ProcessedTransactions (FromUserId);

CREATE INDEX ProcessedTransactions_IndexToUserId 
ON ProcessedTransactions (ToUserId);

CREATE INDEX ProcessedTransactions_IndexValue 
ON ProcessedTransactions (Value);

CREATE VIEW ProcessedTransactions_ViewIncluded AS
SELECT TransactionId, FromUserId, ToUserId, Value, HeuristicValue
FROM ProcessedTransactions
WHERE Included = 1;

CREATE VIEW ProcessedTransactions_ViewIncludedHerusticAsc AS
SELECT TransactionId, FromUserId, ToUserId, Value, HeuristicValue
FROM ProcessedTransactions
WHERE Included = 1
ORDER BY HeuristicValue ASC, TransactionId ASC;

CREATE VIEW ProcessedTransactions_ViewIncludedHerusticDesc AS
SELECT TransactionId, FromUserId, ToUserId, Value, HeuristicValue
FROM ProcessedTransactions
WHERE Included = 1
ORDER BY HeuristicValue DESC, TransactionId ASC;


CREATE TABLE LastUserTransaction (
  UserId INTEGER PRIMARY KEY NOT NULL,
  LastTransactionId_FK INTEGER NOT NULL,
  FOREIGN KEY (LastTransactionId_FK) REFERENCES ProcessedTransactions (TransactionId) 
);

CREATE TABLE CurrentChains (
  ChainId INTEGER NOT NULL,
  TransactionId_FK INTEGER NOT NULL,
  MinimumValue INTEGER NOT NULL,
  Length INTEGER NOT NULL,
  TotalValue INTEGER NOT NULL,
  NumberOfMinimumValues INTEGER NOT NULL,
  PRIMARY KEY (ChainId, TransactionId_FK),
  FOREIGN KEY (TransactionId_FK) REFERENCES ProcessedTransactions (TransactionId) 
);

CREATE TABLE CandinateTransaction (
  ChainId INTEGER NOT NULL,
  TransactionFrom INTEGER NOT NULL,
  TransactionTo INTEGER NOT NULL,
  PRIMARY KEY(ChainId, TransactionFrom)
);

CREATE TABLE AllLoopsStats (
  AllLoopId INTEGER PRIMARY KEY NOT NULL,
  Active INTEGER NOT NULL,
  MinimumValue INTEGER NOT NULL,
  Length INTEGER NOT NULL,
  TotalValue INTEGER NOT NULL,
  NumberOfMinimumValues INTEGER NOT NULL
);

CREATE INDEX AllLoopsStats_IndexActive
ON AllLoopsStats (Active);

CREATE VIEW AllLoopsStats_ViewActive AS
SELECT AllLoopId, MinimumValue, Length, TotalValue, NumberOfMinimumValues
FROM AllLoopsStats
WHERE Active = 1;

CREATE TABLE AllLoops (
  AllLoopId INTEGER NOT NULL,
  TransactionId_FK INTEGER NOT NULL,
  PRIMARY KEY (AllLoopId, TransactionId_FK),
  FOREIGN KEY (AllLoopId) REFERENCES AllLoopsStats (AllLoopId), 
  FOREIGN KEY (TransactionId_FK) REFERENCES ProcessedTransactions (TransactionId) 
);

CREATE INDEX AllLoops_IndexTransactionId
ON AllLoops (TransactionId_FK);

CREATE VIEW AllLoops_ViewActive AS
SELECT AllLoops.AllLoopId, AllLoops.TransactionId_FK
FROM AllLoops, AllLoopsStats
WHERE AllLoopsStats.Active = 1 AND AllLoops.AllLoopId = AllLoopsStats.AllLoopId;


