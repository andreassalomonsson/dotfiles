import XMonad
import XMonad.Actions.CycleWS
import XMonad.Hooks.SetWMName
import XMonad.Layout.ShowWName
import qualified Data.Map as M

main = xmonad $ defaultConfig
    { startupHook = setWMName "LG3D"
    , layoutHook = showWName $ layoutHook defaultConfig
    , keys = myKeys <+> keys defaultConfig
    , normalBorderColor = "#073642"
    , focusedBorderColor = "#839496"
    }

myKeys conf@(XConfig { XMonad.modMask = modmask }) = M.fromList
    [ ((modmask,               xK_l), nextWS)
    , ((modmask,               xK_h), prevWS)
    , ((modmask .|. shiftMask, xK_l), shiftToNext)
    , ((modmask .|. shiftMask, xK_h), shiftToPrev)
    , ((modmask,               xK_k), nextScreen)
    , ((modmask,               xK_j), prevScreen)
    , ((modmask .|. shiftMask, xK_k), shiftNextScreen)
    , ((modmask .|. shiftMask, xK_j), shiftPrevScreen)
    , ((modmask,               xK_z), toggleWS)
    ]
