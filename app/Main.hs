{-# LANGUAGE OverloadedStrings #-}
import qualified Web.AppM as W
import Control.Exception
import Control.Monad
import Control.Monad.IO.Class(liftIO)
import Control.Applicative
setting = W.setPort 8899
  $ W.setHost "*" --Support IPv6 and IPv4
  $ W.setOnException logException
  $ W.setOnExceptionResponse W.defaultOnExceptionResponse
  -- $ W.setTimeout (30*60*60) -- Seconds
  $ W.defaultSettings

logException req someException =  when (W.defaultShouldDisplayException someException == True) $ do
    putStrLn $ displayException someException
main :: IO ()
main = do
  putStrLn "Listen 8899"
  W.runSettings setting $ W.toApplication $ webapp 
  pure ()


webapp :: W.AppIO
webapp = W.appmsum -- I recommend using 'W.appmsum' for safer route management; here 'msum' is used just to demonstrate that it's a `MaybeT`.
  [ intercept -- All routes will go through it
  , W.consume "hello" >> W.respLBS W.status200 "hello" -- `/hello` will respond with "hello"
  , W.consume "api" >> W.consume "user" >> W.respJSON W.status200 (1::Int,2::Int,3::Int) -- `/api/user` will respond with "[1,2,3]"
  , W.consume "api" >> W.consumeV >>= \ x -> W.respJSON W.status200 (x::Int) -- `/api/1` will respond with "1"
  , W.consume "api" >> W.consumeV >>= \ x -> W.respJSON W.status200 (x::String) -- `/api/text` will respond with "text"
  , W.home >> W.respLBS W.status200 "home" --`/` weill repond with "home"
  , W.consume "mutiple" >> W.appmsum
      [ W.consume "one" >> W.respLBS W.status200 "one" --`/mutiple/one` will respond with `one`
      , W.consume "two" >> W.respLBS W.status200 "two" -- `/mutiple/one` will respond with `two`
      ]
  , W.consume "api" >> W.appmsum
      [ W.mGet >> W.respLBS W.status200 "I am get method" -- Getting to `/api` will respond with "I am get method"
      , W.mPost >> do                                     -- Posting to `/api` with JSON [1,2,3] will respond with "[1,2,3]"
          xs <- W.bodyJSONV
          W.respJSON W.status200 (xs::[Int]) 
      ]
  ]

intercept :: W.AppIO
intercept = do
  continued <- W.queryV "continued"
  guard $  continued == False -- `/all/path?without continued=False` will continuing
  W.respLBS W.status500 "Continuing is not allowed" -- `/all/path?continued=False` will respond with "Continuing is now allowed"
  