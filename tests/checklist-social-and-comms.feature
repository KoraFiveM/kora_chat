# Converted from the communitybot legacy tests by kora-qa-panel/scripts/convert-legacy.mjs.
# The """ block under each Scenario is the original test text, verbatim. Review before applying.
Feature: kora_chat — Social & Comms

  @kora_chat @checklist @checklist:kora_chat:open-chat @cat:social-and-comms
  Scenario: Open chat with T and send message
    """
    Checklist test: Press T, type text, Enter: message shows as character-named local chat; Escape closes. Key rebindable in FiveM settings.
    """
    When I press the "T" key
    And I manually: type a short message and press Enter
    Then I confirm: the message shows as local chat labelled with my character name
    When I press the "T" key
    And I manually: press Escape
    Then I confirm: the chat input closes
    When I manually: open FiveM settings and rebind the chat key
    Then I confirm: the chat opens with the new key

  @kora_chat @checklist @checklist:kora_chat:local-range @cat:social-and-comms @manual
  Scenario: Local chat limited to 20 m
    """
    Checklist test: Two players: nearby one sees the message, one 20+ m away does not.
    """
    When I manually: ask a second player to stand within 20 metres of me and a third player to stand more than 20 metres away
    And I manually: send a local chat message
    Then I confirm: the nearby player sees the message
    And I confirm: the player more than 20 metres away does not see the message

  @kora_chat @checklist @checklist:kora_chat:me-command @cat:social-and-comms
  Scenario: /me action with overhead text
    """
    Checklist test: Run /me <action>; nearby players see it in chat and as overhead text above the sender for ~5s.
    """
    When I manually: ask a second player to stand near me
    And I run the command "/me"
    And I manually: type a short action such as waves after /me and press Enter
    Then I confirm: the nearby player sees the action in their chat
    And I confirm: the nearby player sees overhead text above me
    When I wait 5 seconds
    Then I confirm: the overhead text above me has disappeared after about 5 seconds

  @kora_chat @checklist @checklist:kora_chat:ooc-command @cat:social-and-comms @manual
  Scenario: /ooc global out-of-character
    """
    Checklist test: Run /ooc <text>: all players see it, labelled with the account name rather than character name.
    """
    When I manually: ask a second player to be online anywhere on the server
    And I manually: run /ooc hello
    Then I confirm: the other player sees the message labelled with my account name and not my character name

  @kora_chat @checklist @checklist:kora_chat:say-command @cat:social-and-comms
  Scenario: /say from console and in game
    """
    Checklist test: /say <text> sends local chat in game (console version posts as OOC from 'console').
    """
    When I run the command "/say"
    And I manually: type a short text after /say and press Enter
    Then I confirm: the text appears as local chat in game
    When I manually: ask an admin to run say with some text from the server console
    Then I confirm: the console message appears as OOC from console

  @kora_chat @checklist @checklist:kora_chat:history-scroll @cat:social-and-comms
  Scenario: Scroll chat history
    """
    Checklist test: With input open scroll history using mouse wheel or PageUp/PageDown; history stays a fixed-height region.
    """
    When I manually: send enough chat messages to fill the history
    And I press the "T" key
    And I manually: scroll the history with the mouse wheel and with PageUp/PageDown
    Then I confirm: older messages scroll into view
    And I confirm: the history stays a fixed-height region and the input does not move

  @kora_chat @checklist @checklist:kora_chat:fade @cat:social-and-comms
  Scenario: Chat fades after idle
    """
    Checklist test: Close the input: messages fade out after ~8s and reappear when chat is opened.
    """
    When I manually: send a chat message and close the chat input
    And I wait 10 seconds
    Then I confirm: the messages have faded out after about 8 seconds
    When I press the "T" key
    Then I confirm: the messages reappear

  @kora_chat @checklist @checklist:kora_chat:suggestions @cat:social-and-comms
  Scenario: Command suggestions with argument completion
    """
    Checklist test: Type '/' to see command list with help; typing arguments shows value suggestions (e.g. /weather types).
    """
    When I press the "T" key
    And I manually: type /
    Then I confirm: a list of commands with help text is shown
    When I manually: type /weather followed by a space
    Then I confirm: value suggestions for the argument are shown, such as weather types

  @kora_chat @checklist @checklist:kora_chat:clearchat @cat:social-and-comms
  Scenario: /clearchat clears own feed
    """
    Checklist test: Run /clearchat: only your own chat history is cleared, others unaffected.
    """
    When I manually: ask a second player to stay nearby with chat messages visible
    And I manually: send a chat message so both players see it
    And I run the command "/clearchat"
    Then I confirm: my own chat history is cleared
    And I confirm: the other player's chat history is not cleared

  @kora_chat @checklist @checklist:kora_chat:rate-limit @cat:social-and-comms
  Scenario: Message length and spam limits
    """
    Checklist test: Send messages faster than 500ms apart or over 400 characters: they are rejected/trimmed.
    """
    When I manually: send two chat messages less than 500ms apart
    Then I should see a notification containing "You are sending messages too quickly. Slow down."
    When I manually: send a message longer than 400 characters
    Then I should see a notification containing "Your message is too long"

  @kora_chat @checklist @checklist:kora_chat:compat-events @cat:social-and-comms @manual
  Scenario: Stock chat events/exports work
    """
    Checklist test: Other resources calling chat:addMessage / addSuggestion / registerMode show messages and suggestions normally.
    """
    When I manually: trigger another resource that calls chat:addMessage, chat:addSuggestion or registerMode
    Then I confirm: the message shows in the chat normally
    And I confirm: the added suggestion shows normally when I type /
