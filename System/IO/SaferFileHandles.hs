{-# LANGUAGE UnicodeSyntax
           , NoImplicitPrelude
           , CPP
           , RankNTypes
           , KindSignatures
  #-}

-------------------------------------------------------------------------------
-- |
-- Module      :  System.IO.SaferFileHandles
-- Copyright   :  (c) 2010-2011 Bas van Dijk
-- License     :  BSD3 (see the file LICENSE)
-- Maintainer  :  Bas van Dijk <v.dijk.bas@gmail.com>
--
-- The contributions of this module are as follows:
--
-- * This module extends the @regions@ library with the ability to open files in
-- a 'RegionT'. When the region terminates, all opened resources will be closed
-- automatically. The main advantage of regions is that the handles to the
-- opened resources can not be returned from the region. This ensures no I/O
-- with closed resources is possible. The primary technique used in @regions@ is
-- called \"Lightweight monadic regions\" which was invented by Oleg Kiselyov
-- and Chung-chieh Shan. See:
-- <http://okmij.org/ftp/Haskell/regions.html#light-weight>
--
-- * Secondly this module provides all the file operations of @System.IO@ lifted
-- to the region monad.
--
-- * Third, filepaths that are given to functions like 'openFile' are created
-- and manipulated in a type-safe way using the @pathtype@ package.
--
-- * The final contribution of this module is that file handles are
-- parameterised with the IOMode in which the file was opened. This can be
-- either 'ReadMode', 'WriteMode', 'AppendMode' or 'ReadWriteMode'. All
-- operations on files explicitly specify the needed IOMode using the
-- 'ReadModes' and 'WriteModes' type classes. This way it is impossible to read
-- from a write-only handle or write to a read-only handle for example.
--
-- See the @safer-file-handles-examples@ package for examples how to use this
-- package:
--
-- @git clone <https://github.com/basvandijk/safer-file-handles-examples>@
--
-- /NOTE:/ This module also provides functions from @System.IO@ which don't
-- directly work with file handles like 'putStrLn' or 'getLine' for
-- example. These functions implicitly use the standard handles. I actually
-- provide more general versions of these that work in any 'MonadIO'. It could
-- be argued that these functions don't belong in this module because they don't
-- have anything to do with regions and explicit IOModes. However I provide them
-- as a convenience. But be warned that in the future these lifted functions may
-- move to their own package!
--
-------------------------------------------------------------------------------

module System.IO.SaferFileHandles
    ( -- * File handles
      FileHandle
    , RegionalFileHandle

      -- ** IO Modes
      -- | Types that represent the IOMode an opened file can be in.
    , ReadMode
    , WriteMode
    , AppendMode
    , ReadWriteMode

      -- *** Grouping the IOMode types.
    , ReadModes
    , WriteModes

      -- *** A value-level IOMode.
    , IOMode(..)
    , MkIOMode(mkIOMode)

      -- ** Standard handles
      {-| The standard handles have concrete IOModes by default which work
      for the majority of cases. In the rare occasion that you know these
      handles have different IOModes you can safely 'cast' them
      to the expected IOMode.

      Note that these handles are pure values. This means they don't perform
      side-effects like registering finalizers like @hClose stdin@ in the
      'RegionT' monad.

      Finally note that the region parameter of the handles is set to
      'RootRegion' which is the ancestor of any region. This allows the standard
      handles to be used in any region.
      -}
    , StdFileHandle
    , stdin, stdout, stderr
    , cast

      -- ** Opening files in a region
    , openFile, withFile

    -- *** Opening files by inferring the IOMode
    , openFile', withFile'

      -- ** Regions
      {-|
      Note that this module re-exports the @Control.Monad.Trans.Region@ module
      from the @regions@ package which allows you to run regions using 'runRegionT'
      and duplicate a 'RegionalFileHandle' to a parent region using 'dup'.
      -}
    , module Control.Monad.Trans.Region

      -- *  Operations on regional file handles
      -- ** Determining and changing the size of a file
    , hFileSize

#ifdef __GLASGOW_HASKELL__
    , hSetFileSize
#endif

      -- ** Detecting the end of input
    , hIsEOF
    , isEOF

      -- ** Buffering operations
    , BufferMode(..)
    , hSetBuffering
    , hGetBuffering
    , hFlush

    -- ** Repositioning handles
    , hGetPosn
    , hSetPosn
    , HandlePosn

    , hSeek
    , SeekMode(..)
#if !defined(__NHC__)
    , hTell
#endif

    -- ** Handle properties
    , hIsOpen, hIsClosed
    , hIsReadable, hIsWritable
    , hIsSeekable

    -- ** Terminal operations (not portable: GHC/Hugs only)
#if !defined(__NHC__)
    , hIsTerminalDevice

    , hSetEcho
    , hGetEcho
#endif
    -- ** Showing handle state (not portable: GHC only)
#ifdef __GLASGOW_HASKELL__
    , hShow
#endif
    -- * Text input and output
    -- ** Text input
    -- | Note that the following text input operations are polymorphic in the
    -- IOMode of the given handle. However the IOModes are restricted to
    -- 'ReadModes' only which can be either 'ReadMode' or 'ReadWriteMode'.
    , hWaitForInput
    , hReady
    , hGetChar
    , hGetLine
    , hLookAhead
    , hGetContents

    -- ** Text ouput
    -- | Note that the following text output operations are polymorphic in the
    -- IOMode of the given handle. However the IOModes are restricted to
    -- 'WriteModes' only which can be either
    -- 'WriteMode', 'AppendMode' or 'ReadWriteMode'.
    , hPutChar
    , hPutStr
    , hPutStrLn
    , hPrint

    -- ** Special cases for standard input and output
    , interact
    , putChar
    , putStr
    , putStrLn
    , print
    , getChar
    , getLine
    , getContents
    , readIO
    , readLn

    -- * Binary input and output
    , openBinaryFile, withBinaryFile

    -- ** Opening binary files by inferring the IOMode
    , openBinaryFile', withBinaryFile'

    -- ** Operations on binary handles
    , hSetBinaryMode
    , hPutBuf
    , hGetBuf

#if !defined(__NHC__) && !defined(__HUGS__)
#if MIN_VERSION_base(4,3,0)
    , hGetBufSome
#endif
    , hPutBufNonBlocking
    , hGetBufNonBlocking
#endif

    -- * Temporary files
    , Template

    , openTempFile
    , openBinaryTempFile

#if MIN_VERSION_base(4,2,0)
    , openTempFileWithDefaultPermissions
    , openBinaryTempFileWithDefaultPermissions
#endif

#if MIN_VERSION_base(4,2,0) && !defined(__NHC__) && !defined(__HUGS__)
    -- * Unicode encoding/decoding
    , hSetEncoding
    , hGetEncoding

    -- ** Unicode encodings
    , TextEncoding
    , latin1
    , utf8, utf8_bom
    , utf16, utf16le, utf16be
    , utf32, utf32le, utf32be
    , localeEncoding
    , mkTextEncoding

    -- * Newline conversion
    , hSetNewlineMode
    , Newline(..)
    , nativeNewline
    , NewlineMode(..)
    , noNewlineTranslation, universalNewlineMode, nativeNewlineMode
#endif
    )
    where


-------------------------------------------------------------------------------
-- Imports
-------------------------------------------------------------------------------

-- from base:
import Prelude           ( Integer )
import Control.Monad     ( return, (>>=), liftM )
import Data.Bool         ( Bool(..) )
import Data.Function     ( ($) )
import Data.Functor      ( fmap )
import Data.Char         ( Char )
import Data.Int          ( Int )
import Data.Maybe        ( Maybe )
import Text.Show         ( Show )
import Text.Read         ( Read )
import Foreign.Ptr       ( Ptr )

import qualified System.IO as SIO

#if __GLASGOW_HASKELL__ < 700
import Control.Monad     ( fail )
#endif

#if MIN_VERSION_base(4,4,0)
import Data.String       ( String )
#else
import Data.Char         ( String )
#endif

#ifdef __HADDOCK__
import System.IO.Error
#endif

-- from base-unicode-symbols:
import Data.Function.Unicode ( (∘) )

-- from transformers:
import Control.Monad.IO.Class ( MonadIO, liftIO )

-- from regions:
import Control.Monad.Trans.Region     -- ( re-exported entirely )
import Control.Monad.Trans.Region.OnExit ( onExit )
import Control.Monad.Trans.Region.Unsafe ( unsafeControlIO )

-- from explicit-iomodes
import System.IO.ExplicitIOModes ( IO

                                 , Handle

                                 , ReadMode
                                 , WriteMode
                                 , AppendMode
                                 , ReadWriteMode

                                 , ReadModes
                                 , WriteModes

                                 , IOMode(..)
                                 , MkIOMode(mkIOMode)

                                 , CheckMode

                                 , hClose

                                 , BufferMode(..)
                                 , HandlePosn
                                 , SeekMode(..)
#if MIN_VERSION_base(4,2,0) && !defined(__NHC__) && !defined(__HUGS__)
                                 , TextEncoding
                                 , latin1
                                 , utf8, utf8_bom
                                 , utf16, utf16le, utf16be
                                 , utf32, utf32le, utf32be
                                 , localeEncoding

                                 , Newline(..)
                                 , nativeNewline
                                 , NewlineMode(..)
                                 , noNewlineTranslation
                                 , universalNewlineMode
                                 , nativeNewlineMode
#endif
                                 )

import qualified System.IO.ExplicitIOModes as E

-- from pathtype:
import System.Path ( DirPath, FilePath
                   , AbsFile, RelFile
                   , AbsRelClass
                   , getPathString, asAbsFile
                   )

-- from regional-pointers:
import Foreign.Ptr.Region        ( AllocatedPointer )
import Foreign.Ptr.Region.Unsafe ( unsafePtr )

-- from ourselves:
import System.IO.SaferFileHandles.Internal ( RegionalFileHandle(RegionalFileHandle)
                                           , FileHandle
                                           )
import System.IO.SaferFileHandles.Unsafe   ( unsafeHandle
                                           , wrap, wrap2, wrap3
                                           , sanitizeIOError
                                           )

#if MIN_VERSION_base(4,3,0)
import Control.Exception ( mask_ )
#else
import Control.Exception ( block )

mask_ ∷ IO a → IO a
mask_ = block
#endif


-------------------------------------------------------------------------------
-- ** Standard handles
-------------------------------------------------------------------------------

newtype StdFileHandle ioMode (r ∷ * → *) = StdFileHandle (Handle ioMode)

instance FileHandle StdFileHandle where
    unsafeHandle (StdFileHandle handle) = handle

-- | Wraps: @System.IO.'SIO.stdin'@.
stdin ∷ StdFileHandle ReadMode RootRegion
stdin = StdFileHandle E.stdin

-- | Wraps: @System.IO.'SIO.stdout'@.
stdout ∷ StdFileHandle WriteMode RootRegion
stdout = StdFileHandle E.stdout

-- | Wraps: @System.IO.'SIO.stderr'@.
stderr ∷ StdFileHandle WriteMode RootRegion
stderr = StdFileHandle E.stderr

{-| Cast the IOMode of a handle if the handle supports it.

This function is used in combination with the standard handles.
When you know the IOMode of a handle is different from its default IOMode you
can cast it to the right one.
-}
cast ∷ (pr `AncestorRegion` cr, MonadIO cr, CheckMode castedIOMode)
     ⇒ StdFileHandle anyIOMode pr
     → cr (Maybe (StdFileHandle castedIOMode pr))
cast = (liftM ∘ fmap) StdFileHandle ∘ liftIO ∘ E.cast ∘ unsafeHandle


-------------------------------------------------------------------------------
-- ** Opening files in a region
-------------------------------------------------------------------------------

{-| Computation 'openFile' @filePath ioMode@ allocates and returns a new,
regional file handle to manage the file identified by @filePath@. It provides a
safer replacement for @System.IO.'SIO.openFile'@.

If the file does not exist and it is opened for output, it should be created as
a new file. If @ioMode@ is 'WriteMode' and the file already exists, then it
should be truncated to zero length.  Some operating systems delete empty files,
so there is no guarantee that the file will exist following an 'openFile' with
@ioMode@ 'WriteMode' unless it is subsequently written to successfully.  The
handle is positioned at the end of the file if @ioMode@ is 'AppendMode', and
otherwise at the beginning (in which case its internal position is 0). The
initial buffer mode is implementation-dependent.

Note that the returned regional file handle is parameterized by the region in
which it was created. This ensures that handles can never escape their
region. And it also allows operations on handles to be executed in a child
region of the region in which the handle was created.

Note that if you do wish to return a handle from the region in which it was
created you have to duplicate the handle by applying 'dup' to it.

Finally note that the returned regional file handle is also parameterized by the
IOMode in which you opened the file. All operations on files explicitly specify
the needed IOMode using the 'ReadModes' and 'WriteModes' type classes. This way
it is impossible to read from a write-only handle or write to a read-only handle
for example.

This operation may fail with:

 * 'isAlreadyInUseError' if the file is already open and cannot be reopened;

 * 'isDoesNotExistError' if the file does not exist; or

 * 'isPermissionError' if the user does not have permission to open the file.

Note: if you will be working with files containing binary data, you'll want to
be using 'openBinaryFile'.
-}
openFile ∷ (RegionControlIO pr, AbsRelClass ar)
         ⇒ FilePath ar
         → IOMode ioMode
         → RegionT s pr
             (RegionalFileHandle ioMode (RegionT s pr))
openFile = openNormal E.openFile

openNormal ∷ (RegionControlIO pr, AbsRelClass ar)
           ⇒ (E.FilePath → IOMode ioMode → IO (E.Handle ioMode))
           → ( FilePath ar
             → IOMode ioMode
             → RegionT s pr
                 (RegionalFileHandle ioMode (RegionT s pr))
             )
openNormal open = \filePath ioMode → unsafeControlIO $ \runInIO → mask_ $ do
  h ← open (getPathString filePath) ioMode
  runInIO $ do
    ch ← onExit $ sanitizeIOError $ hClose h
    return $ RegionalFileHandle h ch

{-| Convenience function which opens a file, applies the given continuation
function to the resulting regional file handle and runs the resulting
region. This provides a safer replacement for @System.IO.'SIO.withFile'@.
-}
withFile ∷ (RegionControlIO pr, AbsRelClass ar)
         ⇒ FilePath ar
         → IOMode ioMode
         → (∀ s. RegionalFileHandle ioMode (RegionT s pr) → RegionT s pr α)
         → pr α
withFile filePath ioMode f = runRegionT $ openFile filePath ioMode >>= f

-- *** Opening files by inferring the IOMode

-- | Open a file without explicitly specifying the IOMode. The IOMode is
-- inferred from the type of the resulting 'RegionalFileHandle'.
--
-- Note that: @openFile' fp = 'openFile' fp 'mkIOMode'@.
openFile' ∷ (RegionControlIO pr, AbsRelClass ar, MkIOMode ioMode)
          ⇒ FilePath ar
          → RegionT s pr
              (RegionalFileHandle ioMode (RegionT s pr))
openFile' filePath = openFile filePath mkIOMode

-- | Note that: @withFile' filePath = 'withFile' filePath 'mkIOMode'@.
withFile' ∷ (RegionControlIO pr, AbsRelClass ar, MkIOMode ioMode)
          ⇒ FilePath ar
          → (∀ s. RegionalFileHandle ioMode (RegionT s pr) → RegionT s pr α)
          → pr α
withFile' filePath = withFile filePath mkIOMode


-------------------------------------------------------------------------------
-- * Operations on regional file handles
-------------------------------------------------------------------------------

-- **  Determining and changing the size of a file

-- | For a handle @hdl@ which attached to a physical file,
-- 'hFileSize' @hdl@ returns the size of that file in 8-bit bytes.
--
-- Wraps: @System.IO.'SIO.hFileSize'@.
hFileSize ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
          ⇒ handle ioMode pr → cr Integer
hFileSize = wrap E.hFileSize

#ifdef __GLASGOW_HASKELL__
-- | 'hSetFileSize' @hdl@ @size@ truncates the physical file with handle @hdl@
-- to @size@ bytes.
--
-- Wraps: @System.IO.'SIO.hSetFileSize'@.
hSetFileSize ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
             ⇒ handle ioMode pr → Integer → cr ()
hSetFileSize = wrap2 E.hSetFileSize
#endif


-- ** Detecting the end of input

-- | For a readable handle @hdl@, 'hIsEOF' @hdl@ returns
-- 'True' if no further input can be taken from @hdl@ or for a
-- physical file, if the current I\/O position is equal to the length of
-- the file.  Otherwise, it returns 'False'.
--
-- NOTE: 'hIsEOF' may block, because it is the same as calling
-- 'hLookAhead' and checking for an EOF exception.
--
-- Wraps: @System.IO.'SIO.hIsEOF'@.
hIsEOF ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, ReadModes ioMode)
       ⇒ handle ioMode pr → cr Bool
hIsEOF = wrap E.hIsEOF

-- | Generalizes: @System.IO.'SIO.isEOF'@ to any 'MonadIO'.
isEOF ∷ MonadIO m ⇒ m Bool
isEOF = liftIO E.isEOF


-- ** Buffering operations

-- | Computation 'hSetBuffering' @hdl mode@ sets the mode of buffering for
-- handle @hdl@ on subsequent reads and writes.
--
-- If the buffer mode is changed from 'BlockBuffering' or
-- 'LineBuffering' to 'NoBuffering', then
--
--  * if @hdl@ is writable, the buffer is flushed as for 'hFlush';
--
--  * if @hdl@ is not writable, the contents of the buffer is discarded.
--
-- This operation may fail with:
--
--  * 'isPermissionError' if the handle has already been used for reading
--    or writing and the implementation does not allow the buffering mode
--    to be changed.
--
-- Wraps: @System.IO.'SIO.hSetBuffering'@.
hSetBuffering ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
              ⇒ handle ioMode pr → BufferMode → cr ()
hSetBuffering = wrap2 E.hSetBuffering

-- | Computation 'hGetBuffering' @hdl@ returns the current buffering mode for
-- @hdl@.
--
-- Wraps: @System.IO.'SIO.hGetBuffering'@.
hGetBuffering ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
              ⇒ handle ioMode pr → cr BufferMode
hGetBuffering = wrap E.hGetBuffering

-- | The action 'hFlush' @hdl@ causes any items buffered for output in handle
-- @hdl@ to be sent immediately to the operating system.
--
-- This operation may fail with:
--
--  * 'isFullError' if the device is full;
--
--  * 'isPermissionError' if a system resource limit would be exceeded. It is
--  unspecified whether the characters in the buffer are discarded or retained
--  under these circumstances.
--
-- Wraps: @System.IO.'SIO.hFlush'@.
hFlush ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, WriteModes ioMode)
       ⇒ handle ioMode pr → cr ()
hFlush = wrap E.hFlush


-- ** Repositioning handles

-- | Computation 'hGetPosn' @hdl@ returns the current I\/O position of @hdl@ as
-- a value of the abstract type 'HandlePosn'.
--
-- Wraps: @System.IO.'SIO.hGetPosn'@.
hGetPosn ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
         ⇒ handle ioMode pr → cr HandlePosn
hGetPosn = wrap E.hGetPosn

-- | If a call to 'hGetPosn' @hdl@ returns a position @p@, then computation
-- 'hSetPosn' @p@ sets the position of @hdl@ to the position it held at the time
-- of the call to 'hGetPosn'.
--
-- This operation may fail with:
--
--  * 'isPermissionError' if a system resource limit would be exceeded.
--
-- Wraps: @System.IO.'SIO.hSetPosn'@.
hSetPosn ∷ MonadIO m ⇒ HandlePosn → m ()
hSetPosn = liftIO ∘ E.hSetPosn

-- | Computation 'hSeek' @hdl mode i@ sets the position of handle @hdl@
-- depending on @mode@. The offset @i@ is given in terms of 8-bit bytes.
--
-- If @hdl@ is block- or line-buffered, then seeking to a position which is not
-- in the current buffer will first cause any items in the output buffer to be
-- written to the device, and then cause the input buffer to be discarded.  Some
-- handles may not be seekable (see 'hIsSeekable'), or only support a subset of
-- the possible positioning operations (for instance, it may only be possible to
-- seek to the end of a tape, or to a positive offset from the beginning or
-- current position).
-- It is not possible to set a negative I\/O position, or
-- for a physical file, an I\/O position beyond the current end-of-file.
--
-- This operation may fail with:
--
--  * 'isPermissionError' if a system resource limit would be exceeded.
--
-- Wraps: @System.IO.'SIO.hSeek'@.
hSeek ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
      ⇒ handle ioMode pr → SeekMode → Integer → cr ()
hSeek = wrap3 E.hSeek

#if !defined(__NHC__)
-- | Wraps: @System.IO.'SIO.hTell'@.
hTell ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
      ⇒ handle ioMode pr → cr Integer
hTell = wrap E.hTell
#endif


-- ** Handle properties

-- | Note that this operation should always return 'True' since the @regions@
-- framework ensures that handles are always open. This function is used only
-- for testing the correctness of this library.
--
-- Wraps: @System.IO.'SIO.hIsOpen'@.
hIsOpen ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
         ⇒ handle ioMode pr → cr Bool
hIsOpen = wrap E.hIsOpen

-- | Note that this operation should always return 'False' since the @regions@
-- framework ensures that handles are never closed. This function is used only
-- for testing the correctness of this library.
--
-- Wraps: @System.IO.'SIO.hIsClosed'@.
hIsClosed ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
           ⇒ handle ioMode pr → cr Bool
hIsClosed = wrap E.hIsClosed

-- | Note that this operation should always return 'True' for IOModes which have
-- an instance for 'ReadModes'. This function is used only for testing the
-- correctness of this library.
--
-- Wraps: @System.IO.'SIO.hIsReadable'@.
hIsReadable ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
            ⇒ handle ioMode pr → cr Bool
hIsReadable = wrap E.hIsReadable

-- | Note that this operation should always return 'True' for IOModes which have
-- an instance for 'WriteModes'. This function is used only for testing the
-- correctness of this library.
--
-- Wraps: @System.IO.'SIO.hIsWritable'@.
hIsWritable ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
            ⇒ handle ioMode pr → cr Bool
hIsWritable = wrap E.hIsWritable

-- | Wraps: @System.IO.'SIO.hIsSeekable'@.
hIsSeekable ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
            ⇒ handle ioMode pr → cr Bool
hIsSeekable = wrap E.hIsSeekable


-- ** Terminal operations (not portable: GHC/Hugs only)

#if !defined(__NHC__)
-- | Is the handle connected to a terminal?
--
-- Wraps: @System.IO.'SIO.hIsTerminalDevice'@.
hIsTerminalDevice ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
                  ⇒ handle ioMode pr → cr Bool
hIsTerminalDevice = wrap E.hIsTerminalDevice

-- | Set the echoing status of a handle connected to a terminal.
--
-- Wraps: @System.IO.'SIO.hSetEcho'@.
hSetEcho ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
         ⇒ handle ioMode pr → Bool → cr ()
hSetEcho = wrap2 E.hSetEcho

-- | Get the echoing status of a handle connected to a terminal.
--
-- Wraps: @System.IO.'SIO.hGetEcho'@.
hGetEcho ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
         ⇒ handle ioMode pr → cr Bool
hGetEcho = wrap E.hGetEcho
#endif


-- ** Showing handle state (not portable: GHC only)

#ifdef __GLASGOW_HASKELL__
-- | Wraps: @System.IO.'SIO.hShow'@.
hShow ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
      ⇒ handle ioMode pr → cr String
hShow = wrap E.hShow
#endif


--------------------------------------------------------------------------------
-- * Text input and output
--------------------------------------------------------------------------------

-- ** Text input

-- | Computation 'hWaitForInput' @hdl t@
-- waits until input is available on handle @hdl@.
-- It returns 'True' as soon as input is available on @hdl@,
-- or 'False' if no input is available within @t@ milliseconds.
--
-- If @t@ is less than zero, then @hWaitForInput@ waits indefinitely.
--
-- This operation may fail with:
--
--  * 'isEOFError' if the end of file has been reached.
--
-- NOTE for GHC users: unless you use the @-threaded@ flag,
-- @hWaitForInput t@ where @t >= 0@ will block all other Haskell
-- threads for the duration of the call.  It behaves like a
-- @safe@ foreign call in this respect.
--
-- Wraps: @System.IO.'SIO.hWaitForInput'@.
hWaitForInput ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, ReadModes ioMode)
              ⇒ handle ioMode pr → Int → cr Bool
hWaitForInput = wrap2 E.hWaitForInput

-- | Computation 'hReady' @hdl@ indicates whether at least one item is
-- available for input from handle @hdl@.
--
-- This operation may fail with:
--
--  * 'isEOFError' if the end of file has been reached.
--
-- Wraps: @System.IO.'SIO.hReady'@.
hReady ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, ReadModes ioMode)
       ⇒ handle ioMode pr → cr Bool
hReady = wrap E.hReady

-- | Computation 'hGetChar' @hdl@ reads a character from the file or
-- channel managed by @hdl@, blocking until a character is available.
--
-- This operation may fail with:
--
--  * 'isEOFError' if the end of file has been reached.
--
-- Wraps: @System.IO.'SIO.hGetChar'@.
hGetChar ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, ReadModes ioMode)
         ⇒ handle ioMode pr → cr Char
hGetChar = wrap E.hGetChar

-- | Computation 'hGetLine' @hdl@ reads a line from the file or
-- channel managed by @hdl@.
--
-- This operation may fail with:
--
--  * 'isEOFError' if the end of file is encountered when reading
--    the /first/ character of the line.
--
-- If 'hGetLine' encounters end-of-file at any other point while reading
-- in a line, it is treated as a line terminator and the (partial)
-- line is returned.
--
-- Wraps: @System.IO.'SIO.hGetLine'@.
hGetLine ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, ReadModes ioMode)
         ⇒ handle ioMode pr → cr String
hGetLine = wrap E.hGetLine

-- | Computation 'hLookAhead' returns the next character from the handle
-- without removing it from the input buffer, blocking until a character
-- is available.
--
-- This operation may fail with:
--
--  * 'isEOFError' if the end of file has been reached.
--
-- Wraps: @System.IO.'SIO.hLookAhead'@.
hLookAhead ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, ReadModes ioMode)
           ⇒ handle ioMode pr → cr Char
hLookAhead = wrap E.hLookAhead

-- | Computation 'hGetContents' @hdl@ returns the list of characters
-- corresponding to the unread portion of the channel or file managed
-- by @hdl@, which is put into an intermediate state, /semi-closed/.
-- In this state, @hdl@ is effectively closed,
-- but items are read from @hdl@ on demand and accumulated in a special
-- list returned by 'hGetContents' @hdl@.
--
-- Any operation that fails because a handle is closed,
-- also fails if a handle is semi-closed.
-- A semi-closed handle becomes closed:
--
--  * if its corresponding region terminates;
--
--  * if an I\/O error occurs when reading an item from the handle;
--
--  * or once the entire contents of the handle has been read.
--
-- Once a semi-closed handle becomes closed, the contents of the
-- associated list becomes fixed.  The contents of this final list is
-- only partially specified: it will contain at least all the items of
-- the stream that were evaluated prior to the handle becoming closed.
--
-- Any I\/O errors encountered while a handle is semi-closed are simply
-- discarded.
--
-- This operation may fail with:
--
--  * 'isEOFError' if the end of file has been reached.
--
-- Wraps: @System.IO.'SIO.hGetContents'@.
hGetContents ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, ReadModes ioMode)
             ⇒ handle ioMode pr → cr String
hGetContents = wrap E.hGetContents


-- ** Text ouput

-- | Computation 'hPutChar' @hdl ch@ writes the character @ch@ to the
-- file or channel managed by @hdl@.  Characters may be buffered if
-- buffering is enabled for @hdl@.
--
-- This operation may fail with:
--
--  * 'isFullError' if the device is full; or
--
--  * 'isPermissionError' if another system resource limit would be exceeded.
--
-- Wraps: @System.IO.'SIO.hPutChar'@.
hPutChar ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, WriteModes ioMode)
         ⇒ handle ioMode pr → Char → cr ()
hPutChar = wrap2 E.hPutChar

-- | Computation 'hPutStr' @hdl s@ writes the string
-- @s@ to the file or channel managed by @hdl@.
--
-- This operation may fail with:
--
--  * 'isFullError' if the device is full; or
--
--  * 'isPermissionError' if another system resource limit would be exceeded.
--
-- Wraps: @System.IO.'SIO.hPutStr'@.
hPutStr ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, WriteModes ioMode)
        ⇒ handle ioMode pr → String → cr ()
hPutStr = wrap2 E.hPutStr

-- | The same as 'hPutStr', but adds a newline character.
--
-- Wraps: @System.IO.'SIO.hPutStrLn'@.
hPutStrLn ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, WriteModes ioMode)
          ⇒ handle ioMode pr → String → cr ()
hPutStrLn = wrap2 E.hPutStrLn

-- | Computation 'hPrint' @hdl t@ writes the string representation of @t@
-- given by the 'shows' function to the file or channel managed by @hdl@
-- and appends a newline.
--
-- This operation may fail with:
--
--  * 'isFullError' if the device is full; or
--
--  * 'isPermissionError' if another system resource limit would be exceeded.
--
-- Wraps: @System.IO.'SIO.hPrint'@.
hPrint ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr, WriteModes ioMode, Show α)
       ⇒ handle ioMode pr → α → cr ()
hPrint = wrap2 E.hPrint


-- ** Special cases for standard input and output

-- | Generalizes @System.IO.'SIO.interact'@ to any 'MonadIO'.
interact ∷ MonadIO m ⇒ (String → String) → m ()
interact f = liftIO $ SIO.interact f

-- | Generalizes @System.IO.'SIO.putChar'@ to any 'MonadIO'.
putChar ∷ MonadIO m ⇒ Char → m ()
putChar c = liftIO $ SIO.putChar c

-- | Generalizes @System.IO.'SIO.putStr'@ to any 'MonadIO'.
putStr ∷ MonadIO m ⇒ String → m ()
putStr s = liftIO $ SIO.putStr s

-- | Generalizes @System.IO.'SIO.putStrLn'@ to any 'MonadIO'.
putStrLn ∷ MonadIO m ⇒ String → m ()
putStrLn s = liftIO $ SIO.putStrLn s

-- | Generalizes @System.IO.'SIO.print'@ to any 'MonadIO'.
print ∷ (MonadIO m, Show α) ⇒ α → m ()
print x = liftIO $ SIO.print x

-- | Generalizes @System.IO.'SIO.getChar'@ to any 'MonadIO'.
getChar ∷ MonadIO m ⇒ m Char
getChar = liftIO SIO.getChar

-- | Generalizes @System.IO.'SIO.getLine'@ to any 'MonadIO'.
getLine ∷ MonadIO m ⇒ m String
getLine = liftIO SIO.getLine

-- | Generalizes @System.IO.'SIO.getContents'@ to any 'MonadIO'.
getContents ∷ MonadIO m ⇒ m String
getContents = liftIO SIO.getContents

-- | Generalizes @System.IO.'SIO.readIO'@ to any 'MonadIO'.
readIO ∷ (MonadIO m, Read α) ⇒ String → m α
readIO s = liftIO $ SIO.readIO s

-- | Generalizes @System.IO.'SIO.readLn'@ to any 'MonadIO'.
readLn ∷ (MonadIO m, Read α) ⇒ m α
readLn = liftIO SIO.readLn


--------------------------------------------------------------------------------
-- * Binary input and output
--------------------------------------------------------------------------------

-- | Like 'openFile', but open the file in binary mode.
--
-- On Windows, reading a file in text mode (which is the default) will translate
-- CRLF to LF, and writing will translate LF to CRLF. This is usually what you
-- want with text files.  With binary files this is undesirable; also, as usual
-- under Microsoft operating systems, text mode treats control-Z as EOF. Binary
-- mode turns off all special treatment of end-of-line and end-of-file
-- characters.  (See also 'hSetBinaryMode'.)
--
-- This provides a safer replacement for @System.IO.'SIO.openBinaryFile'@.
openBinaryFile ∷ (RegionControlIO pr, AbsRelClass ar)
               ⇒ FilePath ar
               → IOMode ioMode
               → RegionT s pr
                   (RegionalFileHandle ioMode (RegionT s pr))
openBinaryFile = openNormal E.openBinaryFile

{-| A convenience function which opens a file in binary mode, applies the given
continuation function to the resulting regional file handle and runs the
resulting region. This provides a safer replacement for
@System.IO.'SIO.withBinaryFile'@.
-}
withBinaryFile ∷ (RegionControlIO pr, AbsRelClass ar)
               ⇒ FilePath ar
               → IOMode ioMode
               →  (∀ s. RegionalFileHandle ioMode (RegionT s pr) → RegionT s pr α)
               → pr α
withBinaryFile filePath ioMode f = runRegionT $ openBinaryFile filePath ioMode >>= f

-- ** Opening binary files by inferring the IOMode

-- | Note that: @openBinaryFile' filePath = 'openBinaryFile' filePath 'mkIOMode'@.
openBinaryFile' ∷ (RegionControlIO pr, AbsRelClass ar, MkIOMode ioMode)
                ⇒ FilePath ar
                → RegionT s pr
                    (RegionalFileHandle ioMode (RegionT s pr))
openBinaryFile' filePath = openBinaryFile filePath mkIOMode

-- | Note that: @withBinaryFile' filePath = 'withBinaryFile' filePath 'mkIOMode'@.
withBinaryFile' ∷ (RegionControlIO pr, AbsRelClass ar, MkIOMode ioMode)
                ⇒ FilePath ar
                →  (∀ s. RegionalFileHandle ioMode (RegionT s pr) → RegionT s pr α)
                → pr α
withBinaryFile' filePath = withBinaryFile filePath mkIOMode

-- ** Operations on binary handles

-- | Select binary mode ('True') or text mode ('False') on a open handle.
-- (See also 'openBinaryFile'.)
--
-- This has the same effect as calling 'hSetEncoding' with 'latin1', together
-- with 'hSetNewlineMode' with 'noNewlineTranslation'.
--
-- Wraps: @System.IO.'SIO.hSetBinaryMode'@.
hSetBinaryMode ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
               ⇒ handle ioMode pr → Bool → cr ()
hSetBinaryMode = wrap2 E.hSetBinaryMode

-- | 'hPutBuf' @hdl buf count@ writes @count@ 8-bit bytes from the
-- buffer @buf@ to the handle @hdl@.  It returns ().
--
-- 'hPutBuf' ignores any text encoding that applies to the handle,
-- writing the bytes directly to the underlying file or device.
--
-- 'hPutBuf' ignores the prevailing 'TextEncoding' and
-- 'NewlineMode' on the handle, and writes bytes directly.
--
-- This operation may fail with:
--
--  * 'ResourceVanished' if the handle is a pipe or socket, and the
--    reading end is closed.  (If this is a POSIX system, and the program
--    has not asked to ignore SIGPIPE, then a SIGPIPE may be delivered
--    instead, whose default action is to terminate the program).
--
-- Wraps: @System.IO.'SIO.hPutBuf'@.
hPutBuf ∷ ( pr1 `AncestorRegion` cr
          , pr2 `AncestorRegion` cr
          , FileHandle       handle
          , AllocatedPointer pointer
          , MonadIO cr
          , WriteModes ioMode
          )
        ⇒ handle ioMode pr1
        → pointer α pr2
        → Int
        → cr ()
hPutBuf = wrapPtr E.hPutBuf

wrapPtr ∷ ∀ (handle  ∷ * → (* → *) → *) ioMode (pr1 ∷ * → *)
            (pointer ∷ * → (* → *) → *) α      (pr2 ∷ * → *)
            cr β
        . (FileHandle handle, AllocatedPointer pointer, MonadIO cr)
        ⇒ (Handle ioMode → Ptr α → Int → IO β)
        → (handle ioMode pr1 → pointer α pr2 → Int → cr β)
wrapPtr f = \h pointer → liftIO ∘ f (unsafeHandle h) (unsafePtr pointer)

-- | 'hGetBuf' @hdl buf count@ reads data from the handle @hdl@
-- into the buffer @buf@ until either EOF is reached or
-- @count@ 8-bit bytes have been read.
-- It returns the number of bytes actually read.  This may be zero if
-- EOF was reached before any data was read (or if @count@ is zero).
--
-- 'hGetBuf' ignores whatever 'TextEncoding' the handle is
-- currently using, and reads bytes directly from the underlying IO device.
--
-- 'hGetBuf' never raises an EOF exception, instead it returns a value
-- smaller than @count@.
--
-- If the handle is a pipe or socket, and the writing end
-- is closed, 'hGetBuf' will behave as if EOF was reached.
--
-- 'hGetBuf' ignores the prevailing 'TextEncoding' and 'NewlineMode' on the
-- handle, and reads bytes directly.
--
-- Wraps: @System.IO.'SIO.hGetBuf'@.
hGetBuf ∷ ( pr1 `AncestorRegion` cr
          , pr2 `AncestorRegion` cr
          , FileHandle       handle
          , AllocatedPointer pointer
          , MonadIO cr
          , ReadModes ioMode
          )
        ⇒ handle ioMode pr1
        → pointer α pr2
        → Int
        → cr Int
hGetBuf = wrapPtr E.hGetBuf

#if !defined(__NHC__) && !defined(__HUGS__)

#if MIN_VERSION_base(4,3,0)
-- | 'hGetBufSome' @hdl buf count@ reads data from the handle @hdl@
-- into the buffer @buf@.  If there is any data available to read,
-- then 'hGetBufSome' returns it immediately; it only blocks if there
-- is no data to be read.
--
-- It returns the number of bytes actually read.  This may be zero if
-- EOF was reached before any data was read (or if @count@ is zero).
--
-- 'hGetBufSome' never raises an EOF exception, instead it returns a value
-- smaller than @count@.
--
-- If the handle is a pipe or socket, and the writing end
-- is closed, 'hGetBufSome' will behave as if EOF was reached.
--
-- 'hGetBufSome' ignores the prevailing 'TextEncoding' and 'NewlineMode'
-- on the handle, and reads bytes directly.
--
-- Wraps: @System.IO.'SIO.hGetBufSome'@.
hGetBufSome ∷ ( pr1 `AncestorRegion` cr
              , pr2 `AncestorRegion` cr
              , FileHandle       handle
              , AllocatedPointer pointer
              , MonadIO cr
              , ReadModes ioMode
              )
            ⇒ handle ioMode pr1
            → pointer α pr2
            → Int
            → cr Int
hGetBufSome = wrapPtr E.hGetBufSome
#endif

-- | Wraps: @System.IO.'SIO.hPutBufNonBlocking'@.
hPutBufNonBlocking ∷ ( pr1 `AncestorRegion` cr
                     , pr2 `AncestorRegion` cr
                     , FileHandle       handle
                     , AllocatedPointer pointer
                     , MonadIO cr
                     , WriteModes ioMode
                     )
                   ⇒ handle ioMode pr1
                   → pointer α pr2
                   → Int
                   → cr Int
hPutBufNonBlocking = wrapPtr E.hPutBufNonBlocking

-- | 'hGetBufNonBlocking' @hdl buf count@ reads data from the handle @hdl@
-- into the buffer @buf@ until either EOF is reached, or
-- @count@ 8-bit bytes have been read, or there is no more data available
-- to read immediately.
--
-- 'hGetBufNonBlocking' is identical to 'hGetBuf', except that it will
-- never block waiting for data to become available, instead it returns
-- only whatever data is available.  To wait for data to arrive before
-- calling 'hGetBufNonBlocking', use 'hWaitForInput'.
--
-- 'hGetBufNonBlocking' ignores whatever 'TextEncoding' the handle
-- is currently using, and reads bytes directly from the underlying IO device.
--
-- If the handle is a pipe or socket, and the writing end
-- is closed, 'hGetBufNonBlocking' will behave as if EOF was reached.
--
-- 'hGetBufNonBlocking' ignores the prevailing 'TextEncoding' and 'NewlineMode'
-- on the handle, and reads bytes directly.
--
-- Wraps: @System.IO.'SIO.hGetBufNonBlocking'@.
hGetBufNonBlocking ∷ ( pr1 `AncestorRegion` cr
                     , pr2 `AncestorRegion` cr
                     , FileHandle       handle
                     , AllocatedPointer pointer
                     , MonadIO cr
                     , ReadModes ioMode
                     )
                   ⇒ handle ioMode pr1
                   → pointer α pr2
                   → Int
                   → cr Int
hGetBufNonBlocking = wrapPtr E.hGetBufNonBlocking
#endif


--------------------------------------------------------------------------------
-- * Temporary files
--------------------------------------------------------------------------------

-- | The template of a temporary file path.
--
-- If the template is \"foo.ext\" then the created file will be \"fooXXX.ext\"
-- where XXX is some random number.
type Template = RelFile

openTemp ∷ (RegionControlIO pr, AbsRelClass ar)
         ⇒ (E.FilePath → String → IO (E.FilePath, E.Handle ReadWriteMode))
         → ( DirPath ar
           → Template
           → RegionT s pr ( AbsFile
                          , RegionalFileHandle ReadWriteMode (RegionT s pr)
                          )
           )
openTemp open = \dirPath template → unsafeControlIO $ \runInIO → mask_ $ do
  (fp, h) ← open (getPathString dirPath) (getPathString template)
  runInIO $ do
    ch ← onExit $ sanitizeIOError $ hClose h
    return (asAbsFile fp, RegionalFileHandle h ch)

-- | The function creates a temporary file in 'ReadWriteMode'. The created file
-- isn\'t deleted automatically, so you need to delete it manually.
--
-- The file is created with permissions such that only the current
-- user can read\/write it.
--
-- With some exceptions (see below), the file will be created securely in the
-- sense that an attacker should not be able to cause 'openTempFile' to
-- overwrite another file on the filesystem using your credentials, by putting
-- symbolic links (on Unix) in the place where the temporary file is to be
-- created.  On Unix the @O_CREAT@ and @O_EXCL@ flags are used to prevent this
-- attack, but note that @O_EXCL@ is sometimes not supported on NFS filesystems,
-- so if you rely on this behaviour it is best to use local filesystems only.
--
-- This provides a safer replacement for @System.IO.'SIO.openTempFile'@.
openTempFile ∷ (RegionControlIO pr, AbsRelClass ar)
             ⇒ DirPath ar -- ^ Directory in which to create the file.
             → Template   -- ^ File name template.
             → RegionT s pr ( AbsFile
                            , RegionalFileHandle ReadWriteMode (RegionT s pr)
                            )
openTempFile = openTemp E.openTempFile

-- | Like 'openTempFile', but opens the file in binary mode. See
-- 'openBinaryFile' for more comments.
--
-- This provides a safer replacement for @System.IO.'SIO.openBinaryTempFile'@.
openBinaryTempFile ∷
    (RegionControlIO pr, AbsRelClass ar)
  ⇒ DirPath ar
  → Template
  → RegionT s pr ( AbsFile
                 , RegionalFileHandle ReadWriteMode (RegionT s pr)
                 )
openBinaryTempFile = openTemp E.openBinaryTempFile

#if MIN_VERSION_base(4,2,0)
-- | Like 'openTempFile', but uses the default file permissions.
--
-- This provides a safer replacement for
-- @System.IO.'SIO.openTempFileWithDefaultPermissions'@.
openTempFileWithDefaultPermissions ∷
    (RegionControlIO pr, AbsRelClass ar)
  ⇒ DirPath ar
  → Template
  → RegionT s pr ( AbsFile
                 , RegionalFileHandle ReadWriteMode (RegionT s pr)
                 )
openTempFileWithDefaultPermissions = openTemp E.openTempFileWithDefaultPermissions

-- | Like 'openBinaryTempFile', but uses the default file permissions.
--
-- This provides a safer replacement for
-- @System.IO.'SIO.openBinaryTempFileWithDefaultPermissions'@.
openBinaryTempFileWithDefaultPermissions ∷
    (RegionControlIO pr, AbsRelClass ar)
  ⇒ DirPath ar
  → Template
  → RegionT s pr ( AbsFile
                 , RegionalFileHandle ReadWriteMode (RegionT s pr)
                 )
openBinaryTempFileWithDefaultPermissions = openTemp $ E.openBinaryTempFileWithDefaultPermissions
#endif


#if MIN_VERSION_base(4,2,0) && !defined(__NHC__) && !defined(__HUGS__)
--------------------------------------------------------------------------------
-- * Unicode encoding/decoding
--------------------------------------------------------------------------------

-- | The action 'hSetEncoding' @hdl@ @encoding@ changes the text encoding for
-- the handle @hdl@ to @encoding@.  The default encoding when a
-- handle is created is 'localeEncoding', namely the default
-- encoding for the current locale.
--
-- To create a handle with no encoding at all, use
-- 'openBinaryFile'. To stop further encoding or decoding on an existing
-- handle, use 'hSetBinaryMode'.
--
-- 'hSetEncoding' may need to flush buffered data in order to change
-- the encoding.
--
-- Wraps: @System.IO.'SIO.hSetEncoding'@.
hSetEncoding ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
             ⇒ handle ioMode pr → TextEncoding → cr ()
hSetEncoding = wrap2 E.hSetEncoding

-- | Return the current 'TextEncoding' for the specified handle,
-- or 'Nothing' if the handle is in binary mode.
--
-- Note that the 'TextEncoding' remembers nothing about the state of the
-- encoder/decoder in use on this handle. For example, if the
-- encoding in use is UTF-16, then using 'hGetEncoding' and 'hSetEncoding' to
-- save and restore the encoding may result in an extra byte-order-mark being
-- written to the file.
--
-- Wraps: @System.IO.'SIO.hGetEncoding'@.
hGetEncoding ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
             ⇒ handle ioMode pr → cr (Maybe TextEncoding)
hGetEncoding = wrap E.hGetEncoding

-- | Generalizes @System.IO.'SIO.mkTextEncoding'@ to any 'MonadIO'.
mkTextEncoding ∷ MonadIO m ⇒ String → m TextEncoding
mkTextEncoding = liftIO ∘ E.mkTextEncoding


--------------------------------------------------------------------------------
-- * Newline conversion
--------------------------------------------------------------------------------

-- | Set the 'NewlineMode' on the specified handle.
--
-- All buffered data is flushed first.
--
-- Wraps: @System.IO.'SIO.hSetNewlineMode'@.
hSetNewlineMode ∷ (FileHandle handle, pr `AncestorRegion` cr, MonadIO cr)
                ⇒ handle ioMode pr → NewlineMode → cr ()
hSetNewlineMode = wrap2 E.hSetNewlineMode
#endif


-- The End ---------------------------------------------------------------------
