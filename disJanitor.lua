local options = require("options")
local timer = require("timer")
local json = require("json")
local fs = require("fs")

local discordia = require("discordia")
local client = discordia.Client()
discordia.extensions()

-- load managed channels list
local managedFilename = "managed.json"
local messagedUsersFilename = "messagedUsers.json"
local managed
do
	local raw = fs.readFileSync(managedFilename)
	if not raw or raw == "" then
		managed = {}
		fs.writeFileSync(managedFilename, json.encode(managed))
	else
		managed = json.decode(raw)
	end
end
local messagedUsers
do
	local raw = fs.readFileSync(messagedUsersFilename)
	if not raw or raw == "" then
		messagedUsers = {}
		fs.writeFileSync(messagedUsersFilename, json.encode(messagedUsers))
	else
		messagedUsers = json.decode(raw)
	end
end

local colors = {
	good = discordia.Color.fromHex("0080ff").value,
	bad = discordia.Color.fromHex("ff0000").value,
}

local function escapePatterns(str)
	return str:gsub("([^%w])", "%%%1")
end

local function stripPrefix(str, prefix, client)
	return str:gsub("^"..escapePatterns(prefix),""):gsub("^%<%@%!?"..client.user.id.."%>%s+","")
end

local function logError(guild, err)
	client.owner:send{embed={
		title = "Bot crashed!",
		description = "```\n"..err.."```",
		color = colors.bad,
		timestamp = discordia.Date():toISO('T', 'Z'),
		footer = {
			text = "Guild: "..guild.name.." ("..guild.id..")"
		}
	}}
	print("Bot crashed! Guild: "..guild.name.." ("..guild.id..")\n"..err)
end

local function checkPermissions(message, doReply)
	local member = message.guild:getMember(message.author)
	if message.author.id == message.guild.ownerId or member:hasRole(options.staffRoleId) then
		return true
	end
	if doReply then
		message:reply{embed={
			title = "Permission denied",
			description = "You do not have permission to run this command.",
			color = colors.bad
		}}
	end
	return false
end

client:on("ready", function()
	if #client.guilds>1 then
		print("ERROR: This bot is designed to be used in one guild at a time. Shutting down now.")
		client:stop()
		return
	end
	client:setGame{type=2, name="message notification sounds | "..options.prefix.."help"}
end)

client:on("guildCreate", function(guild)
	if #client.guilds>1 then
		client.owner:send("ERROR: This bot is designed to be used in one guild at a time. Shutting down now.")
		print("ERROR: This bot is designed to be used in one guild at a time. Shutting down now.")
		client:stop()
		return
	end
end)

client:on("messageCreate", function(message)
	local success, err = xpcall(function()
		-- safety checks
		if message.author == client.user then return end
		if not message.guild then return end

		local botMember = message.guild:getMember(client.user)

		if managed[message.channel.id] and not checkPermissions(message, false) then
			if not botMember:hasPermission(message.channel, "manageMessages") then
				managed[message.channel.id] = nil
				fs.writeFileSync(managedFilename, json.encode(managed))
				message:reply{
					content="<@&280011595105697792>",
					embed={
						title = "Missing permissions",
						description = "This bot no longer has the Manage Messages permission (needed to delete messages) in this channel, so it has been automatically removed from the list of managed channels. Please give this bot that permission in this channel, then add the channel to the list again using `"..options.prefix.."addchannel #"..message.channel.name.."`.",
						color = colors.bad
					}
				}
				return
			end
			timer.sleep(options.deleteTime)
			if message:delete() and not message.author.bot and not messagedUsers[message.author.id] then
				message.author:send{embed={
					title = "Message removed",
					description = "This is a notification that your message in `#"..message.channel.name.."` in the **"..message.guild.name.."** server has been automatically removed to keep the channel clean. Please feel free to ask for help in `#"..options.helpChannelName.."` if you need it.",
					footer = {
						text = "This message will only be sent once."
					},
					color = colors.good
				}}
				messagedUsers[message.author.id] = true
				fs.writeFileSync(messagedUsersFilename, json.encode(messagedUsers))
			end
			return
		end

		-- more safety checks
		if message.author.bot then return end

		-- commands (this is not a complicated bot, so a full command handler isn't really necessary)
		local content = stripPrefix(message.content, options.prefix, client)
		if message.content == content then return end -- if content is unchanged, there was no valid command prefix
		local command = content:match("^(%S+)")
		local args = content:split("%s+")
		table.remove(args, 1)

		if command == "help" then
			message:reply{
				embed = {
					title = "Help menu",
					color = colors.good,
					fields = {
						{name = "addchannel", value = "Adds a channel to the list of managed channels. Messages sent in these channels will be automatically deleted after "..options.deleteTime/1000 .." second"..(options.deleteTime==1000 and "" or "s")..". Messages sent by staff will not be auto-deleted. Also, this bot's commands will not work in these channels (other bots' commands still will, though).\nUsage: `"..options.prefix.."addchannel <#channel>`\n*Staff only.*"},
						{name = "delchannel", value = "Removes a channel from the list of managed channels.\nUsage: `"..options.prefix.."delchannel <#channel>`\n*Staff only.*"},
						{name = "help", value = "Displays this help menu.\nUsage: `"..options.prefix.."help`"},
						{name = "listchannels", value = "Displays the list of managed channels.\nUsage: `"..options.prefix.."listchannels`\n*Staff only.*"},
					}
				}
			}

		elseif command == "addchannel" and checkPermissions(message, true) then
			local channel = message.mentionedChannels.first
			if not channel then
				message:reply{embed={
					title = "Incorrect usage",
					description = "Command usage: `"..options.prefix.."addchannel <#channel>`",
					color = colors.bad
				}}
				return
			elseif managed[channel.id] then
				message:reply{embed={
					title = "Invalid argument",
					description = channel.mentionString.." is already on the list of managed channels, so it cannot be added to the list.",
					color = colors.bad
				}}
				return
			elseif not botMember:hasPermission(channel, "manageMessages") then
				message:reply{embed={
					title = "Invalid argument",
					description = "This bot doesn't have the Manage Messages permission (needed to delete messages) in "..channel.mentionString..", so it cannot be added to the list of managed channels.",
					color = colors.bad
				}}
				return
			end
			managed[channel.id] = true
			fs.writeFileSync(managedFilename, json.encode(managed))
			message:reply{embed={
				title = "Channel added",
				description = channel.mentionString.." has been added to the list of managed channels. Messages in that channel will now be automatically deleted after "..options.deleteTime/1000 .." second"..(options.deleteTime==1000 and "" or "s")..".",
				color = colors.good
			}}

		elseif command == "delchannel" and checkPermissions(message, true) then
			local channel = message.mentionedChannels.first
			if not channel then
				message:reply{embed={
					title = "Incorrect usage",
					description = "Command usage: `"..options.prefix.."delchannel <#channel>`",
					color = colors.bad
				}}
				return
			elseif not managed[channel.id] then
				message:reply{embed={
					title = "Invalid argument",
					description = channel.mentionString.." is not on the list of managed channels, so it cannot be removed from the list.",
					color = colors.bad
				}}
				return
			end
			managed[channel.id] = nil
			fs.writeFileSync(managedFilename, json.encode(managed))
			message:reply{embed={
				title = "Channel removed",
				description = channel.mentionString.." has been removed from the list of managed channels.",
				color = colors.good
			}}

		elseif command == "listchannels" and checkPermissions(message, true) then
			local channels = ""
			for id, _ in pairs(managed) do
				channels = channels.."<#"..id..">\n"
			end
			message:reply{embed={
				title = "Managed channels",
				description = channels~="" and channels or "There are currently no managed channels.",
				color = colors.good
			}}

		end
	end, debug.traceback)
	if not success then
		logError(message.guild, err)
	end
end)

client:run("Bot "..options.token)
