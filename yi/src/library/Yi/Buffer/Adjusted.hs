-- This module re-exports Yi.Buffer overriding insert* and delete* functions
-- with their more indent-aware variants. It is intended to be imported
-- instead of Yi.Buffer or qualified to avoid name clashes.

module Yi.Buffer.Adjusted
    ( bdeleteB
    , insertB
    , insertN
    , insertN'
    , insertNAt
    , insertNAt'
    , deleteB
    , deleteN
    , deleteRegionB
    , deleteRegionWithStyleB
    , module Yi.Buffer
    ) where

import Control.Applicative
import Control.Monad
import qualified Data.Rope as R

import Yi.Buffer hiding
    ( bdeleteB
    , insertB
    , insertN
    , insertN'
    , insertNAt
    , insertNAt'
    , deleteB
    , deleteN
    , deleteNAt
    , deleteRegionB
    , deleteRegionWithStyleB
    )
import qualified Yi.Buffer as B
import Yi.Misc
import Yi.Utils

insertNAt' :: R.Rope -> Point -> BufferM ()
insertNAt' rope point | R.countNewLines rope > 0 = B.insertNAt' rope point
insertNAt' rope point = B.insertNAt' rope point >> adjBlock (R.length rope) 

-- | Insert the list at specified point, extending size of buffer
insertNAt :: String -> Point -> BufferM ()
insertNAt cs = insertNAt' (R.fromString cs)

-- | Insert the list at current point, extending size of buffer
insertN :: String -> BufferM ()
insertN cs = insertNAt cs =<< pointB

insertN' :: R.Rope -> BufferM ()
insertN' rope = insertNAt' rope =<< pointB

-- | Insert the char at current point, extending size of buffer
insertB :: Char -> BufferM ()
insertB c = B.insertB c >> adjBlock 1

-- | @deleteNAt n p@ deletes @n@ characters forwards from position @p@
deleteNAt :: Direction -> Int -> Point -> BufferM ()
deleteNAt dir n pos = do
  els <- R.take n <$> streamB Forward pos
  applyUpdate (Delete pos dir els)
  when (R.countNewLines els == 0) $
      adjBlock (-(R.length els))

deleteN :: Int -> BufferM ()
deleteN n = pointB >>= deleteNAt Forward n

deleteB :: TextUnit -> Direction -> BufferM ()
deleteB unit dir = deleteRegionB =<< regionOfPartNonEmptyB unit dir

bdeleteB :: BufferM ()
bdeleteB = deleteB Character Backward

deleteRegionB :: Region -> BufferM ()
deleteRegionB r =
    deleteNAt (regionDirection r)
              (fromIntegral (regionEnd r ~- regionStart r))
              (regionStart r)

deleteRegionWithStyleB :: Region -> RegionStyle -> BufferM Point
deleteRegionWithStyleB reg Block = savingPointB $ do
    (start, lengths) <- shapeOfBlockRegionB reg
    moveTo start
    forM_ (zip [1..] lengths) $ \(i, l) -> do
        deleteN l
        moveTo start
        lineMoveRel i
    case lengths of
        [l] -> adjBlock (-l)
        _ -> return ()
    return start

deleteRegionWithStyleB reg style = savingPointB $ do
    effectiveRegion <- convertRegionToStyleB reg style
    deleteRegionB effectiveRegion
    return $! regionStart effectiveRegion