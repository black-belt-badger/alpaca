module Main (main) where

import CommandParser (commandParserInfo)
import Options.Applicative (execParser)

main :: IO ()
main = execParser commandParserInfo >>= print
