CREATE TABLE OriginalTransactions (
  TransactionId INTEGER PRIMARY KEY NOT NULL,
  FromUserId INTEGER NOT NULL,
  ToUserId INTEGER NOT NULL,
  Value INTEGER NOT NULL
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

CREATE TABLE CurrentChainsStats (
  ChainStatsId INTEGER PRIMARY KEY NOT NULL,
  MinimumValue INTEGER NOT NULL,
  Length INTEGER NOT NULL,
  TotalValue INTEGER NOT NULL,
  NumberOfMinimumValues INTEGER NOT NULL
);

CREATE TABLE CurrentChains (
  ChainId INTEGER NOT NULL,
  TransactionId_FK INTEGER NOT NULL,
  ChainStatsId_FK INTEGER NOT NULL,
  PRIMARY KEY (ChainId, TransactionId_FK),
  FOREIGN KEY (TransactionId_FK) REFERENCES ProcessedTransactions (TransactionId),
  FOREIGN KEY (ChainStatsId_FK) REFERENCES CurrentChainsStats (ChainStatsId) 
);

CREATE TABLE BranchedTransactions (
  ChainId_FK INTEGER NOT NULL,
  FromTransactionId_FK INTEGER NOT NULL,
  ToTransactionId_FK INTEGER NOT NULL,
  PRIMARY KEY (ChainId_FK, FromTransactionId_FK, ToTransactionId_FK),
  FOREIGN KEY (ChainId_FK) REFERENCES CurrentChains (ChainId),
  FOREIGN KEY (FromTransactionId_FK) REFERENCES ProcessedTransactions (TransactionId),
  FOREIGN KEY (ToTransactionId_FK) REFERENCES ProcessedTransactions (TransactionId)
);

CREATE TABLE CandinateTransactions (
  CandinateTransactionsId INTEGER NOT NULL UNIQUE,
  ChainId_FK INTEGER,
  TransactionFrom_FK INTEGER,
  TransactionTo_FK INTEGER NOT NULL,
  MinimumValue INTEGER NOT NULL,
  Length INTEGER NOT NULL,
  TotalValue INTEGER NOT NULL,
  NumberOfMinimumValues INTEGER NOT NULL,
  Included INTEGER NOT NULL DEFAULT 1,
  HeuristicValue INTEGER,
  PRIMARY KEY (ChainId_FK, TransactionFrom_FK, TransactionTo_FK),
  FOREIGN KEY (ChainId_FK) REFERENCES CurrentChains (ChainId), 
  FOREIGN KEY (TransactionFrom_FK) REFERENCES ProcessedTransactions (TransactionId), 
  FOREIGN KEY (TransactionTo_FK) REFERENCES ProcessedTransactions (TransactionId), 
  CHECK ((ChainId_FK ISNULL AND TransactionFrom_FK ISNULL) OR (ChainId_FK NOTNULL AND TransactionFrom_FK NOTNULL))
);

CREATE VIEW CandinateTransactions_ViewIncluded AS
SELECT CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, HeuristicValue
FROM CandinateTransactions
WHERE Included = 1;

CREATE VIEW CandinateTransactions_ViewIncludedHerusticAsc AS
SELECT CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, HeuristicValue
FROM CandinateTransactions
WHERE Included = 1
ORDER BY HeuristicValue ASC, TransactionTo_FK ASC;

CREATE VIEW CandinateTransactions_ViewIncludedHerusticDesc AS
SELECT CandinateTransactionsId, ChainId_FK, TransactionFrom_FK, TransactionTo_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, HeuristicValue
FROM CandinateTransactions
WHERE Included = 1
ORDER BY HeuristicValue DESC, TransactionTo_FK ASC;

CREATE TABLE LoopInfo (
  LoopId INTEGER PRIMARY KEY NOT NULL,
  Active INTEGER NOT NULL DEFAULT 0,
  FirstTransactionId_FK INTEGER NOT NULL,
  LastTransactionId_FK INTEGER NOT NULL,
  MinimumValue INTEGER NOT NULL,
  Length INTEGER NOT NULL,
  TotalValue INTEGER NOT NULL,
  NumberOfMinimumValues INTEGER NOT NULL,
  Included INTEGER NOT NULL DEFAULT 1,
  HeuristicValue INTEGER,
  FOREIGN KEY (FirstTransactionId_FK) REFERENCES ProcessedTransactions (TransactionId),
  FOREIGN KEY (LastTransactionId_FK) REFERENCES ProcessedTransactions (TransactionId)  
);

CREATE INDEX LoopInfo_IndexActive
ON LoopInfo (Active);

CREATE VIEW LoopInfo_ViewActive AS
SELECT LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included, HeuristicValue
FROM LoopInfo
WHERE Active = 1;

CREATE VIEW LoopInfo_ViewInactive AS
SELECT LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included, HeuristicValue
FROM LoopInfo
WHERE Active = 0;

CREATE VIEW LoopInfo_ViewIncluded AS
SELECT LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, Included, HeuristicValue
FROM LoopInfo
WHERE Included = 1;

CREATE VIEW LoopInfo_ViewIncludedInactive AS
SELECT LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, HeuristicValue
FROM LoopInfo
WHERE Included = 1 AND Active = 0 ;

CREATE VIEW LoopInfo_ViewIncludedInactiveHerusticAsc AS
SELECT LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, HeuristicValue
FROM LoopInfo
WHERE Included = 1 AND Active = 0
ORDER BY HeuristicValue ASC;

CREATE VIEW LoopInfo_ViewIncludedInactiveHerusticDesc AS
SELECT LoopId, FirstTransactionId_FK, LastTransactionId_FK, MinimumValue, Length, TotalValue, NumberOfMinimumValues, HeuristicValue
FROM LoopInfo
WHERE Included = 1 AND Active = 0
ORDER BY HeuristicValue DESC;

CREATE TABLE Loops (
  LoopId_FK INTEGER NOT NULL,
  TransactionId_FK INTEGER NOT NULL,
  PRIMARY KEY (LoopId_FK, TransactionId_FK),
  FOREIGN KEY (LoopId_FK) REFERENCES LoopInfo (LoopId), 
  FOREIGN KEY (TransactionId_FK) REFERENCES ProcessedTransactions (TransactionId) 
);

CREATE INDEX Loops_IndexTransactionId
ON Loops (TransactionId_FK);

CREATE INDEX Loops_IndexLoopId
ON Loops (LoopId_FK);

CREATE VIEW Loops_ViewActive AS
SELECT Loops.LoopId_FK, Loops.TransactionId_FK
FROM Loops, LoopInfo
WHERE LoopInfo.Active = 1 AND Loops.LoopId = LoopInfo.LoopId;


