{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NoImplicitPrelude #-}
module Main where

import Prelude
import Options.Generic
import Control.Monad (forever)
import Control.Concurrent (threadDelay)
import Data.Foldable (forM_)
import Data.Maybe (fromMaybe, isNothing)
import Database.SQLite.Simple (Connection, withConnection, query, query_, execute, execute_, Only)
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import System.Process as System

data CommitMode
  = DeleteFirst
  | DeleteAfter
  deriving (Generic, Show, Read)
instance ParseField CommitMode

data Action
  = Print
  | Exec
  deriving (Generic, Show, Read)
instance ParseRecord Action
instance ParseField Action
instance ParseFields Action

data Params
  = Init
  { queue :: FilePath
  }
  | Enqueue
  { queue :: FilePath
  , jobs :: FilePath
  }
  | Process
  { queue :: FilePath
  , num :: Maybe Int
  , commitMode :: Maybe CommitMode
  , action :: Action
  }
  deriving (Generic, Show)
instance ParseRecord Params

main :: IO ()
main = do
  params <- getRecord "sqq" :: IO Params
  case params of
    Init _ -> initialize params
    Enqueue _ _ -> enqueue params
    Process _ _ _ _ -> process params

initialize :: Params -> IO ()
initialize params = do
  withConnection (queue params) $ \conn -> do
    _ <- query_ conn "SELECT 1" :: IO [Only Int]
    execute_ conn "CREATE TABLE IF NOT EXISTS jobs (id INTEGER PRIMARY KEY, payload TEXT)"

enqueue :: Params -> IO ()
enqueue params = do
  withConnection (queue params) $ \conn -> do
    payloads <- readPayloads
    forM_ payloads $ \payload -> do
      execute conn "INSERT INTO jobs (payload) VALUES (?)" (Only payload)
  where
    readPayloads :: IO [Text]
    readPayloads = Text.lines <$> Text.readFile (jobs params)

type ProcessJob = (Int,Text)

process :: Params -> IO ()
process params = do
  loop $ do
    withConnection (queue params) $ \conn -> do
      rows <- query conn "SELECT * FROM jobs LIMIT (?)" (Only limit) :: IO [ProcessJob]
      forM_ rows (run conn)
  where
    loop :: IO () -> IO ()
    loop act
       | isNothing (num params) = forever (act *> threadDelay 1000000)
       | otherwise = act

    limit :: Int
    limit = fromMaybe 23 (num params)

    mode :: CommitMode
    mode = fromMaybe DeleteAfter (commitMode params)

    run :: Connection -> ProcessJob -> IO ()
    run conn (jobId, payload) = do
      case mode of
        DeleteFirst -> do
          execute conn "DELETE FROM jobs WHERE id = (?)" (Only jobId)
          handle payload
        DeleteAfter -> do
          handle payload
          execute conn "DELETE FROM jobs WHERE id = (?)" (Only jobId)

    handle :: Text -> IO ()
    handle payload = case action params of
      Print -> Text.putStrLn payload
      Exec -> System.callCommand (Text.unpack payload)
