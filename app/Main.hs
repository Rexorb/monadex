{-# LANGUAGE OverloadedStrings #-}
module Main (main) where

import Application (runApplication)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Logger (runNoLoggingT)
import Data.ByteString.Char8 (pack)
import Data.Char (isAsciiLower, isAsciiUpper, isDigit)
import Data.List (stripPrefix)
import Data.Time.LocalTime.TimeZone.Olson (getTimeZoneSeriesFromOlsonFile)
import qualified Data.Text as T
import Database.Persist.Postgresql (runSqlPool, withPostgresqlPool)
import Foundation (App(..))
import Model (migrateMonadex)
import Service.CardImportService (importSet, persistCatalog)
import System.Environment (getArgs, lookupEnv)
import System.Exit (exitFailure)
import System.Posix.Files (setFileCreationMask, setFileMode)
import Text.Read (readMaybe)
import Yesod.Core (defaultClientSessionBackend, sslOnlySessions, strictSameSiteSessions)

main :: IO ()
main = do
    _ <- setFileCreationMask 0o077
    args <- getArgs
    connection <- lookupEnv "DATABASE_URL"
    portText <- lookupEnv "PORT"
    keyPath <- maybe ".session-key" id <$> lookupEnv "SESSION_KEY_PATH"
    secureCookies <- (== Just "true") <$> lookupEnv "SESSION_COOKIE_SECURE"
    frontendOrigin <- lookupEnv "FRONTEND_ORIGIN"
    case connection of
        Nothing -> ioError (userError "DATABASE_URL is required; see .env.example")
        Just url -> do
            let port = maybe 3000 id (portText >>= readMaybe)
            runNoLoggingT $ withPostgresqlPool (pack url) 10 $ \pool -> do
                runSqlPool migrateMonadex pool
                case args of
                    [] -> liftIO $ do
                        allowedOrigin <- case frontendOrigin of
                            Nothing -> pure Nothing
                            Just origin | validOrigin origin -> pure (Just (pack origin))
                            Just _ -> ioError (userError "FRONTEND_ORIGIN must be one explicit HTTPS origin or a loopback HTTP origin")
                        zone <- getTimeZoneSeriesFromOlsonFile "/usr/share/zoneinfo/America/Sao_Paulo"
                        backend <- defaultClientSessionBackend 120 keyPath
                        setFileMode keyPath 0o600
                        let configured = if secureCookies then sslOnlySessions else id
                        secured <- configured $ strictSameSiteSessions (pure (Just backend))
                        runApplication port (App pool (maybe backend id secured) zone allowedOrigin)
                    ["--import-set", identifier] -> do
                        result <- liftIO (importSet (T.pack identifier))
                        case result of
                            Left failure -> liftIO (print failure >> exitFailure)
                            Right (expansion, cards, report) -> do
                                runSqlPool (persistCatalog expansion cards) pool
                                liftIO (print report)
                    _ -> liftIO (putStrLn "Usage: monadex [--import-set SET_ID]" >> exitFailure)

-- Never allow wildcard/credentials, paths or arbitrary cleartext origins.
validOrigin :: String -> Bool
validOrigin origin = case stripPrefix "https://" origin of
    Just host -> validHost host
    Nothing -> case stripPrefix "http://" origin of
        Just host -> any (`loopbackHost` host) ["localhost", "127.0.0.1"]
        Nothing -> False
  where
    validHost host = not (null host) && all (\c -> isAsciiLower c || isAsciiUpper c
                        || isDigit c || c `elem` (".-:" :: String)) host
    loopbackHost prefix host = host == prefix || case stripPrefix (prefix <> ":") host of
        Just digits -> not (null digits) && all isDigit digits
        Nothing -> False
