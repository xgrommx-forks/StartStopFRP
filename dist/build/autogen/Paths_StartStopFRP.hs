{-# LANGUAGE CPP #-}
{-# OPTIONS_GHC -fno-warn-missing-import-lists #-}
{-# OPTIONS_GHC -fno-warn-implicit-prelude #-}
module Paths_StartStopFRP (
    version,
    getBinDir, getLibDir, getDataDir, getLibexecDir,
    getDataFileName, getSysconfDir
  ) where

import qualified Control.Exception as Exception
import Data.Version (Version(..))
import System.Environment (getEnv)
import Prelude

#if defined(VERSION_base)

#if MIN_VERSION_base(4,0,0)
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#else
catchIO :: IO a -> (Exception.Exception -> IO a) -> IO a
#endif

#else
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
#endif
catchIO = Exception.catch

version :: Version
version = Version [0,1,0,0] []
bindir, libdir, datadir, libexecdir, sysconfdir :: FilePath

bindir     = "/Users/Tyler/Library/Haskell/bin"
libdir     = "/Users/Tyler/Library/Haskell/ghc-7.10.3-x86_64/lib/StartStopFRP-0.1.0.0"
datadir    = "/Users/Tyler/Library/Haskell/share/ghc-7.10.3-x86_64/StartStopFRP-0.1.0.0"
libexecdir = "/Users/Tyler/Library/Haskell/libexec"
sysconfdir = "/Users/Tyler/Library/Haskell/etc"

getBinDir, getLibDir, getDataDir, getLibexecDir, getSysconfDir :: IO FilePath
getBinDir = catchIO (getEnv "StartStopFRP_bindir") (\_ -> return bindir)
getLibDir = catchIO (getEnv "StartStopFRP_libdir") (\_ -> return libdir)
getDataDir = catchIO (getEnv "StartStopFRP_datadir") (\_ -> return datadir)
getLibexecDir = catchIO (getEnv "StartStopFRP_libexecdir") (\_ -> return libexecdir)
getSysconfDir = catchIO (getEnv "StartStopFRP_sysconfdir") (\_ -> return sysconfdir)

getDataFileName :: FilePath -> IO FilePath
getDataFileName name = do
  dir <- getDataDir
  return (dir ++ "/" ++ name)
