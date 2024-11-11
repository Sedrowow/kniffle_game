# kniffel_game

Kniffel in Flutter project. Below are all things to be done and things that are done

- BUGFIX it an exception occurs if player 1 is turn after first round
- BUGFIX if the player 1 is being a bot, it always gets an exception after the first round
- BUGFIX if a bot is playing, the player can still click on the dice
- BUGFIX the LLM didnt always made correct responses
- BUGFIX the saving feauture is not working, causes exception with outdated packages
- FIXME bonus calulation is implemented, but in total score player display its not showing the bonus as well as in the round end
- BUGFIX dice display is not displaying properly
- BUG if the ai or openai difficulty are skipping entry it causes the player not to be able to roll again
- BUGFIX scorecard not displaying properly
- BUGFIX scorecard display is out of bounds

## READ THIS

the ai difficulty needs ollama installed on the local device with the model "llama3.2" pulled

after installing ollama just run in CMD "ollama pull llama3.2" while ollama is running to be able to use ai difficulty

the openai difficulty requires a openai api key, which is not included in this export. for a working openai difficulty, you need to get an api key from openai and replace the key in the .env in the asstets folder.

## Features

- plays kniffel with 0 players up to almost infinite players
- 5 different difficulties from easy to hard and an ai and openai difficulty
- let the bots play against each other by having no player (0 players means that all players are bots)
