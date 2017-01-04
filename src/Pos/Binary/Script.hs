module Pos.Binary.Script () where

import qualified PlutusCore.Program as PLCore
import qualified PlutusCore.Term    as PLCore
import           Universum

import           Pos.Binary.Class   (Bi (..), UnsignedVarInt (..))
import           Pos.Script.Type    (Script (..))

instance Bi PLCore.Term
instance Bi PLCore.Program

instance Bi Script where
    get = do
        UnsignedVarInt scrVersion <- get
        scrScript <- get
        return Script{..}
    put Script{..} = do
        put (UnsignedVarInt scrVersion)
        put scrScript
