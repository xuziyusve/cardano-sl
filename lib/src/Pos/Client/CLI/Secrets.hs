{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE Rank2Types     #-}

-- | VSS certificates and secrets related stuff.

module Pos.Client.CLI.Secrets
       ( prepareUserSecret
       ) where

import           Universum

import           Control.Lens (ix)
import           Crypto.Random (MonadRandom)

import           Pos.Core.Genesis (GeneratedSecrets (..), RichSecrets (..))
import           Pos.Crypto (SecretKey, VssKeyPair, keyGen, runSecureRandom,
                     vssKeyGen)
import           Pos.Util.UserSecret (UserSecret, usPrimKey, usVss,
                     writeUserSecret)
import           Pos.Util.Wlog (WithLogger, logInfo)

import           Pos.Client.CLI.NodeOptions (CommonNodeArgs (..))

-- | This function prepares 'UserSecret' for later usage by node. It
-- ensures that primary key and VSS key are present in
-- 'UserSecret'. They are either taken from generated secrets or
-- generated by this function using secure source of randomness.
prepareUserSecret
    :: (MonadIO m, WithLogger m)
    => CommonNodeArgs
    -> GeneratedSecrets
    -> UserSecret
    -> m (SecretKey, UserSecret)
prepareUserSecret CommonNodeArgs {devGenesisSecretI} generatedSecrets userSecret = do
    (_, userSecretWithVss) <-
        fillUserSecretVSS (rsVssKeyPair <$> predefinedRichKeys) userSecret
    fillPrimaryKey (rsPrimaryKey <$> predefinedRichKeys) userSecretWithVss
  where
    predefinedRichKeys :: Maybe RichSecrets
    predefinedRichKeys =
        devGenesisSecretI >>= \i -> gsRichSecrets generatedSecrets ^? ix i

-- Make sure UserSecret contains a primary key.
fillPrimaryKey ::
       (MonadIO m, WithLogger m)
    => Maybe SecretKey
    -> UserSecret
    -> m (SecretKey, UserSecret)
fillPrimaryKey = fillUserSecretPart (snd <$> keyGen) usPrimKey "signing key"

-- Make sure UserSecret contains a VSS key.
fillUserSecretVSS ::
       (MonadIO m, WithLogger m)
    => Maybe VssKeyPair
    -> UserSecret
    -> m (VssKeyPair, UserSecret)
fillUserSecretVSS = fillUserSecretPart vssKeyGen usVss "VSS keypair"

-- Make sure UserSecret contains something.
fillUserSecretPart ::
       (MonadIO m, WithLogger m)
    => (forall n. MonadRandom n =>
                      n a)
    -> (Lens' UserSecret (Maybe a))
    -> Text
    -> Maybe a
    -> UserSecret
    -> m (a, UserSecret)
fillUserSecretPart genValue l description desiredValue userSecret = do
    toSet <- getValueToSet
    let newUS = userSecret & l .~ Just toSet
    (toSet, newUS) <$ writeUserSecret newUS
  where
    getValueToSet
        | Just desired <- desiredValue = pure desired
        | Just existing <- userSecret ^. l = pure existing
        | otherwise = do
            logInfo $
                "Found no " <> description <>
                " in keyfile, generating random one..."
            liftIO (runSecureRandom genValue)
