# disJanitor
Small Discord bot to auto-delete messages sent in specified channels in a single server.

## Important note

This bot **has not been designed for multi-server use**, and by default will shut itself down if it is in more than one server. The main issues are the lack of per-server configuration for prefix, delete time, and staff roles / command permissions. The reason for this is simply that I designed this bot for a specific task in one server, so it would have been a waste of effort to implement multi-server support when I don't need it to do that.

## Installation

1. Install [Luvit](https://luvit.io) and [Discordia](https://github.com/SinisterRectus/Discordia).
2. Download `disJanitor.lua` and place it in your Luvit directory.
3. Create a file named `options.lua` with the below template.
4. Run the bot with the command `./luvit disJanitor.lua` (Unix) or `luvit disJanitor.lua` (Windows).

## Options

Put this in a file named `options.lua` in your bot directory.

```lua
return {
	token = "", -- your Discord bot token
	prefix = "", -- command prefix
	deleteTime = 1000, -- delay in milliseconds before messages will be deleted
	staffRoleId = "", -- id of the role permitted to use staff commands
}
```
