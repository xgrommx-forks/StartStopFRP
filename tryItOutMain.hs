{-# LANGUAGE RecursiveDo #-}

import TryItOut
import Data.Monoid
import Control.Applicative

data DrawPlot x y = PlotLine [VectorP Plot] Color
                  | PlotPoint (VectorP Plot) Color Float
                  | PlotBlank
                  | PlotVertLine x Color
                  | PlotHorizLine y Color
                  | PlotGrid Color
                  | Plots [DrawPlot x y]
                  | Vector (VectorP Plot) Color

rseq xs = reallySeqList xs xs
instance Monoid (DrawPlot x y) where
  mempty = PlotBlank
  mappend PlotBlank p = p
  mappend p PlotBlank = p
  mappend (Plots ps1) (Plots ps2) = Plots $ rseq $ ps1 <> ps2
  mappend (Plots ps1) p2 = Plots $ rseq $ ps1 <> [p2]
  mappend p1 (Plots ps2) = Plots $ rseq $ [p1] <> ps2
  mappend p1 p2 = Plots $ rseq $ [p1] <> [p2]

data Axis x y = Axis (DrawPlot x y) (x, y) (x, y)

rad2deg :: Float -> Float
rad2deg rad = rad / pi * 180

deg2rad :: Float -> Float
deg2rad deg = deg / 180 * pi

drawAxis :: Conversion -> DrawPlot Float Float -> Picture
drawAxis convInfo drawPlots = plotToPic drawPlots
  where
    (lx, ly) = lowerBound convInfo
    (ux, uy) = upperBound convInfo

    pointToScreen = runVectorP . plot2screen convInfo

    plotToPic (PlotLine path c) = color c $ line $ fmap pointToScreen path
    plotToPic (PlotPoint point c r) = color c $ uncurry translate (pointToScreen point) $ circleSolid r
    plotToPic PlotBlank = Blank
    plotToPic (PlotVertLine x c) = color c $ line [pointToScreen (plotVector (x, ly)), pointToScreen (plotVector (x, uy))]
    plotToPic (PlotHorizLine y c) = color c $ line [pointToScreen (plotVector (lx, y)), pointToScreen (plotVector (ux, y))]
    plotToPic (PlotGrid c) = color c $ foldMap (plotToPic . flip PlotVertLine c . fromIntegral) [floor lx .. ceiling ux] <> foldMap (plotToPic . flip PlotHorizLine c . fromIntegral) [floor ly .. ceiling uy]
    plotToPic (Plots ps) = foldMap plotToPic ps
    plotToPic (Vector v c) = color c $ vectorPic convInfo (plot2screen convInfo v)


vectorPic :: Conversion -> VectorP Screen -> Picture
vectorPic con (PlotVector x y) = line [(ox, oy) , rotateScale aHead] <> line [rotateScale aHead, rotateScale aBack1] <> line [rotateScale aHead, rotateScale aBack2]
  where
    (ox,oy)  = runVectorP $ plot2screen con (plotVector (0,0))
    aHead = (1, 0)
    headLen = 0.1
    aBack1 = (1 - headLen, headLen)
    aBack2 = (1 - headLen, negate headLen)

    rotateScale (a,b) = ((x - ox) * a - (y - oy) * b + ox, a * (y - oy) + b * (x - ox) + oy)

plot :: [VectorP Plot] -> Color -> DrawPlot x y
plot = PlotLine

plotAxis :: DrawPlot Float Float
plotAxis = PlotHorizLine 0 black <> PlotVertLine 0 black

data VectorP plot = PlotVector { vx :: !Float, vy :: !Float } deriving(Show)

runVectorP :: VectorP plot -> (Float, Float)
runVectorP (PlotVector x y) = (x, y)

data Plot
data Screen

data Bijection a b = Bijection { fun :: a -> b, inverse :: b -> a }
type VTrans = Bijection (VectorP Plot) (VectorP Screen)

data Conversion = Conversion { lowerBound :: (Float, Float)
                             , upperBound :: (Float, Float)
                             , screenSize :: (Float, Float)
                             }

plotVector :: (Float, Float) -> VectorP Plot
plotVector = uncurry PlotVector

screenVector :: (Float, Float) -> VectorP Screen
screenVector = uncurry PlotVector

screen2plot :: Conversion -> VectorP Screen -> VectorP Plot
screen2plot = inverse . trans

plot2screen :: Conversion -> VectorP Plot -> VectorP Screen
plot2screen = fun . trans

trans :: Conversion -> VTrans
trans con = Bijection fun inv
  where
    (lx, ly) = lowerBound con
    (ux, uy) = upperBound con
    (sw, sh) = screenSize con

    pointToScreenScaleX = sw / (ux - lx)
    pointToScreenScaleY = sh / (uy - ly)

    fun (PlotVector x y) = screenVector (pointToScreenScaleX * (x - ((ux + lx) / 2)), pointToScreenScaleY * (y - ((uy + ly) / 2)))
    inv (PlotVector sx sy) = plotVector (sx / pointToScreenScaleX + (ux + lx) / 2, sy / pointToScreenScaleY + (uy + ly) / 2)

(<<>*>) = liftA2 (<>)

add :: VectorP p -> VectorP p -> VectorP p
add (PlotVector x1 y1) (PlotVector x2 y2) = uncurry PlotVector (x1 + x2, y1 + y2)

scaleV :: Float -> VectorP p -> VectorP p
scaleV s (PlotVector x y) = uncurry PlotVector (s * x, s * y)

main = tryItOut $ \clock events -> do
  let convInfo = Conversion (-5, -3) (15, 15) (800, 800)

  bMouseVector <- fmap (fmap screenVector) $ bMousePos events
  let bPlotMouse = fmap (screen2plot convInfo) bMouseVector
      bPlotVector = fmap (\vp -> Vector vp green) bPlotMouse

  (bIVector, bJVector) <- bMouseDrag bPlotMouse events convInfo
  let bBasisGrid = gridForBasis <$> bIVector <*> bJVector
      bAVector = liftA2 (\i j -> scaleV 3 i `add` scaleV 2 j) bIVector bJVector

  return $ fmap (drawAxis convInfo) $ pure (PlotGrid (makeColor 0.2 0.2 0.2 0.2)) <<>*> pure plotAxis <<>*> bBasisGrid <<>*> fmap (`Vector` green) bIVector <<>*> fmap (`Vector` red) bJVector <<>*> fmap (`Vector` orange) bAVector

dist :: VectorP p -> VectorP p -> Float
dist (PlotVector x1 y1) (PlotVector x2 y2) = sqrt ((x2 - x1) ^ 2 + (y2 - y1) ^ 2)

gridForBasis :: VectorP Plot -> VectorP Plot -> DrawPlot Float Float
gridForBasis (PlotVector x y) (PlotVector a b) = foldMap igridn [-100 .. 100] <> foldMap jgridn [-100 .. 100]
  where
    gridColor = makeColor 0.2 0.2 0.9 0.5
    igridn n = PlotLine [plotVector (x2, y2), plotVector (x3, y3)] gridColor
      where
        x1 = n * x
        y1 = n * y
        x2 = x1 + a * 100
        y2 = y1 + b * 100
        x3 = x1 - a * 100
        y3 = y1 - b * 100

    jgridn n = PlotLine [plotVector (x2, y2), plotVector (x3, y3)] gridColor
      where
        x1 = n * a
        y1 = n * b
        x2 = x1 + x * 100
        y2 = y1 + y * 100
        x3 = x1 - x * 100
        y3 = y1 - y * 100

data IJ = I | J | None deriving (Eq, Show)
bMouseDrag :: Reactive t (VectorP Plot) -> EvStream t Event -> Conversion -> Behavior t (Reactive t (VectorP Plot), Reactive t (VectorP Plot))
bMouseDrag bPlotVector evs convInfo = do
  let mouseClicks = filterMap isMouseClickEvent evs

  rec
    bIVector <- holdEs (plotVector (1, 0)) evIVector
    bJVector <- holdEs (plotVector (0, 1)) evJVector

    let isMouseDrag :: VectorP Plot -> VectorP Plot -> Event -> Maybe IJ
        isMouseDrag currentI currentJ (EventKey (MouseButton LeftButton) Down _ pos)
          | dist currentI (screen2plot convInfo (screenVector pos)) < 0.5 = Just I
          | dist currentJ (screen2plot convInfo (screenVector pos)) < 0.5 = Just J
          | otherwise = Nothing
        isMouseDrag _ _ (EventKey (MouseButton LeftButton) Up _ _) = Just None
        isMouseDrag _ _ _ = Nothing

    bDragging <- holdEs None (filterMap id $ isMouseDrag <$> bIVector <*> bJVector <@> mouseClicks)

    let evIVector = gate (fmap (==I) bDragging) $ filterMap (fmap (screen2plot convInfo. screenVector) . isMouseChange) evs
        evJVector = gate (fmap (==J) bDragging) $ filterMap (fmap (screen2plot convInfo. screenVector) . isMouseChange) evs

  return (bIVector, bJVector)
