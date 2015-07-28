{-# LANGUAGE OverloadedStrings #-}
import Control.Monad.IO.Class (liftIO)
import qualified Database.Persist.Sqlite as Sqlite
import Network.HTTP.Types.Status (status404)
import System.Environment
import Web.Spock.Safe
import Web.PathPieces

import TodoBackend.Model
import TodoBackend.Utils

main :: IO ()
main = do
  runDb $ Sqlite.runMigration migrateAll
  port <- read <$> getEnv "PORT"
  runSpock port $ spockT id $ do
    middleware allowCors
    middleware allowOptions
    subcomponent "/todos" $ do
        get root $ do
            todos <- liftIO $ runDb $ Sqlite.selectList [] ([] :: [Sqlite.SelectOpt Todo])
            json todos
        get var $ \tid -> actionOr404 tid (\ident -> do
                        Just todo <- liftIO $ runDb $ Sqlite.get
                                     (ident :: TodoId)
                        json (Sqlite.Entity ident todo))
        patch var $ \tid -> actionOr404 tid (\ident -> do
                            todoAct <- jsonBody'
                            let todoUp = actionToUpdates todoAct
                            todo <- liftIO $ runDb $ Sqlite.updateGet
                                    ident todoUp
                            json (Sqlite.Entity ident todo))
        delete var $ \tid -> actionOr404 tid (\ident ->
                             liftIO $ runDb $ Sqlite.delete (ident :: TodoId))
        post root $ do
            todoAct <- jsonBody'
            let todo = actionToTodo todoAct
            tid <- liftIO $ runDb $ Sqlite.insert todo
            json (Sqlite.Entity tid todo)
        delete root $ liftIO $ runDb $ Sqlite.deleteWhere ([] :: [Sqlite.Filter Todo])
  where
    actionOr404 pid action = case fromPathPiece pid of
            Nothing  -> setStatus status404
            Just tid -> action tid
