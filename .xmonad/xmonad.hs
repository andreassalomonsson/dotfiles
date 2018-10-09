import XMonad
import XMonad.Actions.CycleWS
import XMonad.Hooks.SetWMName
import XMonad.Layout.ShowWName
import XMonad.StackSet
import qualified Data.Map as M

main = xmonad $ def
    { startupHook = setWMName "LG3D"
    , layoutHook = showWName $ layoutHook def
    , modMask = mod4Mask
    , keys = myKeys <+> keys def
    , normalBorderColor = "#073642"
    , focusedBorderColor = "#839496"
    }

myKeys conf@(XConfig { XMonad.modMask = modmask }) = M.fromList
    [((m .|. modmask, k), windows $ f i)
        | (i, k) <- zip (XMonad.workspaces conf) [xK_ampersand, xK_bracketleft, xK_braceleft, xK_braceright, xK_parenleft
                                                 ,xK_equal, xK_asterisk, xK_parenright, xK_plus, xK_bracketright, xK_exclam]
        , (f, m) <- [(view, 0), (shift, shiftMask)]]
